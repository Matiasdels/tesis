import 'dart:convert';

import 'package:http/http.dart' as http;

import '../remote/api_config.dart';
import 'database_helper.dart';

class SyncService {
  SyncService({DatabaseHelper? databaseHelper, http.Client? client})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance,
        _client = client ?? http.Client();

  final DatabaseHelper _databaseHelper;
  final http.Client _client;

  Future<SyncResult> syncPendingActions(String accessToken) async {
    final pending = await _databaseHelper.getPendingSyncActions();
    var completed = 0;
    Object? syncError;

    for (final action in pending) {
      try {
        final response = await _send(action, accessToken);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          await _databaseHelper.markSyncActionCompleted(action.id);
          completed++;
        } else {
          final error = response.body.isEmpty
              ? 'HTTP ${response.statusCode}'
              : response.body;
          await _databaseHelper.markSyncActionFailed(
            action.id,
            error,
          );
          syncError ??= error;
        }
      } catch (error) {
        await _databaseHelper.markSyncActionFailed(action.id, error);
        syncError = error;
        break;
      }
    }

    return SyncResult(
      completedCount: completed,
      pendingCount: await _databaseHelper.pendingSyncCount(),
      error: syncError,
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
}

class SyncResult {
  final int completedCount;
  final int pendingCount;
  final Object? error;

  const SyncResult({
    required this.completedCount,
    required this.pendingCount,
    this.error,
  });

  bool get hasError => error != null;
}

class SyncServiceException implements Exception {
  final String message;

  const SyncServiceException(this.message);

  @override
  String toString() => message;
}
