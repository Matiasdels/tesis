import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../local/database_helper.dart';
import 'auth_api.dart';

class AuthState extends ChangeNotifier {
  final AuthApi _authApi;

  AuthSession? _session;
  String? _authNotice;
  bool _loading = false;
  bool _initialized = false;

  AuthState({AuthApi? authApi}) : _authApi = authApi ?? AuthApi();

  AuthSession? get session => _session;
  AuthUser? get user => _session?.user;
  String? get authNotice => _authNotice;
  bool get isAuthenticated => _session != null;
  bool get loading => _loading;
  bool get initialized => _initialized;

  Future<void> initialize() async {
    final storedSession = await _readStoredSession();

    if (storedSession == null ||
        storedSession.expiresAt.isBefore(DateTime.now())) {
      await _clearStoredSession();
      if (storedSession != null) {
        _authNotice = 'Tu sesion expiro. Volve a iniciar sesion.';
      }
      _initialized = true;
      notifyListeners();
      return;
    }

    try {
      final user = await _authApi.me(storedSession.accessToken);
      _session = storedSession.copyWith(user: user);
      await _saveSession(_session!);
    } on AuthApiException catch (error) {
      await _clearStoredSession();
      _session = null;
      _authNotice = error.statusCode == 401
          ? 'Tu sesion expiro. Volve a iniciar sesion.'
          : 'No pudimos validar tu sesion. Volve a iniciar sesion.';
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> login({
    required String usuarioOEmail,
    required String password,
  }) async {
    await _run(() async {
      _authNotice = null;
      _session = await _authApi.login(
        usuarioOEmail: usuarioOEmail,
        password: password,
      );
      await _saveSession(_session!);
    });
  }

  Future<void> register({
    required String nombreUsuario,
    required String email,
    required String password,
    required String nombre,
    required String apellido,
  }) async {
    await _run(() async {
      _authNotice = null;
      _session = await _authApi.register(
        nombreUsuario: nombreUsuario,
        email: email,
        password: password,
        nombre: nombre,
        apellido: apellido,
      );
      await _saveSession(_session!);
    });
  }

  Future<void> logout() async {
    _session = null;
    _authNotice = null;
    await _clearStoredSession();
    notifyListeners();
  }

  Future<void> expireSession() async {
    _session = null;
    _authNotice = 'Tu sesion expiro. Volve a iniciar sesion.';
    await _clearStoredSession();
    notifyListeners();
  }

  void clearAuthNotice() {
    if (_authNotice == null) return;
    _authNotice = null;
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    _loading = true;
    notifyListeners();

    try {
      await action();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _saveSession(AuthSession session) async {
    if (kIsWeb) return;

    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'auth_session',
      {'id': 1, 'data': jsonEncode(session.toJson())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AuthSession?> _readStoredSession() async {
    if (kIsWeb) return null;

    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'auth_session',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final data = rows.first['data'] as String;
    return AuthSession.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  Future<void> _clearStoredSession() async {
    if (kIsWeb) return;

    final db = await DatabaseHelper.instance.database;
    await db.delete('auth_session', where: 'id = ?', whereArgs: [1]);
  }
}
