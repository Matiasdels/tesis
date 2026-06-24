import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'Listado → Detalle → Resumen → Detalle → Listado conserva el stack',
    (tester) async {
      final rootNavigatorKey = GlobalKey<NavigatorState>();
      final shellNavigatorKey = GlobalKey<NavigatorState>();

      final router = GoRouter(
        navigatorKey: rootNavigatorKey,
        initialLocation: '/matches',
        routes: [
          ShellRoute(
            navigatorKey: shellNavigatorKey,
            builder: (_, __, child) => Scaffold(body: child),
            routes: [
              GoRoute(
                path: '/matches',
                builder: (_, __) => const _MatchesPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (_, state) => MaterialPage<bool>(
                      key: state.pageKey,
                      child: const _DetailPage(),
                    ),
                    routes: [
                      GoRoute(
                        path: 'summary',
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (_, state) => MaterialPage<void>(
                          key: state.pageKey,
                          child: const _SummaryPage(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router),
      );

      await tester.tap(find.text('Abrir detalle'));
      await tester.pumpAndSettle();
      expect(find.text('Detalle'), findsOneWidget);

      await tester.tap(find.text('Ver resumen'));
      await tester.pumpAndSettle();
      expect(find.text('Resumen'), findsOneWidget);

      await tester.tap(find.text('Volver a detalle'));
      await tester.pumpAndSettle();
      expect(find.text('Detalle'), findsOneWidget);

      await tester.tap(find.text('Volver al listado'));
      await tester.pumpAndSettle();
      expect(find.text('Listado'), findsOneWidget);
      expect(find.text('Resultado: true'), findsOneWidget);
    },
  );
}

class _MatchesPage extends StatefulWidget {
  const _MatchesPage();

  @override
  State<_MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<_MatchesPage> {
  bool? _result;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('Listado'),
        TextButton(
          onPressed: () async {
            final result = await context.push<bool>('/matches/1');
            if (mounted) setState(() => _result = result);
          },
          child: const Text('Abrir detalle'),
        ),
        Text('Resultado: $_result'),
      ],
    );
  }
}

class _DetailPage extends StatelessWidget {
  const _DetailPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Text('Detalle'),
          TextButton(
            onPressed: () => context.push<void>('/matches/1/summary'),
            child: const Text('Ver resumen'),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            child: const Text('Volver al listado'),
          ),
        ],
      ),
    );
  }
}

class _SummaryPage extends StatelessWidget {
  const _SummaryPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Text('Resumen'),
          TextButton(
            onPressed: context.pop,
            child: const Text('Volver a detalle'),
          ),
        ],
      ),
    );
  }
}
