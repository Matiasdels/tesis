using FutbolStats.Api.Services;
using Xunit;

namespace FutbolStats.Tests;

// ── Helpers ──────────────────────────────────────────────────────────────────
file static class P
{
    public static InfoJugador T(int id, string n = "T") => new(id, n, true);
    public static InfoJugador S(int id, string n = "S") => new(id, n, false);
    public static InfoEvento  Cambio(int sale, int entra) =>
        new(PlantelPartidoStateBuilder.NombreCambio, sale, entra);
    public static InfoEvento Roja(int id) =>
        new(PlantelPartidoStateBuilder.NombreTarjetaRoja, id, null);
}

// ── PlantelPartidoStateBuilder ────────────────────────────────────────────────
public class PlantelStateBuilderTests
{
    // 1. Sin eventos: titulares en cancha, suplentes disponibles, sin sustituidos ni expulsados.
    [Fact]
    public void EstadoInicial_SinEventos()
    {
        var alin = new[] { P.T(1), P.T(2), P.S(10), P.S(11) };

        var estado = PlantelPartidoStateBuilder.Reconstruir(alin, []);

        Assert.Equal(2, estado.EnCancha.Count);
        Assert.Equal(2, estado.SuplentesDisponibles.Count);
        Assert.Empty(estado.Sustituidos);
        Assert.Empty(estado.Expulsados);
        Assert.Contains(estado.EnCancha, j => j.JugadorId == 1);
        Assert.Contains(estado.EnCancha, j => j.JugadorId == 2);
        Assert.Contains(estado.SuplentesDisponibles, j => j.JugadorId == 10);
        Assert.Contains(estado.SuplentesDisponibles, j => j.JugadorId == 11);
    }

    // 2. Un cambio: titular sale, suplente entra — todas las colecciones correctas.
    [Fact]
    public void Cambio_TitularSaleSuplenteEntra_EstadoCorrecto()
    {
        var alin = new[] { P.T(1), P.T(2), P.S(10) };
        var evs  = new[] { P.Cambio(1, 10) };

        var estado = PlantelPartidoStateBuilder.Reconstruir(alin, evs);

        Assert.Equal(2, estado.EnCancha.Count);
        Assert.Contains(estado.EnCancha, j => j.JugadorId == 2);
        Assert.Contains(estado.EnCancha, j => j.JugadorId == 10);
        Assert.Empty(estado.SuplentesDisponibles);
        Assert.Single(estado.Sustituidos);
        Assert.Equal(1, estado.Sustituidos[0].JugadorId);
        Assert.Empty(estado.Expulsados);
    }

    // 3. El jugador que salió no está en EnCancha tras el cambio.
    [Fact]
    public void Cambio_SalienteNoEstaEnCanchaPostCambio()
    {
        var alin = new[] { P.T(1), P.S(10) };
        var evs  = new[] { P.Cambio(1, 10) };

        var estado = PlantelPartidoStateBuilder.Reconstruir(alin, evs);

        Assert.DoesNotContain(estado.EnCancha, j => j.JugadorId == 1);
    }

    // 4. El jugador que entró no está en SuplentesDisponibles tras el cambio.
    [Fact]
    public void Cambio_EntranteNoEsDisponiblePostCambio()
    {
        var alin = new[] { P.T(1), P.S(10) };
        var evs  = new[] { P.Cambio(1, 10) };

        var estado = PlantelPartidoStateBuilder.Reconstruir(alin, evs);

        Assert.DoesNotContain(estado.SuplentesDisponibles, j => j.JugadorId == 10);
    }

    // 5. Tres cambios consecutivos sin límite máximo — estado final correcto.
    [Fact]
    public void MultiplesCAmbios_EstadoFinalCorrecto()
    {
        var alin = new[] { P.T(1), P.T(2), P.T(3), P.S(10), P.S(11), P.S(12) };
        var evs  = new[] { P.Cambio(1, 10), P.Cambio(2, 11), P.Cambio(3, 12) };

        var estado = PlantelPartidoStateBuilder.Reconstruir(alin, evs);

        Assert.Equal(3, estado.EnCancha.Count);
        Assert.Contains(estado.EnCancha, j => j.JugadorId == 10);
        Assert.Contains(estado.EnCancha, j => j.JugadorId == 11);
        Assert.Contains(estado.EnCancha, j => j.JugadorId == 12);
        Assert.Empty(estado.SuplentesDisponibles);
        Assert.Equal(3, estado.Sustituidos.Count);
        Assert.Empty(estado.Expulsados);
    }

