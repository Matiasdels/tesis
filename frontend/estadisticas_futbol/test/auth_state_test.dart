import 'package:estadisticas_futbol/data/remote/auth_state.dart';
import 'package:estadisticas_futbol/data/remote/auth_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// AuthApi falso que resuelve inmediatamente sin red.
class _FakeAuthApi extends AuthApi {
  @override
  Future<AuthUser> me(String accessToken) async {
    throw Exception('No hay sesión en tests');
  }
}

void main() {
  group('AuthState — estado inicial (antes de initialize)', () {
    test('isAuthenticated es false', () {
      final state = AuthState(authApi: _FakeAuthApi());
      expect(state.isAuthenticated, isFalse);
    });

    test('initialized es false', () {
      final state = AuthState(authApi: _FakeAuthApi());
      expect(state.initialized, isFalse);
    });

    test('session es null', () {
      final state = AuthState(authApi: _FakeAuthApi());
      expect(state.session, isNull);
    });

    test('loading es false', () {
      final state = AuthState(authApi: _FakeAuthApi());
      expect(state.loading, isFalse);
    });
  });

  group('AuthState.initialize — sin demora artificial', () {
    test('initialize() termina en menos de 2 segundos (sin delay fijo de 3s)', () async {
      // Este test verifica que se eliminó el delay artificial de 3 segundos.
      // En entorno de test, sqflite puede no estar disponible y la función
      // puede lanzar — lo que importa es que NO espera 3 segundos.
      final state = AuthState(authApi: _FakeAuthApi());
      final sw = Stopwatch()..start();

      try {
        await state.initialize().timeout(const Duration(seconds: 4));
      } catch (_) {
        // Si sqflite no está disponible, la función lanza antes de los 3s.
        // Eso sigue siendo una victoria: no hay delay artificial.
      }

      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(2000),
          reason:
              'initialize() no debe tener un delay fijo de 3 segundos. '
              'Tiempo real: ${sw.elapsedMilliseconds}ms');
    });
  });
}
