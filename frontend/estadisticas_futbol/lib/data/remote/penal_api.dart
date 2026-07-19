import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/models.dart';
import 'api_config.dart';

class PenalApi {
  final http.Client _client = http.Client();

  Future<PartidoModel> guardarPenales({
    required int partidoId,
    required int resultadoPenalesEquipo,
    required int resultadoPenalesRival,
    required List<PenalDetalleModel> detalle,
    required String accessToken,
  }) async {
    final uri =
        Uri.parse('${ApiConfig.baseUrl}/api/Partidos/$partidoId/penales');
    final body = jsonEncode({
      'resultadoPenalesEquipo': resultadoPenalesEquipo,
      'resultadoPenalesRival': resultadoPenalesRival,
      'detalle': detalle.map((d) => d.toApiJson()).toList(),
    });
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: body,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PenalApiException(
          'Error ${response.statusCode}: ${response.body.replaceAll('"', '')}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return PartidoModel.fromApi(json);
  }

  Future<({int equipo, int rival, List<PenalDetalleModel> detalle})>
      getPenales({
    required int partidoId,
    required String accessToken,
  }) async {
    final uri =
        Uri.parse('${ApiConfig.baseUrl}/api/Partidos/$partidoId/penales');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PenalApiException(
          'Error ${response.statusCode}: ${response.body.replaceAll('"', '')}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final detalleList = (json['detalle'] as List<dynamic>)
        .map((d) => PenalDetalleModel.fromApi(d as Map<String, dynamic>))
        .toList();
    return (
      equipo: json['resultadoPenalesEquipo'] as int,
      rival: json['resultadoPenalesRival'] as int,
      detalle: detalleList,
    );
  }
}

class PenalApiException implements Exception {
  final String message;
  const PenalApiException(this.message);

  @override
  String toString() => message;
}
