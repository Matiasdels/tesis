import 'package:estadisticas_futbol/core/constants/app_constants.dart';
import 'package:estadisticas_futbol/models/models.dart';
import 'package:estadisticas_futbol/services/match_roster_state.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AlineacionEntradaModel titular(int id, [String? nombre]) => AlineacionEntradaModel(
      alineacionId: id,
      jugadorId: id,
      nombreJugador: nombre ?? 'Jugador $id',
      esTitular: true,
    );

AlineacionEntradaModel suplente(int id, [String? nombre]) => AlineacionEntradaModel(
      alineacionId: id,
      jugadorId: id,
      nombreJugador: nombre ?? 'Suplente $id',
      esTitular: false,
    );

EventoPartidoModel cambio(int sale, int entra) => EventoPartidoModel(
      eventoId: sale * 1000 + entra,
      partidoId: 1,
      jugadorId: sale,
      nombreJugador: 'J$sale',
      jugadorRelacionadoId: entra,
      nombreJugadorRelacionado: 'J$entra',
      tipoEventoId: 99,
      tipoEventoNombre: EventTypes.cambio,
      minuto: 30,
      pitchX: 0.5,
      pitchY: 0.5,
    );

EventoPartidoModel roja(int id) => EventoPartidoModel(
      eventoId: id + 9000,
      partidoId: 1,
      jugadorId: id,
      nombreJugador: 'J$id',
      tipoEventoId: 88,
      tipoEventoNombre: EventTypes.redCard,
      minuto: 50,
      pitchX: 0.5,
      pitchY: 0.5,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MatchRosterState.build()', () {
    test('sin eventos: titulares en cancha, suplentes disponibles', () {
      final lineup = [titular(1), titular(2), suplente(10)];
      final state = MatchRosterState.build(lineup: lineup, events: []);

      expect(state.jugadoresEnCancha.map((j) => j.jugadorId), containsAll([1, 2]));
      expect(state.suplentesDisponibles.map((j) => j.jugadorId), contains(10));
      expect(state.jugadoresSustituidos, isEmpty);
      expect(state.jugadoresExpulsados, isEmpty);
    });

    test('cambio mueve sale a sustituidos y entra a cancha', () {
      final lineup = [titular(1), titular(2), suplente(10)];
      final state = MatchRosterState.build(lineup: lineup, events: [cambio(1, 10)]);

      expect(state.idsEnCancha, containsAll([2, 10]));
      expect(state.idsSustituidos, contains(1));
      expect(state.suplentesDisponibles, isEmpty);
    });

    test('jugador entrante puede registrar eventos', () {
      final lineup = [titular(1), suplente(10)];
      final state = MatchRosterState.build(lineup: lineup, events: [cambio(1, 10)]);

      expect(state.idsEnCancha, contains(10));
      expect(state.idsSustituidos, contains(1));
    });

    test('jugador saliente no está en cancha tras cambio', () {
      final lineup = [titular(1), titular(2), suplente(10)];
      final state = MatchRosterState.build(lineup: lineup, events: [cambio(1, 10)]);

      expect(state.idsEnCancha, isNot(contains(1)));
      expect(state.idsSustituidos, contains(1));
    });

    test('tarjeta roja expulsa titular', () {
      final lineup = [titular(1), titular(2)];
      final state = MatchRosterState.build(lineup: lineup, events: [roja(1)]);

      expect(state.idsEnCancha, isNot(contains(1)));
      expect(state.idsExpulsados, contains(1));
    });

    test('tarjeta roja expulsa suplente desde banca', () {
      final lineup = [titular(1), suplente(10)];
      final state = MatchRosterState.build(lineup: lineup, events: [roja(10)]);

      expect(state.suplentesDisponibles, isEmpty);
      expect(state.idsExpulsados, contains(10));
    });

    test('cambio con jugadorRelacionadoId nulo es ignorado', () {
      const ev = EventoPartidoModel(
        eventoId: 1,
        partidoId: 1,
        jugadorId: 1,
        nombreJugador: 'J1',
        tipoEventoId: 99,
        tipoEventoNombre: EventTypes.cambio,
        minuto: 30,
        pitchX: 0.5,
        pitchY: 0.5,
      );
      final lineup = [titular(1), suplente(10)];
      final state = MatchRosterState.build(lineup: lineup, events: [ev]);

      expect(state.idsEnCancha, contains(1));
      expect(state.jugadoresSustituidos, isEmpty);
    });

    test('dos cambios consecutivos son aplicados en orden', () {
      final lineup = [titular(1), titular(2), suplente(10), suplente(11)];
      final state = MatchRosterState.build(
        lineup: lineup,
        events: [cambio(1, 10), cambio(2, 11)],
      );

      expect(state.idsEnCancha, containsAll([10, 11]));
      expect(state.idsSustituidos, containsAll([1, 2]));
      expect(state.suplentesDisponibles, isEmpty);
    });

    test('estado vacío tiene listas vacías', () {
      expect(MatchRosterState.empty.jugadoresEnCancha, isEmpty);
      expect(MatchRosterState.empty.suplentesDisponibles, isEmpty);
      expect(MatchRosterState.empty.jugadoresSustituidos, isEmpty);
      expect(MatchRosterState.empty.jugadoresExpulsados, isEmpty);
    });

    test('idsEnCancha, idsSustituidos, idsExpulsados retornan sets correctos', () {
      final lineup = [titular(1), titular(2), suplente(10)];
      final state = MatchRosterState.build(
        lineup: lineup,
        events: [cambio(1, 10), roja(2)],
      );

      expect(state.idsEnCancha, {10});
      expect(state.idsSustituidos, {1});
      expect(state.idsExpulsados, {2});
    });
  });
}
