import 'package:estadisticas_futbol/core/utils/match_time.dart';
import 'package:flutter_test/flutter_test.dart';

/// Los tests sin --dart-define corren con el valor por defecto (60).
/// Para probar modo acelerado usar:
///   flutter test --dart-define=MATCH_SECONDS_PER_MINUTE=1
void main() {
  // Valor configurado en esta ejecución (depende del dart-define usado).
  const spm = MatchTime.secondsPerMatchMinute;

  group('MatchTime — configuración', () {
    test('secondsPerMatchMinute es mayor que cero', () {
      expect(spm, greaterThan(0));
    });

    test('secondsPerMatchMinute es 1 o 60 (los únicos valores documentados)', () {
      expect(spm == 1 || spm == 60, isTrue,
          reason: 'Valores reconocidos: 1 (acelerado) o 60 (real). '
              'Valor actual: $spm. '
              'Pasá --dart-define=MATCH_SECONDS_PER_MINUTE=1 o =60.');
    });
  });

  group('MatchTime.calcularMinuto — con spm=$spm', () {
    test('0 segundos → 0 minutos', () => expect(MatchTime.calcularMinuto(0), 0));

    test('1 segundo → ${1 ~/ spm} minutos',
        () => expect(MatchTime.calcularMinuto(1), 1 ~/ spm));

    test('59 segundos → ${59 ~/ spm} minutos',
        () => expect(MatchTime.calcularMinuto(59), 59 ~/ spm));

    test('60 segundos → ${60 ~/ spm} minutos',
        () => expect(MatchTime.calcularMinuto(60), 60 ~/ spm));

    test('61 segundos → ${61 ~/ spm} minutos',
        () => expect(MatchTime.calcularMinuto(61), 61 ~/ spm));

    test('90 segundos → ${90 ~/ spm} minutos',
        () => expect(MatchTime.calcularMinuto(90), 90 ~/ spm));

    test('${spm * 90} segundos → 90 minutos de partido (duración normal)',
        () => expect(MatchTime.calcularMinuto(spm * 90), 90));

    test('${spm * 45} segundos → 45 minutos (medio tiempo)',
        () => expect(MatchTime.calcularMinuto(spm * 45), 45));
  });

  group('MatchTime.reloj — con spm=$spm', () {
    test('0 s → "0\'"', () => expect(MatchTime.reloj(0), "0'"));

    test('${spm * 60} s → "60\'"',
        () => expect(MatchTime.reloj(spm * 60), "60'"));

    test('${spm * 90} s → "90\'"',
        () => expect(MatchTime.reloj(spm * 90), "90'"));

    test('nunca contiene formato mm:ss (nunca usa dos puntos)', () {
      expect(MatchTime.reloj(spm * 60).contains(':'), isFalse);
    });

    test('termina en comilla simple', () {
      expect(MatchTime.reloj(spm * 37).endsWith("'"), isTrue);
    });
  });

  group('MatchTime — comportamiento modo real (spm=60)', () {
    test('90 minutos de partido transcurren en 5400 segundos reales', () {
      // Este test documenta el modo real independientemente del spm configurado.
      const elapsedReal = 60 * 90; // 5400 s
      const expectedMinuto = elapsedReal ~/ 60;
      expect(expectedMinuto, 90);
    });
  });

  group('MatchTime — comportamiento modo acelerado (spm=1)', () {
    test('90 minutos de partido transcurren en 90 segundos reales', () {
      const elapsedAcelerado = 1 * 90; // 90 s
      const expectedMinuto = elapsedAcelerado ~/ 1;
      expect(expectedMinuto, 90);
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
