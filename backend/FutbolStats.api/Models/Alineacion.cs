namespace FutbolStats.Api.Models;

public class Alineacion
{
    public int AlineacionId { get; set; }
    public int PartidoId { get; set; }
    public int JugadorId { get; set; }
    public bool EsTitular { get; set; }
    public string? PosicionAsignada { get; set; }

    public Partido? Partido { get; set; }
    public Jugador? Jugador { get; set; }
}
