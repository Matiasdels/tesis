import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/models.dart';
import 'api_config.dart';

class PlayerApi {
  final http.Client _client = http.Client();

  Future<List<PlayerModel>> getPlayers({
    required String accessToken,
    String? estado,
    String? search,
  }) async {
    final query = <String, String>{};
    if (estado != null && estado.isNotEmpty) query['estado'] = estado;
    if (search != null && search.isNotEmpty) query['search'] = search;

    final response = await _getList('/api/Jugadores', accessToken, query: query);
    return response
        .map((item) => PlayerModel.fromApi(item as Map<String, dynamic>))
        .toList();
  }

  Future<PlayerModel> getPlayer(String id, String accessToken) async {
    final response = await _getMap('/api/Jugadores/$id', accessToken);
    return PlayerModel.fromApi(response);
  }

  Future<PlayerModel> createPlayer(PlayerModel player, String accessToken) async {
    final response = await _send('POST', '/api/Jugadores', accessToken, player.toApiJson());
    return PlayerModel.fromApi(response);
  }

  Future<PlayerModel> updatePlayer(
    String id,
    PlayerModel player,
    String accessToken,
  ) async {
    final response = await _send('PUT', '/api/Jugadores/$id', accessToken, player.toApiJson());
    return PlayerModel.fromApi(response);
  }

  Future<void> deactivatePlayer(String id, String accessToken) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/Jugadores/$id');
    final response = await _client.delete(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PlayerApiException(_friendlyError(response.statusCode, response.body));
    }
  }

  Future<List<CategoryModel>> getCategories(String accessToken) async {
    final response = await _getList('/api/Catalogos/categorias', accessToken);
    return response
        .map((item) => CategoryModel.fromApi(item as Map<String, dynamic>))
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
      throw PlayerApiException(_friendlyError(response.statusCode, response.body));
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
      throw PlayerApiException(_friendlyError(response.statusCode, response.body));
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
      throw PlayerApiException(_friendlyError(response.statusCode, response.body));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _friendlyError(int statusCode, String responseBody) {
    final cleanBody = responseBody.replaceAll('"', '').trim();

    if (statusCode == 400) {
      return cleanBody.isEmpty
          ? 'Revisá los datos del jugador e intentá nuevamente.'
          : cleanBody;
    }

    if (statusCode == 404) {
      return 'No se encontró el jugador solicitado.';
    }

    if (statusCode == 401) {
      return 'Tu sesión expiró. Volvé a iniciar sesión.';
    }

    return 'No pudimos completar la acción. Intentá nuevamente.';
  }
}

class PlayerApiException implements Exception {
  final String message;

  PlayerApiException(this.message);

  @override
  String toString() => message.replaceAll('"', '');
}
