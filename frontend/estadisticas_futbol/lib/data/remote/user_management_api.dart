import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/user_management_models.dart';
import 'api_config.dart';

class UserManagementApi {
  final http.Client _client = http.Client();

  Future<List<ManagedUserModel>> getUsers(String accessToken) async {
    final response = await _getList('/api/Usuarios', accessToken);
    return response
        .map((item) => ManagedUserModel.fromApi(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<RoleModel>> getRoles(String accessToken) async {
    final response = await _getList('/api/Catalogos/roles', accessToken);
    return response
        .map((item) => RoleModel.fromApi(item as Map<String, dynamic>))
        .toList();
  }

  Future<ManagedUserModel> createUser(
    CreateUserDraft draft,
    String accessToken,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/Usuarios');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(draft.toApiJson()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw UserManagementApiException(
        _friendlyError(response.statusCode, response.body),
      );
    }

    return ManagedUserModel.fromApi(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<dynamic>> _getList(String path, String accessToken) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw UserManagementApiException(
        _friendlyError(response.statusCode, response.body),
      );
    }

    return jsonDecode(response.body) as List<dynamic>;
  }

  String _friendlyError(int statusCode, String responseBody) {
    final message = _extractMessage(responseBody);
    if (statusCode == 401) return 'Tu sesion expiro. Volve a iniciar sesion.';
    if (statusCode == 409) {
      return message.isEmpty ? 'Ya existe un usuario con esos datos.' : message;
    }
    if (statusCode == 400) {
      return message.isEmpty ? 'Revisa los datos del usuario.' : message;
    }
    return 'No pudimos completar la accion. Intenta nuevamente.';
  }

  String _extractMessage(String body) {
    try {
      final json = jsonDecode(body);
      if (json is String) return json;
      if (json is Map<String, dynamic>) {
        return (json['detail'] ?? json['title'] ?? '').toString();
      }
    } catch (_) {}
    return body.replaceAll('"', '').trim();
  }
}

class UserManagementApiException implements Exception {
  final String message;

  const UserManagementApiException(this.message);

  @override
  String toString() => message;
}
