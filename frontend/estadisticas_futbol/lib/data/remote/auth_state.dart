import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../local/database_helper.dart';
import 'auth_api.dart';

class AuthState extends ChangeNotifier {
  final AuthApi _authApi;

  AuthSession? _session;
  String? _authNotice;
  Timer? _refreshTimer;
  bool _loading = false;
  bool _initialized = false;

  static const _refreshBeforeExpiry = Duration(minutes: 5);

  AuthState({AuthApi? authApi}) : _authApi = authApi ?? AuthApi();

  AuthSession? get session => _session;
  AuthUser? get user => _session?.user;
  String? get authNotice => _authNotice;
  bool get isAuthenticated => _session != null;
  bool get loading => _loading;
  bool get initialized => _initialized;

  Future<void> initialize() async {
    final storedSession = await _readStoredSession();

    if (storedSession == null) {
      await _clearStoredSession();
      _initialized = true;
      notifyListeners();
      return;
    }

    try {
      final activeSession = await _sessionWithFreshAccess(storedSession);
      final user = await _authApi.me(activeSession.accessToken);
      _session = activeSession.copyWith(user: user);
      await _saveSession(_session!);
      _scheduleRefresh();
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
      _scheduleRefresh();
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
      _scheduleRefresh();
    });
  }

  Future<void> logout() async {
    final refreshToken = _session?.refreshToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      unawaited(_authApi.logout(refreshToken));
    }
    _refreshTimer?.cancel();
    _session = null;
    _authNotice = null;
    await _clearStoredSession();
    notifyListeners();
  }

  Future<void> expireSession() async {
    _refreshTimer?.cancel();
    _session = null;
    _authNotice = 'Tu sesion expiro. Volve a iniciar sesion.';
    await _clearStoredSession();
    notifyListeners();
  }

  Future<AuthSession> _sessionWithFreshAccess(AuthSession session) async {
    final now = DateTime.now();
    if (session.expiresAt.isAfter(now.add(_refreshBeforeExpiry))) {
      return session;
    }

    if (session.refreshToken.isEmpty ||
        session.refreshExpiresAt.isBefore(now)) {
      throw AuthApiException(
        'Tu sesion expiro. Volve a iniciar sesion.',
        statusCode: 401,
      );
    }

    return _authApi.refresh(session.refreshToken);
  }

  Future<void> _refreshSession() async {
    final current = _session;
    if (current == null || current.refreshToken.isEmpty) return;

    try {
      final refreshed = await _authApi.refresh(current.refreshToken);
      _session = refreshed;
      await _saveSession(refreshed);
      _scheduleRefresh();
      notifyListeners();
    } on AuthApiException catch (error) {
      if (error.statusCode == 401) {
        await expireSession();
      }
    } catch (_) {
      _scheduleRefresh(delay: const Duration(minutes: 2));
    }
  }

  void _scheduleRefresh({Duration? delay}) {
    _refreshTimer?.cancel();

    final current = _session;
    if (current == null || current.refreshToken.isEmpty) return;
    if (current.refreshExpiresAt.isBefore(DateTime.now())) return;

    final refreshDelay = delay ??
        current.expiresAt.difference(DateTime.now()) - _refreshBeforeExpiry;

    _refreshTimer = Timer(
      refreshDelay.isNegative ? Duration.zero : refreshDelay,
      () => unawaited(_refreshSession()),
    );
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

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
