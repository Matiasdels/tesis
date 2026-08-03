using FutbolStats.Api.Services;
using Xunit;

namespace FutbolStats.Tests;

// Helpers reutilizables compartidos con PlantelTests.
// Duplicar solo los que no coinciden con el file static class P de PlantelTests.cs
file static class EV
{
    public static InfoJugador T(int id) => new(id, $"Titular{id}", true);
    public static InfoJugador S(int id) => new(id, $"Suplente{id}", false);
    public static InfoEvento  Cambio(int sale, int entra) =>
        new(PlantelPartidoStateBuilder.NombreCambio, sale, entra);
    public static InfoEvento  Roja(int id) =>
        new(PlantelPartidoStateBuilder.NombreTarjetaRoja, id, null);

    // Construye estado a partir de alineación + eventos en orden cronológico.
    public static EstadoPlantel Estado(
        IEnumerable<InfoJugador> lineup,
        params InfoEvento[] events)
        => PlantelPartidoStateBuilder.Reconstruir(lineup, events);
}

public class EventoValidationTests
{
    private static readonly HashSet<int> AlineacionBase = [1, 2, 3, 10, 11];

    // 1. Suplente que nunca ingresó no puede registrar un evento de campo.
    [Fact]
    public void Suplente_Nunca_Ingreso_EventoDeCampo_Rechazado()
    {
        var lineup = new[] { EV.T(1), EV.T(2), EV.S(10) };
        var plantel = EV.Estado(lineup);
        var ids     = new HashSet<int> { 1, 2, 10 };

        var r = PresenciaEnCanchaValidator.Validar("Gol", 10, plantel, ids);

        Assert.False(r.EsValido);
        Assert.Equal("JugadorNoEstaEnCancha", r.CodigoError);
    }

    // 2. Titular en cancha sí puede registrar un evento.
    [Fact]
    public void Titular_EnCancha_EventoDeCampo_Aceptado()
    {
        var lineup = new[] { EV.T(1), EV.T(2), EV.S(10) };
        var plantel = EV.Estado(lineup);
        var ids     = new HashSet<int> { 1, 2, 10 };

        var r = PresenciaEnCanchaValidator.Validar("Gol", 1, plantel, ids);

        Assert.True(r.EsValido);
    }

    // 3. Después de un cambio, el jugador entrante puede registrar eventos.
    [Fact]
    public void EntranteTrasCambio_PuedeRegistrarEventos()
    {
        var lineup  = new[] { EV.T(1), EV.T(2), EV.S(10) };
        var plantel = EV.Estado(lineup, EV.Cambio(1, 10));
        var ids     = new HashSet<int> { 1, 2, 10 };

        var r = PresenciaEnCanchaValidator.Validar("Remate", 10, plantel, ids);

        Assert.True(r.EsValido);
    }

    // 4. Después de un cambio, el jugador saliente no puede registrar eventos.
    [Fact]
    public void SalienteTrasCambio_NoRecibeEventos()
    {
        var lineup  = new[] { EV.T(1), EV.T(2), EV.S(10) };
        var plantel = EV.Estado(lineup, EV.Cambio(1, 10));
        var ids     = new HashSet<int> { 1, 2, 10 };

        var r = PresenciaEnCanchaValidator.Validar("Tarjeta amarilla", 1, plantel, ids);

        Assert.False(r.EsValido);
        Assert.Equal("JugadorSustituido", r.CodigoError);
    }

    // 5. Jugador sustituido no puede registrar eventos (código explícito).
    [Fact]
    public void JugadorSustituido_Rechazado_ConCodigoCorrecto()
    {
        var lineup  = new[] { EV.T(1), EV.S(10), EV.S(11) };
        var plantel = EV.Estado(lineup, EV.Cambio(1, 10));
        var ids     = new HashSet<int> { 1, 10, 11 };

        var r = PresenciaEnCanchaValidator.Validar("Falta", 1, plantel, ids);

        Assert.False(r.EsValido);
        Assert.Equal("JugadorSustituido", r.CodigoError);
    }

