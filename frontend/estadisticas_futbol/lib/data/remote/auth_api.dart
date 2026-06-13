import 'dart:convert';
import 'dart:io';

import 'api_config.dart';

class AuthApi {
  final HttpClient _client = HttpClient();

  Future<AuthSession> login({
    required String usuarioOEmail,
    required String password,
  }) async {
    final response = await _post('/api/Auth/login', {
      'usuarioOEmail': usuarioOEmail,
      'password': password,
    });

    return AuthSession.fromJson(response);
  }

  Future<AuthSession> register({
    required String nombreUsuario,
    required String email,
    required String password,
    required String nombre,
    required String apellido,
    required int rolId,
  }) async {
    final response = await _post('/api/Auth/registro', {
      'nombreUsuario': nombreUsuario,
      'email': email,
      'password': password,
      'nombre': nombre,
      'apellido': apellido,
      'rolId': rolId,
    });

    return AuthSession.fromJson(response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final request = await _client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthApiException(
        responseBody.isEmpty ? 'No se pudo completar la solicitud.' : responseBody,
      );
    }

    return jsonDecode(responseBody) as Map<String, dynamic>;
  }
}

class AuthApiException implements Exception {
  final String message;

  AuthApiException(this.message);

  @override
  String toString() => message.replaceAll('"', '');
}

class AuthSession {
  final AuthUser user;
  final String accessToken;
  final DateTime expiresAt;

  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.expiresAt,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      user: AuthUser.fromJson(json['usuario'] as Map<String, dynamic>),
      accessToken: json['accessToken'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }
}

class AuthUser {
  final int usuarioId;
  final String nombreUsuario;
  final String email;
  final String nombre;
  final String apellido;
  final int rolId;
  final String? rol;

  const AuthUser({
    required this.usuarioId,
    required this.nombreUsuario,
    required this.email,
    required this.nombre,
    required this.apellido,
    required this.rolId,
    required this.rol,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      usuarioId: json['usuarioId'] as int,
      nombreUsuario: json['nombreUsuario'] as String,
      email: json['email'] as String,
      nombre: json['nombre'] as String,
      apellido: json['apellido'] as String,
      rolId: json['rolId'] as int,
      rol: json['rol'] as String?,
    );
  }
}
