using FutbolStats.Api.Services;
using Xunit;

namespace FutbolStats.Tests;

file static class EG
{
    private static int _nextId = 1;

    public static InfoPartidoEst Partido(
        int golesEquipo, int golesRival,
        DateTime? fecha = null, string rival = "Rival",
        int? id = null)
        => new(id ?? _nextId++, rival, fecha ?? DateTime.UtcNow, golesEquipo, golesRival);

    public static InfoEventoEst Evento(
        int jugadorId, string tipo, int partidoId = 1, string nombre = "")
        => new(partidoId, jugadorId, nombre.Length > 0 ? nombre : $"Jugador{jugadorId}", tipo);

    public static ResumenGlobalResponse Calcular(
        IReadOnlyList<InfoPartidoEst> partidos,
        IReadOnlyList<InfoEventoEst>? eventos = null)
        => EstadisticasCalculator.Calcular(partidos, eventos ?? []);
}

public class EstadisticasGlobalesTests
{
    // 1. Sin partidos finalizados: todos los totales en 0.
    [Fact]
    public void SinPartidos_TodosLosTotalesEnCero()
    {
        var r = EG.Calcular([]);

        Assert.Equal(0, r.PartidosJugados);
        Assert.Equal(0, r.Victorias);
        Assert.Equal(0, r.Empates);
        Assert.Equal(0, r.Derrotas);
        Assert.Equal(0, r.GolesFavor);
        Assert.Equal(0, r.GolesContra);
        Assert.Equal(0, r.DiferenciaGoles);
        Assert.Equal(0.0, r.PorcentajeVictorias);
        Assert.Empty(r.RendimientoReciente);
        Assert.Empty(r.TopGoleadores);
        Assert.Empty(r.TopAsistidores);
    }

    // 2. Un partido ganado: victoria, goles y porcentaje correctos.
    [Fact]
    public void UnPartidoGanado_VictoriaYPorcentajeCorrectos()
    {
        var r = EG.Calcular([EG.Partido(3, 1)]);

        Assert.Equal(1, r.PartidosJugados);
        Assert.Equal(1, r.Victorias);
        Assert.Equal(0, r.Empates);
        Assert.Equal(0, r.Derrotas);
        Assert.Equal(3, r.GolesFavor);
        Assert.Equal(1, r.GolesContra);
        Assert.Equal(2, r.DiferenciaGoles);
        Assert.Equal(100.0, r.PorcentajeVictorias);
    }

    // 3. Un empate: clasificación correcta.
    [Fact]
    public void UnEmpate_ClasificadoComoEmpate()
    {
        var r = EG.Calcular([EG.Partido(2, 2)]);

        Assert.Equal(0, r.Victorias);
        Assert.Equal(1, r.Empates);
        Assert.Equal(0, r.Derrotas);
        Assert.Equal("E", r.RendimientoReciente[0].Resultado);
    }

    // 4. Una derrota: clasificación correcta.
    [Fact]
    public void UnaDerrota_ClasificadaComoDerrota()
    {
        var r = EG.Calcular([EG.Partido(0, 2)]);

        Assert.Equal(0, r.Victorias);
        Assert.Equal(0, r.Empates);
        Assert.Equal(1, r.Derrotas);
        Assert.Equal("P", r.RendimientoReciente[0].Resultado);
        Assert.Equal(-2, r.DiferenciaGoles);
    }

    // 5. Varios partidos: resumen correcto (2G + 1E + 1D).
    [Fact]
    public void VariosPartidos_ResumenCorrecto()
    {
        var partidos = new[]
        {
            EG.Partido(2, 0),
            EG.Partido(1, 1),
            EG.Partido(0, 1),
            EG.Partido(3, 2),
        };
        var r = EG.Calcular(partidos);

        Assert.Equal(4, r.PartidosJugados);
        Assert.Equal(2, r.Victorias);
        Assert.Equal(1, r.Empates);
        Assert.Equal(1, r.Derrotas);
        Assert.Equal(6,  r.GolesFavor);
        Assert.Equal(4,  r.GolesContra);
        Assert.Equal(2,  r.DiferenciaGoles);
        Assert.Equal(50.0, r.PorcentajeVictorias);
    }

    // 6. Sin partidos: no divide por cero (PorcentajeVictorias = 0).
    [Fact]
    public void SinPartidos_PorcentajeVictoriasNoEsNaN()
    {
        var r = EG.Calcular([]);

        Assert.Equal(0.0, r.PorcentajeVictorias);
        Assert.False(double.IsNaN(r.PorcentajeVictorias));
    }

