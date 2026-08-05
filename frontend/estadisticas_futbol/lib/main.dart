import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:estadisticas_futbol/core/router/app_router.dart';
import 'package:estadisticas_futbol/core/settings/app_settings_controller.dart';
import 'package:estadisticas_futbol/core/theme/app_theme.dart';
import 'package:estadisticas_futbol/core/theme/theme_controller.dart';
import 'package:estadisticas_futbol/data/remote/auth_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final themeController = ThemeController();
  final settingsController = AppSettingsController();
  await themeController.initialize();
  await settingsController.initialize();

  runApp(KanchaApp(
    themeController: themeController,
    settingsController: settingsController,
  ));
}

class KanchaApp extends StatefulWidget {
  final ThemeController themeController;
  final AppSettingsController settingsController;

  const KanchaApp({
    super.key,
    required this.themeController,
    required this.settingsController,
  });

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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authState),
        ChangeNotifierProvider.value(value: widget.themeController),
        ChangeNotifierProvider.value(value: widget.settingsController),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) {
          return MaterialApp.router(
            title: 'Kancha',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode:
                themeController.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
