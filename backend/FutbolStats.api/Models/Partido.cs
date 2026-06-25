namespace FutbolStats.Api.Models;

public class Partido
{
    public int PartidoId { get; set; }
    public int CategoriaId { get; set; }
    public string Rival { get; set; } = string.Empty;
    public bool EsLocal { get; set; }
    public DateTime Fecha { get; set; }
    public string TipoCompeticion { get; set; } = "Amistoso";
    public string? Lugar { get; set; }
    public string Estado { get; set; } = "Programado";
    public int? GolesEquipo { get; set; }
    public int? GolesRival { get; set; }
    public int? MinutoActual { get; set; }
    public int? UsuarioCreadorId { get; set; }
    public bool Activo { get; set; } = true;

    public Categoria? Categoria { get; set; }
}
