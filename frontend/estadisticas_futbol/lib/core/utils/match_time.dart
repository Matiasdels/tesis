/// Conversión centralizada de tiempo de partido.
///
/// El valor [secondsPerMatchMinute] se configura en tiempo de compilación:
///
///   Modo acelerado (desarrollo/pruebas rápidas):
///     flutter run --dart-define=MATCH_SECONDS_PER_MINUTE=1
///
///   Modo real (demo / producción):
///     flutter run --dart-define=MATCH_SECONDS_PER_MINUTE=60
///
/// Si no se pasa el define, el valor por defecto es 60 (modo real).
/// Nunca dejar el valor en 1 para una demo o release.
abstract class MatchTime {
  /// Cuántos segundos reales equivalen a 1 minuto de partido.
  ///
  /// Valor seguro por defecto: 60 (modo real).
  /// Para pruebas aceleradas: pasar --dart-define=MATCH_SECONDS_PER_MINUTE=1.
  static const int secondsPerMatchMinute = int.fromEnvironment(
    'MATCH_SECONDS_PER_MINUTE',
    defaultValue: 60,
  );

  /// Minuto futbolístico a partir de los segundos transcurridos.
  ///
  /// Con secondsPerMatchMinute = 60 (modo real):
  ///    60 s → 1'   |  3600 s → 60'  |  5400 s → 90'
  ///
  /// Con secondsPerMatchMinute = 1 (modo acelerado):
  ///    1 s → 1'    |    60 s → 60'  |    90 s → 90'
  static int calcularMinuto(int elapsedSeconds) =>
      secondsPerMatchMinute > 0 ? elapsedSeconds ~/ secondsPerMatchMinute : 0;

  /// Texto del reloj para mostrar en pantalla: "90'" en lugar de "1:30:00".
  static String reloj(int elapsedSeconds) =>
      "${calcularMinuto(elapsedSeconds)}'";
}
