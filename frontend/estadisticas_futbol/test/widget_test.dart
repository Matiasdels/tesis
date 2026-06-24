import 'package:flutter_test/flutter_test.dart';
import 'package:estadisticas_futbol/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('Carga inicial de KanchaApp sin errores',
      (WidgetTester tester) async {
    await tester.pumpWidget(const KanchaApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.byType(KanchaApp), findsOneWidget);
  });
}
