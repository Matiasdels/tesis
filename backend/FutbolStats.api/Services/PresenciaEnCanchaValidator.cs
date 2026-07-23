namespace FutbolStats.Api.Services;

public record PresenciaValidationResult(
    bool    EsValido,
    string? CodigoError = null,
    string? Mensaje     = null)
{
    public static readonly PresenciaValidationResult Ok = new(true);

    public static PresenciaValidationResult Error(string codigoError, string mensaje) =>
        new(false, codigoError, mensaje);
}

public static class PresenciaEnCanchaValidator
{
    // Valida que el jugador esté actualmente en el campo de juego.
    // No se llama para Cambio (tiene CambioValidator) ni Tarjeta roja (puede expulsar a suplentes).
    public static PresenciaValidationResult Validar(
        string           tipoEventoNombre,
        int              jugadorId,
        EstadoPlantel    plantel,
        IReadOnlySet<int> alineacionIds)
    {
        // Tipos exentos de la validación de presencia en cancha
        if (tipoEventoNombre == PlantelPartidoStateBuilder.NombreCambio ||
            tipoEventoNombre == PlantelPartidoStateBuilder.NombreTarjetaRoja)
            return PresenciaValidationResult.Ok;

        if (!alineacionIds.Contains(jugadorId))
            return PresenciaValidationResult.Error(
                "JugadorFueraDeAlineacion",
                $"El jugador ({jugadorId}) no pertenece a la alineación del partido.");

        if (plantel.Expulsados.Any(j => j.JugadorId == jugadorId))
            return PresenciaValidationResult.Error(
                "JugadorExpulsado",
                "El jugador está expulsado y no puede registrar más eventos.");

        if (plantel.Sustituidos.Any(j => j.JugadorId == jugadorId))
            return PresenciaValidationResult.Error(
                "JugadorSustituido",
                "El jugador fue sustituido y no puede registrar más eventos.");

        if (!plantel.EnCancha.Any(j => j.JugadorId == jugadorId))
            return PresenciaValidationResult.Error(
                "JugadorNoEstaEnCancha",
                "El jugador no está actualmente en el campo.");

        return PresenciaValidationResult.Ok;
    }
}
