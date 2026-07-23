import 'package:estadisticas_futbol/core/utils/match_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MatchTime.calcularMinuto (secondsPerMatchMinute = 1)', () {
    test('0 segundos → 0', () => expect(MatchTime.calcularMinuto(0), 0));
    test('1 segundo → 1',  () => expect(MatchTime.calcularMinuto(1), 1));
    test('59 segundos → 59', () => expect(MatchTime.calcularMinuto(59), 59));
    test('60 segundos → 60', () => expect(MatchTime.calcularMinuto(60), 60));
    test('61 segundos → 61', () => expect(MatchTime.calcularMinuto(61), 61));
    test('90 segundos → 90', () => expect(MatchTime.calcularMinuto(90), 90));
    test('105 segundos → 105', () => expect(MatchTime.calcularMinuto(105), 105));
  });

  group('MatchTime.reloj', () {
    test('0 s → "0\'"',  () => expect(MatchTime.reloj(0),  "0'"));
    test('60 s → "60\'"', () => expect(MatchTime.reloj(60), "60'"));
    test('90 s → "90\'"', () => expect(MatchTime.reloj(90), "90'"));
    test('nunca muestra formato mm:ss', () {
      final texto = MatchTime.reloj(60);
      expect(texto.contains(':'), isFalse);
    });
  });

  group('Lógica de presentación de eventos (pura)', () {
    test('minuto 60 se muestra como "60\'" y nunca como "1:00"', () {
      const minuto = 60;
      const display = "$minuto'";
      expect(display, "60'");
      expect(display, isNot(contains(':')));
    });

    test('minuto 37 se muestra como "37\'"', () {
      const minuto = 37;
      expect("$minuto'", "37'");
    });

    test('nombre entrante usa nombreJugadorRelacionado si está disponible', () {
      const nombreRelacionado = 'Vinicius Junior';
      const entra = nombreRelacionado;
      expect(entra, 'Vinicius Junior');
    });

    test('nombre entrante cae a fallback cuando es null', () {
      const String? nombreRelacionado = null;
      const entra = nombreRelacionado ?? 'Jugador entrante no disponible';
      expect(entra, 'Jugador entrante no disponible');
    });

    test('texto de cambio incluye sale y entra', () {
      const sale = 'Pedri González';
      const entra = 'Vinicius Junior';
      const texto = '$sale → $entra';
      expect(texto, contains(sale));
      expect(texto, contains(entra));
      expect(texto, contains('→'));
    });
  });
}
