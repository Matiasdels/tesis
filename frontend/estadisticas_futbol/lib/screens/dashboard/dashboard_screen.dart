import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/remote/auth_state.dart';
import '../../data/remote/match_api.dart';
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
  final _matchApi = MatchApi();

  bool _showWelcome = true;
  bool _loadingPlayers = true;
  bool _loadingMatches = true;
  bool _playersLoadRequested = false;
  String? _playersError;
  List<PlayerModel> _players = [];
  PartidoModel? _nextMatch;
  PartidoModel? _lastMatch;
  Timer? _welcomeTimer;

  @override
  void initState() {
    super.initState();
    _welcomeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showWelcome = false);
    });
  }

  @override
  void dispose() {
    _welcomeTimer?.cancel();
    super.dispose();
  }

  void _requestPlayersWhenSessionIsReady(AuthState authState) {
    if (_playersLoadRequested ||
        !authState.initialized ||
        authState.session == null) {
      return;
    }

    _playersLoadRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadAll();
    });
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadPlayers(), _loadMatches()]);
  }

  Future<void> _loadPlayers() async {
    setState(() {
      _loadingPlayers = true;
      _playersError = null;
    });

    try {
      final session = context.read<AuthState>().session;
      if (session == null) {
        if (!mounted) return;
        setState(() {
          _loadingPlayers = true;
          _playersError = null;
        });
        return;
      }

      final token = session.accessToken;
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

  Future<void> _loadMatches() async {
    setState(() => _loadingMatches = true);

    try {
      final token = context.read<AuthState>().session?.accessToken;
      if (token == null) return;

      final upcoming = await _matchApi.getMatches(
        accessToken: token,
        estado: 'Programado',
      );
      final finished = await _matchApi.getMatches(
        accessToken: token,
        estado: 'Finalizado',
      );

      upcoming.sort((a, b) => a.fecha.compareTo(b.fecha));
      finished.sort((a, b) => b.fecha.compareTo(a.fecha));

      if (!mounted) return;
      setState(() {
        _nextMatch = upcoming.isNotEmpty ? upcoming.first : null;
        _lastMatch = finished.isNotEmpty ? finished.first : null;
        _loadingMatches = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMatches = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    _requestPlayersWhenSessionIsReady(authState);

    final user = authState.user;
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
        onRefresh: _loadAll,
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
            _MatchesCard(
              loading: _loadingMatches,
              nextMatch: _nextMatch,
              lastMatch: _lastMatch,
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
                  style: TextStyle(
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
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
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  player.position.isEmpty ? 'Sin posicion' : player.position,
                  style: TextStyle(
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

class _MatchesCard extends StatelessWidget {
  final bool loading;
  final PartidoModel? nextMatch;
  final PartidoModel? lastMatch;

  const _MatchesCard({
    required this.loading,
    required this.nextMatch,
    required this.lastMatch,
  });

  String _formatDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }

  String _score(PartidoModel m) {
    if (m.golesEquipo == null || m.golesRival == null) return '-';
    return m.esLocal
        ? '${m.golesEquipo} - ${m.golesRival}'
        : '${m.golesRival} - ${m.golesEquipo}';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Partidos',
            action: 'Ver todos',
            onAction: () => context.go(AppConstants.routeMatches),
          ),
          const SizedBox(height: 12),
          if (loading)
            const SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _MatchRow(
              label: 'Próximo',
              match: nextMatch,
              emptyMessage: 'Sin partidos programados',
              formatDate: _formatDate,
              score: _score,
            ),
            if (lastMatch != null) ...[
              Divider(color: AppColors.borderSubtle, height: 20),
              _MatchRow(
                label: 'Último',
                match: lastMatch,
                emptyMessage: '',
                formatDate: _formatDate,
                score: _score,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  final String label;
  final PartidoModel? match;
  final String emptyMessage;
  final String Function(DateTime) formatDate;
  final String Function(PartidoModel) score;

  const _MatchRow({
    required this.label,
    required this.match,
    required this.emptyMessage,
    required this.formatDate,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    if (match == null) {
      return Row(
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.bgMuted,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            emptyMessage,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      );
    }

    final rival = match!.rival;
    final localLabel = match!.esLocal ? 'Local' : 'Visitante';
    final scoreStr = label == 'Último' ? score(match!) : null;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push('/matches/${match!.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accentDim,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'vs $rival',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${formatDate(match!.fecha)} · $localLabel · ${match!.tipoCompeticion}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (scoreStr != null)
              Text(
                scoreStr,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
          ],
        ),
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
                  style: TextStyle(
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
