namespace FutbolStats.Api.Models;

public class Entrenamiento
{
    public int      EntrenamientoId { get; set; }
    public int      CategoriaId     { get; set; }
    public DateTime Fecha           { get; set; }
    public string   Titulo          { get; set; } = string.Empty;
    public string   Tipo            { get; set; } = string.Empty;
    public int?     DuracionMinutos { get; set; }
    public string?  Lugar           { get; set; }
    public bool     Activo          { get; set; } = true;

    public Categoria?                           Categoria   { get; set; }
    public ICollection<AsistenciaEntrenamiento> Asistencias { get; set; } = [];
}

public class AsistenciaEntrenamiento
{
    public int     AsistenciaId    { get; set; }
    public int     EntrenamientoId { get; set; }
    public int     JugadorId       { get; set; }
    public bool    Asistio         { get; set; } = true;
    public double? Rpe             { get; set; }
    public string? Observacion     { get; set; }

    public Entrenamiento? Entrenamiento { get; set; }
    public Jugador?        Jugador       { get; set; }
}
