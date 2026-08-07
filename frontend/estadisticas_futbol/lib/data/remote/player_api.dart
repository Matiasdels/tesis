import 'dart:convert';

import 'package:http/http.dart' as http;

import '../local/database_helper.dart';
import '../../models/models.dart';
import 'api_config.dart';

class PlayerApi {
  final http.Client _client = http.Client();
  final _databaseHelper = DatabaseHelper.instance;

  Future<List<PlayerModel>> getPlayers({
    required String accessToken,
    String? estado,
    String? search,
    bool activo = true,
  }) async {
    final query = <String, String>{};
    if (estado != null && estado.isNotEmpty) query['estado'] = estado;
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (!activo) query['activo'] = 'false';

    final cacheKey = _playersCacheKey(estado: estado, search: search, activo: activo);

    try {
      final response =
          await _getList('/api/Jugadores', accessToken, query: query);
      await _databaseHelper.saveJson(cacheKey, response);
      if (activo && query.isEmpty) {
        await _databaseHelper.saveJson(_playersCacheKey(), response);
      }
      if (activo) {
        for (final item in response) {
          final map = item as Map<String, dynamic>;
          await _databaseHelper.saveJson('players:item:${map['jugadorId']}', map);
        }
      }
      return response
          .map((item) => PlayerModel.fromApi(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      final cached = await _databaseHelper.readJsonList(cacheKey) ??
          (activo ? await _databaseHelper.readJsonList(_playersCacheKey()) : null);
      if (cached != null) {
        return cached
            .map((item) => PlayerModel.fromApi(item as Map<String, dynamic>))
            .where((player) => _matchesLocalFilters(player, estado, search, activo))
            .toList();
      }
      rethrow;
    }
  }

  Future<PlayerModel> getPlayer(int id, String accessToken) async {
    try {
      final response = await _getMap('/api/Jugadores/$id', accessToken);
      await _databaseHelper.saveJson('players:item:$id', response);
      return PlayerModel.fromApi(response);
    } catch (_) {
      final cached = await _databaseHelper.readJsonMap('players:item:$id');
      if (cached != null) return PlayerModel.fromApi(cached);

      final cachedList = await _databaseHelper.readJsonList(_playersCacheKey());
      final cachedPlayer = cachedList?.whereType<Map<String, dynamic>>().where(
            (item) => item['jugadorId'] == id,
          );
      if (cachedPlayer != null && cachedPlayer.isNotEmpty) {
        return PlayerModel.fromApi(cachedPlayer.first);
      }
      rethrow;
    }
  }

  Future<PlayerModel> createPlayer(
      PlayerModel player, String accessToken) async {
    final response =
        await _send('POST', '/api/Jugadores', accessToken, player.toApiJson());
    await _databaseHelper.saveJson(
      'players:item:${response['jugadorId']}',
      response,
    );
    return PlayerModel.fromApi(response);
  }

  Future<PlayerModel> updatePlayer(
    int id,
    PlayerModel player,
    String accessToken,
  ) async {
    final response = await _send(
        'PUT', '/api/Jugadores/$id', accessToken, player.toApiJson());
    await _databaseHelper.saveJson('players:item:$id', response);
    return PlayerModel.fromApi(response);
  }

  Future<void> deactivatePlayer(int id, String accessToken) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/Jugadores/$id');
    final response = await _client.delete(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PlayerApiException(
          _friendlyError(response.statusCode, response.body));
    }
  }

  Future<List<PlayerObservacionModel>> getPlayerObservations(
      int playerId, String accessToken) async {
    final response = await _getList(
        '/api/Jugadores/$playerId/observaciones', accessToken);
    return response
        .map((item) =>
            PlayerObservacionModel.fromApi(item as Map<String, dynamic>))
        .toList();
  }

  Future<PlayerObservacionModel> createPlayerObservation(
    int playerId,
    String contenido,
    String accessToken, {
    String tipo = 'General',
  }) async {
    final uri = Uri.parse(
        '${ApiConfig.baseUrl}/api/Jugadores/$playerId/observaciones');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'contenido': contenido, 'tipo': tipo}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PlayerApiException(
          _friendlyError(response.statusCode, response.body));
    }
    return PlayerObservacionModel.fromApi(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<PlayerMatchModel>> getPlayerMatches(
      int playerId, String accessToken) async {
    final response = await _getList(
        '/api/Jugadores/$playerId/partidos', accessToken);
    return response
        .map((item) =>
            PlayerMatchModel.fromApi(item as Map<String, dynamic>))
        .toList();
  }

  Future<ActividadJugadorModel> getActividadJugador(
      int playerId, String accessToken) async {
    final cacheKey = 'players:$playerId:actividad';
    try {
      final response =
          await _getMap('/api/Jugadores/$playerId/actividad', accessToken);
      await _databaseHelper.saveJson(cacheKey, response);
      return ActividadJugadorModel.fromApi(response);
    } catch (_) {
      final cached = await _databaseHelper.readJsonMap(cacheKey);
      if (cached != null) return ActividadJugadorModel.fromApi(cached);
      rethrow;
    }
  }

  Future<List<CategoryModel>> getCategories(String accessToken) async {
    try {
      final response = await _getList('/api/Catalogos/categorias', accessToken);
      await _databaseHelper.saveJson('catalogs:categories', response);
      return response
          .map((item) => CategoryModel.fromApi(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      final cached = await _databaseHelper.readJsonList('catalogs:categories');
      if (cached != null) {
        return cached
            .map((item) => CategoryModel.fromApi(item as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
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
      throw PlayerApiException(
          _friendlyError(response.statusCode, response.body));
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
      throw PlayerApiException(
          _friendlyError(response.statusCode, response.body));
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
      throw PlayerApiException(
          _friendlyError(response.statusCode, response.body));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _friendlyError(int statusCode, String responseBody) {
    if (statusCode == 404) return 'No se encontró el jugador solicitado.';
    if (statusCode == 401) return 'Tu sesión expiró. Volvé a iniciar sesión.';

    final extracted = _extractMessage(responseBody);

    if (statusCode == 400) {
      return extracted.isEmpty
          ? 'Revisá los datos del jugador e intentá nuevamente.'
          : extracted;
    }

    if (statusCode == 409) return extracted.isEmpty ? 'Operación no permitida.' : extracted;

    return 'No pudimos completar la acción. Intentá nuevamente.';
  }

  String _extractMessage(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        final detail = json['detail'] as String?;
        if (detail != null && detail.isNotEmpty) return detail;
        final title = json['title'] as String?;
        if (title != null && title.isNotEmpty) return title;
      }
      if (json is String) return json;
    } catch (_) {}
    return body.replaceAll('"', '').trim();
  }

  String _playersCacheKey({String? estado, String? search, bool activo = true}) {
    final status = estado?.trim() ?? '';
    final term = search?.trim().toLowerCase() ?? '';
    final prefix = activo ? 'players:list' : 'players:list:inactivo';
    if (status.isEmpty && term.isEmpty) return prefix;
    return '$prefix:estado=$status:search=$term';
  }

  bool _matchesLocalFilters(
      PlayerModel player, String? estado, String? search, bool activo) {
    if (player.active != activo) return false;
    final statusMatches = estado == null ||
        estado.isEmpty ||
        PlayerModel.statusToApi(player.status) == estado;
    final term = search?.trim().toLowerCase();
    final searchMatches = term == null ||
        term.isEmpty ||
        player.name.toLowerCase().contains(term);
    return statusMatches && searchMatches;
  }
}

class PlayerApiException implements Exception {
  final String message;

  PlayerApiException(this.message);

  @override
  String toString() => message.replaceAll('"', '');
}
