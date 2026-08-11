import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class AuthApi {
  final http.Client _client = http.Client();

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
  }) async {
    final response = await _post('/api/Auth/registro', {
      'nombreUsuario': nombreUsuario,
      'email': email,
      'password': password,
      'nombre': nombre,
      'apellido': apellido,
    });

    return AuthSession.fromJson(response);
  }

  Future<AuthUser> me(String accessToken) async {
    final response = await _get('/api/Auth/me', accessToken);

    return AuthUser.fromJson(response);
  }

  Future<AuthSession> refresh(String refreshToken) async {
    final response = await _post('/api/Auth/refresh', {
      'refreshToken': refreshToken,
    });

    return AuthSession.fromJson(response);
  }

  Future<void> logout(String refreshToken) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/Auth/logout');
    await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );
  }

  Future<Map<String, dynamic>> _get(String path, String accessToken) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthApiException(
        _friendlyError(response.statusCode, response.body),
        statusCode: response.statusCode,
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthApiException(
        _friendlyError(response.statusCode, response.body),
        statusCode: response.statusCode,
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _friendlyError(int statusCode, String responseBody) {
    final cleanBody = responseBody.replaceAll('"', '').trim();

    if (statusCode == 401 || statusCode == 400) {
      if (cleanBody.toLowerCase().contains('credenciales')) {
        return 'Usuario o contraseña incorrectos.';
      }
      return cleanBody.isEmpty
          ? 'Revisá los datos ingresados e intentá nuevamente.'
          : cleanBody;
    }

    if (statusCode == 409) {
      return cleanBody.isEmpty
          ? 'Ya existe un usuario con esos datos.'
          : cleanBody;
    }

    return 'No pudimos completar la acción. Intentá nuevamente.';
  }
}

class AuthApiException implements Exception {
  final String message;
  final int? statusCode;

  AuthApiException(this.message, {this.statusCode});

  @override
  String toString() => message.replaceAll('"', '');
}

class AuthSession {
  final AuthUser user;
  final String accessToken;
  final DateTime expiresAt;
  final String refreshToken;
  final DateTime refreshExpiresAt;

  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.expiresAt,
    required this.refreshToken,
    required this.refreshExpiresAt,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      user: AuthUser.fromJson(json['usuario'] as Map<String, dynamic>),
      accessToken: json['accessToken'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      refreshToken: json['refreshToken'] as String? ?? '',
      refreshExpiresAt: DateTime.tryParse(
            json['refreshExpiresAt'] as String? ?? '',
          ) ??
          DateTime.parse(json['expiresAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'usuario': user.toJson(),
      'accessToken': accessToken,
      'expiresAt': expiresAt.toIso8601String(),
      'refreshToken': refreshToken,
      'refreshExpiresAt': refreshExpiresAt.toIso8601String(),
    };
  }

  AuthSession copyWith({
    AuthUser? user,
    String? accessToken,
    DateTime? expiresAt,
    String? refreshToken,
    DateTime? refreshExpiresAt,
  }) {
    return AuthSession(
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      expiresAt: expiresAt ?? this.expiresAt,
      refreshToken: refreshToken ?? this.refreshToken,
      refreshExpiresAt: refreshExpiresAt ?? this.refreshExpiresAt,
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

  Map<String, dynamic> toJson() {
    return {
      'usuarioId': usuarioId,
      'nombreUsuario': nombreUsuario,
      'email': email,
      'nombre': nombre,
      'apellido': apellido,
      'rolId': rolId,
      'rol': rol,
    };
  }
}
