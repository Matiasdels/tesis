namespace FutbolStats.Api.Services;

public record EjecucionPenal(string Equipo, string Resultado);

public record PenalValidationResult(
    bool EsValido,
    string? CodigoError = null,
    string? Mensaje = null,
    int? NumeroEjecucion = null)
{
    public static readonly PenalValidationResult Ok = new(true);

    public static PenalValidationResult Error(
        string codigoError,
        string mensaje,
        int? numeroEjecucion = null) =>
        new(false, codigoError, mensaje, numeroEjecucion);
}

public static class PenalShootoutValidator
{
    // Valida la plausibilidad del resultado declarado, sin requerir detalle.
    public static PenalValidationResult ValidarResultado(int equipo, int rival)
    {
        if (equipo < 0 || rival < 0)
            return PenalValidationResult.Error(
                "ResultadoNegativo",
                "Los resultados de penales no pueden ser negativos.");

        if (equipo == rival)
            return PenalValidationResult.Error(
                "ResultadoEmpatado",
                "El resultado de penales debe tener un ganador.");

        var max  = Math.Max(equipo, rival);
        var min  = Math.Min(equipo, rival);
        var diff = Math.Abs(equipo - rival);

        if (max > 5 && diff != 1)
            return PenalValidationResult.Error(
                "ResultadoImposible",
                "Resultado imposible: cuando algún equipo supera 5 goles la diferencia debe ser exactamente 1.");

        if (max == 5 && min < 3)
            return PenalValidationResult.Error(
                "ResultadoImposible",
                "Resultado imposible: con 5 goles, el rival debe haber convertido al menos 3.");

        if (max == 4 && min == 0)
            return PenalValidationResult.Error(
                "ResultadoImposible",
                "Resultado imposible: con 4 goles, el rival debe haber convertido al menos 1.");

        return PenalValidationResult.Ok;
    }

    // Valida alternancia, coherencia de goles y progresión cronológica de la tanda.
    // No valida jugadores (requeriría acceso a BD).
    public static PenalValidationResult ValidarDetalle(
        IReadOnlyList<EjecucionPenal> detalle,
        int equipo,
        int rival)
    {
        // 1. Alternancia
        for (var i = 1; i < detalle.Count; i++)
        {
            if (detalle[i].Equipo == detalle[i - 1].Equipo)
                return PenalValidationResult.Error(
                    "AlternanciaInvalida",
                    $"Los equipos deben alternar sus ejecuciones (error en ejecución #{i + 1}).",
                    i + 1);
        }

        // 2. Coherencia goles detalle vs resultado declarado
        var golesEquipo = detalle.Count(d => d.Equipo == "Propio" && d.Resultado == "Gol");
        var golesRival  = detalle.Count(d => d.Equipo == "Rival"  && d.Resultado == "Gol");

        if (golesEquipo != equipo)
            return PenalValidationResult.Error(
                "ResultadoNoCoincide",
                $"Los goles del equipo en el detalle ({golesEquipo}) no coinciden con el resultado ({equipo}).");

        if (golesRival != rival)
            return PenalValidationResult.Error(
                "ResultadoNoCoincide",
                $"Los goles del rival en el detalle ({golesRival}) no coinciden con el resultado ({rival}).");

        // 3. Progresión reglamentaria
        return ValidarProgresionSerie(detalle);
    }

    private static PenalValidationResult ValidarProgresionSerie(IReadOnlyList<EjecucionPenal> detalle)
    {
        if (detalle.Count == 0)
            return PenalValidationResult.Error(
                "SerieIncompleta",
                "La serie está incompleta: la última ejecución no define al ganador.");

        int gA = 0, gB = 0, sA = 0, sB = 0;
        var ultimaEjecucionDefineLaTanda = false;
        var primerEquipo = detalle[0].Equipo;

        for (var i = 0; i < detalle.Count; i++)
        {
            var esA           = detalle[i].Equipo == "Propio";
            var esUltimoDePar = detalle[i].Equipo != primerEquipo;
            var gol           = detalle[i].Resultado == "Gol";

            if (esA) { sA++; if (gol) gA++; }
            else     { sB++; if (gol) gB++; }

            bool terminada;

            if (sA <= 5 && sB <= 5)
            {
                // Serie inicial (5 rondas): detección anticipada cuando el rival ya no puede alcanzar al líder.
                var rA = 5 - sA;
                var rB = 5 - sB;
                terminada = gA > gB + rB || gB > gA + rA;
            }
            else if (sA > 5 && sB > 5 && sA == sB && esUltimoDePar)
            {
                // Muerte súbita: verifica al completar cada pareja (quién cierra la pareja depende de quién inició).
                terminada = gA != gB;
            }
            else
            {
                terminada = false;
            }

            if (terminada && i < detalle.Count - 1)
                return PenalValidationResult.Error(
                    "EjecucionPosteriorAlFinal",
                    $"La tanda ya estaba definida en la ejecución #{i + 1}. Las posteriores son inválidas.",
                    i + 1);

            ultimaEjecucionDefineLaTanda = terminada;
        }

        if (!ultimaEjecucionDefineLaTanda)
            return PenalValidationResult.Error(
                "SerieIncompleta",
                "La serie está incompleta: la última ejecución no define al ganador.");

        return PenalValidationResult.Ok;
    }
}
