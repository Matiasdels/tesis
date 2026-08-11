using FutbolStats.Api.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FutbolStats.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CatalogosController(FutbolStatsDbContext context) : ControllerBase
{
    [HttpGet("categorias")]
    public async Task<IActionResult> GetCategorias()
    {
        var categorias = await context.Categorias
            .AsNoTracking()
            .OrderBy(categoria => categoria.Nombre)
            .Select(categoria => new
            {
                categoria.CategoriaId,
                categoria.Nombre,
                categoria.Descripcion
            })
            .ToListAsync();

        return Ok(categorias);
    }

    [HttpGet("tipos-evento")]
    public async Task<IActionResult> GetTiposEvento()
    {
        var tiposEvento = await context.TiposEvento
            .AsNoTracking()
            .OrderBy(tipoEvento => tipoEvento.Nombre)
            .Select(tipoEvento => new
            {
                tipoEvento.TipoEventoId,
                tipoEvento.Nombre
            })
            .ToListAsync();

        return Ok(tiposEvento);
    }

    [HttpGet("roles")]
    public async Task<IActionResult> GetRoles()
    {
        var roles = await context.Roles
            .AsNoTracking()
            .OrderBy(rol => rol.Nombre)
            .Select(rol => new RoleCatalogItem(
                rol.RolId,
                rol.Nombre,
                ToDisplayRoleName(rol.Nombre)))
            .ToListAsync();

        var visibleRoles = roles
            .Where(rol => rol.Nombre is not null)
            .Where(rol => rol.DisplayName is not null)
            .GroupBy(rol => rol.DisplayName!)
            .Select(group => group
                .OrderByDescending(rol => rol.Nombre == rol.DisplayName)
                .ThenBy(rol => rol.RolId)
                .First())
            .OrderBy(rol => rol.DisplayName)
            .Select(rol => new
            {
                rol.RolId,
                Nombre = rol.DisplayName
            })
            .ToList();

        return Ok(visibleRoles);
    }

    private static string? ToDisplayRoleName(string nombre)
    {
        return nombre switch
        {
            "Cuerpo tecnico" => "Cuerpo tecnico",
            "Responsable institucional" => "Responsable institucional",
            "Entrenador" => "Cuerpo tecnico",
            "Admin" => "Responsable institucional",
            "Asistente" => null,
            "Analista" => null,
            "Preparador fisico" => null,
            _ => null
        };
    }

    private sealed record RoleCatalogItem(int RolId, string Nombre, string? DisplayName);
}
