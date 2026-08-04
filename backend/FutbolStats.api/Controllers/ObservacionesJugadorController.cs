using System.Security.Claims;
using FutbolStats.Api.Data;
using FutbolStats.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FutbolStats.Api.Controllers;

[ApiController]
[Route("api/jugadores/{jugadorId:int}/observaciones")]
[Authorize]
public class ObservacionesJugadorController(FutbolStatsDbContext context) : ControllerBase
{
    private const string TipoGeneral = "General";
    private static readonly string[] TiposValidos =
        { "General", "Tecnica", "Tactica", "Fisica" };

    [HttpGet]
    public async Task<IActionResult> GetObservaciones(int jugadorId)
    {
        var existe = await context.Jugadores
            .AnyAsync(j => j.JugadorId == jugadorId && j.Activo);
        if (!existe) return NotFound();

        var observaciones = await context.Observaciones
            .Include(o => o.Usuario)
            .AsNoTracking()
            .Where(o => o.JugadorId == jugadorId)
            .OrderByDescending(o => o.Fecha)
            .ToListAsync();

        return Ok(observaciones.Select(ToResponse));
    }

    [HttpPost]
    public async Task<IActionResult> CreateObservacion(int jugadorId, ObservacionRequest request)
    {
        var existe = await context.Jugadores
            .AnyAsync(j => j.JugadorId == jugadorId && j.Activo);
        if (!existe) return NotFound();

        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(userIdStr, out var userId))
            return Unauthorized();

        if (string.IsNullOrWhiteSpace(request.Contenido))
            return BadRequest("El contenido no puede estar vacío.");

        if (request.Contenido.Trim().Length > 1000)
            return BadRequest("El contenido no puede superar los 1000 caracteres.");

        var tipo = string.IsNullOrWhiteSpace(request.Tipo)
            ? TipoGeneral
            : request.Tipo.Trim();
        if (!TiposValidos.Contains(tipo))
            return BadRequest("Tipo de observacion invalido.");

        var observacion = new Observacion
        {
            JugadorId = jugadorId,
            UsuarioId = userId,
            Fecha = DateTime.UtcNow,
            Tipo = tipo,
            Contenido = request.Contenido.Trim(),
        };

        context.Observaciones.Add(observacion);
        await context.SaveChangesAsync();
        await context.Entry(observacion).Reference(o => o.Usuario).LoadAsync();

        return CreatedAtAction(nameof(GetObservaciones), new { jugadorId }, ToResponse(observacion));
    }

    private static ObservacionResponse ToResponse(Observacion o) =>
        new(
            o.ObservacionId,
            o.JugadorId,
            DateOnly.FromDateTime(o.Fecha),
            o.Tipo,
            o.Contenido,
            $"{o.Usuario?.Nombre} {o.Usuario?.Apellido}".Trim()
        );
}

public record ObservacionRequest(string Contenido, string? Tipo);

public record ObservacionResponse(
    int ObservacionId,
    int JugadorId,
    DateOnly Fecha,
    string Tipo,
    string Contenido,
    string AutorNombre);
