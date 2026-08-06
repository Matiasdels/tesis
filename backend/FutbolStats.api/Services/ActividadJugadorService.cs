namespace FutbolStats.Api.Services;

// ── Records de entrada (pure; sin dependencia de EF) ─────────────────────────

public record InfoAlineacionAct(
    int      PartidoId,
    DateTime Fecha,
    string   Rival,
    bool     EsTitular,
    int?     GolesEquipo,
    int?     GolesRival,
    int      MinutosJugados);

public record InfoAsistenciaAct(DateTime Fecha);

// ── DTOs de respuesta ─────────────────────────────────────────────────────────

public record ActividadItemAct(
    string   Tipo,
    DateTime Fecha,
    string   Detalle,
    string?  Rival,
    int?     GolesEquipo,
    int?     GolesRival,
    int?     MinutosJugados);   // null para entrenamientos

public record ActividadResumenAct(
    int       EntrenamientosRealizados,
    int       EntrenamientosConvocado,
    int       PartidosDisputados,
    int       Titularidades,
    int       IngresosDesdeBanco,
    int       MinutosDisputados,
    DateTime? UltimaActividad,
    List<ActividadItemAct> Historial);

// ── Calculador puro (testeable sin EF) ───────────────────────────────────────

public static class ActividadCalculator
{
    public static ActividadResumenAct Calcular(
        IReadOnlyList<InfoAlineacionAct> alineaciones,
        IReadOnlySet<int>                cambiosIngreso,
        IReadOnlyList<InfoAsistenciaAct> asistencias,
        int                              totalEntrenamientos = 0)
    {
        int titularidades = alineaciones.Count(a => a.EsTitular);
        int ingresos      = alineaciones.Count(a => !a.EsTitular && cambiosIngreso.Contains(a.PartidoId));

        DateTime? ultimaActividad = alineaciones
            .Select(a => a.Fecha)
            .Concat(asistencias.Select(a => a.Fecha))
            .Cast<DateTime?>()
            .DefaultIfEmpty(null)
            .Max();

        int minutosDisputados = alineaciones.Sum(a => a.MinutosJugados);

        var historialPartidos = alineaciones.Select(a => new ActividadItemAct(
            "Partido",
            a.Fecha,
            a.EsTitular ? "Titular"
                : cambiosIngreso.Contains(a.PartidoId) ? "Ingresó desde el banco"
                : "No ingresó",
            a.Rival,
            a.GolesEquipo,
            a.GolesRival,
            a.MinutosJugados > 0 ? a.MinutosJugados : null));

        var historialEntrenamientos = asistencias.Select(a => new ActividadItemAct(
            "Entrenamiento", a.Fecha, "Asistió", null, null, null, null));

        var historial = historialPartidos
            .Concat(historialEntrenamientos)
            .OrderByDescending(x => x.Fecha)
            .ToList();

        return new ActividadResumenAct(
            asistencias.Count,
            Math.Max(totalEntrenamientos, asistencias.Count),
            alineaciones.Count,
            titularidades,
            ingresos,
            minutosDisputados,
            ultimaActividad,
            historial);
    }
}
