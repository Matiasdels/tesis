import 'package:flutter_test/flutter_test.dart';
import 'package:estadisticas_futbol/main.dart';

void main() {
  testWidgets('Carga inicial de KanchaApp sin errores',
      (WidgetTester tester) async {
    await tester.pumpWidget(const KanchaApp());
    await tester.pumpAndSettle();

    expect(find.byType(KanchaApp), findsOneWidget);
  });
}
