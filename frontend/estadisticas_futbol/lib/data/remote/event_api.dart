import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/models.dart';
import '../local/database_helper.dart';
import '../local/sync_service.dart';
import 'api_config.dart';

class EventApi {
  final http.Client _client = http.Client();
  final _databaseHelper = DatabaseHelper.instance;
  late final SyncService _syncService = SyncService(
    databaseHelper: _databaseHelper,
    client: _client,
  );

  Future<int> pendingSyncCount() => _syncService.pendingCount();

  Future<SyncResult> syncPendingActions(String accessToken) =>
      _syncService.syncPendingActions(accessToken);

  Future<List<TipoEventoModel>> getTiposEvento(String accessToken) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/Catalogos/tipos-evento');
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      _checkStatus(response);
      final list = jsonDecode(response.body) as List<dynamic>;
      await _databaseHelper.saveJson('catalogs:tipos-evento', list);
      return list
          .map((e) => TipoEventoModel.fromApi(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      final cached =
          await _databaseHelper.readJsonList('catalogs:tipos-evento');
      if (cached != null) {
        return cached
            .map((e) => TipoEventoModel.fromApi(e as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
  }

  Future<List<EventoPartidoModel>> getEventos(
    int partidoId,
    String accessToken,
  {
    bool syncPending = true,
  }) async {
    if (syncPending) {
      try {
        await _syncService.syncPendingActions(accessToken);
      } catch (_) {
        // Si no hay conexion, se usan los eventos cacheados debajo.
      }
    }

    try {
      final uri =
          Uri.parse('${ApiConfig.baseUrl}/api/Partidos/$partidoId/eventos');
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      _checkStatus(response);
      final list = jsonDecode(response.body) as List<dynamic>;
      await _databaseHelper.saveJson(_eventsCacheKey(partidoId), list);
      return list
          .map((e) => EventoPartidoModel.fromApi(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      final cached = await _databaseHelper.readJsonList(
        _eventsCacheKey(partidoId),
      );
      if (cached != null) {
        return cached
            .map((e) => EventoPartidoModel.fromApi(e as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
  }

  Future<EventoPartidoModel> createEvento({
    required int partidoId,
    int? jugadorId,
    String? nombreJugador,
    // Para Cambio: jugador que entra.
    int? jugadorRelacionadoId,
    String? nombreJugadorRelacionado,
    required int tipoEventoId,
    String? tipoEventoNombre,
    required int minuto,
    required double pitchX,
    required double pitchY,
    String? observacion,
    String? periodo,
    required String accessToken,
  }) async {
    final endpoint = '/api/Partidos/$partidoId/eventos';
    final localEventoId = -DateTime.now().toUtc().millisecondsSinceEpoch;
    final body = {
      'localEventoId': localEventoId,
      if (jugadorId != null) 'jugadorId': jugadorId,
      if (jugadorRelacionadoId != null) 'jugadorRelacionadoId': jugadorRelacionadoId,
      'tipoEventoId': tipoEventoId,
      'minuto': minuto,
      'pitchX': pitchX,
      'pitchY': pitchY,
      if (observacion != null) 'observacion': observacion,
      if (periodo != null) 'periodo': periodo,
    };

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(body),
      );
      _checkStatus(response);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      // Preserve periodo in local cache since backend may not return it
      if (periodo != null && json['periodo'] == null) json['periodo'] = periodo;
      await _appendCachedEvento(partidoId, json);
      return EventoPartidoModel.fromApi(json);
    } on EventApiException {
      rethrow;
    } catch (_) {
      await _databaseHelper.enqueueSyncAction(
        entity: 'evento_partido',
        action: 'create',
        method: 'POST',
        endpoint: endpoint,
        payload: body,
      );

      final localJson = {
        'eventoId': localEventoId,
        'partidoId': partidoId,
        'jugadorId': jugadorId,
        'nombreJugador': nombreJugador,
        'jugadorRelacionadoId': jugadorRelacionadoId,
        'nombreJugadorRelacionado': nombreJugadorRelacionado,
        'tipoEventoId': tipoEventoId,
        'tipoEventoNombre': tipoEventoNombre ?? 'Evento pendiente',
        'minuto': minuto,
        'pitchX': pitchX,
        'pitchY': pitchY,
        'observacion': observacion,
        'periodo': periodo,
      };
      await _appendCachedEvento(partidoId, localJson);
      return EventoPartidoModel.fromApi(localJson);
    }
  }

  Future<void> deleteEvento({
    required int partidoId,
    required int eventoId,
    required String accessToken,
  }) async {
    if (eventoId < 0) {
      await _databaseHelper.deletePendingEventByLocalId(eventoId);
      await _removeCachedEvento(partidoId, eventoId);
      return;
    }

    final uri = Uri.parse(
        '${ApiConfig.baseUrl}/api/Partidos/$partidoId/eventos/$eventoId');
    final response = await _client.delete(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    _checkStatus(response);
    await _removeCachedEvento(partidoId, eventoId);
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) {
        throw const EventApiException(
          'Tu sesion expiro. Volve a iniciar sesion.',
          sessionExpired: true,
        );
      }
      throw EventApiException(
          _extractMessage(response.statusCode, response.body));
    }
  }

  String _extractMessage(int statusCode, String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final detail = json['detail'] as String?;
      if (detail != null && detail.isNotEmpty) return detail;
      final title = json['title'] as String?;
      if (title != null && title.isNotEmpty) return title;
    } catch (_) {
      // No es JSON o no tiene el formato ProblemDetails esperado.
    }
    final clean = body.replaceAll('"', '').trim();
    return clean.isNotEmpty ? clean : 'Error $statusCode';
  }

  String _eventsCacheKey(int partidoId) => 'matches:$partidoId:events';

  Future<void> _appendCachedEvento(
    int partidoId,
    Map<String, dynamic> evento,
  ) async {
    final key = _eventsCacheKey(partidoId);
    final cached = await _databaseHelper.readJsonList(key) ?? [];
    final withoutDuplicate = cached.where((item) {
      final map = item as Map<String, dynamic>;
      return map['eventoId'] != evento['eventoId'];
    }).toList();
    await _databaseHelper.saveJson(key, [...withoutDuplicate, evento]);
  }

  Future<void> _removeCachedEvento(int partidoId, int eventoId) async {
    final key = _eventsCacheKey(partidoId);
    final cached = await _databaseHelper.readJsonList(key) ?? [];
    final filtered = cached.where((item) {
      final map = item as Map<String, dynamic>;
      return map['eventoId'] != eventoId;
    }).toList();
    await _databaseHelper.saveJson(key, filtered);
  }
}

class EventApiException implements Exception {
  final String message;
  final bool sessionExpired;

  const EventApiException(
    this.message, {
    this.sessionExpired = false,
  });

  @override
  String toString() => message;
}
