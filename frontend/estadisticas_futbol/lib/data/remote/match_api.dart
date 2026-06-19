import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/models.dart';
import 'api_config.dart';

class MatchApi {
  final http.Client _client = http.Client();

  Future<List<PartidoModel>> getMatches({
    required String accessToken,
    int? categoriaId,
    String? estado,
  }) async {
    final query = <String, String>{};
    if (categoriaId != null) query['categoriaId'] = '$categoriaId';
    if (estado != null && estado.isNotEmpty) query['estado'] = estado;

    final response = await _getList('/api/Partidos', accessToken, query: query);
    return response
        .map((item) => PartidoModel.fromApi(item as Map<String, dynamic>))
        .toList();
  }

  Future<PartidoModel> getMatch(int id, String accessToken) async {
    final response = await _getMap('/api/Partidos/$id', accessToken);
    return PartidoModel.fromApi(response);
  }

  Future<PartidoModel> createMatch(PartidoModel match, String accessToken) async {
    final response = await _send('POST', '/api/Partidos', accessToken, match.toApiJson());
    return PartidoModel.fromApi(response);
  }

  Future<PartidoModel> updateMatch(int id, PartidoModel match, String accessToken) async {
    final response = await _send('PUT', '/api/Partidos/$id', accessToken, match.toApiJson());
    return PartidoModel.fromApi(response);
  }

  Future<PartidoModel> patchEstado(
    int id,
    String estado,
    String accessToken, {
    int? golesEquipo,
    int? golesRival,
    int? minutoActual,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/Partidos/$id/estado');
    final body = jsonEncode({
      'estado': estado,
      if (golesEquipo != null) 'golesEquipo': golesEquipo,
      if (golesRival != null) 'golesRival': golesRival,
      if (minutoActual != null) 'minutoActual': minutoActual,
    });
    final response = await _client.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: body,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MatchApiException(_friendlyError(response.statusCode, response.body));
    }
    return PartidoModel.fromApi(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteMatch(int id, String accessToken) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/Partidos/$id');
    final response = await _client.delete(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MatchApiException(_friendlyError(response.statusCode, response.body));
    }
  }

  Future<List<AlineacionEntradaModel>> getLineup(int matchId, String accessToken) async {
    final response = await _getList('/api/Partidos/$matchId/alineacion', accessToken);
    return response
        .map((item) => AlineacionEntradaModel.fromApi(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<AlineacionEntradaModel>> setLineup(
    int matchId,
    List<Map<String, dynamic>> entries,
    String accessToken,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/Partidos/$matchId/alineacion');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
    final body = jsonEncode({'jugadores': entries});
    final response = await _client.put(uri, headers: headers, body: body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MatchApiException(_friendlyError(response.statusCode, response.body));
    }

    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((item) => AlineacionEntradaModel.fromApi(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<dynamic>> _getList(
    String path,
    String accessToken, {
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path')
        .replace(queryParameters: query?.isEmpty ?? true ? null : query);
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MatchApiException(_friendlyError(response.statusCode, response.body));
    }
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> _getMap(String path, String accessToken) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MatchApiException(_friendlyError(response.statusCode, response.body));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path,
    String accessToken,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
    final encodedBody = jsonEncode(body);
    final response = method == 'POST'
        ? await _client.post(uri, headers: headers, body: encodedBody)
        : await _client.put(uri, headers: headers, body: encodedBody);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MatchApiException(_friendlyError(response.statusCode, response.body));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _friendlyError(int statusCode, String responseBody) {
    final cleanBody = responseBody.replaceAll('"', '').trim();
    if (statusCode == 401) return 'Tu sesión expiró. Volvé a iniciar sesión.';
    if (cleanBody.isNotEmpty) return cleanBody;
    if (statusCode == 404) return 'Recurso no encontrado. Verificá que el servidor esté actualizado.';
    return 'Error $statusCode. No pudimos completar la acción. Intente nuevamente.';
  }
}

class MatchApiException implements Exception {
  final String message;
  MatchApiException(this.message);

  @override
  String toString() => message.replaceAll('"', '');
}
