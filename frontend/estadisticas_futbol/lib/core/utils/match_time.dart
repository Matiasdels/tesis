/// Conversión centralizada de tiempo de partido.
///
/// En modo acelerado (desarrollo): 1 segundo real = 1 minuto de partido.
/// Para producción, cambiar [secondsPerMatchMinute] a 60 y todos los
/// cálculos se actualizan automáticamente.
abstract class MatchTime {
  /// Cuántos segundos reales equivalen a 1 minuto de partido.
  /// Modo acelerado: 1. Modo real: 60.
  static const int secondsPerMatchMinute = 1;

  /// Minuto futbolístico a partir de los segundos transcurridos.
  ///
  /// Ejemplos (secondsPerMatchMinute = 1):
  ///   0 s  →  0'
  ///   1 s  →  1'
  ///  59 s  → 59'
  ///  60 s  → 60'
  ///  61 s  → 61'
  ///  90 s  → 90'
  static int calcularMinuto(int elapsedSeconds) =>
      elapsedSeconds ~/ secondsPerMatchMinute;

  /// Texto del reloj para mostrar en pantalla: "60'" en lugar de "1:00".
  static String reloj(int elapsedSeconds) =>
      "${calcularMinuto(elapsedSeconds)}'";
}
