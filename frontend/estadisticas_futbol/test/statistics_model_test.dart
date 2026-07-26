import 'package:estadisticas_futbol/models/estadisticas_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResumenGlobalModel.fromApi', () {
    final sampleJson = {
      'partidosJugados':     5,
      'victorias':           3,
      'empates':             1,
      'derrotas':            1,
      'golesFavor':          9,
      'golesContra':         4,
      'diferenciaGoles':     5,
      'porcentajeVictorias': 60.0,
      'rendimientoReciente': [
        {
          'partidoId':  1,
          'rival':       'Rival A',
          'golesFavor':  2,
          'golesContra': 1,
          'resultado':   'G',
          'fecha':       '2025-06-01T00:00:00Z',
        },
      ],
      'topGoleadores': [
        {'jugadorId': 10, 'nombre': 'Valverde', 'cantidad': 5},
      ],
      'topAsistidores': [
        {'jugadorId': 20, 'nombre': 'Lamine', 'cantidad': 3},
      ],
    };

    test('parsea todos los campos correctamente', () {
      final model = ResumenGlobalModel.fromApi(sampleJson);

      expect(model.partidosJugados,     5);
      expect(model.victorias,           3);
      expect(model.empates,             1);
      expect(model.derrotas,            1);
      expect(model.golesFavor,          9);
      expect(model.golesContra,         4);
      expect(model.diferenciaGoles,     5);
      expect(model.porcentajeVictorias, 60.0);
    });

    test('parsea rendimientoReciente correctamente', () {
      final model = ResumenGlobalModel.fromApi(sampleJson);

      expect(model.rendimientoReciente.length, 1);
      expect(model.rendimientoReciente[0].rival,      'Rival A');
      expect(model.rendimientoReciente[0].resultado,  'G');
      expect(model.rendimientoReciente[0].golesFavor, 2);
    });

    test('parsea topGoleadores correctamente', () {
      final model = ResumenGlobalModel.fromApi(sampleJson);

      expect(model.topGoleadores.length,       1);
      expect(model.topGoleadores[0].nombre,    'Valverde');
      expect(model.topGoleadores[0].cantidad,  5);
      expect(model.topGoleadores[0].jugadorId, 10);
    });

    test('parsea topAsistidores correctamente', () {
      final model = ResumenGlobalModel.fromApi(sampleJson);

      expect(model.topAsistidores[0].nombre,  'Lamine');
      expect(model.topAsistidores[0].cantidad, 3);
    });

    test('listas vacías cuando no hay datos', () {
      final emptyJson = {
        'partidosJugados':     0,
        'victorias':           0,
        'empates':             0,
        'derrotas':            0,
        'golesFavor':          0,
        'golesContra':         0,
        'diferenciaGoles':     0,
        'porcentajeVictorias': 0.0,
        'rendimientoReciente': <dynamic>[],
        'topGoleadores':       <dynamic>[],
        'topAsistidores':      <dynamic>[],
      };
      final model = ResumenGlobalModel.fromApi(emptyJson);

      expect(model.partidosJugados, 0);
      expect(model.rendimientoReciente, isEmpty);
      expect(model.topGoleadores,       isEmpty);
      expect(model.topAsistidores,      isEmpty);
    });

    test('toJson → fromApi produce el mismo modelo', () {
      final original = ResumenGlobalModel.fromApi(sampleJson);
      final roundtrip = ResumenGlobalModel.fromApi(original.toJson());

      expect(roundtrip.partidosJugados, original.partidosJugados);
      expect(roundtrip.victorias,       original.victorias);
      expect(roundtrip.golesFavor,      original.golesFavor);
      expect(roundtrip.porcentajeVictorias, original.porcentajeVictorias);
      expect(roundtrip.rendimientoReciente[0].rival, original.rendimientoReciente[0].rival);
      expect(roundtrip.topGoleadores[0].nombre,      original.topGoleadores[0].nombre);
    });
  });

  group('RendimientoRecienteItem', () {
    test('resultado G E P se mapea correctamente', () {
      for (final res in ['G', 'E', 'P']) {
        final item = RendimientoRecienteItem.fromApi({
          'partidoId': 1, 'rival': 'X', 'golesFavor': 0,
          'golesContra': 0, 'resultado': res,
          'fecha': '2025-01-01T00:00:00Z',
        });
        expect(item.resultado, res);
      }
    });
  });

  group('TopJugadorItem', () {
    test('parsea jugadorId, nombre y cantidad', () {
      final item = TopJugadorItem.fromApi(
          {'jugadorId': 99, 'nombre': 'Darwin', 'cantidad': 7});

      expect(item.jugadorId, 99);
      expect(item.nombre,    'Darwin');
      expect(item.cantidad,  7);
    });
  });
}
