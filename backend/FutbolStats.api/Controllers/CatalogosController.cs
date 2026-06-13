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
            .Select(rol => new
            {
                rol.RolId,
                rol.Nombre
            })
            .ToListAsync();

        return Ok(roles);
    }
}
