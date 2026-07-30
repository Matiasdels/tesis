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
            .FirstOrDefaultAsync(e => e.EntrenamientoId == id);
        return e is null ? NotFound() : Ok(ToResponse(e));
    }

    // POST /api/Entrenamientos
    [HttpPost]
    public async Task<IActionResult> CreateEntrenamiento(EntrenamientoRequest request)
    {
        var categoriaExiste = await context.Categorias.AnyAsync(c => c.CategoriaId == request.CategoriaId);
        if (!categoriaExiste) return BadRequest("Categoría no encontrada.");

        var entrenamiento = new Entrenamiento
        {
            CategoriaId = request.CategoriaId,
            Fecha       = request.Fecha.Date,
            Titulo      = string.IsNullOrWhiteSpace(request.Titulo) ? null : request.Titulo.Trim(),
            Tipo        = string.IsNullOrWhiteSpace(request.Tipo)   ? null : request.Tipo.Trim(),
            DuracionMinutos = request.DuracionMinutos,
            Lugar       = string.IsNullOrWhiteSpace(request.Lugar)  ? null : request.Lugar.Trim(),
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
            .FirstOrDefaultAsync(e => e.EntrenamientoId == id);
        if (entrenamiento is null) return NotFound();

        // Reemplazar toda la asistencia del entrenamiento.
        entrenamiento.Asistencias.Clear();
        await context.SaveChangesAsync(); // flush deletes antes de insertar
        foreach (var item in request)
        {
            entrenamiento.Asistencias.Add(new AsistenciaEntrenamiento
            {
                EntrenamientoId = id,
                JugadorId       = item.JugadorId,
                Asistio         = item.Asistio,
            });
        }
        await context.SaveChangesAsync();
        return Ok(ToResponse(entrenamiento));
    }

    // DELETE /api/Entrenamientos/{id}
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> DeleteEntrenamiento(int id)
    {
        var entrenamiento = await context.Entrenamientos.FirstOrDefaultAsync(e => e.EntrenamientoId == id);
        if (entrenamiento is null) return NotFound();
        context.Entrenamientos.Remove(entrenamiento);
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
        e.Asistencias.Count(a => !a.Asistio));
}

public record EntrenamientoRequest(
    int       CategoriaId,
    DateTime  Fecha,
    string?   Titulo,
    string?   Tipo,
    int?      DuracionMinutos,
    string?   Lugar);
public record AsistenciaRequest(int JugadorId, bool Asistio);
public record EntrenamientoResponse(
    int       EntrenamientoId,
    int       CategoriaId,
    DateTime  Fecha,
    string?   Titulo,
    string?   Tipo,
    int?      DuracionMinutos,
    string?   Lugar,
    int       Asistieron,
    int       NoAsistieron);
