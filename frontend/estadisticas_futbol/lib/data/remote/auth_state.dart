import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../local/database_helper.dart';
import 'auth_api.dart';

class AuthState extends ChangeNotifier {
  final AuthApi _authApi;

  AuthSession? _session;
  bool _loading = false;
  bool _initialized = false;

  AuthState({AuthApi? authApi}) : _authApi = authApi ?? AuthApi();

  AuthSession? get session => _session;
  AuthUser? get user => _session?.user;
  bool get isAuthenticated => _session != null;
  bool get loading => _loading;
  bool get initialized => _initialized;

  Future<void> initialize() async {
    final minimumSplashTime = Future<void>.delayed(
      const Duration(seconds: 3),
    );
    final storedSession = await _readStoredSession();

    if (storedSession == null ||
        storedSession.expiresAt.isBefore(DateTime.now())) {
      await _clearStoredSession();
      await minimumSplashTime;
      _initialized = true;
      notifyListeners();
      return;
    }

    try {
      final user = await _authApi.me(storedSession.accessToken);
      _session = storedSession.copyWith(user: user);
      await _saveSession(_session!);
    } catch (_) {
      await _clearStoredSession();
      _session = null;
    } finally {
      await minimumSplashTime;
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> login({
    required String usuarioOEmail,
    required String password,
  }) async {
    await _run(() async {
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
    required int rolId,
  }) async {
    await _run(() async {
      _session = await _authApi.register(
        nombreUsuario: nombreUsuario,
        email: email,
        password: password,
        nombre: nombre,
        apellido: apellido,
        rolId: rolId,
      );
      await _saveSession(_session!);
    });
  }

  Future<void> logout() async {
    _session = null;
    await _clearStoredSession();
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

  Future<Database> _database() async {
    final db = await DatabaseHelper.instance.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS auth_session (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        data TEXT NOT NULL
      )
    ''');
    return db;
  }

  Future<void> _saveSession(AuthSession session) async {
    if (kIsWeb) return;

    final db = await _database();
    await db.insert(
      'auth_session',
      {'id': 1, 'data': jsonEncode(session.toJson())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AuthSession?> _readStoredSession() async {
    if (kIsWeb) return null;

    final db = await _database();
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

    final db = await _database();
    await db.delete('auth_session', where: 'id = ?', whereArgs: [1]);
  }
}
