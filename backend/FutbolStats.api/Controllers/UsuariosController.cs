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
public class UsuariosController(
    FutbolStatsDbContext context,
    PasswordHasher passwordHasher) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<List<UsuarioGestionResponse>>> GetUsuarios()
    {
        var usuarios = await context.Usuarios
            .Include(usuario => usuario.Rol)
            .AsNoTracking()
            .OrderBy(usuario => usuario.Nombre)
            .ThenBy(usuario => usuario.Apellido)
            .Select(usuario => ToResponse(usuario))
            .ToListAsync();

        return Ok(usuarios);
    }

    [HttpPost]
    public async Task<ActionResult<UsuarioGestionResponse>> CrearUsuario(
        CrearUsuarioRequest request)
    {
        var nombreUsuario = BusinessRules.NormalizeRequiredText(
            request.NombreUsuario,
            nameof(request.NombreUsuario));
        var email = BusinessRules.NormalizeRequiredText(
            request.Email,
            nameof(request.Email)).ToLowerInvariant();
        var nombre = BusinessRules.NormalizeRequiredText(
            request.Nombre,
            nameof(request.Nombre));
        var apellido = BusinessRules.NormalizeRequiredText(
            request.Apellido,
            nameof(request.Apellido));

        if (request.Password.Length < 8)
        {
            return BadRequest("La contrasena debe tener al menos 8 caracteres.");
        }

        var rol = await context.Roles.FirstOrDefaultAsync(
            rol => rol.RolId == request.RolId);
        if (rol is null)
        {
            return BadRequest("Selecciona un rol valido.");
        }

        var exists = await context.Usuarios.AnyAsync(usuario =>
            usuario.NombreUsuario == nombreUsuario || usuario.Email == email);
        if (exists)
        {
            return Conflict("Ya existe un usuario con ese nombre o email.");
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

        return CreatedAtAction(nameof(GetUsuarios), ToResponse(usuario));
    }

    private static UsuarioGestionResponse ToResponse(Usuario usuario)
    {
        return new UsuarioGestionResponse(
            usuario.UsuarioId,
            usuario.NombreUsuario,
            usuario.Email,
            usuario.Nombre,
            usuario.Apellido,
            usuario.RolId,
            ToDisplayRoleName(usuario.Rol?.Nombre),
            usuario.Activo,
            usuario.FechaCreacion);
    }

    private static string? ToDisplayRoleName(string? nombre)
    {
        return nombre switch
        {
            "Cuerpo tecnico" => "Cuerpo tecnico",
            "Responsable institucional" => "Responsable institucional",
            "Entrenador" => "Cuerpo tecnico",
            "Asistente" => "Cuerpo tecnico",
            "Analista" => "Cuerpo tecnico",
            "Preparador fisico" => "Cuerpo tecnico",
            "Admin" => "Responsable institucional",
            _ => nombre
        };
    }
}

public record CrearUsuarioRequest(
    string NombreUsuario,
    string Email,
    string Password,
    string Nombre,
    string Apellido,
    int RolId);

public record UsuarioGestionResponse(
    int UsuarioId,
    string NombreUsuario,
    string Email,
    string Nombre,
    string Apellido,
    int RolId,
    string? Rol,
    bool Activo,
    DateTime FechaCreacion);
