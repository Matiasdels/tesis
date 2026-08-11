using FutbolStats.Api.Data;
using FutbolStats.Api.Models;
using FutbolStats.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace FutbolStats.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController(
    FutbolStatsDbContext context,
    PasswordHasher passwordHasher,
    TokenService tokenService) : ControllerBase
{
    private const string PublicRegistrationRole = "Cuerpo tecnico";

    [HttpPost("registro")]
    [AllowAnonymous]
    public async Task<ActionResult<AuthResponse>> Register(RegisterRequest request)
    {
        var nombreUsuario = BusinessRules.NormalizeRequiredText(request.NombreUsuario, nameof(request.NombreUsuario));
        var email = BusinessRules.NormalizeRequiredText(request.Email, nameof(request.Email)).ToLowerInvariant();
        var nombre = BusinessRules.NormalizeRequiredText(request.Nombre, nameof(request.Nombre));
        var apellido = BusinessRules.NormalizeRequiredText(request.Apellido, nameof(request.Apellido));

        if (request.Password.Length < 8)
        {
            return BadRequest("La contraseña debe tener al menos 8 caracteres.");
        }

        var exists = await context.Usuarios.AnyAsync(usuario =>
            usuario.NombreUsuario == nombreUsuario || usuario.Email == email);

        if (exists)
        {
            return Conflict("Ya existe un usuario con ese nombre de usuario o email.");
        }

        var rol = await context.Roles
            .FirstOrDefaultAsync(r => r.Nombre == PublicRegistrationRole);
        if (rol is null)
        {
            return Problem("No hay un rol predeterminado configurado para nuevos usuarios.");
        }

        var usuario = new Usuario
        {
            NombreUsuario = nombreUsuario,
            Email = email,
            Nombre = nombre,
            Apellido = apellido,
            RolId = rol.RolId,
            Rol = rol,
            PasswordHash = passwordHasher.Hash(request.Password),
            Activo = true
        };

        context.Usuarios.Add(usuario);
        await context.SaveChangesAsync();

        var response = await CreateAuthResponse(usuario);
        return CreatedAtAction(nameof(GetMe), new { }, response);
    }

    [HttpPost("login")]
    [AllowAnonymous]
    [EnableRateLimiting(RateLimitPolicies.Login)]
    public async Task<ActionResult<AuthResponse>> Login(LoginRequest request)
    {
        var usuarioOEmail = BusinessRules.NormalizeRequiredText(
            request.UsuarioOEmail,
            nameof(request.UsuarioOEmail));

        var usuario = await context.Usuarios
            .Include(u => u.Rol)
            .FirstOrDefaultAsync(u =>
                u.NombreUsuario == usuarioOEmail ||
                u.Email == usuarioOEmail.ToLowerInvariant());

        if (usuario is null || !usuario.Activo || !passwordHasher.Verify(request.Password, usuario.PasswordHash))
        {
            return Unauthorized("Usuario o contraseña incorrectos.");
        }

        return Ok(await CreateAuthResponse(usuario));
    }

    [HttpPost("refresh")]
    [AllowAnonymous]
    public async Task<ActionResult<AuthResponse>> Refresh(RefreshTokenRequest request)
    {
        var refreshToken = BusinessRules.NormalizeRequiredText(
            request.RefreshToken,
            nameof(request.RefreshToken));
        var tokenHash = tokenService.HashRefreshToken(refreshToken);

        var storedToken = await context.RefreshTokens
            .Include(token => token.Usuario)
            .ThenInclude(usuario => usuario!.Rol)
            .FirstOrDefaultAsync(token => token.TokenHash == tokenHash);

        if (storedToken is null ||
            !storedToken.IsActive ||
            storedToken.Usuario is null ||
            !storedToken.Usuario.Activo)
        {
            return Unauthorized("Tu sesion expiro. Volve a iniciar sesion.");
        }

        var newRefreshToken = tokenService.CreateRefreshToken();
        storedToken.RevokedAt = DateTime.UtcNow;
        storedToken.ReplacedByTokenHash = newRefreshToken.TokenHash;

        context.RefreshTokens.Add(new RefreshToken
        {
            UsuarioId = storedToken.UsuarioId,
            TokenHash = newRefreshToken.TokenHash,
            ExpiresAt = newRefreshToken.ExpiresAt
        });

        await context.SaveChangesAsync();

        var accessToken = tokenService.CreateToken(storedToken.Usuario);
        return Ok(ToAuthResponse(storedToken.Usuario, accessToken, newRefreshToken));
    }

    [HttpPost("logout")]
    [AllowAnonymous]
    public async Task<IActionResult> Logout(RefreshTokenRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.RefreshToken))
        {
            return NoContent();
        }

        var tokenHash = tokenService.HashRefreshToken(request.RefreshToken.Trim());
        var storedToken = await context.RefreshTokens
            .FirstOrDefaultAsync(token => token.TokenHash == tokenHash);

        if (storedToken is not null && storedToken.RevokedAt is null)
        {
            storedToken.RevokedAt = DateTime.UtcNow;
            await context.SaveChangesAsync();
        }

        return NoContent();
    }

    [HttpGet("me")]
    [Authorize]
    public async Task<ActionResult<UsuarioResponse>> GetMe()
    {
        var userIdClaim = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        if (!int.TryParse(userIdClaim, out var userId))
        {
            return Unauthorized();
        }

        var usuario = await context.Usuarios
            .Include(u => u.Rol)
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.UsuarioId == userId);

        return usuario is null ? NotFound() : ToUsuarioResponse(usuario);
    }

    private async Task<AuthResponse> CreateAuthResponse(Usuario usuario)
    {
        var accessToken = tokenService.CreateToken(usuario);
        var refreshToken = tokenService.CreateRefreshToken();

        context.RefreshTokens.Add(new RefreshToken
        {
            UsuarioId = usuario.UsuarioId,
            TokenHash = refreshToken.TokenHash,
            ExpiresAt = refreshToken.ExpiresAt
        });

        await context.SaveChangesAsync();

        return ToAuthResponse(usuario, accessToken, refreshToken);
    }

    private static AuthResponse ToAuthResponse(
        Usuario usuario,
        AuthToken token,
        AuthRefreshToken refreshToken)
    {
        return new AuthResponse(
            ToUsuarioResponse(usuario),
            token.AccessToken,
            token.ExpiresAt,
            refreshToken.RefreshToken,
            refreshToken.ExpiresAt);
    }

    private static UsuarioResponse ToUsuarioResponse(Usuario usuario)
    {
        return new UsuarioResponse(
            usuario.UsuarioId,
            usuario.NombreUsuario,
            usuario.Email,
            usuario.Nombre,
            usuario.Apellido,
            usuario.RolId,
            usuario.Rol?.Nombre,
            usuario.Activo);
    }
}

public record RegisterRequest(
    string NombreUsuario,
    string Email,
    string Password,
    string Nombre,
    string Apellido);

public record LoginRequest(string UsuarioOEmail, string Password);

public record RefreshTokenRequest(string RefreshToken);

public record UsuarioResponse(
    int UsuarioId,
    string NombreUsuario,
    string Email,
    string Nombre,
    string Apellido,
    int RolId,
    string? Rol,
    bool Activo);

public record AuthResponse(
    UsuarioResponse Usuario,
    string AccessToken,
    DateTime ExpiresAt,
    string RefreshToken,
    DateTime RefreshExpiresAt);
