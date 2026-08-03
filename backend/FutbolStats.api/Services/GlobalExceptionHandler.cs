using FutbolStats.Api.Services;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;

namespace FutbolStats.Api.Services;

/// <summary>
/// Manejador global de excepciones no controladas.
/// - DomainValidationException → 400 con mensaje legible.
/// - Cualquier otra excepción → 500 con mensaje genérico (detalle solo en log).
/// No devuelve stack trace, rutas internas ni detalles de conexión al cliente.
/// </summary>
internal sealed class GlobalExceptionHandler(ILogger<GlobalExceptionHandler> logger)
    : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        (int statusCode, string title, string detail) = exception switch
        {
            DomainValidationException dve => (
                StatusCodes.Status400BadRequest,
                "Datos inválidos",
                dve.Message),
            DomainConflictException dce => (
                StatusCodes.Status409Conflict,
                "Conflicto de estado",
                dce.Message),
            _ => (
                StatusCodes.Status500InternalServerError,
                "Error interno",
                "Ocurrió un error inesperado. Intentá nuevamente.")
        };

        if (statusCode == StatusCodes.Status500InternalServerError)
        {
            logger.LogError(
                exception,
                "Excepción no controlada en {Method} {Path}",
                httpContext.Request.Method,
                httpContext.Request.Path);
        }

        httpContext.Response.StatusCode = statusCode;

        var problem = new ProblemDetails
        {
            Status = statusCode,
            Title = title,
            Detail = detail,
        };

        await httpContext.Response.WriteAsJsonAsync(problem, cancellationToken);
        return true;
    }
}
