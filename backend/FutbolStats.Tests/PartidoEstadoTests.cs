using FutbolStats.Api.Services;
using Xunit;

namespace FutbolStats.Tests;

public class PartidoEstadoTransicionTests
{
    // ── Transiciones válidas ──────────────────────────────────────────────────

    [Fact]
    public void Programado_A_EnJuego_Permitida()
        => Assert.True(PartidoEstados.TransicionPermitida(
            PartidoEstados.Programado, PartidoEstados.EnJuego));

    [Fact]
    public void Programado_A_Cancelado_Permitida()
        => Assert.True(PartidoEstados.TransicionPermitida(
            PartidoEstados.Programado, PartidoEstados.Cancelado));

    [Fact]
    public void EnJuego_A_Finalizado_Permitida()
        => Assert.True(PartidoEstados.TransicionPermitida(
            PartidoEstados.EnJuego, PartidoEstados.Finalizado));

    [Fact]
    public void EnJuego_A_EsperandoPenales_Permitida()
        => Assert.True(PartidoEstados.TransicionPermitida(
            PartidoEstados.EnJuego, PartidoEstados.EsperandoPenales));

    [Fact]
    public void EnJuego_A_Cancelado_Permitida()
        => Assert.True(PartidoEstados.TransicionPermitida(
            PartidoEstados.EnJuego, PartidoEstados.Cancelado));

    [Fact]
    public void EsperandoPenales_A_Finalizado_Permitida()
        => Assert.True(PartidoEstados.TransicionPermitida(
            PartidoEstados.EsperandoPenales, PartidoEstados.Finalizado));

    [Fact]
    public void EsperandoPenales_A_Cancelado_Permitida()
        => Assert.True(PartidoEstados.TransicionPermitida(
            PartidoEstados.EsperandoPenales, PartidoEstados.Cancelado));

    // ── Mismo estado (idempotente) ────────────────────────────────────────────

    [Theory]
    [InlineData(PartidoEstados.Programado)]
    [InlineData(PartidoEstados.EnJuego)]
    [InlineData(PartidoEstados.EsperandoPenales)]
    [InlineData(PartidoEstados.Finalizado)]
    [InlineData(PartidoEstados.Cancelado)]
    public void MismoEstado_SiemprePermitido(string estado)
        => Assert.True(PartidoEstados.TransicionPermitida(estado, estado));

    // ── Transiciones prohibidas ───────────────────────────────────────────────

    [Fact]
    public void Programado_A_Finalizado_Prohibida()
        => Assert.False(PartidoEstados.TransicionPermitida(
            PartidoEstados.Programado, PartidoEstados.Finalizado));

    [Fact]
    public void Programado_A_EsperandoPenales_Prohibida()
        => Assert.False(PartidoEstados.TransicionPermitida(
            PartidoEstados.Programado, PartidoEstados.EsperandoPenales));

    [Fact]
    public void EnJuego_A_Programado_Prohibida()
        => Assert.False(PartidoEstados.TransicionPermitida(
            PartidoEstados.EnJuego, PartidoEstados.Programado));

    [Fact]
    public void EsperandoPenales_A_EnJuego_Prohibida()
        => Assert.False(PartidoEstados.TransicionPermitida(
            PartidoEstados.EsperandoPenales, PartidoEstados.EnJuego));

    [Fact]
    public void Finalizado_A_EnJuego_Prohibida()
        => Assert.False(PartidoEstados.TransicionPermitida(
            PartidoEstados.Finalizado, PartidoEstados.EnJuego));

    [Fact]
    public void Finalizado_A_Cancelado_Prohibida()
        => Assert.False(PartidoEstados.TransicionPermitida(
            PartidoEstados.Finalizado, PartidoEstados.Cancelado));

    [Fact]
    public void Cancelado_A_EnJuego_Prohibida()
        => Assert.False(PartidoEstados.TransicionPermitida(
            PartidoEstados.Cancelado, PartidoEstados.EnJuego));

    [Fact]
    public void Cancelado_A_Programado_Prohibida()
        => Assert.False(PartidoEstados.TransicionPermitida(
            PartidoEstados.Cancelado, PartidoEstados.Programado));

    // ── Conjuntos de estados ──────────────────────────────────────────────────

    [Fact]
    public void Todos_ContieneLoscincoEstados()
    {
        Assert.Contains(PartidoEstados.Programado,       PartidoEstados.Todos);
        Assert.Contains(PartidoEstados.EnJuego,          PartidoEstados.Todos);
        Assert.Contains(PartidoEstados.EsperandoPenales, PartidoEstados.Todos);
        Assert.Contains(PartidoEstados.Finalizado,       PartidoEstados.Todos);
        Assert.Contains(PartidoEstados.Cancelado,        PartidoEstados.Todos);
        Assert.Equal(5, PartidoEstados.Todos.Count);
    }

    [Fact]
    public void Terminales_ContieneFinalizadoYCancelado()
    {
        Assert.Contains(PartidoEstados.Finalizado, PartidoEstados.Terminales);
        Assert.Contains(PartidoEstados.Cancelado,  PartidoEstados.Terminales);
        Assert.Equal(2, PartidoEstados.Terminales.Count);
    }

    [Fact]
    public void PermiteEventos_ContieneEnJuegoYEsperandoPenales()
    {
        Assert.Contains(PartidoEstados.EnJuego,          PartidoEstados.PermiteEventos);
        Assert.Contains(PartidoEstados.EsperandoPenales, PartidoEstados.PermiteEventos);
        Assert.Equal(2, PartidoEstados.PermiteEventos.Count);
    }

    [Fact]
    public void PermiteModificarAlineacion_SoloProgramado()
    {
        Assert.Contains(PartidoEstados.Programado, PartidoEstados.PermiteModificarAlineacion);
        Assert.Single(PartidoEstados.PermiteModificarAlineacion);
    }
}
