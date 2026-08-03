namespace FutbolStats.Api.Services;

public record CambioValidationResult(
    bool    EsValido,
    string? CodigoError = null,
    string? Mensaje     = null,
    int?    JugadorId   = null)
{
    public static readonly CambioValidationResult Ok = new(true);

    public static CambioValidationResult Error(
        string codigoError, string mensaje, int? jugadorId = null) =>
        new(false, codigoError, mensaje, jugadorId);
}

public static class CambioValidator
{
    // alineacionIds incluye titulares y suplentes del partido.
    public static CambioValidationResult Validar(
        string           estadoPartido,
        EstadoPlantel    plantel,
        int              jugadorSaleId,
        int              jugadorEntraId,
        IReadOnlySet<int> alineacionIds)
    {
        if (PartidoEstados.Terminales.Contains(estadoPartido))
            return CambioValidationResult.Error(
                "PartidoTerminado",
                "No se pueden registrar cambios en un partido que ya ha concluido.");

        if (jugadorSaleId == jugadorEntraId)
            return CambioValidationResult.Error(
                "JugadoresIguales",
                "El jugador que sale y el que entra no pueden ser el mismo.",
                jugadorSaleId);

        if (!alineacionIds.Contains(jugadorSaleId))
            return CambioValidationResult.Error(
                "JugadorFueraDeAlineacion",
                "El jugador que sale no pertenece a la alineación del partido.",
                jugadorSaleId);

        if (!alineacionIds.Contains(jugadorEntraId))
            return CambioValidationResult.Error(
                "JugadorFueraDeAlineacion",
                "El jugador que entra no pertenece a la alineación del partido.",
                jugadorEntraId);

        // Validaciones sobre el jugador que sale
        if (plantel.Expulsados.Any(j => j.JugadorId == jugadorSaleId))
            return CambioValidationResult.Error(
                "JugadorExpulsado",
                "El jugador que sale está expulsado.",
                jugadorSaleId);

        if (plantel.Sustituidos.Any(j => j.JugadorId == jugadorSaleId))
            return CambioValidationResult.Error(
                "JugadorYaSustituido",
                "El jugador que sale ya fue sustituido anteriormente.",
                jugadorSaleId);

        if (!plantel.EnCancha.Any(j => j.JugadorId == jugadorSaleId))
            return CambioValidationResult.Error(
                "JugadorQueSaleNoEstaEnCancha",
                "El jugador que sale no está actualmente en el campo.",
                jugadorSaleId);

        // Validaciones sobre el jugador que entra
        if (plantel.Expulsados.Any(j => j.JugadorId == jugadorEntraId))
            return CambioValidationResult.Error(
                "JugadorExpulsado",
                "El jugador que entra está expulsado y no puede ingresar.",
                jugadorEntraId);

        if (plantel.Sustituidos.Any(j => j.JugadorId == jugadorEntraId))
            return CambioValidationResult.Error(
                "JugadorYaSustituido",
                "El jugador que entra ya fue sustituido anteriormente y no puede reingresar.",
                jugadorEntraId);

        if (!plantel.SuplentesDisponibles.Any(j => j.JugadorId == jugadorEntraId))
            return CambioValidationResult.Error(
                "JugadorQueEntraNoEstaDisponible",
                "El jugador que entra no está disponible como suplente.",
                jugadorEntraId);

        return CambioValidationResult.Ok;
    }
}
