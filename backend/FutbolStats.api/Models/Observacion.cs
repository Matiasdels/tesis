namespace FutbolStats.Api.Models;

public class Observacion
{
    public int ObservacionId { get; set; }
    public int JugadorId { get; set; }
    public int UsuarioId { get; set; }
    public DateTime Fecha { get; set; }
    public string Tipo { get; set; } = "General";
    public string Contenido { get; set; } = string.Empty;

    public Jugador? Jugador { get; set; }
    public Usuario? Usuario { get; set; }
}
