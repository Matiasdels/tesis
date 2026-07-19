namespace FutbolStats.Api.Models;

public class PenalDetalle
{
    public int PenalDetalleId { get; set; }
    public int PartidoId { get; set; }
    public string Equipo { get; set; } = string.Empty;   // "Propio" | "Rival"
    public int? JugadorId { get; set; }
    public string Resultado { get; set; } = string.Empty; // "Gol" | "Errado"
    public int Orden { get; set; }
    public bool Activo { get; set; } = true;

    public Partido? Partido { get; set; }
    public Jugador? Jugador { get; set; }
}
