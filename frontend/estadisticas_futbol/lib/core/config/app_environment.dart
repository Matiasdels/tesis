import 'package:flutter/foundation.dart';

/// Configuración central de entorno de la aplicación.
///
/// Todos los valores se inyectan en tiempo de compilación mediante --dart-define.
/// Ver docs/CONFIGURATION.md para los comandos de cada entorno.
abstract class AppEnvironment {
  /// URL base de la API. Siempre sin barra final.
  ///
  /// Configurar con:
  ///   --dart-define=API_BASE_URL=http://10.0.2.2:5224   (emulador Android)
  ///   --dart-define=API_BASE_URL=http://127.0.0.1:5224  (simulador iOS)
  ///   --dart-define=API_BASE_URL=http://IP_LOCAL:5224    (dispositivo físico)
  static const String _rawBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Segundos reales por minuto de partido.
  ///
  ///   --dart-define=MATCH_SECONDS_PER_MINUTE=1    (desarrollo acelerado)
  ///   --dart-define=MATCH_SECONDS_PER_MINUTE=60   (demo / producción)
  static const int secondsPerMatchMinute = int.fromEnvironment(
    'MATCH_SECONDS_PER_MINUTE',
    defaultValue: 60,
  );

  /// URL normalizada de la API (sin barra final).
  /// En release lanza [StateError] si no se configuró API_BASE_URL.
  static String get apiBaseUrl {
    final raw = _rawBaseUrl.trim();

    if (raw.isEmpty) {
      if (kReleaseMode) {
        throw StateError(
          'API_BASE_URL no está configurada. '
          'Usá --dart-define=API_BASE_URL=<URL> al compilar. '
          'Ver docs/CONFIGURATION.md.',
        );
      }
      // En debug/profile mantenemos el default del emulador Android.
      return 'http://10.0.2.2:5224';
    }

    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  /// true si la app se ejecuta con tiempo de partido acelerado (spm < 60).
  static bool get isAcceleratedMatchTime => secondsPerMatchMinute < 60;
}