    // 6. Jugador expulsado no puede registrar eventos.
    [Fact]
    public void JugadorExpulsado_Rechazado()
    {
        var lineup  = new[] { EV.T(1), EV.T(2) };
        var plantel = EV.Estado(lineup, EV.Roja(1));
        var ids     = new HashSet<int> { 1, 2 };

        var r = PresenciaEnCanchaValidator.Validar("Remate al arco", 1, plantel, ids);

        Assert.False(r.EsValido);
        Assert.Equal("JugadorExpulsado", r.CodigoError);
    }

    // 7. Jugador fuera de la alineación es rechazado.
    [Fact]
    public void JugadorFueraDeAlineacion_Rechazado()
    {
        var lineup  = new[] { EV.T(1), EV.T(2) };
        var plantel = EV.Estado(lineup);
        var ids     = new HashSet<int> { 1, 2 };

        var r = PresenciaEnCanchaValidator.Validar("Asistencia", 99, plantel, ids);

        Assert.False(r.EsValido);
        Assert.Equal("JugadorFueraDeAlineacion", r.CodigoError);
    }

    // 8. Evento sin jugadorId (jugadorId = null): el validador no se llama;
    //    confirmamos que un null pasado indirectamente retorna Ok si se eximen los tipos.
    //    En la práctica, el controller hace un cortocircuito cuando jugadorId == null.
    //    Verificamos que el validador devuelve Ok para tipos exentos.
    [Fact]
    public void TipoExento_Cambio_ValidadorDevuelveOk()
    {
        var lineup  = new[] { EV.T(1), EV.S(10) };
        var plantel = EV.Estado(lineup);
        var ids     = new HashSet<int> { 1, 10 };

        // "Cambio" es exento: cualquier jugadorId, incluyendo uno no en cancha, pasa
        var r = PresenciaEnCanchaValidator.Validar(
            PlantelPartidoStateBuilder.NombreCambio, 10, plantel, ids);

        Assert.True(r.EsValido);
    }

    // 9. Tarjeta roja a suplente disponible: el validador la exime correctamente.
    [Fact]
    public void TarjetaRoja_Suplente_EsExenta()
    {
        var lineup  = new[] { EV.T(1), EV.S(10) };
        var plantel = EV.Estado(lineup);
        var ids     = new HashSet<int> { 1, 10 };

        // S(10) no está en cancha, pero Tarjeta roja está exenta
        var r = PresenciaEnCanchaValidator.Validar(
            PlantelPartidoStateBuilder.NombreTarjetaRoja, 10, plantel, ids);

        Assert.True(r.EsValido);
    }

    // 10. Tarjeta roja a jugador en cancha también sigue siendo válida.
    [Fact]
    public void TarjetaRoja_JugadorEnCancha_Aceptada()
    {
        var lineup  = new[] { EV.T(1), EV.T(2) };
        var plantel = EV.Estado(lineup);
        var ids     = new HashSet<int> { 1, 2 };

        var r = PresenciaEnCanchaValidator.Validar(
            PlantelPartidoStateBuilder.NombreTarjetaRoja, 1, plantel, ids);

        Assert.True(r.EsValido);
    }

    // ── Hallazgo 3.7: tarjeta roja exenta a jugador sustituido ───────────────

    // 11. Tarjeta roja a jugador ya sustituido: el validador de presencia la exime.
    [Fact]
    public void TarjetaRoja_JugadorSustituido_EsExenta()
    {
        var lineup  = new[] { EV.T(1), EV.T(2), EV.S(10) };
        var plantel = EV.Estado(lineup, EV.Cambio(1, 10));
        var ids     = new HashSet<int> { 1, 2, 10 };

        // J1 está en Sustituidos; la tarjeta roja es exenta → validador Ok
        var r = PresenciaEnCanchaValidator.Validar(
            PlantelPartidoStateBuilder.NombreTarjetaRoja, 1, plantel, ids);

        Assert.True(r.EsValido);
    }
}
