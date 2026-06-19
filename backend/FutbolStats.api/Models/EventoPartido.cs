namespace FutbolStats.Api.Models;

public class EventoPartido
{
    public int EventoId { get; set; }
    public int PartidoId { get; set; }
    public int? JugadorId { get; set; }
    public int TipoEventoId { get; set; }
    public int Minuto { get; set; }
    public decimal? PitchX { get; set; }
    public decimal? PitchY { get; set; }
    public int? JugadorRelacionadoId { get; set; }
    public string? Observacion { get; set; }
    public DateTime FechaRegistro { get; set; } = DateTime.UtcNow;

    public Jugador? Jugador { get; set; }
    public TipoEvento? TipoEvento { get; set; }
}
