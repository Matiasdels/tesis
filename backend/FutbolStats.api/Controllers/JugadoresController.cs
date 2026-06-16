using FutbolStats.Api.Data;
using FutbolStats.Api.Models;
using FutbolStats.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FutbolStats.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class JugadoresController(FutbolStatsDbContext context) : ControllerBase
{
    private static readonly string[] EstadosValidos = ["Disponible", "Lesionado", "Suspendido"];

    [HttpGet]
    public async Task<IActionResult> GetJugadores([FromQuery] string? estado, [FromQuery] string? search)
    {
        var query = context.Jugadores.Include(j => j.Categoria).AsNoTracking().Where(j => j.Activo);

        if (!string.IsNullOrWhiteSpace(estado))
        {
            query = query.Where(j => j.Estado == estado);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            query = query.Where(j =>
                j.Nombre.Contains(term) || j.Apellido.Contains(term));
        }

        var jugadores = await query
            .OrderBy(j => j.Apellido)
            .ThenBy(j => j.Nombre)
            .ToListAsync();

        return Ok(jugadores.Select(ToResponse));
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetJugador(int id)
    {
        var jugador = await context.Jugadores
            .Include(j => j.Categoria)
            .AsNoTracking()
            .FirstOrDefaultAsync(j => j.JugadorId == id);

        return jugador is null ? NotFound() : Ok(ToResponse(jugador));
    }

    [HttpPost]
    public async Task<IActionResult> CreateJugador(JugadorRequest request)
    {
        var validation = await ValidateRequest(request);
        if (validation is not null)
        {
            return validation;
        }

        var jugador = new Jugador
        {
            Nombre = BusinessRules.NormalizeRequiredText(request.Nombre, nameof(request.Nombre)),
            Apellido = BusinessRules.NormalizeRequiredText(request.Apellido, nameof(request.Apellido)),
            FechaNacimiento = request.FechaNacimiento,
            Nacionalidad = BusinessRules.NormalizeOptionalText(request.Nacionalidad),
            Dni = BusinessRules.NormalizeOptionalText(request.Dni),
            PosicionPrincipal = BusinessRules.NormalizeOptionalText(request.PosicionPrincipal),
            NumeroCamiseta = request.NumeroCamiseta,
            AlturaCm = request.AlturaCm,
            PesoKg = request.PesoKg,
            PiernaHabil = BusinessRules.NormalizeOptionalText(request.PiernaHabil),
            Estado = request.Estado,
            CategoriaId = request.CategoriaId,
            Activo = request.Activo ?? true,
        };

        context.Jugadores.Add(jugador);
        await context.SaveChangesAsync();

        await context.Entry(jugador).Reference(j => j.Categoria).LoadAsync();
        return CreatedAtAction(nameof(GetJugador), new { id = jugador.JugadorId }, ToResponse(jugador));
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> UpdateJugador(int id, JugadorRequest request)
    {
        var jugador = await context.Jugadores.FirstOrDefaultAsync(j => j.JugadorId == id);
        if (jugador is null)
        {
            return NotFound();
        }

        var validation = await ValidateRequest(request);
        if (validation is not null)
        {
            return validation;
        }

        jugador.Nombre = BusinessRules.NormalizeRequiredText(request.Nombre, nameof(request.Nombre));
        jugador.Apellido = BusinessRules.NormalizeRequiredText(request.Apellido, nameof(request.Apellido));
        jugador.FechaNacimiento = request.FechaNacimiento;
        jugador.Nacionalidad = BusinessRules.NormalizeOptionalText(request.Nacionalidad);
        jugador.Dni = BusinessRules.NormalizeOptionalText(request.Dni);
        jugador.PosicionPrincipal = BusinessRules.NormalizeOptionalText(request.PosicionPrincipal);
        jugador.NumeroCamiseta = request.NumeroCamiseta;
        jugador.AlturaCm = request.AlturaCm;
        jugador.PesoKg = request.PesoKg;
        jugador.PiernaHabil = BusinessRules.NormalizeOptionalText(request.PiernaHabil);
        jugador.Estado = request.Estado;
        jugador.CategoriaId = request.CategoriaId;
        if (request.Activo is not null)
        {
            jugador.Activo = request.Activo.Value;
        }

        await context.SaveChangesAsync();

        await context.Entry(jugador).Reference(j => j.Categoria).LoadAsync();
        return Ok(ToResponse(jugador));
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> DeactivateJugador(int id)
    {
        var jugador = await context.Jugadores.FirstOrDefaultAsync(j => j.JugadorId == id);
        if (jugador is null)
        {
            return NotFound();
        }

        jugador.Activo = false;
        await context.SaveChangesAsync();
        return NoContent();
    }

    private async Task<IActionResult?> ValidateRequest(JugadorRequest request)
    {
        if (!EstadosValidos.Contains(request.Estado))
        {
            return BadRequest($"Estado inválido. Valores permitidos: {string.Join(", ", EstadosValidos)}.");
        }

        var categoriaExiste = await context.Categorias.AnyAsync(c => c.CategoriaId == request.CategoriaId);
        if (!categoriaExiste)
        {
            return BadRequest("La categoría indicada no existe.");
        }

        return null;
    }

    private static JugadorResponse ToResponse(Jugador jugador)
    {
        return new JugadorResponse(
            jugador.JugadorId,
            jugador.Nombre,
            jugador.Apellido,
            jugador.FechaNacimiento,
            jugador.Nacionalidad,
            jugador.Dni,
            jugador.PosicionPrincipal,
            jugador.NumeroCamiseta,
            jugador.AlturaCm,
            jugador.PesoKg,
            jugador.PiernaHabil,
            jugador.Estado,
            jugador.CategoriaId,
            jugador.Categoria?.Nombre,
            jugador.Activo);
    }
}

public record JugadorRequest(
    string Nombre,
    string Apellido,
    DateOnly? FechaNacimiento,
    string? Nacionalidad,
    string? Dni,
    string? PosicionPrincipal,
    int? NumeroCamiseta,
    decimal? AlturaCm,
    decimal? PesoKg,
    string? PiernaHabil,
    string Estado,
    int CategoriaId,
    bool? Activo);

public record JugadorResponse(
    int JugadorId,
    string Nombre,
    string Apellido,
    DateOnly? FechaNacimiento,
    string? Nacionalidad,
    string? Dni,
    string? PosicionPrincipal,
    int? NumeroCamiseta,
    decimal? AlturaCm,
    decimal? PesoKg,
    string? PiernaHabil,
    string Estado,
    int CategoriaId,
    string? CategoriaNombre,
    bool Activo);
