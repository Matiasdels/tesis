import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/models.dart';
import '../local/database_helper.dart';
import 'api_config.dart';

class MatchApi {
  final http.Client _client = http.Client();
  final _databaseHelper = DatabaseHelper.instance;

  Future<List<PartidoModel>> getMatches({
    required String accessToken,
    int? categoriaId,
    String? estado,
  }) async {
    final query = <String, String>{};
    if (categoriaId != null) query['categoriaId'] = '$categoriaId';
    if (estado != null && estado.isNotEmpty) query['estado'] = estado;

    final cacheKey = _matchesCacheKey(categoriaId: categoriaId, estado: estado);

    try {
      final response =
          await _getList('/api/Partidos', accessToken, query: query);
      await _databaseHelper.saveJson(cacheKey, response);
      if (query.isEmpty) {
        await _databaseHelper.saveJson(_matchesCacheKey(), response);
      }
      for (final item in response) {
        final map = item as Map<String, dynamic>;
        await _databaseHelper.saveJson(
          'matches:item:${map['partidoId']}',
          map,
        );
      }
      return response
          .map((item) => PartidoModel.fromApi(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      final cached = await _databaseHelper.readJsonList(cacheKey) ??
          await _databaseHelper.readJsonList(_matchesCacheKey());
      if (cached != null) {
        return cached
            .map((item) => PartidoModel.fromApi(item as Map<String, dynamic>))
            .where((match) => _matchesLocalFilters(match, categoriaId, estado))
            .toList();
      }
      rethrow;
    }
  }

  Future<PartidoModel> getMatch(int id, String accessToken) async {
    try {
      final response = await _getMap('/api/Partidos/$id', accessToken);
      await _databaseHelper.saveJson('matches:item:$id', response);
      return PartidoModel.fromApi(response);
    } catch (_) {
      final cached = await _databaseHelper.readJsonMap('matches:item:$id');
      if (cached != null) return PartidoModel.fromApi(cached);
      rethrow;
    }
  }

  Future<PartidoModel> createMatch(
    PartidoModel match,
    String accessToken,
  ) async {
    final response = await _send(
      'POST',
      '/api/Partidos',
      accessToken,
      match.toApiJson(),
    );
    await _databaseHelper.saveJson(
      'matches:item:${response['partidoId']}',
      response,
    );
    return PartidoModel.fromApi(response);
  }

  Future<PartidoModel> updateMatch(
    int id,
    PartidoModel match,
    String accessToken,
  ) async {
    final response = await _send(
      'PUT',
      '/api/Partidos/$id',
      accessToken,
      match.toApiJson(),
    );
    await _databaseHelper.saveJson('matches:item:$id', response);
    return PartidoModel.fromApi(response);
  }

  Future<PartidoModel> patchEstado(
    int id,
    String estado,
    String accessToken, {
    int? golesEquipo,
    int? golesRival,
    int? minutoActual,
    String? periodoActual,
    bool? huboAlargue,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/Partidos/$id/estado');
    final body = jsonEncode({
      'estado': estado,
      if (golesEquipo != null) 'golesEquipo': golesEquipo,
      if (golesRival != null) 'golesRival': golesRival,
      if (minutoActual != null) 'minutoActual': minutoActual,
      if (periodoActual != null) 'periodoActual': periodoActual,
      if (huboAlargue != null) 'huboAlargue': huboAlargue,
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
      throw MatchApiException(
          _friendlyError(response.statusCode, response.body));
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    await _databaseHelper.saveJson('matches:item:$id', json);
    return PartidoModel.fromApi(json);
  }

  Future<void> deleteMatch(int id, String accessToken) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/Partidos/$id');
    final response = await _client.delete(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MatchApiException(
          _friendlyError(response.statusCode, response.body));
    }
  }

  Future<AnalisisPartidoModel> generateIntelligentAnalysis(
    int id,
    String accessToken,
  ) async {
    final uri = Uri.parse(
        '${ApiConfig.baseUrl}/api/Partidos/$id/analisis-inteligente');
    final response = await _client.post(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MatchApiException(
          _friendlyError(response.statusCode, response.body));
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return AnalisisPartidoModel.fromApi(json);
  }

  Future<List<AlineacionEntradaModel>> getLineup(
    int matchId,
    String accessToken,
  ) async {
    try {
      final response =
          await _getList('/api/Partidos/$matchId/alineacion', accessToken);
      await _databaseHelper.saveJson('matches:$matchId:lineup', response);
      return response
          .map((item) =>
              AlineacionEntradaModel.fromApi(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      final cached =
          await _databaseHelper.readJsonList('matches:$matchId:lineup');
      if (cached != null) {
        return cached
            .map((item) =>
                AlineacionEntradaModel.fromApi(item as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
  }

  Future<List<AlineacionEntradaModel>> setLineup(
    int matchId,
    List<Map<String, dynamic>> entries,
    String accessToken, {
    String? formacion,
  }) async {
    final uri =
        Uri.parse('${ApiConfig.baseUrl}/api/Partidos/$matchId/alineacion');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
    final body = jsonEncode({
      if (formacion != null) 'formacion': formacion,
      'jugadores': entries,
    });
    final response = await _client.put(uri, headers: headers, body: body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MatchApiException(
          _friendlyError(response.statusCode, response.body));
    }

    final list = jsonDecode(response.body) as List<dynamic>;
    await _databaseHelper.saveJson('matches:$matchId:lineup', list);
    return list
        .map((item) =>
            AlineacionEntradaModel.fromApi(item as Map<String, dynamic>))
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
      throw MatchApiException(
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
      throw MatchApiException(
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
      throw MatchApiException(
          _friendlyError(response.statusCode, response.body));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _friendlyError(int statusCode, String responseBody) {
    if (statusCode == 401) return 'Tu sesion expiro. Volve a iniciar sesion.';
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final detail = json['detail'] as String?;
      if (detail != null && detail.isNotEmpty) return detail;
      final title = json['title'] as String?;
      if (title != null && title.isNotEmpty) return title;
    } catch (_) {
      // No es JSON o no tiene el formato ProblemDetails esperado.
    }
    final cleanBody = responseBody.replaceAll('"', '').trim();
    if (cleanBody.isNotEmpty) return cleanBody;
    if (statusCode == 404) {
      return 'Recurso no encontrado. Verifica que el servidor este actualizado.';
    }
    return 'Error $statusCode. No pudimos completar la accion. Intente nuevamente.';
  }

  String _matchesCacheKey({int? categoriaId, String? estado}) {
    if (categoriaId == null && (estado == null || estado.isEmpty)) {
      return 'matches:list';
    }
    return 'matches:list:categoria=${categoriaId ?? ''}:estado=${estado ?? ''}';
  }

  bool _matchesLocalFilters(
    PartidoModel match,
    int? categoriaId,
    String? estado,
  ) {
    final categoryMatches =
        categoriaId == null || match.categoriaId == categoriaId;
    final statusMatches =
        estado == null || estado.isEmpty || match.estado == estado;
    return categoryMatches && statusMatches;
  }
}

class MatchApiException implements Exception {
  final String message;
  MatchApiException(this.message);

  @override
  String toString() => message.replaceAll('"', '');
}
