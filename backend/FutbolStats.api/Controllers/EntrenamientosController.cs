using FutbolStats.Api.Data;
using FutbolStats.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FutbolStats.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class EntrenamientosController(FutbolStatsDbContext context) : ControllerBase
{
    // GET /api/Entrenamientos?categoriaId=1
    [HttpGet]
    public async Task<IActionResult> GetEntrenamientos([FromQuery] int? categoriaId)
    {
        var query = context.Entrenamientos
            .Include(e => e.Asistencias)
            .AsNoTracking()
            .Where(e => e.Activo)
            .AsQueryable();

        if (categoriaId.HasValue)
            query = query.Where(e => e.CategoriaId == categoriaId.Value);

        var list = await query.OrderByDescending(e => e.Fecha).ToListAsync();
        return Ok(list.Select(ToResponse));
    }

    // GET /api/Entrenamientos/{id}
    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetEntrenamiento(int id)
    {
        var e = await context.Entrenamientos
            .Include(e => e.Asistencias)
            .AsNoTracking()
            .FirstOrDefaultAsync(e => e.EntrenamientoId == id && e.Activo);
        return e is null ? NotFound() : Ok(ToResponse(e));
    }

    // POST /api/Entrenamientos
    [HttpPost]
    public async Task<IActionResult> CreateEntrenamiento(EntrenamientoRequest request)
    {
        var categoriaExiste = await context.Categorias.AnyAsync(c => c.CategoriaId == request.CategoriaId);
        if (!categoriaExiste) return BadRequest("Categoría no encontrada.");

        if (string.IsNullOrWhiteSpace(request.Titulo))
            return BadRequest("El titulo del entrenamiento es obligatorio.");

        if (string.IsNullOrWhiteSpace(request.Tipo))
            return BadRequest("El tipo de entrenamiento es obligatorio.");

        var entrenamiento = new Entrenamiento
        {
            CategoriaId = request.CategoriaId,
            Fecha       = request.Fecha.Date,
            Titulo      = request.Titulo.Trim(),
            Tipo        = request.Tipo.Trim(),
            DuracionMinutos = request.DuracionMinutos,
            Lugar       = string.IsNullOrWhiteSpace(request.Lugar)  ? null : request.Lugar.Trim(),
            Activo      = true,
        };
        context.Entrenamientos.Add(entrenamiento);
        await context.SaveChangesAsync();
        return CreatedAtAction(nameof(GetEntrenamiento),
            new { id = entrenamiento.EntrenamientoId }, ToResponse(entrenamiento));
    }

    // PUT /api/Entrenamientos/{id}/asistencia
    // Body: [{ jugadorId: 1, asistio: true }, ...]
    [HttpPut("{id:int}/asistencia")]
    public async Task<IActionResult> SetAsistencia(int id, List<AsistenciaRequest> request)
    {
        var entrenamiento = await context.Entrenamientos
            .Include(e => e.Asistencias)
            .FirstOrDefaultAsync(e => e.EntrenamientoId == id && e.Activo);
        if (entrenamiento is null) return NotFound();

        await using var transaction = await context.Database.BeginTransactionAsync();

        // Reemplazar toda la asistencia del entrenamiento.
        entrenamiento.Asistencias.Clear();
        await context.SaveChangesAsync(); // flush deletes antes de insertar
        foreach (var item in request)
        {
            if (item.Rpe is < 0 or > 10)
                return BadRequest("El RPE debe estar entre 0 y 10.");

            entrenamiento.Asistencias.Add(new AsistenciaEntrenamiento
            {
                EntrenamientoId = id,
                JugadorId       = item.JugadorId,
                Asistio         = item.Asistio,
                Rpe             = item.Rpe,
                Observacion     = string.IsNullOrWhiteSpace(item.Observacion)
                    ? null
                    : item.Observacion.Trim(),
            });
        }
        await context.SaveChangesAsync();
        await transaction.CommitAsync();

        return Ok(ToResponse(entrenamiento));
    }

    // DELETE /api/Entrenamientos/{id}
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> DeleteEntrenamiento(int id)
    {
        var entrenamiento = await context.Entrenamientos
            .FirstOrDefaultAsync(e => e.EntrenamientoId == id && e.Activo);
        if (entrenamiento is null) return NotFound();
        entrenamiento.Activo = false;
        await context.SaveChangesAsync();
        return NoContent();
    }

    private static EntrenamientoResponse ToResponse(Entrenamiento e) => new(
        e.EntrenamientoId,
        e.CategoriaId,
        e.Fecha,
        e.Titulo,
        e.Tipo,
        e.DuracionMinutos,
        e.Lugar,
        e.Asistencias.Count(a => a.Asistio),
        e.Asistencias.Count(a => !a.Asistio),
        e.Asistencias
            .OrderBy(a => a.JugadorId)
            .Select(a => new AsistenciaResponse(
                a.JugadorId,
                a.Asistio,
                a.Rpe,
                a.Observacion))
            .ToList());
}

public record EntrenamientoRequest(
    int       CategoriaId,
    DateTime  Fecha,
    string    Titulo,
    string    Tipo,
    int?      DuracionMinutos,
    string?   Lugar);
public record AsistenciaRequest(
    int     JugadorId,
    bool    Asistio,
    double? Rpe,
    string? Observacion);

public record AsistenciaResponse(
    int     JugadorId,
    bool    Asistio,
    double? Rpe,
    string? Observacion);

public record EntrenamientoResponse(
    int       EntrenamientoId,
    int       CategoriaId,
    DateTime  Fecha,
    string    Titulo,
    string    Tipo,
    int?      DuracionMinutos,
    string?   Lugar,
    int       Asistieron,
    int       NoAsistieron,
    IReadOnlyList<AsistenciaResponse> Asistencias);
