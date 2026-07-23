namespace FutbolStats.Api.Services;

public record InfoJugador(int JugadorId, string NombreCompleto, bool EsTitular);

// Información mínima de un evento para reconstrucción del plantel.
// JugadorId       = jugador que sale (Cambio) o jugador expulsado (Tarjeta roja).
// JugadorRelacionadoId = jugador que entra (solo en Cambio).
public record InfoEvento(string TipoEventoNombre, int? JugadorId, int? JugadorRelacionadoId);

// Estado del plantel en un instante dado. No se persiste; se reconstruye desde
// la alineación inicial + eventos cronológicos (OrderBy Minuto, ThenBy FechaRegistro).
public record EstadoPlantel(
    IReadOnlyList<InfoJugador> EnCancha,
    IReadOnlyList<InfoJugador> SuplentesDisponibles,
    IReadOnlyList<InfoJugador> Sustituidos,
    IReadOnlyList<InfoJugador> Expulsados);

public static class PlantelPartidoStateBuilder
{
    public const string NombreCambio      = "Cambio";
    public const string NombreTarjetaRoja = "Tarjeta roja";

    // Reconstruye el estado del plantel aplicando los eventos en el orden recibido.
    // Eventos no reconocidos o con datos incompletos se ignoran silenciosamente.
    public static EstadoPlantel Reconstruir(
        IEnumerable<InfoJugador> alineacion,
        IEnumerable<InfoEvento>  eventos)
    {
        var enCancha             = new Dictionary<int, InfoJugador>();
        var suplentesDisponibles = new Dictionary<int, InfoJugador>();
        var sustituidos          = new List<InfoJugador>();
        var expulsados           = new List<InfoJugador>();

        foreach (var j in alineacion)
        {
            if (j.EsTitular) enCancha[j.JugadorId]             = j;
            else              suplentesDisponibles[j.JugadorId] = j;
        }

        foreach (var ev in eventos)
        {
            if (ev.TipoEventoNombre == NombreCambio
                && ev.JugadorId.HasValue
                && ev.JugadorRelacionadoId.HasValue)
            {
                AplicarCambio(ev.JugadorId.Value, ev.JugadorRelacionadoId.Value,
                              enCancha, suplentesDisponibles, sustituidos);
            }
            else if (ev.TipoEventoNombre == NombreTarjetaRoja && ev.JugadorId.HasValue)
            {
                AplicarExpulsion(ev.JugadorId.Value,
                                 enCancha, suplentesDisponibles, expulsados);
            }
        }

        return new EstadoPlantel(
            enCancha.Values.ToList(),
            suplentesDisponibles.Values.ToList(),
            sustituidos,
            expulsados);
    }

    private static void AplicarCambio(
        int saleId, int entraId,
        Dictionary<int, InfoJugador> enCancha,
        Dictionary<int, InfoJugador> suplentesDisponibles,
        List<InfoJugador>            sustituidos)
    {
        if (enCancha.TryGetValue(saleId, out var sale))
        {
            enCancha.Remove(saleId);
            sustituidos.Add(sale);
        }

        if (suplentesDisponibles.TryGetValue(entraId, out var entra))
        {
            suplentesDisponibles.Remove(entraId);
            enCancha[entraId] = entra;
        }
    }

    private static void AplicarExpulsion(
        int expulsadoId,
        Dictionary<int, InfoJugador> enCancha,
        Dictionary<int, InfoJugador> suplentesDisponibles,
        List<InfoJugador>            expulsados)
    {
        if (enCancha.TryGetValue(expulsadoId, out var jugador))
        {
            enCancha.Remove(expulsadoId);
            expulsados.Add(jugador);
        }
        else if (suplentesDisponibles.TryGetValue(expulsadoId, out var suplente))
        {
            suplentesDisponibles.Remove(expulsadoId);
            expulsados.Add(suplente);
        }
    }
}
