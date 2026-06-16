import 'package:flutter/material.dart';

import '../../widgets/common/app_widgets.dart';

class LiveMatchScreen extends StatelessWidget {
  final String matchId;

  const LiveMatchScreen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'Partido en vivo',
      showBack: true,
      body: EmptyState(
        icon: Icons.sports_soccer_outlined,
        title: 'Sin partido real cargado',
        subtitle:
            'La pantalla de partido en vivo queda desactivada hasta conectar partidos y eventos reales desde la API.',
      ),
    );
  }
}