    // 7. Rendimiento reciente: máximo 5 partidos en orden más reciente primero.
    [Fact]
    public void RendimientoReciente_MaximoCincoPorOrdenFecha()
    {
        var base_ = new DateTime(2025, 1, 1, 0, 0, 0, DateTimeKind.Utc);
        var partidos = Enumerable.Range(1, 7)
            .Select(i => EG.Partido(i, 0, fecha: base_.AddDays(i), id: i))
            .ToArray();

        var r = EG.Calcular(partidos);

        Assert.Equal(5, r.RendimientoReciente.Count);
        // El más reciente (día 7) debe ser el primero.
        Assert.Equal(base_.AddDays(7), r.RendimientoReciente[0].Fecha);
        Assert.Equal(base_.AddDays(6), r.RendimientoReciente[1].Fecha);
    }

    // 8. Top goleadores: agrupa por jugador y ordena por cantidad desc.
    [Fact]
    public void TopGoleadores_AgrupaYOrdena()
    {
        var partidos = new[] { EG.Partido(5, 0, id: 1) };
        var eventos = new[]
        {
            EG.Evento(1, "Gol", 1, "Valverde"),
            EG.Evento(1, "Gol", 1, "Valverde"),
            EG.Evento(1, "Gol", 1, "Valverde"),
            EG.Evento(2, "Gol", 1, "Darwin"),
            EG.Evento(2, "Gol", 1, "Darwin"),
            EG.Evento(3, "Gol", 1, "Araújo"),
        };

        var r = EG.Calcular(partidos, eventos);

        Assert.Equal(3, r.TopGoleadores.Count);
        Assert.Equal("Valverde", r.TopGoleadores[0].Nombre);
        Assert.Equal(3, r.TopGoleadores[0].Cantidad);
        Assert.Equal(2, r.TopGoleadores[1].Cantidad);
        Assert.Equal(1, r.TopGoleadores[2].Cantidad);
    }

    // 9. "Gol rival" no cuenta como gol propio en top goleadores.
    [Fact]
    public void GolRival_NoContaComoGolPropio()
    {
        var partidos = new[] { EG.Partido(0, 2, id: 1) };
        var eventos = new[]
        {
            EG.Evento(1, "Gol rival", 1, "Rival1"),
            EG.Evento(2, "Gol rival", 1, "Rival2"),
        };

        var r = EG.Calcular(partidos, eventos);

        Assert.Empty(r.TopGoleadores);
    }

    // 10. Top asistidores: agrupa y ordena correctamente.
    [Fact]
    public void TopAsistidores_AgrupaYOrdena()
    {
        var partidos = new[] { EG.Partido(3, 0, id: 1) };
        var eventos = new[]
        {
            EG.Evento(10, "Asistencia", 1, "Lamine"),
            EG.Evento(10, "Asistencia", 1, "Lamine"),
            EG.Evento(20, "Asistencia", 1, "Pedri"),
        };

        var r = EG.Calcular(partidos, eventos);

        Assert.Equal(2, r.TopAsistidores.Count);
        Assert.Equal("Lamine", r.TopAsistidores[0].Nombre);
        Assert.Equal(2, r.TopAsistidores[0].Cantidad);
        Assert.Equal("Pedri", r.TopAsistidores[1].Nombre);
        Assert.Equal(1, r.TopAsistidores[1].Cantidad);
    }

    // 11. Eventos de partidos no incluidos (no finalizados) no cuentan.
    [Fact]
    public void Eventos_DePartidoNoIncluido_NoCuentan()
    {
        // Solo el partido con ID 1 está en la lista de partidos finalizados.
        var partidos = new[] { EG.Partido(2, 0, id: 1) };
        var eventos = new[]
        {
            EG.Evento(5, "Gol", partidoId: 1,  nombre: "Titular"),  // sí cuenta
            EG.Evento(5, "Gol", partidoId: 99, nombre: "Titular"),  // partido 99 no está en la lista
        };

        var r = EG.Calcular(partidos, eventos);

        Assert.Equal(1, r.TopGoleadores[0].Cantidad); // solo el del partido 1
    }

    // 12. Desempate en top goleadores: orden alfabético por nombre.
    [Fact]
    public void TopGoleadores_Desempate_PorNombreAlfabetico()
    {
        var partidos = new[] { EG.Partido(3, 0, id: 1) };
        var eventos = new[]
        {
            EG.Evento(1, "Gol", 1, "Zelaya"),
            EG.Evento(2, "Gol", 1, "Alves"),
            EG.Evento(3, "Gol", 1, "Martínez"),
        };

        var r = EG.Calcular(partidos, eventos);

        Assert.Equal("Alves",    r.TopGoleadores[0].Nombre);
        Assert.Equal("Martínez", r.TopGoleadores[1].Nombre);
        Assert.Equal("Zelaya",   r.TopGoleadores[2].Nombre);
    }
}
