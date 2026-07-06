namespace FutbolStats.Api.Models;

public class Jugador
{
    public int JugadorId { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string Apellido { get; set; } = string.Empty;
    public DateOnly? FechaNacimiento { get; set; }
    public string? Nacionalidad { get; set; }
    public string? Dni { get; set; }
    public string? PosicionPrincipal { get; set; }
    public int? NumeroCamiseta { get; set; }
    public decimal? AlturaCm { get; set; }
    public decimal? PesoKg { get; set; }
    public string? PiernaHabil { get; set; }
    public string Estado { get; set; } = "Disponible";
    public int? PartidosSuspendido { get; set; }
    public DateOnly? FechaEstimadaRegreso { get; set; }
    public int CategoriaId { get; set; }
    public Categoria? Categoria { get; set; }
    public bool Activo { get; set; } = true;
}
