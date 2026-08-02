namespace FutbolStats.Api.Services;

/// <summary>
/// Excepción de validación de dominio mapeada globalmente a HTTP 400.
/// Usar para errores de entrada inválida detectados en servicios o reglas de negocio.
/// No usar para errores de programación inesperados.
/// </summary>
public sealed class DomainValidationException(string message, string? field = null)
    : Exception(message)
{
    public string? Field { get; } = field;
}
