import '../../core/config/app_environment.dart';

abstract class ApiConfig {
  /// URL base de la API, sin barra final.
  /// Se resuelve desde AppEnvironment (--dart-define=API_BASE_URL=...).
  static String get baseUrl => AppEnvironment.apiBaseUrl;
}
