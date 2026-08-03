namespace FutbolStats.Api.Services;

/// <summary>
/// Nombres canónicos de tipos de evento tal como se almacenan en la tabla TiposEvento.
/// Usar estas constantes en cualquier comparación o filtro sobre el nombre del tipo de evento.
/// Si el nombre cambia en la BD, solo hay que actualizar esta clase.
/// </summary>
public static class EventTypeNames
{
    public const string Gol             = "Gol";
    public const string Asistencia      = "Asistencia";
    public const string Remate          = "Remate";
    public const string RemateAlArco    = "Remate al arco";
    public const string Falta           = "Falta";
    public const string TarjetaAmarilla = "Tarjeta amarilla";
    public const string TarjetaRoja     = "Tarjeta roja";
    public const string Cambio          = "Cambio";
}
