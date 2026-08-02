using FutbolStats.Api.Services;
using Xunit;

namespace FutbolStats.Tests;

public class BusinessRulesTests
{
    // ── NormalizeRequiredText ────────────────────────────────────────────────

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void NormalizeRequiredText_LanzaValidacion_CuandoVacio(string? valor)
    {
        var ex = Assert.Throws<DomainValidationException>(
            () => BusinessRules.NormalizeRequiredText(valor, "Campo"));

        Assert.Contains("Campo", ex.Message);
        Assert.Equal("Campo", ex.Field);
    }

    [Fact]
    public void NormalizeRequiredText_DevuelveTexto_CuandoValido()
    {
        var result = BusinessRules.NormalizeRequiredText("Hola", "Campo");
        Assert.Equal("Hola", result);
    }

    [Fact]
    public void NormalizeRequiredText_Recorta_EspaciosInicioFin()
    {
        var result = BusinessRules.NormalizeRequiredText("  Hola  ", "Campo");
        Assert.Equal("Hola", result);
    }

    [Fact]
    public void NormalizeRequiredText_DevuelveTexto_ConEspacioInterno()
    {
        var result = BusinessRules.NormalizeRequiredText("Juan Pablo", "Nombre");
        Assert.Equal("Juan Pablo", result);
    }

    [Fact]
    public void NormalizeRequiredText_EsLanzadaComoValidacion_NoArgumentException()
    {
        var ex = Record.Exception(
            () => BusinessRules.NormalizeRequiredText("", "X"));

        Assert.IsType<DomainValidationException>(ex);
        Assert.IsNotType<ArgumentException>(ex);
    }

    // ── NormalizeOptionalText ────────────────────────────────────────────────

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void NormalizeOptionalText_DevuelveNull_CuandoVacio(string? valor)
    {
        Assert.Null(BusinessRules.NormalizeOptionalText(valor));
    }

    [Fact]
    public void NormalizeOptionalText_Recorta_CuandoTieneContenido()
    {
        Assert.Equal("ok", BusinessRules.NormalizeOptionalText("  ok  "));
    }
}
