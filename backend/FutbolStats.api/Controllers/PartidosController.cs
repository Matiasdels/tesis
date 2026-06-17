using FutbolStats.Api.Data;
using FutbolStats.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FutbolStats.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class PartidosController(FutbolStatsDbContext context) : ControllerBase
{
    private static readonly string[] TiposCompeticionValidos = ["Liga", "Copa", "Amistoso", "Torneo"];
    private static readonly string[] EstadosValidos = ["Programado", "EnJuego", "Finalizado", "Cancelado"];

    [HttpGet]
    public async Task<IActionResult> GetPartidos(
        [FromQuery] int? categoriaId,
        [FromQuery] string? estado)
    {
        var query = context.Partidos.Include(p => p.Categoria).AsNoTracking();

        if (categoriaId.HasValue)
            query = query.Where(p => p.CategoriaId == categoriaId.Value);

        if (!string.IsNullOrWhiteSpace(estado))
            query = query.Where(p => p.Estado == estado);

        var partidos = await query
            .OrderByDescending(p => p.Fecha)
            .ToListAsync();

        return Ok(partidos.Select(ToResponse));
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetPartido(int id)
    {
        var partido = await context.Partidos
            .Include(p => p.Categoria)
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.PartidoId == id);

        return partido is null ? NotFound() : Ok(ToResponse(partido));
    }

    [HttpPost]
    public async Task<IActionResult> CreatePartido(PartidoRequest request)
    {
        var validation = await ValidateRequest(request);
        if (validation is not null) return validation;

        var partido = new Partido
        {
            CategoriaId = request.CategoriaId,
            Rival = request.Rival.Trim(),
            EsLocal = request.EsLocal,
            Fecha = request.Fecha,
            TipoCompeticion = request.TipoCompeticion,
            Lugar = string.IsNullOrWhiteSpace(request.Lugar) ? null : request.Lugar.Trim(),
            Estado = request.Estado,
        };

        context.Partidos.Add(partido);
        await context.SaveChangesAsync();
        await context.Entry(partido).Reference(p => p.Categoria).LoadAsync();

        return CreatedAtAction(nameof(GetPartido), new { id = partido.PartidoId }, ToResponse(partido));
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> UpdatePartido(int id, PartidoRequest request)
    {
        var partido = await context.Partidos.FirstOrDefaultAsync(p => p.PartidoId == id);
        if (partido is null) return NotFound();

        var validation = await ValidateRequest(request);
        if (validation is not null) return validation;

        partido.CategoriaId = request.CategoriaId;
        partido.Rival = request.Rival.Trim();
        partido.EsLocal = request.EsLocal;
        partido.Fecha = request.Fecha;
        partido.TipoCompeticion = request.TipoCompeticion;
        partido.Lugar = string.IsNullOrWhiteSpace(request.Lugar) ? null : request.Lugar.Trim();
        partido.Estado = request.Estado;

        await context.SaveChangesAsync();
        await context.Entry(partido).Reference(p => p.Categoria).LoadAsync();

        return Ok(ToResponse(partido));
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> DeletePartido(int id)
    {
        var partido = await context.Partidos.FirstOrDefaultAsync(p => p.PartidoId == id);
        if (partido is null) return NotFound();

        context.Partidos.Remove(partido);
        await context.SaveChangesAsync();
        return NoContent();
    }

    [HttpGet("{id:int}/alineacion")]
    public async Task<IActionResult> GetAlineacion(int id)
    {
        var existe = await context.Partidos.AnyAsync(p => p.PartidoId == id);
        if (!existe) return NotFound();

        var alineacion = await context.Alineaciones
            .Include(a => a.Jugador)
            .AsNoTracking()
            .Where(a => a.PartidoId == id)
            .OrderBy(a => !a.EsTitular)
            .ThenBy(a => a.Jugador!.Apellido)
            .ToListAsync();

        return Ok(alineacion.Select(ToAlineacionResponse));
    }

    [HttpPut("{id:int}/alineacion")]
    public async Task<IActionResult> SetAlineacion(int id, AlineacionRequest request)
    {
        var partido = await context.Partidos
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.PartidoId == id);

        if (partido is null) return NotFound();

        var jugadoresRequest = request.Jugadores ?? [];

        // Validar al menos 1 titular
        if (!jugadoresRequest.Any(j => j.EsTitular))
            return BadRequest("La alineación debe incluir al menos un jugador titular.");

        // Validar jugadores sin duplicados
        var ids = jugadoresRequest.Select(j => j.JugadorId).ToList();
        if (ids.Count != ids.Distinct().Count())
            return BadRequest("Un jugador no puede aparecer más de una vez en la alineación.");

        // Cargar jugadores y validar que pertenezcan a la categoría del partido
        var jugadores = await context.Jugadores
            .AsNoTracking()
            .Where(j => ids.Contains(j.JugadorId) && j.Activo)
            .ToListAsync();

        var noEncontrados = ids.Except(jugadores.Select(j => j.JugadorId)).ToList();
        if (noEncontrados.Count > 0)
            return BadRequest($"Los siguientes jugadores no existen o están inactivos: {string.Join(", ", noEncontrados)}.");

        var fueraDeCat = jugadores.Where(j => j.CategoriaId != partido.CategoriaId).ToList();
        if (fueraDeCat.Count > 0)
        {
            var nombres = fueraDeCat.Select(j => $"{j.Nombre} {j.Apellido}");
            return BadRequest($"Los siguientes jugadores no pertenecen a la categoría del partido: {string.Join(", ", nombres)}.");
        }

        // Reemplazar alineación completa
        var existentes = await context.Alineaciones
            .Where(a => a.PartidoId == id)
            .ToListAsync();

        context.Alineaciones.RemoveRange(existentes);

        var nuevas = jugadoresRequest.Select(j => new Alineacion
        {
            PartidoId = id,
            JugadorId = j.JugadorId,
            EsTitular = j.EsTitular,
            PosicionAsignada = string.IsNullOrWhiteSpace(j.PosicionAsignada) ? null : j.PosicionAsignada.Trim(),
        }).ToList();

        await context.Alineaciones.AddRangeAsync(nuevas);
        await context.SaveChangesAsync();

        var resultado = await context.Alineaciones
            .Include(a => a.Jugador)
            .AsNoTracking()
            .Where(a => a.PartidoId == id)
            .OrderBy(a => !a.EsTitular)
            .ThenBy(a => a.Jugador!.Apellido)
            .ToListAsync();

        return Ok(resultado.Select(ToAlineacionResponse));
    }

    private async Task<IActionResult?> ValidateRequest(PartidoRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Rival))
            return BadRequest("El nombre del rival es obligatorio.");

        if (request.Rival.Trim().Length > 100)
            return BadRequest("El nombre del rival no puede superar los 100 caracteres.");

        if (!TiposCompeticionValidos.Contains(request.TipoCompeticion))
            return BadRequest($"Tipo de competición inválido. Valores permitidos: {string.Join(", ", TiposCompeticionValidos)}.");

        if (!EstadosValidos.Contains(request.Estado))
            return BadRequest($"Estado inválido. Valores permitidos: {string.Join(", ", EstadosValidos)}.");

        if (request.Fecha == default)
            return BadRequest("La fecha del partido es obligatoria.");

        var categoriaExiste = await context.Categorias.AnyAsync(c => c.CategoriaId == request.CategoriaId);
        if (!categoriaExiste)
            return BadRequest("La categoría indicada no existe.");

        if (!string.IsNullOrWhiteSpace(request.Lugar) && request.Lugar.Trim().Length > 150)
            return BadRequest("El lugar no puede superar los 150 caracteres.");

        return null;
    }

    private static PartidoResponse ToResponse(Partido p) => new(
        p.PartidoId,
        p.CategoriaId,
        p.Categoria?.Nombre,
        p.Rival,
        p.EsLocal,
        p.Fecha,
        p.TipoCompeticion,
        p.Lugar,
        p.Estado,
        p.GolesEquipo,
        p.GolesRival,
        p.MinutoActual);

    private static AlineacionEntradaResponse ToAlineacionResponse(Alineacion a) => new(
        a.AlineacionId,
        a.JugadorId,
        $"{a.Jugador!.Nombre} {a.Jugador.Apellido}",
        a.EsTitular,
        a.PosicionAsignada);
}

public record PartidoRequest(
    int CategoriaId,
    string Rival,
    bool EsLocal,
    DateTime Fecha,
    string TipoCompeticion,
    string? Lugar,
    string Estado);

public record PartidoResponse(
    int PartidoId,
    int CategoriaId,
    string? CategoriaNombre,
    string Rival,
    bool EsLocal,
    DateTime Fecha,
    string TipoCompeticion,
    string? Lugar,
    string Estado,
    int? GolesEquipo,
    int? GolesRival,
    int? MinutoActual);

public record AlineacionEntrada(int JugadorId, bool EsTitular, string? PosicionAsignada);

public record AlineacionRequest(List<AlineacionEntrada> Jugadores);

public record AlineacionEntradaResponse(
    int AlineacionId,
    int JugadorId,
    string NombreJugador,
    bool EsTitular,
    string? PosicionAsignada);
