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
    public string? Formacion { get; set; }
    public string DefinicionEmpate { get; set; } = "TerminaEnEmpate";
    public string? PeriodoActual { get; set; }
    public bool HuboAlargue { get; set; } = false;
    public bool HuboPenales { get; set; } = false;
    public int? ResultadoPenalesEquipo { get; set; }
    public int? ResultadoPenalesRival { get; set; }

    public Categoria? Categoria { get; set; }
}
