import 'dart:convert';

import 'package:http/http.dart' as http;

import '../remote/api_config.dart';
import 'database_helper.dart';

class SyncService {
  SyncService({DatabaseHelper? databaseHelper, http.Client? client})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance,
        _client = client ?? http.Client();

  static const int _maxServerAttempts = 3;

  final DatabaseHelper _databaseHelper;
  final http.Client _client;

  Future<SyncResult> syncPendingActions(String accessToken) async {
    final pending = await _databaseHelper.getPendingSyncActions();
    var completed = 0;
    String? technicalError;

    for (final action in pending) {
      if (action.attempts >= _maxServerAttempts) {
        technicalError ??= action.lastError;
        continue;
      }

      try {
        final response = await _send(action, accessToken);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          await _clearSyncedLocalEvent(action);
          await _databaseHelper.markSyncActionCompleted(action.id);
          completed++;
        } else {
          final error = _formatHttpError(response);
          await _databaseHelper.markSyncActionFailed(
            action.id,
            error,
          );
          technicalError ??= error;
        }
      } catch (error) {
        final technicalMessage = _formatException(error);
        await _databaseHelper.markSyncActionConnectionFailed(
          action.id,
          technicalMessage,
        );
        technicalError = technicalMessage;
        break;
      }
    }

    return SyncResult(
      completedCount: completed,
      pendingCount: await _databaseHelper.pendingSyncCount(),
      technicalError: technicalError,
    );
  }

  Future<int> pendingCount() => _databaseHelper.pendingSyncCount();

  Future<http.Response> _send(
    PendingSyncAction action,
    String accessToken,
  ) {
    final uri = Uri.parse('${ApiConfig.baseUrl}${action.endpoint}');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
    final body = jsonEncode(action.payload);

    switch (action.method.toUpperCase()) {
      case 'POST':
        return _client.post(uri, headers: headers, body: body);
      case 'PUT':
        return _client.put(uri, headers: headers, body: body);
      case 'PATCH':
        return _client.patch(uri, headers: headers, body: body);
      case 'DELETE':
        return _client.delete(uri, headers: headers, body: body);
      default:
        throw SyncServiceException('Metodo no soportado: ${action.method}');
    }
  }

  Future<void> _clearSyncedLocalEvent(PendingSyncAction action) async {
    if (action.entity != 'evento_partido' || action.action != 'create') return;

    final localEventoId = action.payload['localEventoId'];
    if (localEventoId is! int) return;

    final match = RegExp(r'^/api/Partidos/(\d+)/eventos$')
        .firstMatch(action.endpoint);
    final partidoId = match == null ? null : int.tryParse(match.group(1)!);
    if (partidoId == null) return;

    try {
      await _databaseHelper.removeCachedEventByLocalId(
        partidoId,
        localEventoId,
      );
    } catch (_) {
      // La sincronizacion ya fue aceptada por el servidor; no se bloquea la cola
      // si la limpieza local no puede completarse.
    }
  }

  String _formatHttpError(http.Response response) {
    final body = response.body.trim();
    final detail = body.isEmpty ? 'Sin cuerpo de respuesta' : body;
    return _limitTechnicalError('HTTP ${response.statusCode}: $detail');
  }

  String _formatException(Object error) =>
      _limitTechnicalError('${error.runtimeType}: $error');

  String _limitTechnicalError(String value) {
    const maxLength = 1000;
    return value.length <= maxLength
        ? value
        : '${value.substring(0, maxLength)}...';
  }
}

class SyncResult {
  final int completedCount;
  final int pendingCount;
  final String? technicalError;

  const SyncResult({
    required this.completedCount,
    required this.pendingCount,
    this.technicalError,
  });

  bool get hasError => technicalError != null;
}

class SyncServiceException implements Exception {
  final String message;

  const SyncServiceException(this.message);

  @override
  String toString() => message;
}