    // 6. Tarjeta roja a jugador en cancha: sale de EnCancha y va a Expulsados.
    [Fact]
    public void TarjetaRoja_JugadorEnCancha_MueveAExpulsados()
    {
        var alin = new[] { P.T(1), P.T(2) };
        var evs  = new[] { P.Roja(1) };

        var estado = PlantelPartidoStateBuilder.Reconstruir(alin, evs);

        Assert.Single(estado.EnCancha);
        Assert.Equal(2, estado.EnCancha[0].JugadorId);
        Assert.Single(estado.Expulsados);
        Assert.Equal(1, estado.Expulsados[0].JugadorId);
    }

    // 7. Tarjeta roja a suplente en banca: sale de SuplentesDisponibles y va a Expulsados.
    [Fact]
    public void TarjetaRoja_JugadorBanquillo_SaleDeDisponibles()
    {
        var alin = new[] { P.T(1), P.S(10) };
        var evs  = new[] { P.Roja(10) };

        var estado = PlantelPartidoStateBuilder.Reconstruir(alin, evs);

        Assert.Single(estado.EnCancha);
        Assert.Empty(estado.SuplentesDisponibles);
        Assert.Single(estado.Expulsados);
        Assert.Equal(10, estado.Expulsados[0].JugadorId);
    }

    // 8. Cambio seguido de expulsión — estado combinado correcto.
    [Fact]
    public void CambioYExpulsion_EstadoCombinado()
    {
        var alin = new[] { P.T(1), P.T(2), P.T(3), P.S(10) };
        var evs  = new[] { P.Cambio(1, 10), P.Roja(2) };

        var estado = PlantelPartidoStateBuilder.Reconstruir(alin, evs);

        Assert.Equal(2, estado.EnCancha.Count);
        Assert.Contains(estado.EnCancha, j => j.JugadorId == 3);
        Assert.Contains(estado.EnCancha, j => j.JugadorId == 10);
        Assert.Single(estado.Sustituidos);
        Assert.Equal(1, estado.Sustituidos[0].JugadorId);
        Assert.Single(estado.Expulsados);
        Assert.Equal(2, estado.Expulsados[0].JugadorId);
    }

    // 9. Evento de tipo desconocido es ignorado silenciosamente.
    [Fact]
    public void EventoTipoDesconocido_NoModificaEstado()
    {
        var alin    = new[] { P.T(1), P.S(10) };
        var eventos = new[] { new InfoEvento("Gol", 1, null) };

        var estado = PlantelPartidoStateBuilder.Reconstruir(alin, eventos);

        Assert.Single(estado.EnCancha);
        Assert.Single(estado.SuplentesDisponibles);
        Assert.Empty(estado.Sustituidos);
        Assert.Empty(estado.Expulsados);
    }

    // 10. Reconstrucción idempotente: mismas entradas producen el mismo resultado.
    [Fact]
    public void ReconstruccionIdempotente_MismoResultado()
    {
        var alin = new[] { P.T(1), P.T(2), P.S(10) };
        var evs  = new[] { P.Cambio(1, 10) };

        var estado1 = PlantelPartidoStateBuilder.Reconstruir(alin, evs);
        var estado2 = PlantelPartidoStateBuilder.Reconstruir(alin, evs);

        Assert.Equal(estado1.EnCancha.Select(j => j.JugadorId).OrderBy(x => x),
                     estado2.EnCancha.Select(j => j.JugadorId).OrderBy(x => x));
        Assert.Equal(estado1.Sustituidos.Select(j => j.JugadorId),
                     estado2.Sustituidos.Select(j => j.JugadorId));
    }

    // ── Hallazgo 3.7: tarjeta roja a jugador ya sustituido ───────────────────

