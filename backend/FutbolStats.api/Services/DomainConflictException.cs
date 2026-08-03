namespace FutbolStats.Api.Services;

/// <summary>
/// Excepción de conflicto de estado de dominio mapeada globalmente a HTTP 409.
/// Usar cuando una operación es sintácticamente válida pero incompatible con el
/// estado actual del recurso (partido finalizado, alineación cerrada, etc.).
/// No usar para datos de entrada inválidos (usar DomainValidationException → 400).
/// </summary>
public sealed class DomainConflictException(string message) : Exception(message);
