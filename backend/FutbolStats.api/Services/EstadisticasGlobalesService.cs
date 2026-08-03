using FutbolStats.Api.Data;
using Microsoft.EntityFrameworkCore;

namespace FutbolStats.Api.Services;

// ── Records de entrada (pure; sin dependencia de EF) ─────────────────────────

public record InfoPartidoEst(
    int    PartidoId,
    string Rival,
    DateTime Fecha,
    int    GolesEquipo,
    int    GolesRival);

public record InfoEventoEst(
    int    PartidoId,
    int    JugadorId,
    string NombreJugador,
    string TipoNombre);

// ── DTOs de respuesta ─────────────────────────────────────────────────────────

public record ResumenGlobalResponse(
    int    PartidosJugados,
    int    Victorias,
    int    Empates,
    int    Derrotas,
    int    GolesFavor,
    int    GolesContra,
    int    DiferenciaGoles,
    double PorcentajeVictorias,
    List<RendimientoRecienteItem> RendimientoReciente,
    List<TopJugadorItem>         TopGoleadores,
    List<TopJugadorItem>         TopAsistidores);

public record RendimientoRecienteItem(
    int    PartidoId,
    string Rival,
    int    GolesFavor,
    int    GolesContra,
    string Resultado,    // "G" | "E" | "P"
    DateTime Fecha);

public record TopJugadorItem(
    int    JugadorId,
    string Nombre,
    int    Cantidad);

// ── Calculador puro (sin EF; testeable directamente) ─────────────────────────

public static class EstadisticasCalculator
{
    public static ResumenGlobalResponse Calcular(
        IReadOnlyList<InfoPartidoEst> partidos,
        IReadOnlyList<InfoEventoEst>  eventos)
    {
        var jugados   = partidos.Count;
        var victorias = partidos.Count(p => p.GolesEquipo > p.GolesRival);
        var empates   = partidos.Count(p => p.GolesEquipo == p.GolesRival);
        var derrotas  = partidos.Count(p => p.GolesEquipo < p.GolesRival);
        var golesFavor  = partidos.Sum(p => p.GolesEquipo);
        var golesContra = partidos.Sum(p => p.GolesRival);
        var diferencia  = golesFavor - golesContra;
        var porcentaje  = jugados == 0
            ? 0.0
            : Math.Round((double)victorias / jugados * 100, 1);

        var recientes = partidos
            .OrderByDescending(p => p.Fecha)
            .Take(5)
            .Select(p => new RendimientoRecienteItem(
                p.PartidoId,
                p.Rival,
                p.GolesEquipo,
                p.GolesRival,
                p.GolesEquipo > p.GolesRival ? "G"
                    : p.GolesEquipo == p.GolesRival ? "E" : "P",
                p.Fecha))
            .ToList();

        // Solo contar eventos de partidos incluidos en la lista.
        var partidoIds = partidos.Select(p => p.PartidoId).ToHashSet();
        var eventosFiltrados = eventos.Where(e => partidoIds.Contains(e.PartidoId));

        var topGoleadores = eventosFiltrados
            .Where(e => e.TipoNombre == EventTypeNames.Gol)
            .GroupBy(e => new { e.JugadorId, e.NombreJugador })
            .Select(g => new TopJugadorItem(g.Key.JugadorId, g.Key.NombreJugador, g.Count()))
            .OrderByDescending(x => x.Cantidad)
            .ThenBy(x => x.Nombre)          // desempate: nombre ascendente
            .Take(3)
            .ToList();

        var topAsistidores = eventosFiltrados
            .Where(e => e.TipoNombre == EventTypeNames.Asistencia)
            .GroupBy(e => new { e.JugadorId, e.NombreJugador })
            .Select(g => new TopJugadorItem(g.Key.JugadorId, g.Key.NombreJugador, g.Count()))
            .OrderByDescending(x => x.Cantidad)
            .ThenBy(x => x.Nombre)
            .Take(3)
            .ToList();

        return new ResumenGlobalResponse(
            jugados, victorias, empates, derrotas,
            golesFavor, golesContra, diferencia, porcentaje,
            recientes, topGoleadores, topAsistidores);
    }
}

// ── Servicio con acceso a BD ──────────────────────────────────────────────────

public class EstadisticasGlobalesService(FutbolStatsDbContext context)
{
    private static readonly HashSet<string> TiposRelevantes = [EventTypeNames.Gol, EventTypeNames.Asistencia];

    public async Task<ResumenGlobalResponse> GetResumenGlobalAsync()
    {
        // Solo partidos finalizados y activos con marcador definido.
        var partidos = await context.Partidos
            .AsNoTracking()
            .Where(p => p.Activo
                     && p.Estado == PartidoEstados.Finalizado
                     && p.GolesEquipo != null
                     && p.GolesRival  != null)
            .Select(p => new InfoPartidoEst(
                p.PartidoId,
                p.Rival,
                p.Fecha,
                p.GolesEquipo!.Value,
                p.GolesRival!.Value))
            .ToListAsync();

        if (partidos.Count == 0)
            return EstadisticasCalculator.Calcular([], []);

        var ids = partidos.Select(p => p.PartidoId).ToHashSet();

        // Solo eventos de tipo Gol o Asistencia de esos partidos.
        var eventos = await (
            from e in context.EventosPartido
            join t in context.TiposEvento on e.TipoEventoId equals t.TipoEventoId
            join j in context.Jugadores   on e.JugadorId      equals j.JugadorId
            where ids.Contains(e.PartidoId)
               && TiposRelevantes.Contains(t.Nombre)
               && e.JugadorId != null
            select new InfoEventoEst(
                e.PartidoId,
                j.JugadorId,
                j.Nombre + " " + j.Apellido,
                t.Nombre)
        ).AsNoTracking().ToListAsync();

        return EstadisticasCalculator.Calcular(partidos, eventos);
    }
}
