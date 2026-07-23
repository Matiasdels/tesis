import '../core/constants/app_constants.dart';
import '../models/models.dart';

/// Estado dinámico del plantel en un momento dado.
/// No se persiste: se reconstruye desde la alineación inicial + eventos cronológicos.
class MatchRosterState {
  final List<AlineacionEntradaModel> jugadoresEnCancha;
  final List<AlineacionEntradaModel> suplentesDisponibles;
  final List<AlineacionEntradaModel> jugadoresSustituidos;
  final List<AlineacionEntradaModel> jugadoresExpulsados;

  const MatchRosterState({
    required this.jugadoresEnCancha,
    required this.suplentesDisponibles,
    required this.jugadoresSustituidos,
    required this.jugadoresExpulsados,
  });

  static const MatchRosterState empty = MatchRosterState(
    jugadoresEnCancha: [],
    suplentesDisponibles: [],
    jugadoresSustituidos: [],
    jugadoresExpulsados: [],
  );

  /// Reconstruye el estado del plantel aplicando los eventos en orden.
  /// [events] debe estar en orden cronológico (más antiguo primero).
  /// Espejo del PlantelPartidoStateBuilder del backend.
  static MatchRosterState build({
    required List<AlineacionEntradaModel> lineup,
    required List<EventoPartidoModel> events,
  }) {
    final enCancha    = <int, AlineacionEntradaModel>{};
    final disponibles = <int, AlineacionEntradaModel>{};
    final sustituidos = <AlineacionEntradaModel>[];
    final expulsados  = <AlineacionEntradaModel>[];

    for (final j in lineup) {
      if (j.esTitular) {
        enCancha[j.jugadorId] = j;
      } else {
        disponibles[j.jugadorId] = j;
      }
    }

    for (final ev in events) {
      if (ev.tipoEventoNombre == EventTypes.cambio) {
        _aplicarCambio(ev, enCancha, disponibles, sustituidos);
      } else if (ev.tipoEventoNombre == EventTypes.redCard) {
        _aplicarExpulsion(ev, enCancha, disponibles, expulsados);
      }
      // El resto de los eventos no cambia el plantel.
    }

    return MatchRosterState(
      jugadoresEnCancha: enCancha.values.toList(),
      suplentesDisponibles: disponibles.values.toList(),
      jugadoresSustituidos: sustituidos,
      jugadoresExpulsados: expulsados,
    );
  }

  static void _aplicarCambio(
    EventoPartidoModel ev,
    Map<int, AlineacionEntradaModel> enCancha,
    Map<int, AlineacionEntradaModel> disponibles,
    List<AlineacionEntradaModel> sustituidos,
  ) {
    final saleId  = ev.jugadorId;
    final entraId = ev.jugadorRelacionadoId;
    if (saleId == null || entraId == null) return;

    final sale = enCancha.remove(saleId);
    if (sale != null) sustituidos.add(sale);

    final entra = disponibles.remove(entraId);
    if (entra != null) enCancha[entraId] = entra;
  }

  static void _aplicarExpulsion(
    EventoPartidoModel ev,
    Map<int, AlineacionEntradaModel> enCancha,
    Map<int, AlineacionEntradaModel> disponibles,
    List<AlineacionEntradaModel> expulsados,
  ) {
    final id = ev.jugadorId;
    if (id == null) return;

    final jugadorCancha = enCancha.remove(id);
    if (jugadorCancha != null) {
      expulsados.add(jugadorCancha);
      return;
    }

    final jugadorBanca = disponibles.remove(id);
    if (jugadorBanca != null) {
      expulsados.add(jugadorBanca);
    }
  }

  Set<int> get idsEnCancha    => jugadoresEnCancha.map((j) => j.jugadorId).toSet();
  Set<int> get idsExpulsados  => jugadoresExpulsados.map((j) => j.jugadorId).toSet();
  Set<int> get idsSustituidos => jugadoresSustituidos.map((j) => j.jugadorId).toSet();
}
