import 'package:flutter/foundation.dart';

import 'auth_api.dart';

class AuthState extends ChangeNotifier {
  final AuthApi _authApi;

  AuthSession? _session;
  bool _loading = false;

  AuthState({AuthApi? authApi}) : _authApi = authApi ?? AuthApi();

  AuthSession? get session => _session;
  AuthUser? get user => _session?.user;
  bool get isAuthenticated => _session != null;
  bool get loading => _loading;

  Future<void> login({
    required String usuarioOEmail,
    required String password,
  }) async {
    await _run(() async {
      _session = await _authApi.login(
        usuarioOEmail: usuarioOEmail,
        password: password,
      );
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
    });
  }

  void logout() {
    _session = null;
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
}
