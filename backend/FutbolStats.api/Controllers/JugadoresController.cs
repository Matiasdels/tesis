using System.Text.RegularExpressions;
using FutbolStats.Api.Data;
using FutbolStats.Api.Models;
using FutbolStats.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FutbolStats.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class JugadoresController(FutbolStatsDbContext context) : ControllerBase
{
    private static readonly string[] EstadosValidos = ["Disponible", "Lesionado", "Suspendido"];

    [HttpGet]
    public async Task<IActionResult> GetJugadores([FromQuery] string? estado, [FromQuery] string? search, [FromQuery] bool activo = true)
    {
        var query = context.Jugadores.Include(j => j.Categoria).AsNoTracking().Where(j => j.Activo == activo);

        if (!string.IsNullOrWhiteSpace(estado))
        {
            query = query.Where(j => j.Estado == estado);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            query = query.Where(j =>
                j.Nombre.Contains(term) || j.Apellido.Contains(term));
        }

        var jugadores = await query
            .OrderBy(j => j.Apellido)
            .ThenBy(j => j.Nombre)
            .ToListAsync();

        return Ok(jugadores.Select(ToResponse));
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetJugador(int id)
    {
        var jugador = await context.Jugadores
            .Include(j => j.Categoria)
            .AsNoTracking()
            .FirstOrDefaultAsync(j => j.JugadorId == id);

        return jugador is null ? NotFound() : Ok(ToResponse(jugador));
    }

    [HttpPost]
    public async Task<IActionResult> CreateJugador(JugadorRequest request)
    {
        var validation = await ValidateRequest(request);
        if (validation is not null)
        {
            return validation;
        }

        var jugador = new Jugador
        {
            Nombre = BusinessRules.NormalizeRequiredText(request.Nombre, nameof(request.Nombre)),
            Apellido = BusinessRules.NormalizeRequiredText(request.Apellido, nameof(request.Apellido)),
            FechaNacimiento = request.FechaNacimiento,
            Nacionalidad = BusinessRules.NormalizeOptionalText(request.Nacionalidad),
            Dni = BusinessRules.NormalizeOptionalText(request.Dni),
            PosicionPrincipal = BusinessRules.NormalizeOptionalText(request.PosicionPrincipal),
            NumeroCamiseta = request.NumeroCamiseta,
            AlturaCm = request.AlturaCm,
            PesoKg = request.PesoKg,
            PiernaHabil = BusinessRules.NormalizeOptionalText(request.PiernaHabil),
            Estado = request.Estado,
            PartidosSuspendido = request.Estado == "Suspendido" ? request.PartidosSuspendido : null,
            FechaEstimadaRegreso = request.Estado == "Lesionado" ? request.FechaEstimadaRegreso : null,
            CategoriaId = request.CategoriaId,
            Activo = request.Activo ?? true,
        };

        context.Jugadores.Add(jugador);

        try
        {
            await context.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (IsDniDuplicate(ex))
        {
            return BadRequest("Ya existe un jugador registrado con ese DNI.");
        }

        await context.Entry(jugador).Reference(j => j.Categoria).LoadAsync();
        return CreatedAtAction(nameof(GetJugador), new { id = jugador.JugadorId }, ToResponse(jugador));
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> UpdateJugador(int id, JugadorRequest request)
    {
        var jugador = await context.Jugadores.FirstOrDefaultAsync(j => j.JugadorId == id);
        if (jugador is null)
        {
            return NotFound();
        }

        var validation = await ValidateRequest(request);
        if (validation is not null)
        {
            return validation;
        }

        jugador.Nombre = BusinessRules.NormalizeRequiredText(request.Nombre, nameof(request.Nombre));
        jugador.Apellido = BusinessRules.NormalizeRequiredText(request.Apellido, nameof(request.Apellido));
        jugador.FechaNacimiento = request.FechaNacimiento;
        jugador.Nacionalidad = BusinessRules.NormalizeOptionalText(request.Nacionalidad);
        jugador.Dni = BusinessRules.NormalizeOptionalText(request.Dni);
        jugador.PosicionPrincipal = BusinessRules.NormalizeOptionalText(request.PosicionPrincipal);
        jugador.NumeroCamiseta = request.NumeroCamiseta;
        jugador.AlturaCm = request.AlturaCm;
        jugador.PesoKg = request.PesoKg;
        jugador.PiernaHabil = BusinessRules.NormalizeOptionalText(request.PiernaHabil);
        jugador.Estado = request.Estado;
        jugador.PartidosSuspendido = request.Estado == "Suspendido" ? request.PartidosSuspendido : null;
        jugador.FechaEstimadaRegreso = request.Estado == "Lesionado" ? request.FechaEstimadaRegreso : null;
        jugador.CategoriaId = request.CategoriaId;
        if (request.Activo is not null)
        {
            jugador.Activo = request.Activo.Value;
        }

        try
        {
            await context.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (IsDniDuplicate(ex))
        {
            return BadRequest("Ya existe un jugador registrado con ese DNI.");
        }

        await context.Entry(jugador).Reference(j => j.Categoria).LoadAsync();
        return Ok(ToResponse(jugador));
    }

    [HttpGet("{id:int}/partidos")]
    public async Task<IActionResult> GetPartidosDelJugador(int id)
    {
        var jugadorExiste = await context.Jugadores.AnyAsync(j => j.JugadorId == id);
        if (!jugadorExiste) return NotFound();

        var alineaciones = await context.Alineaciones
            .Include(a => a.Partido)
                .ThenInclude(p => p!.Categoria)
            .AsNoTracking()
            .Where(a => a.JugadorId == id && a.Partido!.Activo)
            .OrderByDescending(a => a.Partido!.Fecha)
            .ToListAsync();

        if (!alineaciones.Any()) return Ok(Array.Empty<object>());

        var partidoIds = alineaciones.Select(a => a.PartidoId).ToList();
        var eventos = await context.EventosPartido
            .Include(e => e.TipoEvento)
            .AsNoTracking()
            .Where(e => e.JugadorId == id && partidoIds.Contains(e.PartidoId))
            .ToListAsync();

        var eventosPorPartido = eventos
            .GroupBy(e => e.PartidoId)
            .ToDictionary(g => g.Key, g => g.ToList());

        var resultado = alineaciones.Select(a =>
        {
            var evs = eventosPorPartido.GetValueOrDefault(a.PartidoId, []);
            return new JugadorPartidoResponse(
                a.Partido!.PartidoId,
                a.Partido.Rival,
                a.Partido.Fecha,
                a.Partido.CategoriaId,
                a.Partido.Categoria?.Nombre,
                a.Partido.TipoCompeticion,
                a.Partido.EsLocal,
                a.Partido.Estado,
                a.Partido.GolesEquipo,
                a.Partido.GolesRival,
                a.EsTitular,
                a.PosicionAsignada,
                new JugadorEstadisticasResponse(
                    evs.Count(e => e.TipoEvento?.Nombre == EventTypeNames.Gol),
                    evs.Count(e => e.TipoEvento?.Nombre == EventTypeNames.Asistencia),
                    evs.Count(e => e.TipoEvento?.Nombre == EventTypeNames.Remate || e.TipoEvento?.Nombre == EventTypeNames.RemateAlArco),
                    evs.Count(e => e.TipoEvento?.Nombre == EventTypeNames.Falta),
                    evs.Count(e => e.TipoEvento?.Nombre == EventTypeNames.TarjetaAmarilla),
                    evs.Count(e => e.TipoEvento?.Nombre == EventTypeNames.TarjetaRoja)
                )
            );
        });

        return Ok(resultado);
    }

    // GET /api/Jugadores/{id}/actividad
    // Devuelve resumen de actividad + historial cronológico para la pestaña "Carga física".
    [HttpGet("{id:int}/actividad")]
    public async Task<IActionResult> GetActividadJugador(int id)
    {
        var jugador = await context.Jugadores.AsNoTracking()
            .FirstOrDefaultAsync(j => j.JugadorId == id && j.Activo);
        if (jugador is null) return NotFound();

        // ── Partidos ─────────────────────────────────────────────────────────
        var alineaciones = await context.Alineaciones
            .Include(a => a.Partido)
            .AsNoTracking()
            .Where(a => a.JugadorId == id && a.Partido!.Activo && a.Partido.Estado == PartidoEstados.Finalizado)
            .OrderByDescending(a => a.Partido!.Fecha)
            .ToListAsync();

        var partidoIds = alineaciones.Select(a => a.PartidoId).ToHashSet();

        // Todos los cambios del jugador en esos partidos (salida o entrada).
        var cambios = await context.EventosPartido
            .AsNoTracking()
            .Where(e => partidoIds.Contains(e.PartidoId)
                     && e.TipoEvento!.Nombre == EventTypeNames.Cambio
                     && (e.JugadorId == id || e.JugadorRelacionadoId == id))
            .Select(e => new { e.PartidoId, SaleId = e.JugadorId, EntraId = e.JugadorRelacionadoId, e.Minuto })
            .ToListAsync();

        var minutoSalidaPorPartido = cambios
            .Where(c => c.SaleId == id)
            .ToDictionary(c => c.PartidoId, c => c.Minuto);
        var minutoEntradaPorPartido = cambios
            .Where(c => c.EntraId == id)
            .ToDictionary(c => c.PartidoId, c => c.Minuto);

        var cambiosIngreso = minutoEntradaPorPartido.Keys.ToHashSet();

        // ── Entrenamientos ───────────────────────────────────────────────────
        var asistencias = await context.AsistenciasEntrenamiento
            .Include(a => a.Entrenamiento)
            .AsNoTracking()
            .Where(a => a.JugadorId == id
                     && a.Asistio
                     && a.Entrenamiento!.Activo)
            .OrderByDescending(a => a.Entrenamiento!.Fecha)
            .ToListAsync();

        var totalEntrenamientos = await context.Entrenamientos
            .AsNoTracking()
            .CountAsync(e => e.CategoriaId == jugador.CategoriaId && e.Activo);

        // ── Cálculo puro ─────────────────────────────────────────────────────
        var infoAlineaciones = alineaciones.Select(a =>
        {
            int totalMin = a.Partido!.HuboAlargue ? 120 : 90;
            int jugados;
            if (a.EsTitular)
                jugados = minutoSalidaPorPartido.TryGetValue(a.PartidoId, out var sal) ? sal : totalMin;
            else
                jugados = minutoEntradaPorPartido.TryGetValue(a.PartidoId, out var ent) ? totalMin - ent : 0;

            return new InfoAlineacionAct(
                a.PartidoId, a.Partido.Fecha, a.Partido.Rival, a.EsTitular,
                a.Partido.GolesEquipo, a.Partido.GolesRival, jugados);
        }).ToList();

        var infoAsistencias = asistencias
            .Select(a => new InfoAsistenciaAct(a.Entrenamiento!.Fecha)).ToList();

        var resumen = ActividadCalculator.Calcular(infoAlineaciones, cambiosIngreso, infoAsistencias, totalEntrenamientos);

        var historial = resumen.Historial.Select(x => new ActividadItem(
            x.Tipo, x.Fecha, x.Detalle, x.Rival, x.GolesEquipo, x.GolesRival, x.MinutosJugados)).ToList();

        return Ok(new ActividadJugadorResponse(
            resumen.EntrenamientosRealizados,
            resumen.EntrenamientosConvocado,
            resumen.PartidosDisputados,
            resumen.Titularidades,
            resumen.IngresosDesdeBanco,
            resumen.MinutosDisputados,
            resumen.UltimaActividad,
            historial));
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> DeactivateJugador(int id)
    {
        var jugador = await context.Jugadores.FirstOrDefaultAsync(j => j.JugadorId == id);
        if (jugador is null)
        {
            return NotFound();
        }

        var estadosTerminales = PartidoEstados.Terminales.ToArray();
        var partidoActivo = await context.Alineaciones
            .Include(a => a.Partido)
            .AsNoTracking()
            .Where(a => a.JugadorId == id
                     && a.Partido!.Activo
                     && !estadosTerminales.Contains(a.Partido.Estado))
            .OrderBy(a => a.Partido!.Fecha)
            .Select(a => new { a.Partido!.Rival, a.Partido.Fecha, a.Partido.Estado })
            .FirstOrDefaultAsync();

        if (partidoActivo is not null)
        {
            throw new DomainConflictException(
                $"No se puede dar de baja al jugador porque esta en la alineacion " +
                $"del partido contra {partidoActivo.Rival}.");
        }

        jugador.Activo = false;
        await context.SaveChangesAsync();
        return NoContent();
    }

    private async Task<IActionResult?> ValidateRequest(JugadorRequest request)
    {
        // Obligatorios: formato texto
        if (!EsTextoNombre(request.Nombre))
            return BadRequest("El nombre solo puede contener letras, espacios y guiones.");

        if (request.Nombre.Trim().Length > 100)
            return BadRequest("El nombre no puede superar los 100 caracteres.");

        if (!EsTextoNombre(request.Apellido))
            return BadRequest("El apellido solo puede contener letras, espacios y guiones.");

        if (request.Apellido.Trim().Length > 100)
            return BadRequest("El apellido no puede superar los 100 caracteres.");

        // Estado
        if (!EstadosValidos.Contains(request.Estado))
            return BadRequest($"Estado inválido. Valores permitidos: {string.Join(", ", EstadosValidos)}.");

        // Categoría
        var categoriaExiste = await context.Categorias.AnyAsync(c => c.CategoriaId == request.CategoriaId);
        if (!categoriaExiste)
            return BadRequest("La categoría indicada no existe.");

        // Opcionales con restricciones
        if (request.NumeroCamiseta is not null && (request.NumeroCamiseta < 0 || request.NumeroCamiseta > 99))
            return BadRequest("El numero de camiseta debe estar entre 0 y 99.");

        if (request.AlturaCm is not null && (request.AlturaCm < 140 || request.AlturaCm > 220))
            return BadRequest("La altura debe estar entre 140 y 220 cm.");

        if (request.PesoKg is not null && (request.PesoKg < 45 || request.PesoKg > 160))
            return BadRequest("El peso debe estar entre 45 y 160 kg.");

        if (request.FechaNacimiento is not null)
        {
            var edad = EdadEnAnios(request.FechaNacimiento.Value);
            if (edad < 10 || edad > 60)
                return BadRequest("La fecha de nacimiento debe corresponder a una edad entre 10 y 60 años.");
        }

        if (!string.IsNullOrWhiteSpace(request.Nacionalidad) && request.Nacionalidad.Trim().Length > 50)
            return BadRequest("La nacionalidad no puede superar los 50 caracteres.");

        if (!string.IsNullOrWhiteSpace(request.Dni))
        {
            var dni = request.Dni.Trim();
            if (dni.Length > 20)
                return BadRequest("El DNI no puede superar los 20 caracteres.");
            if (!Regex.IsMatch(dni, @"^[a-zA-Z0-9]+$"))
                return BadRequest("El DNI solo puede contener letras y números.");
        }

        if (request.Estado == "Suspendido" && request.PartidosSuspendido.HasValue && request.PartidosSuspendido < 0)
            return BadRequest("Los partidos de suspensión no pueden ser negativos.");

        return null;
    }

    private static bool EsTextoNombre(string valor) =>
        !string.IsNullOrWhiteSpace(valor) && Regex.IsMatch(valor.Trim(), @"^[\p{L}\s'\-]+$");

    private static int EdadEnAnios(DateOnly fechaNacimiento)
    {
        var hoy = DateOnly.FromDateTime(DateTime.Today);
        var edad = hoy.Year - fechaNacimiento.Year;
        if (fechaNacimiento > hoy.AddYears(-edad)) edad--;
        return edad;
    }

    private static bool IsDniDuplicate(DbUpdateException ex) =>
        ex.InnerException?.Message.Contains("IX_Jugadores_DNI") == true ||
        ex.InnerException?.Message.Contains("UQ_Jugadores_DNI") == true;

    private static JugadorResponse ToResponse(Jugador jugador)
    {
        return new JugadorResponse(
            jugador.JugadorId,
            jugador.Nombre,
            jugador.Apellido,
            jugador.FechaNacimiento,
            jugador.Nacionalidad,
            jugador.Dni,
            jugador.PosicionPrincipal,
            jugador.NumeroCamiseta,
            jugador.AlturaCm,
            jugador.PesoKg,
            jugador.PiernaHabil,
            jugador.Estado,
            jugador.CategoriaId,
            jugador.Categoria?.Nombre,
            jugador.Activo,
            jugador.PartidosSuspendido,
            jugador.FechaEstimadaRegreso);
    }
}

public record JugadorRequest(
    string Nombre,
    string Apellido,
    DateOnly? FechaNacimiento,
    string? Nacionalidad,
    string? Dni,
    string? PosicionPrincipal,
    int? NumeroCamiseta,
    decimal? AlturaCm,
    decimal? PesoKg,
    string? PiernaHabil,
    string Estado,
    int CategoriaId,
    bool? Activo,
    int? PartidosSuspendido,
    DateOnly? FechaEstimadaRegreso);

public record JugadorResponse(
    int JugadorId,
    string Nombre,
    string Apellido,
    DateOnly? FechaNacimiento,
    string? Nacionalidad,
    string? Dni,
    string? PosicionPrincipal,
    int? NumeroCamiseta,
    decimal? AlturaCm,
    decimal? PesoKg,
    string? PiernaHabil,
    string Estado,
    int CategoriaId,
    string? CategoriaNombre,
    bool Activo,
    int? PartidosSuspendido,
    DateOnly? FechaEstimadaRegreso);

public record JugadorEstadisticasResponse(
    int Goles,
    int Asistencias,
    int Remates,
    int Faltas,
    int Amarillas,
    int Rojas);

public record JugadorPartidoResponse(
    int PartidoId,
    string Rival,
    DateTime Fecha,
    int CategoriaId,
    string? CategoriaNombre,
    string TipoCompeticion,
    bool EsLocal,
    string Estado,
    int? GolesEquipo,
    int? GolesRival,
    bool EsTitular,
    string? PosicionAsignada,
    JugadorEstadisticasResponse Estadisticas);


public record ActividadItem(
    string   Tipo,        // "Partido" | "Entrenamiento"
    DateTime Fecha,
    string   Detalle,     // "Titular" | "Ingresó desde el banco" | "No ingresó" | "Asistió"
    string?  Rival,
    int?     GolesEquipo,
    int?     GolesRival,
    int?     MinutosJugados);   // null para entrenamientos

public record ActividadJugadorResponse(
    int       EntrenamientosRealizados,
    int       EntrenamientosConvocado,
    int       PartidosDisputados,
    int       Titularidades,
    int       IngresosDesdeBanco,
    int       MinutosDisputados,
    DateTime? UltimaActividad,
    List<ActividadItem> Historial);
