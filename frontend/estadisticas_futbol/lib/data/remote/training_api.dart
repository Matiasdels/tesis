import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/models.dart';
import '../local/database_helper.dart';
import 'api_config.dart';

class TrainingApi {
  final http.Client _client = http.Client();
  final _databaseHelper = DatabaseHelper.instance;

  Future<List<TrainingSessionModel>> getTrainingSessions({
    required String accessToken,
    int? categoriaId,
  }) async {
    final query = <String, String>{};
    if (categoriaId != null) query['categoriaId'] = '$categoriaId';
    final cacheKey = _trainingCacheKey(categoriaId: categoriaId);

    try {
      final response =
          await _getList('/api/Entrenamientos', accessToken, query: query);
      await _databaseHelper.saveJson(cacheKey, response);
      if (query.isEmpty) {
        await _databaseHelper.saveJson(_trainingCacheKey(), response);
      }
      return response
          .map((item) =>
              TrainingSessionModel.fromApi(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      final cached = await _databaseHelper.readJsonList(cacheKey) ??
          await _databaseHelper.readJsonList(_trainingCacheKey());
      if (cached != null) {
        return cached
            .map((item) =>
                TrainingSessionModel.fromApi(item as Map<String, dynamic>))
            .where((session) =>
                categoriaId == null || session.categoriaId == categoriaId)
            .toList();
      }
      rethrow;
    }
  }

  Future<TrainingSessionModel> createTrainingSession(
    TrainingSessionModel session,
    String accessToken,
  ) async {
    final response = await _send(
      'POST',
      '/api/Entrenamientos',
      accessToken,
      session.toApiJson(),
    );
    return TrainingSessionModel.fromApi(response);
  }

  Future<TrainingSessionModel> updateAttendance({
    required int sessionId,
    required List<TrainingAttendanceModel> attendance,
    required String accessToken,
  }) async {
    final response = await _send(
      'PUT',
      '/api/Entrenamientos/$sessionId/asistencia',
      accessToken,
      attendance.map((item) => item.toApiJson()).toList(),
    );
    return TrainingSessionModel.fromApi(response);
  }

  Future<void> deleteTrainingSession({
    required int sessionId,
    required String accessToken,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/Entrenamientos/$sessionId');
    final response = await _client.delete(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TrainingApiException(
        _friendlyError(response.statusCode, response.body),
      );
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
      throw TrainingApiException(
        _friendlyError(response.statusCode, response.body),
      );
    }

    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path,
    String accessToken,
    Object body,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
    final encodedBody = jsonEncode(body);
    final response = switch (method.toUpperCase()) {
      'POST' => await _client.post(uri, headers: headers, body: encodedBody),
      'PUT' => await _client.put(uri, headers: headers, body: encodedBody),
      _ => throw TrainingApiException(
          'No pudimos completar la accion. Intente nuevamente.'),
    };

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TrainingApiException(
        _friendlyError(response.statusCode, response.body),
      );
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
      // Respuesta no estructurada.
    }
    final cleanBody = responseBody.replaceAll('"', '').trim();
    if (cleanBody.isNotEmpty) return cleanBody;
    return 'No pudimos completar la accion. Intente nuevamente.';
  }

  String _trainingCacheKey({int? categoriaId}) =>
      categoriaId == null ? 'training:list' : 'training:list:$categoriaId';
}

class TrainingApiException implements Exception {
  final String message;

  TrainingApiException(this.message);

  @override
  String toString() => message.replaceAll('"', '');
}
