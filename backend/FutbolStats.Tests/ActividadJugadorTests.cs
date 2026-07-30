using FutbolStats.Api.Services;
using Xunit;

namespace FutbolStats.Tests;

file static class AC
{
    private static int _nextId = 1;
    private static readonly DateTime Base = new(2025, 1, 1);

    public static InfoAlineacionAct Partido(
        bool   esTitular,
        int?   id      = null,
        int    dias    = 0,
        string rival   = "Rival",
        int?   gf      = 1,
        int?   gc      = 0,
        int    minutos = 90)
        => new(id ?? _nextId++, Base.AddDays(dias), rival, esTitular, gf, gc, minutos);

    public static InfoAsistenciaAct Entrena(int dias = 0) => new(Base.AddDays(dias));

    public static ActividadResumenAct Calcular(
        IReadOnlyList<InfoAlineacionAct>?  alineaciones  = null,
        IReadOnlySet<int>?                cambiosIngreso = null,
        IReadOnlyList<InfoAsistenciaAct>? asistencias   = null)
        => ActividadCalculator.Calcular(
            alineaciones  ?? [],
            cambiosIngreso ?? new HashSet<int>(),
            asistencias   ?? []);
}

public class ActividadJugadorTests
{
    // 1. Sin actividad: todos los conteos en 0 y historial vacío.
    [Fact]
    public void SinActividad_ConteosCeroYHistorialVacio()
    {
        var r = AC.Calcular();

        Assert.Equal(0, r.PartidosDisputados);
        Assert.Equal(0, r.Titularidades);
        Assert.Equal(0, r.IngresosDesdeBanco);
        Assert.Equal(0, r.EntrenamientosRealizados);
        Assert.Equal(0, r.MinutosDisputados);
        Assert.Null(r.UltimaActividad);
        Assert.Empty(r.Historial);
    }

    // 2. Partido como titular: titularidades = 1, ingresos = 0.
    [Fact]
    public void PartidoTitular_CuentaTitularidad()
    {
        var r = AC.Calcular(alineaciones: [AC.Partido(esTitular: true, id: 10)]);

        Assert.Equal(1, r.PartidosDisputados);
        Assert.Equal(1, r.Titularidades);
        Assert.Equal(0, r.IngresosDesdeBanco);
    }

    // 3. Partido como suplente con cambio: ingreso desde el banco.
    [Fact]
    public void SuplenteCambio_CuentaIngreso()
    {
        var r = AC.Calcular(
            alineaciones:  [AC.Partido(esTitular: false, id: 5, minutos: 30)],
            cambiosIngreso: new HashSet<int> { 5 });

        Assert.Equal(1, r.IngresosDesdeBanco);
        Assert.Equal(0, r.Titularidades);
        Assert.Equal("Ingresó desde el banco", r.Historial[0].Detalle);
        Assert.Equal(30, r.Historial[0].MinutosJugados);
        Assert.Equal(30, r.MinutosDisputados);
    }

    // 4. Partido como suplente sin cambio: no ingresó, minutos = 0.
    [Fact]
    public void SuplementeSinCambio_NoIngreso()
    {
        var r = AC.Calcular(alineaciones: [AC.Partido(esTitular: false, id: 7, minutos: 0)]);

        Assert.Equal(0, r.IngresosDesdeBanco);
        Assert.Equal("No ingresó", r.Historial[0].Detalle);
        Assert.Null(r.Historial[0].MinutosJugados);
        Assert.Equal(0, r.MinutosDisputados);
    }

    // 5. Entrenamiento asistido: cuenta como entrenamientoRealizado.
    [Fact]
    public void Entrenamiento_CuentaRealizado()
    {
        var r = AC.Calcular(asistencias: [AC.Entrena()]);

        Assert.Equal(1, r.EntrenamientosRealizados);
        Assert.Equal(0, r.PartidosDisputados);
        Assert.Equal("Asistió", r.Historial[0].Detalle);
        Assert.Equal("Entrenamiento", r.Historial[0].Tipo);
        Assert.Null(r.Historial[0].MinutosJugados);
    }

    // 6. Historial ordenado por fecha descendente.
    [Fact]
    public void Historial_OrdenadoMasRecientePrimero()
    {
        var r = AC.Calcular(
            alineaciones: [AC.Partido(true, id: 1, dias: 0), AC.Partido(true, id: 2, dias: 5)],
            asistencias:  [AC.Entrena(dias: 3)]);

        // dias 5 > dias 3 > dias 0
        Assert.Equal(5, (r.Historial[0].Fecha - new DateTime(2025, 1, 1)).Days);
        Assert.Equal(3, (r.Historial[1].Fecha - new DateTime(2025, 1, 1)).Days);
        Assert.Equal(0, (r.Historial[2].Fecha - new DateTime(2025, 1, 1)).Days);
    }

    // 7. UltimaActividad es la fecha más reciente entre partidos y entrenamientos.
    [Fact]
    public void UltimaActividad_EsLaMasReciente()
    {
        var r = AC.Calcular(
            alineaciones: [AC.Partido(true, id: 1, dias: 2)],
            asistencias:  [AC.Entrena(dias: 10)]);

        Assert.Equal(new DateTime(2025, 1, 1).AddDays(10), r.UltimaActividad);
    }

    // 8. Partido titular: Detalle = "Titular", minutos presentes.
    [Fact]
    public void HistorialPartidoTitular_DetalleEsTitular()
    {
        var r = AC.Calcular(alineaciones: [AC.Partido(esTitular: true, id: 1, rival: "Defensor", gf: 2, gc: 1, minutos: 90)]);

        var item = r.Historial[0];
        Assert.Equal("Partido", item.Tipo);
        Assert.Equal("Titular", item.Detalle);
        Assert.Equal("Defensor", item.Rival);
        Assert.Equal(2, item.GolesEquipo);
        Assert.Equal(1, item.GolesRival);
        Assert.Equal(90, item.MinutosJugados);
    }

    // 9. Múltiples partidos y entrenamientos: conteos correctos.
    [Fact]
    public void MultiplesActividades_ConteosCorrectos()
    {
        var r = AC.Calcular(
            alineaciones: [
                AC.Partido(true,  id: 1, minutos: 90),
                AC.Partido(false, id: 2, minutos: 20),
                AC.Partido(false, id: 3, minutos: 0),
            ],
            cambiosIngreso: new HashSet<int> { 2 },
            asistencias: [AC.Entrena(), AC.Entrena(dias: 1)]);

        Assert.Equal(3, r.PartidosDisputados);
        Assert.Equal(1, r.Titularidades);
        Assert.Equal(1, r.IngresosDesdeBanco);
        Assert.Equal(2, r.EntrenamientosRealizados);
        Assert.Equal(110, r.MinutosDisputados); // 90 + 20 + 0
        Assert.Equal(5, r.Historial.Count);
    }

    // 10. Minutos disputados se suman correctamente entre partidos.
    [Fact]
    public void MinutosDisputados_SumaCorrectamente()
    {
        var r = AC.Calcular(alineaciones: [
            AC.Partido(true,  id: 1, minutos: 90),
            AC.Partido(true,  id: 2, minutos: 75),
            AC.Partido(false, id: 3, minutos: 0),
        ]);

        Assert.Equal(165, r.MinutosDisputados);
    }
}