    // 11. Roja a jugador sustituido: aparece en Expulsados.
    [Fact]
    public void TarjetaRoja_JugadorYaSustituido_ApareceeEnExpulsados()
    {
        // J1 sale, J10 entra; luego J1 recibe roja estando en Sustituidos.
        var alin = new[] { P.T(1), P.T(2), P.S(10) };
        var evs  = new[] { P.Cambio(1, 10), P.Roja(1) };

        var estado = PlantelPartidoStateBuilder.Reconstruir(alin, evs);

        Assert.Contains(estado.Expulsados, j => j.JugadorId == 1);
    }

    // 12. Roja a jugador sustituido: sigue apareciendo también en Sustituidos.
    [Fact]
    public void TarjetaRoja_JugadorYaSustituido_SigueSiendoSustituido()
    {
        var alin = new[] { P.T(1), P.T(2), P.S(10) };
        var evs  = new[] { P.Cambio(1, 10), P.Roja(1) };

        var estado = PlantelPartidoStateBuilder.Reconstruir(alin, evs);

        Assert.Contains(estado.Sustituidos, j => j.JugadorId == 1);
    }

    // 13. Roja a jugador sustituido: no afecta al jugador que entró en su lugar.
    [Fact]
    public void TarjetaRoja_JugadorYaSustituido_NoAfectaAlEntrante()
    {
        var alin = new[] { P.T(1), P.T(2), P.S(10) };
        var evs  = new[] { P.Cambio(1, 10), P.Roja(1) };

        var estado = PlantelPartidoStateBuilder.Reconstruir(alin, evs);

        Assert.Contains(estado.EnCancha, j => j.JugadorId == 10);
        Assert.DoesNotContain(estado.Expulsados, j => j.JugadorId == 10);
    }
}

// ── CambioValidator ───────────────────────────────────────────────────────────
public class CambioValidatorTests
{
    // Construye un plantel base: T(1), T(2) en cancha; S(10) disponible.
    private static (EstadoPlantel plantel, HashSet<int> alineacionIds) PlantelBase()
    {
        var alin   = new[] { P.T(1), P.T(2), P.S(10) };
        var estado = PlantelPartidoStateBuilder.Reconstruir(alin, []);
        return (estado, new HashSet<int> { 1, 2, 10 });
    }

    // 11a. Partido finalizado: rechazado.
    [Fact]
    public void Validar_PartidoFinalizado_Rechazado()
    {
        var (plantel, ids) = PlantelBase();
        var resultado = CambioValidator.Validar("Finalizado", plantel, 1, 10, ids);
        Assert.False(resultado.EsValido);
        Assert.Equal("PartidoTerminado", resultado.CodigoError);
    }

    // 11b. Partido cancelado: también rechazado (estado terminal).
    [Fact]
    public void Validar_PartidoCancelado_Rechazado()
    {
        var (plantel, ids) = PlantelBase();
        var resultado = CambioValidator.Validar("Cancelado", plantel, 1, 10, ids);
        Assert.False(resultado.EsValido);
        Assert.Equal("PartidoTerminado", resultado.CodigoError);
    }

    // 12. Partido en curso, cambio válido: aceptado.
    [Fact]
    public void Validar_PartidoEnCurso_CambioValido_Aceptado()
    {
        var (plantel, ids) = PlantelBase();
        var resultado = CambioValidator.Validar("EnCurso", plantel, 1, 10, ids);
        Assert.True(resultado.EsValido);
    }

    // 13. Cualquier estado no-Finalizado (p. ej. EsperandoPenales) permite cambios.
    [Fact]
    public void Validar_EstadoNoFinalizado_Aceptado()
    {
        var (plantel, ids) = PlantelBase();
        var resultado = CambioValidator.Validar("EsperandoPenales", plantel, 1, 10, ids);
        Assert.True(resultado.EsValido);
    }

    // 14. Mismo jugador como saliente y entrante: rechazado.
    [Fact]
    public void Validar_MismoJugador_RetornaJugadoresIguales()
    {
        var (plantel, ids) = PlantelBase();
        var resultado = CambioValidator.Validar("EnCurso", plantel, 1, 1, ids);
        Assert.False(resultado.EsValido);
        Assert.Equal("JugadoresIguales", resultado.CodigoError);
    }

