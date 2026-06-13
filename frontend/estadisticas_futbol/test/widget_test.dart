import 'package:flutter_test/flutter_test.dart';
import 'package:estadisticas_futbol/main.dart';

void main() {
  testWidgets('Carga inicial de FieldIQApp sin errores', (WidgetTester tester) async {
    // Construye la aplicación con GoRouter y dispara el primer renderizado
    await tester.pumpWidget(const FieldIQApp());

    // Espera a que las animaciones o la inicialización de rutas terminen
    await tester.pumpAndSettle();

    // Verifica que la aplicación montó el árbol de widgets principal con éxito
    expect(find.byType(FieldIQApp), findsOneWidget);
  });
}
