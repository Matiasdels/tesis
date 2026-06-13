using FutbolStats.Api.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FutbolStats.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class HealthController(FutbolStatsDbContext context) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<HealthResponse>> Get()
    {
        var canConnect = await context.Database.CanConnectAsync();
        return new HealthResponse("ok", canConnect);
    }
}

public record HealthResponse(string Status, bool Database);
