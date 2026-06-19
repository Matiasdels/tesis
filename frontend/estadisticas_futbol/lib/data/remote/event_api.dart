import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/models.dart';
import 'api_config.dart';

class EventApi {
  final http.Client _client = http.Client();

  Future<List<TipoEventoModel>> getTiposEvento(String accessToken) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/Catalogos/tipos-evento');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    _checkStatus(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => TipoEventoModel.fromApi(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<EventoPartidoModel>> getEventos(
      int partidoId, String accessToken) async {
    final uri =
        Uri.parse('${ApiConfig.baseUrl}/api/Partidos/$partidoId/eventos');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    _checkStatus(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => EventoPartidoModel.fromApi(e as Map<String, dynamic>))
        .toList();
  }

  Future<EventoPartidoModel> createEvento({
    required int partidoId,
    int? jugadorId,
    required int tipoEventoId,
    required int minuto,
    required double pitchX,
    required double pitchY,
    String? observacion,
    required String accessToken,
  }) async {
    final uri =
        Uri.parse('${ApiConfig.baseUrl}/api/Partidos/$partidoId/eventos');
    final body = jsonEncode({
      if (jugadorId != null) 'jugadorId': jugadorId,
      'tipoEventoId': tipoEventoId,
      'minuto': minuto,
      'pitchX': pitchX,
      'pitchY': pitchY,
      if (observacion != null) 'observacion': observacion,
    });
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: body,
    );
    _checkStatus(response);
    return EventoPartidoModel.fromApi(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteEvento({
    required int partidoId,
    required int eventoId,
    required String accessToken,
  }) async {
    final uri = Uri.parse(
        '${ApiConfig.baseUrl}/api/Partidos/$partidoId/eventos/$eventoId');
    final response = await _client.delete(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    _checkStatus(response);
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body.replaceAll('"', '').trim();
      if (response.statusCode == 401) {
        throw const EventApiException('Tu sesión expiró. Volvé a iniciar sesión.');
      }
      throw EventApiException(body.isNotEmpty ? body : 'Error ${response.statusCode}');
    }
  }
}

class EventApiException implements Exception {
  final String message;
  const EventApiException(this.message);

  @override
  String toString() => message;
}
