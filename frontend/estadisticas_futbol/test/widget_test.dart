import 'package:flutter_test/flutter_test.dart';
import 'package:estadisticas_futbol/core/settings/app_settings_controller.dart';
import 'package:estadisticas_futbol/core/theme/theme_controller.dart';
import 'package:estadisticas_futbol/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('Carga inicial de KanchaApp sin errores',
      (WidgetTester tester) async {
    final settingsController = AppSettingsController();

    await tester.pumpWidget(
      KanchaApp(
        themeController: ThemeController(),
        settingsController: settingsController,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.byType(KanchaApp), findsOneWidget);
  });
}
