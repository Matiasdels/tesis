import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../mock/mock_data.dart';
import '../../widgets/common/app_widgets.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Panel',
      subtitle: 'Temporada 2024–25 · Jornada 22',
      actions: [
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.download_outlined, size: 16),
          label: const Text('Exportar'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => context.go(AppConstants.routeMatches),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Nuevo partido'),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.pagePadding),
        children: const [
          _KpiRow(),
          SizedBox(height: AppConstants.sectionSpacing),
          _MidSection(),
          SizedBox(height: AppConstants.sectionSpacing),
          _BottomSection(),
        ],
      ),
    );
  }
}

// ── KPI row ────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  const _KpiRow();

  @override
  Widget build(BuildContext context) {
    const kpis = MockData.dashboardKpis;
    final colors = [
      AppColors.textPrimary,
      AppColors.accent,
      AppColors.textPrimary,
      AppColors.danger
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final crossCount = constraints.maxWidth > 600 ? 4 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossCount,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.7,
        ),
        itemCount: kpis.length,
        itemBuilder: (_, i) => StatCard(data: kpis[i], accentColor: colors[i]),
      );
    });
  }
}

// ── Middle section ─────────────────────────────────────────────────────────

class _MidSection extends StatelessWidget {
  const _MidSection();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width > 700;

    final leftPanel = _PlayerPerformanceCard();
    final rightPanels = Column(
      children: [
        _NextMatchCard(),
        const SizedBox(height: 10),
        _RecentFormCard(),
      ],
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: leftPanel),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: rightPanels),
        ],
      );
    }
    return Column(
      children: [
        leftPanel,
        const SizedBox(height: 10),
        rightPanels,
      ],
    );
  }
}

class _PlayerPerformanceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final top = MockData.players.where((p) => p.isAvailable).toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
    final display = top.take(5).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Rendimiento individual — semana',
            action: 'Ver todos',
            onAction: () => context.go(AppConstants.routePlayers),
          ),
          const SizedBox(height: 10),
          ...display.map((p) => _PlayerRatingRow(player: p)),
        ],
      ),
    );
  }
}

class _PlayerRatingRow extends StatelessWidget {
  final dynamic player;
  const _PlayerRatingRow({required this.player});

  Color get _ratingColor {
    if (player.rating >= 85) return AppColors.accent;
    if (player.rating >= 75) return AppColors.info;
    if (player.rating >= 65) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          PlayerAvatar(player: player, radius: 15),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                Text(player.position,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
          ),
          SizedBox(
            width: 70,
            child: LinearProgressIndicator(
              value: player.rating / 100,
              minHeight: 4,
              backgroundColor: AppColors.borderDefault,
              valueColor: AlwaysStoppedAnimation(_ratingColor),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text('${player.rating.toInt()}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _ratingColor)),
        ],
      ),
    );
  }
}

class _NextMatchCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final next = MockData.matches.firstWhere((m) => m.status == 'upcoming');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Próximo partido'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgMuted,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSubtle, width: 0.5),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TeamBlock(
                        abbr: next.homeAbbr,
                        name: next.homeTeam,
                        color: AppColors.accent),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Text('vs',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.textSecondary)),
                    ),
                    _TeamBlock(
                        abbr: next.awayAbbr,
                        name: next.awayTeam,
                        color: AppColors.info),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_weekday(next.date)} ${next.date.day} ene · ${next.date.hour}:${next.date.minute.toString().padLeft(2, '0')} · ${next.venue}',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    _MiniStat('3 días', 'Faltan'),
                    _MiniStat('21', 'Disponibles'),
                    _MiniStat('68%', 'Win prob.'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/matches/live/${next.id}'),
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('Iniciar partido en vivo'),
            ),
          ),
        ],
      ),
    );
  }

  String _weekday(DateTime d) {
    const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return days[d.weekday - 1];
  }
}

class _TeamBlock extends StatelessWidget {
  final String abbr;
  final String name;
  final Color color;
  const _TeamBlock(
      {required this.abbr, required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Text(abbr,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w500)),
        ),
        const SizedBox(height: 4),
        Text(name,
            style:
                const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  const _MiniStat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
            Text(label,
                style: const TextStyle(
                    fontSize: 9, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _RecentFormCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Forma reciente'),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: MockData.recentForm
                .map((r) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FormBadge(result: r)))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── Bottom section ─────────────────────────────────────────────────────────

class _BottomSection extends StatelessWidget {
  const _BottomSection();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width > 700;

    final activity = _ActivityCard();
    final alerts = _AlertsCard();

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: activity),
          const SizedBox(width: 10),
          Expanded(child: alerts),
        ],
      );
    }
    return Column(children: [activity, const SizedBox(height: 10), alerts]);
  }
}

class _ActivityCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      (
        AppColors.accent,
        'Entrenamiento registrado — Táctica defensiva',
        'Hoy 10:30'
      ),
      (
        AppColors.info,
        'Partido vs Atlético Sur — estadísticas cargadas',
        'Ayer 19:15'
      ),
      (AppColors.purple, 'Reporte semanal generado por Analista', 'Ayer 14:00'),
      (
        AppColors.warning,
        'Observación táctica de J. Rodríguez añadida',
        'Hace 2 días'
      ),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
              title: 'Actividad reciente', action: 'Ver todo', onAction: () {}),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: item.$1, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(item.$2,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textPrimary))),
                    Text(item.$3,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _AlertsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final alerts = [
      (
        Icons.favorite_border,
        AppColors.danger,
        'M. González — posible sobrecarga',
        'RPE de 9/10 en 3 sesiones consecutivas'
      ),
      (
        Icons.bedtime_outlined,
        AppColors.warning,
        'P. Torres — monitoreo descanso',
        '2 días sin reporte de bienestar'
      ),
      (
        Icons.article_outlined,
        AppColors.accent,
        'Reporte mensual listo para revisar',
        'Generado automáticamente'
      ),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Alertas del sistema'),
          const SizedBox(height: 8),
          ...alerts.map((a) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: a.$2.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(a.$1, size: 16, color: a.$2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.$3,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textPrimary)),
                          Text(a.$4,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
