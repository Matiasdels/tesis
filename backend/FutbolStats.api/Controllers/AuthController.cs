using FutbolStats.Api.Data;
using FutbolStats.Api.Models;
using FutbolStats.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FutbolStats.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController(
    FutbolStatsDbContext context,
    PasswordHasher passwordHasher,
    TokenService tokenService) : ControllerBase
{
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

        var rol = await context.Roles.FindAsync(request.RolId);
        if (rol is null)
        {
            return BadRequest("El rol indicado no existe.");
        }

        var usuario = new Usuario
        {
            NombreUsuario = nombreUsuario,
            Email = email,
            Nombre = nombre,
            Apellido = apellido,
            RolId = request.RolId,
            Rol = rol,
            PasswordHash = passwordHasher.Hash(request.Password),
            Activo = true
        };

        context.Usuarios.Add(usuario);
        await context.SaveChangesAsync();

        var token = tokenService.CreateToken(usuario);
        return CreatedAtAction(nameof(GetMe), new { }, ToAuthResponse(usuario, token));
    }

    [HttpPost("login")]
    [AllowAnonymous]
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

        var token = tokenService.CreateToken(usuario);
        return Ok(ToAuthResponse(usuario, token));
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

    private static AuthResponse ToAuthResponse(Usuario usuario, AuthToken token)
    {
        return new AuthResponse(ToUsuarioResponse(usuario), token.AccessToken, token.ExpiresAt);
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
    string Apellido,
    int RolId);

public record LoginRequest(string UsuarioOEmail, string Password);

public record UsuarioResponse(
    int UsuarioId,
    string NombreUsuario,
    string Email,
    string Nombre,
    string Apellido,
    int RolId,
    string? Rol,
    bool Activo);

public record AuthResponse(UsuarioResponse Usuario, string AccessToken, DateTime ExpiresAt);
