import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:estadisticas_futbol/core/router/app_router.dart';
import 'package:estadisticas_futbol/core/theme/app_theme.dart';
import 'package:estadisticas_futbol/data/remote/auth_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const KanchaApp());
}

class KanchaApp extends StatefulWidget {
  const KanchaApp({super.key});

  @override
  State<KanchaApp> createState() => _KanchaAppState();
}

class _KanchaAppState extends State<KanchaApp> {
  late final AuthState _authState;
  late final RouterConfig<Object> _router;

  @override
  void initState() {
    super.initState();
    _authState = AuthState();
    _router = createRouter(_authState);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authState.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => _authState,
      child: MaterialApp.router(
        title: 'Kancha',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        routerConfig: _router,
      ),
    );
  }
}
