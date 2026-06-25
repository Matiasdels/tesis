import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/remote/auth_state.dart';
import '../../data/remote/player_api.dart';
import '../../models/models.dart';
import '../../widgets/common/app_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _playerApi = PlayerApi();

  bool _showWelcome = true;
  bool _loadingPlayers = true;
  String? _playersError;
  List<PlayerModel> _players = [];
  Timer? _welcomeTimer;

  @override
  void initState() {
    super.initState();
    _loadPlayers();
    _welcomeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showWelcome = false);
    });
  }

  @override
  void dispose() {
    _welcomeTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPlayers() async {
    setState(() {
      _loadingPlayers = true;
      _playersError = null;
    });

    try {
      final token = context.read<AuthState>().session!.accessToken;
      final players = await _playerApi.getPlayers(accessToken: token);
      if (!mounted) return;
      setState(() {
        _players = players;
        _loadingPlayers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _playersError = 'No pudimos cargar los jugadores reales.';
        _loadingPlayers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    final fullName = '${user?.nombre ?? ''} ${user?.apellido ?? ''}'.trim();
    final displayName =
        fullName.isEmpty ? user?.nombreUsuario ?? 'Usuario' : fullName;

    return PageScaffold(
      title: 'Panel',
      subtitle: 'Datos reales del sistema',
      actions: [
        ElevatedButton.icon(
          onPressed: () => context.go(AppConstants.routePlayers),
          icon: const Icon(Icons.person_add_outlined, size: 16),
          label: const Text('Jugadores'),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _loadPlayers,
        child: ListView(
          padding: const EdgeInsets.all(AppConstants.pagePadding),
          children: [
            AnimatedSwitcher(
              duration: AppConstants.animNormal,
              child: _showWelcome
                  ? _WelcomeCard(displayName: displayName)
                  : const SizedBox.shrink(),
            ),
            if (_showWelcome)
              const SizedBox(height: AppConstants.sectionSpacing),
            _KpiRow(players: _players, loading: _loadingPlayers),
            const SizedBox(height: AppConstants.sectionSpacing),
            _RosterCard(
              players: _players,
              loading: _loadingPlayers,
              error: _playersError,
              onRetry: _loadPlayers,
            ),
            const SizedBox(height: AppConstants.sectionSpacing),
            const _PendingDataCard(
              icon: Icons.sports_soccer_outlined,
              title: 'Partidos',
              subtitle:
                  'Crea, consulta y administra los partidos reales desde la seccion Partidos.',
            ),
            const SizedBox(height: AppConstants.sectionSpacing),
            const _PendingDataCard(
              icon: Icons.bar_chart_outlined,
              title: 'Estadisticas y reportes',
              subtitle:
                  'Los reportes y metricas se generan a partir de partidos y eventos registrados.',
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final String displayName;

  const _WelcomeCard({required this.displayName});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.35),
              ),
            ),
            child: const Icon(
              Icons.waving_hand_outlined,
              color: AppColors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, $displayName',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  final List<PlayerModel> players;
  final bool loading;

  const _KpiRow({required this.players, required this.loading});

  @override
  Widget build(BuildContext context) {
    final available = players.where((p) => p.status == 'available').length;
    final injured = players.where((p) => p.status == 'injured').length;
    final suspended = players.where((p) => p.status == 'suspended').length;

    final kpis = [
      StatCardData(
        label: 'Jugadores',
        value: loading ? '...' : '${players.length}',
        delta: 'Registrados',
        deltaPositive: null,
      ),
      StatCardData(
        label: 'Disponibles',
        value: loading ? '...' : '$available',
        delta: 'Activos',
        deltaPositive: null,
      ),
      StatCardData(
        label: 'Lesionados',
        value: loading ? '...' : '$injured',
        delta: 'Estado actual',
        deltaPositive: null,
      ),
      StatCardData(
        label: 'Suspendidos',
        value: loading ? '...' : '$suspended',
        delta: 'Estado actual',
        deltaPositive: null,
      ),
    ];

    final colors = [
      AppColors.textPrimary,
      AppColors.accent,
      AppColors.danger,
      AppColors.warning,
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

class _RosterCard extends StatelessWidget {
  final List<PlayerModel> players;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  const _RosterCard({
    required this.players,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const AppCard(
        child: SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (error != null) {
      return AppCard(
        child: EmptyState(
          icon: Icons.error_outline,
          title: 'No se pudo cargar la plantilla',
          subtitle: error!,
          actionLabel: 'Reintentar',
          onAction: onRetry,
        ),
      );
    }

    final display = players.take(5).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Plantilla registrada',
            action: 'Ver todos',
            onAction: () => context.go(AppConstants.routePlayers),
          ),
          const SizedBox(height: 10),
          if (display.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'Todavia no hay jugadores registrados.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ...display.map((player) => _PlayerRow(player: player)),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final PlayerModel player;

  const _PlayerRow({required this.player});

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
                Text(
                  player.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  player.position.isEmpty ? 'Sin posicion' : player.position,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(status: player.status),
        ],
      ),
    );
  }
}

class _PendingDataCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PendingDataCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textMuted, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
