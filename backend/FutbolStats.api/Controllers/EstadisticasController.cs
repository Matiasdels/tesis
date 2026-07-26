using FutbolStats.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FutbolStats.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class EstadisticasController(EstadisticasGlobalesService service) : ControllerBase
{
    [HttpGet("resumen-global")]
    public async Task<IActionResult> GetResumenGlobal()
    {
        var resultado = await service.GetResumenGlobalAsync();
        return Ok(resultado);
    }
}
