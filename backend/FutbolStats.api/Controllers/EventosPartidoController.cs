using FutbolStats.Api.Data;
using FutbolStats.Api.Models;
using FutbolStats.Api.Options;
using FutbolStats.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace FutbolStats.Api.Controllers;

[ApiController]
[Route("api/Partidos/{partidoId:int}/eventos")]
[Authorize]
public class EventosPartidoController(
    FutbolStatsDbContext context,
    ILogger<EventosPartidoController> logger,
    IOptions<MatchRulesOptions> matchRulesOptions) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetEventos(int partidoId)
    {
        var existe = await context.Partidos.AnyAsync(p => p.PartidoId == partidoId);
        if (!existe) return NotFound();

        var eventos = await context.EventosPartido
            .Include(e => e.Jugador)
            .Include(e => e.JugadorRelacionado)
            .Include(e => e.TipoEvento)
            .AsNoTracking()
            .Where(e => e.PartidoId == partidoId)
            .OrderBy(e => e.Minuto)
            .ThenBy(e => e.FechaRegistro)
            .ToListAsync();

        return Ok(eventos.Select(ToResponse));
    }

    [HttpPost]
    public async Task<IActionResult> CreateEvento(int partidoId, EventoRequest request)
    {
        var partido = await context.Partidos.AsNoTracking()
            .FirstOrDefaultAsync(p => p.PartidoId == partidoId);
        if (partido is null) return NotFound("Partido no encontrado.");

        if (!PartidoEstados.PermiteEventos.Contains(partido.Estado))
            throw new DomainConflictException(
                $"No se pueden registrar eventos en un partido con estado '{partido.Estado}'. " +
                "El partido debe estar en juego o esperando penales.");

        var jugadorId = request.JugadorId is > 0 ? request.JugadorId : null;
        logger.LogDebug("CreateEvento partido={PartidoId} jugadorId={JugadorId}", partidoId, jugadorId);

        if (jugadorId.HasValue)
        {
            var jugadorExiste = await context.Jugadores.AnyAsync(j => j.JugadorId == jugadorId && j.Activo);
            if (!jugadorExiste) return BadRequest($"El jugador indicado ({jugadorId}) no existe o está inactivo.");
        }

        var tipoEvento = await context.TiposEvento
            .AsNoTracking()
            .FirstOrDefaultAsync(t => t.TipoEventoId == request.TipoEventoId);
        if (tipoEvento is null) return BadRequest("El tipo de evento no existe.");

        if (request.Minuto < 0 || request.Minuto > 200)
            return BadRequest("El minuto debe estar entre 0 y 200.");

        int? jugadorRelacionadoId = null;

        if (tipoEvento.Nombre == PlantelPartidoStateBuilder.NombreCambio)
        {
            var validacion = await ValidarCambio(
                partido, partidoId, jugadorId, request.JugadorRelacionadoId);

            if (validacion.result is not null) return validacion.result;
            jugadorRelacionadoId = validacion.jugadorRelacionadoId;
        }
        else if (jugadorId.HasValue)
        {
            var presencia = await ValidarPresenciaEnCanchaAsync(
                partidoId, jugadorId.Value, tipoEvento.Nombre);
            if (!presencia.EsValido)
                return BadRequest(presencia.Mensaje);
        }

        var evento = new EventoPartido
        {
            PartidoId            = partidoId,
            JugadorId            = jugadorId,
            JugadorRelacionadoId = jugadorRelacionadoId,
            TipoEventoId         = request.TipoEventoId,
            Minuto               = request.Minuto,
            PitchX               = request.PitchX,
            PitchY               = request.PitchY,
            Observacion          = string.IsNullOrWhiteSpace(request.Observacion) ? null : request.Observacion.Trim(),
            Periodo              = string.IsNullOrWhiteSpace(request.Periodo) ? null : request.Periodo.Trim(),
            FechaRegistro        = DateTime.UtcNow,
        };

        context.EventosPartido.Add(evento);
        await context.SaveChangesAsync();

        await context.Entry(evento).Reference(e => e.Jugador).LoadAsync();
        await context.Entry(evento).Reference(e => e.JugadorRelacionado).LoadAsync();
        await context.Entry(evento).Reference(e => e.TipoEvento).LoadAsync();

        return CreatedAtAction(nameof(GetEventos), new { partidoId }, ToResponse(evento));
    }

    [HttpDelete("{eventoId:int}")]
    public async Task<IActionResult> DeleteEvento(int partidoId, int eventoId)
    {
        var estadoPartido = await context.Partidos
            .AsNoTracking()
            .Where(p => p.PartidoId == partidoId)
            .Select(p => (string?)p.Estado)
            .FirstOrDefaultAsync();

        if (estadoPartido is null) return NotFound("Partido no encontrado.");

        if (PartidoEstados.Terminales.Contains(estadoPartido))
            throw new DomainConflictException(
                $"No se pueden eliminar eventos de un partido que ya ha concluido " +
                $"(estado: {estadoPartido}).");

        var evento = await context.EventosPartido
            .FirstOrDefaultAsync(e => e.EventoId == eventoId && e.PartidoId == partidoId);

        if (evento is null) return NotFound();

        context.EventosPartido.Remove(evento);
        await context.SaveChangesAsync();
        return NoContent();
    }

    // Retorna (null, jugadorRelacionadoId) si válido; (IActionResult, _) si inválido.
    private async Task<(IActionResult? result, int? jugadorRelacionadoId)> ValidarCambio(
        Partido partido, int partidoId, int? jugadorSaleId, int? rawJugadorRelacionadoId)
    {
        if (!jugadorSaleId.HasValue)
            return (BadRequest("Para un Cambio, JugadorId (jugador que sale) es obligatorio."), null);

        var jugadorEntraId = rawJugadorRelacionadoId is > 0 ? rawJugadorRelacionadoId : null;
        if (!jugadorEntraId.HasValue)
            return (BadRequest("Para un Cambio, JugadorRelacionadoId (jugador que entra) es obligatorio."), null);

        var jugadorEntraExiste = await context.Jugadores
            .AnyAsync(j => j.JugadorId == jugadorEntraId && j.Activo);
        if (!jugadorEntraExiste)
            return (BadRequest($"El jugador que entra ({jugadorEntraId}) no existe o está inactivo."), null);

        var alineacion = await context.Alineaciones
            .Include(a => a.Jugador)
            .AsNoTracking()
            .Where(a => a.PartidoId == partidoId)
            .ToListAsync();

        var eventosExistentes = await context.EventosPartido
            .Include(e => e.TipoEvento)
            .AsNoTracking()
            .Where(e => e.PartidoId == partidoId)
            .OrderBy(e => e.Minuto)
            .ThenBy(e => e.FechaRegistro)
            .ToListAsync();

        var infoAlineacion = alineacion.Select(a => new InfoJugador(
            a.JugadorId,
            a.Jugador is null ? $"Jugador {a.JugadorId}" : $"{a.Jugador.Nombre} {a.Jugador.Apellido}",
            a.EsTitular)).ToList();

        var infoEventos = eventosExistentes.Select(e => new InfoEvento(
            e.TipoEvento?.Nombre ?? "",
            e.JugadorId,
            e.JugadorRelacionadoId)).ToList();

        var plantel       = PlantelPartidoStateBuilder.Reconstruir(infoAlineacion, infoEventos);
        var alineacionIds = alineacion.Select(a => a.JugadorId).ToHashSet();

        var validacion = CambioValidator.Validar(
            partido.Estado,
            plantel,
            jugadorSaleId:  jugadorSaleId.Value,
            jugadorEntraId: jugadorEntraId.Value,
            alineacionIds,
            Math.Max(0, matchRulesOptions.Value.MaxCambiosPorPartido));

        if (!validacion.EsValido)
            return (BadRequest(validacion.Mensaje), null);

        return (null, jugadorEntraId);
    }

    // Carga el plantel reconstruido y valida que el jugador esté en cancha.
    // Solo se llama cuando el tipo de evento NO es Cambio ni Tarjeta roja.
    private async Task<PresenciaValidationResult> ValidarPresenciaEnCanchaAsync(
        int partidoId, int jugadorId, string tipoEventoNombre)
    {
        // Tarjeta roja puede aplicarse a suplentes o expulsados — exento
        if (tipoEventoNombre == PlantelPartidoStateBuilder.NombreTarjetaRoja)
            return PresenciaValidationResult.Ok;

        var alineacion = await context.Alineaciones
            .Include(a => a.Jugador)
            .AsNoTracking()
            .Where(a => a.PartidoId == partidoId)
            .ToListAsync();

        var eventos = await context.EventosPartido
            .Include(e => e.TipoEvento)
            .AsNoTracking()
            .Where(e => e.PartidoId == partidoId)
            .OrderBy(e => e.Minuto)
            .ThenBy(e => e.FechaRegistro)
            .ToListAsync();

        var infoAlineacion = alineacion.Select(a => new InfoJugador(
            a.JugadorId,
            a.Jugador is null ? $"Jugador {a.JugadorId}" : $"{a.Jugador.Nombre} {a.Jugador.Apellido}",
            a.EsTitular)).ToList();

        var infoEventos = eventos.Select(e => new InfoEvento(
            e.TipoEvento?.Nombre ?? "",
            e.JugadorId,
            e.JugadorRelacionadoId)).ToList();

        var plantel       = PlantelPartidoStateBuilder.Reconstruir(infoAlineacion, infoEventos);
        var alineacionIds = alineacion.Select(a => a.JugadorId).ToHashSet();

        return PresenciaEnCanchaValidator.Validar(tipoEventoNombre, jugadorId, plantel, alineacionIds);
    }

    private static EventoResponse ToResponse(EventoPartido e) => new(
        e.EventoId,
        e.PartidoId,
        e.JugadorId,
        e.Jugador is null ? null : $"{e.Jugador.Nombre} {e.Jugador.Apellido}",
        e.JugadorRelacionadoId,
        e.JugadorRelacionado is null ? null : $"{e.JugadorRelacionado.Nombre} {e.JugadorRelacionado.Apellido}",
        e.TipoEventoId,
        e.TipoEvento?.Nombre ?? "",
        e.Minuto,
        e.PitchX,
        e.PitchY,
        e.Observacion,
        e.FechaRegistro,
        e.Periodo);
}

public class EventoRequest
{
    public int? JugadorId { get; set; }
    public int? JugadorRelacionadoId { get; set; }
    public int TipoEventoId { get; set; }
    public int Minuto { get; set; }
    public decimal? PitchX { get; set; }
    public decimal? PitchY { get; set; }
    public string? Observacion { get; set; }
    public string? Periodo { get; set; }
}

public record EventoResponse(
    int       EventoId,
    int       PartidoId,
    int?      JugadorId,
    string?   NombreJugador,
    int?      JugadorRelacionadoId,
    string?   NombreJugadorRelacionado,
    int       TipoEventoId,
    string    TipoEventoNombre,
    int       Minuto,
    decimal?  PitchX,
    decimal?  PitchY,
    string?   Observacion,
    DateTime  FechaRegistro,
    string?   Periodo);
