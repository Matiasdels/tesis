using FutbolStats.Api.Services;
using Xunit;

namespace FutbolStats.Tests;

// ─────────────────────────────────────────────────────────────────────────────
// Helpers de legibilidad
// ─────────────────────────────────────────────────────────────────────────────

file static class E
{
    public static EjecucionPenal PG() => new("Propio", "Gol");
    public static EjecucionPenal PE() => new("Propio", "Errado");
    public static EjecucionPenal RG() => new("Rival",  "Gol");
    public static EjecucionPenal RE() => new("Rival",  "Errado");
}

// ─────────────────────────────────────────────────────────────────────────────
// Casos 14 y 15: ValidarResultado (sin detalle)
// ─────────────────────────────────────────────────────────────────────────────

public class ValidarResultado_Tests
{
    // Caso 15 – un resultado válido sin detalle debe aprobarse.
    [Fact]
    public void ResultadoValido_SinDetalle_DebeAprobarse()
    {
        var r = PenalShootoutValidator.ValidarResultado(3, 2);

        Assert.True(r.EsValido);
        Assert.Null(r.CodigoError);
    }

    // Caso 14 – resultado empatado debe rechazarse.
    [Fact]
    public void ResultadoEmpatado_DebeRechazarse()
    {
        var r = PenalShootoutValidator.ValidarResultado(3, 3);

        Assert.False(r.EsValido);
        Assert.Equal("ResultadoEmpatado", r.CodigoError);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Casos 1–13: ValidarDetalle (alternancia, coherencia y progresión)
// ─────────────────────────────────────────────────────────────────────────────

public class ValidarDetalle_Tests
{
    // ── Caso 1 ───────────────────────────────────────────────────────────────
    // Serie válida con equipo propio comenzando.
    // Secuencia: P-G R-G P-G R-G P-G R-E P-E R-E P-E R-E → 3-2
    // La tanda se define en la última ejecución (i=9): sA=5, sB=5, rA=0, rB=0 → 3 > 2+0 = true.
    [Fact]
    public void SerieValida_PropioComienza_DebeAprobarse()
    {
        var detalle = new List<EjecucionPenal>
        {
            E.PG(), E.RG(),   // ronda 1
            E.PG(), E.RG(),   // ronda 2
            E.PG(), E.RE(),   // ronda 3 — Rival falla
            E.PE(), E.RE(),   // ronda 4
            E.PE(), E.RE(),   // ronda 5
        };

        var r = PenalShootoutValidator.ValidarDetalle(detalle, equipo: 3, rival: 2);

        Assert.True(r.EsValido);
    }

    // ── Caso 2 ───────────────────────────────────────────────────────────────
    // Serie válida con rival comenzando.
    // Secuencia: R-G P-G R-G P-G R-E P-E R-E P-E R-E P-G → Propio 3, Rival 2
    // La tanda se define en la última ejecución (i=9): sA=5, sB=5, rA=0, rB=0 → 3 > 2+0 = true.
    // En i=8 (último tiro del Rival): sA=4, sB=5, rA=1, rB=0 → 2 > 2+0? No. No termina.
    [Fact]
    public void SerieValida_RivalComienza_DebeAprobarse()
    {
        var detalle = new List<EjecucionPenal>
        {
            E.RG(), E.PG(),   // ronda 1
            E.RG(), E.PG(),   // ronda 2
            E.RE(), E.PE(),   // ronda 3
            E.RE(), E.PE(),   // ronda 4
            E.RE(), E.PG(),   // ronda 5 — Propio define en el último tiro
        };

        var r = PenalShootoutValidator.ValidarDetalle(detalle, equipo: 3, rival: 2);

        Assert.True(r.EsValido);
    }

    // ── Caso 3 ───────────────────────────────────────────────────────────────
    // Dos ejecuciones consecutivas del mismo equipo deben rechazarse.
    [Fact]
    public void DosEjecucionesConsecutivasMismoEquipo_DebeRechazarse()
    {
        var detalle = new List<EjecucionPenal> { E.PG(), E.PG() };

        var r = PenalShootoutValidator.ValidarDetalle(detalle, equipo: 2, rival: 0);

        Assert.False(r.EsValido);
        Assert.Equal("AlternanciaInvalida", r.CodigoError);
        Assert.Equal(2, r.NumeroEjecucion);
    }

    // ── Caso 4 ───────────────────────────────────────────────────────────────
    // Resultado 3-1 con secuencia incompleta (6 ejecuciones, exactamente el spec).
    // En i=5 (3.er tiro del Rival, Errado): sA=3, sB=3, rA=2, rB=2 → 3 > 1+2 = 3? No (estricto).
    // La tanda no quedó definida → SerieIncompleta.
    [Fact]
    public void Resultado3_1_SecuenciaIncompleta_DebeRechazarse()
    {
        var detalle = new List<EjecucionPenal>
        {
            E.PG(), E.RG(),
            E.PG(), E.RE(),
            E.PG(), E.RE(),
        };

        var r = PenalShootoutValidator.ValidarDetalle(detalle, equipo: 3, rival: 1);

        Assert.False(r.EsValido);
        Assert.Equal("SerieIncompleta", r.CodigoError);
    }

    // ── Caso 5 ───────────────────────────────────────────────────────────────
    // Resultado 3-1 con secuencia válida cuya última ejecución define la tanda.
    // Secuencia: P-G R-G P-G R-E P-G R-E P-E R-E (8 ejecuciones)
    // En i=7 (4.o tiro del Rival, Errado): sA=4, sB=4, gA=3, gB=1, rA=1, rB=1 → 3 > 1+1 = 2. Termina.
    [Fact]
    public void Resultado3_1_UltimaEjecucionDefine_DebeAprobarse()
    {
        var detalle = new List<EjecucionPenal>
        {
            E.PG(), E.RG(),   // ronda 1: 1-1
            E.PG(), E.RE(),   // ronda 2: 2-1
            E.PG(), E.RE(),   // ronda 3: 3-1 (Rival no puede recuperar con rB=1)
            E.PE(), E.RE(),   // ronda 4: Rival usa su último tiro y falla → definido
        };
        // En la ronda 4, tras el fallo del Rival (i=7): sA=4, sB=4, rA=1, rB=1 → 3 > 1+1. Termina.

        var r = PenalShootoutValidator.ValidarDetalle(detalle, equipo: 3, rival: 1);

        Assert.True(r.EsValido);
    }

    // ── Caso 6 ───────────────────────────────────────────────────────────────
    // Secuencia con ejecuciones posteriores a una definición anticipada (exactamente el spec).
    // En i=5 (3.er fallo del Rival): sA=3, sB=3, gA=3, gB=0, rA=2, rB=2 → 3 > 0+2 = 2. Termina.
    // Existen i=6 y i=7 → EjecucionPosteriorAlFinal en ejecución #6.
    [Fact]
    public void EjecucionesPosterioresADefinicionAnticipada_DebeRechazarse()
    {
        var detalle = new List<EjecucionPenal>
        {
            E.PG(), E.RE(),
            E.PG(), E.RE(),
            E.PG(), E.RE(),   // i=5: tanda definida (3-0 irreversible)
            E.PE(), E.RG(),   // i=6, i=7: posteriores al final
        };

        // El R-G de la ejecución 8 suma 1 gol al Rival; la coherencia pasa con 3-1.
        // La progresión detecta que la tanda ya estaba definida en la ejecución 6.
        var r = PenalShootoutValidator.ValidarDetalle(detalle, equipo: 3, rival: 1);

        Assert.False(r.EsValido);
        Assert.Equal("EjecucionPosteriorAlFinal", r.CodigoError);
        Assert.Equal(6, r.NumeroEjecucion);
    }

    // ── Caso 7 ───────────────────────────────────────────────────────────────
    // Detalle vacío debe rechazarse como serie incompleta.
    // Con resultado 0-0 los goles coinciden (0==0), lo que aísla el chequeo de serie vacía.
    [Fact]
    public void DetalleVacio_DebeRechazarseComoSerieIncompleta()
    {
        var r = PenalShootoutValidator.ValidarDetalle([], equipo: 0, rival: 0);

        Assert.False(r.EsValido);
        Assert.Equal("SerieIncompleta", r.CodigoError);
    }

    // ── Caso 8 ───────────────────────────────────────────────────────────────
    // Una sola ejecución no puede definir la tanda: debe rechazarse como serie incompleta.
    [Fact]
    public void UnaEjecucion_DebeRechazarseComoSerieIncompleta()
    {
        var detalle = new List<EjecucionPenal> { E.PG() };

        var r = PenalShootoutValidator.ValidarDetalle(detalle, equipo: 1, rival: 0);

        Assert.False(r.EsValido);
        Assert.Equal("SerieIncompleta", r.CodigoError);
    }

    // ── Caso 9 ───────────────────────────────────────────────────────────────
    // Muerte súbita válida.
    // 5 rondas regulares terminan 3-3 → pasa a SD.
    // SD: Propio convierte, Rival falla → Propio gana 4-3.
    // En i=11 (tiro del Rival en SD): sA=6, sB=6, esUltimoDePar=true → gA(4) != gB(3). Termina.
    [Fact]
    public void MuerteSubitaValida_UnaRondaExtra_DebeAprobarse()
    {
        var detalle = new List<EjecucionPenal>
        {
            // 5 rondas: 3-3
            E.PG(), E.RG(),
            E.PG(), E.RG(),
            E.PG(), E.RG(),
            E.PE(), E.RE(),
            E.PE(), E.RE(),
            // SD ronda 1: Propio convierte, Rival falla
            E.PG(), E.RE(),
        };

        var r = PenalShootoutValidator.ValidarDetalle(detalle, equipo: 4, rival: 3);

        Assert.True(r.EsValido);
    }

    // ── Caso 10 ──────────────────────────────────────────────────────────────
    // Muerte súbita incompleta: solo ejecutó el primer equipo de la ronda SD.
    // En i=10 (tiro de Propio en SD): sA=6, sB=5 → condición SD no se activa (sB no > 5).
    // ultimaEjecucionDefineLaTanda queda false → SerieIncompleta.
    [Fact]
    public void MuerteSubitaIncompleta_SoloUnEquipoEnRondaSD_DebeRechazarse()
    {
        var detalle = new List<EjecucionPenal>
        {
            // 5 rondas: 3-3
            E.PG(), E.RG(),
            E.PG(), E.RG(),
            E.PG(), E.RG(),
            E.PE(), E.RE(),
            E.PE(), E.RE(),
            // SD ronda 1: solo Propio ejecuta
            E.PG(),
        };

        var r = PenalShootoutValidator.ValidarDetalle(detalle, equipo: 4, rival: 3);

        Assert.False(r.EsValido);
        Assert.Equal("SerieIncompleta", r.CodigoError);
    }

    // ── Caso 11 ──────────────────────────────────────────────────────────────
    // Muerte súbita con múltiples rondas.
    // Ronda SD-1: ambos convierten (4-3 → 4-4 en medio de la pareja, no: 3-3 → 4-3 tras P, 4-4 tras R).
    // Ronda SD-2: ambos fallan → sigue empatado 4-4.
    // Ronda SD-3: Propio convierte, Rival falla → 5-4. Termina.
    [Fact]
    public void MuerteSubitaVariasRondas_DefinidaEnTercerRondaSD_DebeAprobarse()
    {
        var detalle = new List<EjecucionPenal>
        {
            // 5 rondas regulares: 2-2
            E.PG(), E.RG(),
            E.PG(), E.RG(),
            E.PE(), E.RE(),
            E.PE(), E.RE(),
            E.PE(), E.RE(),
            // SD ronda 1: ambos convierten
            E.PG(), E.RG(),
            // SD ronda 2: ambos fallan
            E.PE(), E.RE(),
            // SD ronda 3: Propio convierte, Rival falla → define
            E.PG(), E.RE(),
        };

        // Propio: 2 regulares + 1 SD-1 + 1 SD-3 = 4 goles. Rival: 2 regulares + 1 SD-1 = 3 goles.
        var r = PenalShootoutValidator.ValidarDetalle(detalle, equipo: 4, rival: 3);

        Assert.True(r.EsValido);
    }

    // ── Caso 12 ──────────────────────────────────────────────────────────────
    // Ejecución posterior al final de la muerte súbita debe rechazarse.
    // Igual que caso 9 pero con un tiro extra al final.
    [Fact]
    public void EjecucionPosteriorAlFinalDeMuerteSubitaDebeRechazarse()
    {
        var detalle = new List<EjecucionPenal>
        {
            // 5 rondas: 3-3
            E.PG(), E.RG(),
            E.PG(), E.RG(),
            E.PG(), E.RG(),
            E.PE(), E.RE(),
            E.PE(), E.RE(),
            // SD: Propio convierte, Rival falla → tanda definida en i=11
            E.PG(), E.RE(),
            // i=12: ejecución posterior al final
            E.PE(),
        };

        var r = PenalShootoutValidator.ValidarDetalle(detalle, equipo: 4, rival: 3);

        Assert.False(r.EsValido);
        Assert.Equal("EjecucionPosteriorAlFinal", r.CodigoError);
        Assert.Equal(12, r.NumeroEjecucion);
    }

    // ── Caso 13 ──────────────────────────────────────────────────────────────
    // Goles calculados desde el detalle no coinciden con el resultado declarado.
    [Fact]
    public void GolesDetalleNoCoincideConResultadoDeclarado_DebeRechazarse()
    {
        // Secuencia produce Propio=3, Rival=2 (caso 1)
        var detalle = new List<EjecucionPenal>
        {
            E.PG(), E.RG(),
            E.PG(), E.RG(),
            E.PG(), E.RE(),
            E.PE(), E.RE(),
            E.PE(), E.RE(),
        };

        // Pero se declara resultado 4-2 (incorrecto)
        var r = PenalShootoutValidator.ValidarDetalle(detalle, equipo: 4, rival: 2);

        Assert.False(r.EsValido);
        Assert.Equal("ResultadoNoCoincide", r.CodigoError);
    }
}