    // 15. Jugador que sale no está en la alineación: rechazado.
    [Fact]
    public void Validar_JugadorSaleFueraDeAlineacion_Rechazado()
    {
        var (plantel, ids) = PlantelBase();
        var resultado = CambioValidator.Validar("EnCurso", plantel, 99, 10, ids);
        Assert.False(resultado.EsValido);
        Assert.Equal("JugadorFueraDeAlineacion", resultado.CodigoError);
        Assert.Equal(99, resultado.JugadorId);
    }

    // 16. Jugador que entra no está en la alineación: rechazado.
    [Fact]
    public void Validar_JugadorEntraFueraDeAlineacion_Rechazado()
    {
        var (plantel, ids) = PlantelBase();
        var resultado = CambioValidator.Validar("EnCurso", plantel, 1, 99, ids);
        Assert.False(resultado.EsValido);
        Assert.Equal("JugadorFueraDeAlineacion", resultado.CodigoError);
        Assert.Equal(99, resultado.JugadorId);
    }

    // 17. Jugador expulsado no puede salir por cambio.
    [Fact]
    public void Validar_JugadorSaleExpulsado_Rechazado()
    {
        var alin   = new[] { P.T(1), P.T(2), P.S(10) };
        var plantel = PlantelPartidoStateBuilder.Reconstruir(alin, [P.Roja(1)]);
        var ids    = new HashSet<int> { 1, 2, 10 };

        var resultado = CambioValidator.Validar("EnCurso", plantel, 1, 10, ids);
        Assert.False(resultado.EsValido);
        Assert.Equal("JugadorExpulsado", resultado.CodigoError);
        Assert.Equal(1, resultado.JugadorId);
    }

    // 18. Jugador expulsado no puede ingresar como entrante.
    [Fact]
    public void Validar_JugadorEntraExpulsado_Rechazado()
    {
        var alin    = new[] { P.T(1), P.T(2), P.S(10) };
        var plantel = PlantelPartidoStateBuilder.Reconstruir(alin, [P.Roja(10)]);
        var ids     = new HashSet<int> { 1, 2, 10 };

        var resultado = CambioValidator.Validar("EnCurso", plantel, 1, 10, ids);
        Assert.False(resultado.EsValido);
        Assert.Equal("JugadorExpulsado", resultado.CodigoError);
        Assert.Equal(10, resultado.JugadorId);
    }

    // 19. Jugador ya sustituido no puede volver a salir ni reingresar.
    [Fact]
    public void Validar_JugadorYaSustituido_NoReingresa()
    {
        // T(1) ya salió por T(10); ahora se intenta hacer salir a T(1) de nuevo.
        var alin    = new[] { P.T(1), P.T(2), P.S(10), P.S(11) };
        var plantel = PlantelPartidoStateBuilder.Reconstruir(alin, [P.Cambio(1, 10)]);
        var ids     = new HashSet<int> { 1, 2, 10, 11 };

        // Intenta hacer salir nuevamente a jugador 1 (ya en Sustituidos)
        var resultado = CambioValidator.Validar("EnCurso", plantel, 1, 11, ids);
        Assert.False(resultado.EsValido);
        Assert.Equal("JugadorYaSustituido", resultado.CodigoError);

        // Intenta hacer ingresar nuevamente a jugador 10 (ya entró antes, ya no es disponible)
        var resultado2 = CambioValidator.Validar("EnCurso", plantel, 2, 10, ids);
        Assert.False(resultado2.EsValido);
        Assert.Equal("JugadorQueEntraNoEstaDisponible", resultado2.CodigoError);
    }

    // 20. Suplente intenta salir por cambio sin haber entrado antes: rechazado.
    [Fact]
    public void Validar_JugadorQueSaleNoEstaEnCancha_Rechazado()
    {
        // S(10) es suplente disponible (nunca entró). No está en cancha.
        var (plantel, ids) = PlantelBase();
        var resultado = CambioValidator.Validar("EnCurso", plantel, 10, 1, ids);
        Assert.False(resultado.EsValido);
        Assert.Equal("JugadorQueSaleNoEstaEnCancha", resultado.CodigoError);
        Assert.Equal(10, resultado.JugadorId);
    }
}
