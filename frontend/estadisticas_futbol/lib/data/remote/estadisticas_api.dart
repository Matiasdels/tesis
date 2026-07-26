import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/estadisticas_model.dart';
import '../local/database_helper.dart';
import 'api_config.dart';

class EstadisticasApi {
  final http.Client _client = http.Client();
  final _db = DatabaseHelper.instance;

  static const _cacheKey = 'estadisticas:resumen-global';

  Future<ResumenGlobalModel> getResumenGlobal(String accessToken) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/Estadisticas/resumen-global');
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw EstadisticasApiException(_friendlyError(response.statusCode, response.body));
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      await _db.saveJson(_cacheKey, json);
      return ResumenGlobalModel.fromApi(json);
    } on EstadisticasApiException {
      rethrow;
    } catch (_) {
      final cached = await _db.readJsonMap(_cacheKey);
      if (cached != null) return ResumenGlobalModel.fromApi(cached);
      rethrow;
    }
  }

  String _friendlyError(int code, String body) {
    final clean = body.replaceAll('"', '').trim();
    if (code == 401) return 'Tu sesión expiró. Volvé a iniciar sesión.';
    if (clean.isNotEmpty) return clean;
    return 'Error $code al cargar estadísticas.';
  }
}

class EstadisticasApiException implements Exception {
  final String message;
  const EstadisticasApiException(this.message);
  @override
  String toString() => message;
}
