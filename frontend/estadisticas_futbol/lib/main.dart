import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:estadisticas_futbol/core/router/app_router.dart';
import 'package:estadisticas_futbol/core/theme/app_theme.dart';
import 'package:estadisticas_futbol/data/remote/auth_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const FieldIQApp());
}

class FieldIQApp extends StatelessWidget {
  const FieldIQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthState(),
      child: MaterialApp.router(
        title: 'Kancha',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        routerConfig: router,
      ),
    );
  }
}
