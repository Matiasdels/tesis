using FutbolStats.Api.Data;
using FutbolStats.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FutbolStats.Api.Controllers;

[ApiController]
[Route("api/Partidos/{partidoId:int}/eventos")]
[Authorize]
public class EventosPartidoController(FutbolStatsDbContext context) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetEventos(int partidoId)
    {
        var existe = await context.Partidos.AnyAsync(p => p.PartidoId == partidoId);
        if (!existe) return NotFound();

        var eventos = await context.EventosPartido
            .Include(e => e.Jugador)
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

        var jugadorId = request.JugadorId is > 0 ? request.JugadorId : null;
        Console.WriteLine($"[DEBUG] JugadorId recibido: {request.JugadorId?.ToString() ?? "NULL"}, normalizado: {jugadorId?.ToString() ?? "NULL"}");

        if (jugadorId.HasValue)
        {
            var jugadorExiste = await context.Jugadores.AnyAsync(j => j.JugadorId == jugadorId && j.Activo);
            if (!jugadorExiste) return BadRequest($"El jugador indicado ({jugadorId}) no existe o está inactivo.");
        }

        var tipoExiste = await context.TiposEvento.AnyAsync(t => t.TipoEventoId == request.TipoEventoId);
        if (!tipoExiste) return BadRequest("El tipo de evento no existe.");

        if (request.Minuto < 0 || request.Minuto > 200)
            return BadRequest("El minuto debe estar entre 0 y 200.");

        var evento = new EventoPartido
        {
            PartidoId = partidoId,
            JugadorId = jugadorId,
            TipoEventoId = request.TipoEventoId,
            Minuto = request.Minuto,
            PitchX = request.PitchX,
            PitchY = request.PitchY,
            Observacion = string.IsNullOrWhiteSpace(request.Observacion) ? null : request.Observacion.Trim(),
            Periodo = string.IsNullOrWhiteSpace(request.Periodo) ? null : request.Periodo.Trim(),
            FechaRegistro = DateTime.UtcNow,
        };

        context.EventosPartido.Add(evento);
        await context.SaveChangesAsync();

        await context.Entry(evento).Reference(e => e.Jugador).LoadAsync();
        await context.Entry(evento).Reference(e => e.TipoEvento).LoadAsync();

        return CreatedAtAction(nameof(GetEventos), new { partidoId }, ToResponse(evento));
    }

    [HttpDelete("{eventoId:int}")]
    public async Task<IActionResult> DeleteEvento(int partidoId, int eventoId)
    {
        var evento = await context.EventosPartido
            .FirstOrDefaultAsync(e => e.EventoId == eventoId && e.PartidoId == partidoId);

        if (evento is null) return NotFound();

        context.EventosPartido.Remove(evento);
        await context.SaveChangesAsync();
        return NoContent();
    }

    private static EventoResponse ToResponse(EventoPartido e) => new(
        e.EventoId,
        e.PartidoId,
        e.JugadorId,
        e.Jugador is null ? null : $"{e.Jugador.Nombre} {e.Jugador.Apellido}",
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
    public int TipoEventoId { get; set; }
    public int Minuto { get; set; }
    public decimal? PitchX { get; set; }
    public decimal? PitchY { get; set; }
    public string? Observacion { get; set; }
    public string? Periodo { get; set; }
}

public record EventoResponse(
    int EventoId,
    int PartidoId,
    int? JugadorId,
    string? NombreJugador,
    int TipoEventoId,
    string TipoEventoNombre,
    int Minuto,
    decimal? PitchX,
    decimal? PitchY,
    string? Observacion,
    DateTime FechaRegistro,
    string? Periodo);
