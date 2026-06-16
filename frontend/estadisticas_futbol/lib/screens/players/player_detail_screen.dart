import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/remote/auth_state.dart';
import '../../data/remote/player_api.dart';
import '../../mock/mock_data.dart';
import '../../models/models.dart';
import '../../widgets/common/app_widgets.dart';

class PlayerDetailScreen extends StatefulWidget {
  final String playerId;
  const PlayerDetailScreen({super.key, required this.playerId});

  @override
  State<PlayerDetailScreen> createState() => _PlayerDetailScreenState();
}

class _PlayerDetailScreenState extends State<PlayerDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _api = PlayerApi();

  PlayerModel? _player;
  bool _loading = true;
  bool _changed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = context.read<AuthState>().session!.accessToken;
      final player = await _api.getPlayer(widget.playerId, token);
      setState(() {
        _player = player;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'No pudimos cargar el jugador. Intentá nuevamente.';
        _loading = false;
      });
    }
  }

  Future<void> _toggleActive() async {
    final player = _player;
    if (player == null) return;

    final token = context.read<AuthState>().session!.accessToken;

    try {
      if (player.active) {
        await _api.deactivatePlayer(player.id, token);
      } else {
        await _api.updatePlayer(player.id, player.copyWith(active: true), token);
      }
      _changed = true;
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos actualizar el estado del jugador.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || _player == null
              ? EmptyState(
                  icon: Icons.error_outline,
                  title: 'Algo salió mal',
                  subtitle: _error ?? 'Jugador no encontrado',
                  actionLabel: 'Reintentar',
                  onAction: _load,
                )
              : _buildContent(_player!),
    );
  }

  Widget _buildContent(PlayerModel player) {
    return NestedScrollView(
      headerSliverBuilder: (_, __) => [
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: AppColors.bgSurface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(_changed),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar jugador',
              onPressed: () async {
                final updated = await context
                    .push<bool>('/players/${player.id}/edit');
                if (updated == true) {
                  _changed = true;
                  _load();
                }
              },
            ),
            IconButton(
              icon: Icon(player.active
                  ? Icons.person_remove_outlined
                  : Icons.person_add_alt_1_outlined),
              tooltip: player.active ? 'Dar de baja' : 'Reactivar',
              onPressed: _toggleActive,
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: _PlayerHeader(player: player),
          ),
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: AppColors.accent,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(text: 'Rendimiento'),
              Tab(text: 'Carga física'),
              Tab(text: 'Partidos'),
              Tab(text: 'Observaciones'),
            ],
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabs,
        children: [
          _PerformanceTab(player: player),
          _LoadTab(player: player),
          _MatchesTab(player: player),
          _ObservationsTab(player: player),
        ],
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────

class _PlayerHeader extends StatelessWidget {
  final PlayerModel player;
  const _PlayerHeader({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgSurface,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 56, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.accentDim,
            child: Text(player.initials,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: AppColors.accent)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Row(children: [
                  StatusBadge(status: player.status),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.infoDim,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.info.withValues(alpha: 0.4), width: 0.5),
                    ),
                    child: Text(
                        '${player.position.isEmpty ? '—' : player.position} · '
                        '#${player.number == 0 ? '—' : player.number}',
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.info,
                            fontWeight: FontWeight.w500)),
                  ),
                ]),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  children: [
                    _MetaItem(Icons.calendar_today_outlined,
                        player.age == 0 ? '— años' : '${player.age} años'),
                    _MetaItem(Icons.height_outlined,
                        player.heightCm == 0 ? '— cm' : '${player.heightCm.toInt()} cm'),
                    _MetaItem(Icons.fitness_center_outlined,
                        player.weightKg == 0 ? '— kg' : '${player.weightKg.toInt()} kg'),
                    _MetaItem(Icons.flag_outlined,
                        player.nationality.isEmpty ? '—' : player.nationality),
                  ],
                ),
              ],
            ),
          ),
          // Rating circle
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent, width: 2),
              color: AppColors.accentDim,
            ),
            alignment: Alignment.center,
            child: Text(
                player.hasPerformanceData ? '${player.rating.toInt()}' : '—',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: AppColors.accent)),
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaItem(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 3),
        Text(text,
            style:
                const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ── Performance tab ────────────────────────────────────────────────────────

class _PerformanceTab extends StatelessWidget {
  final PlayerModel player;
  const _PerformanceTab({required this.player});

  @override
  Widget build(BuildContext context) {
    final stats = player.stats;

    if (!player.hasPerformanceData) {
      return const EmptyState(
        icon: Icons.bar_chart_outlined,
        title: 'Sin datos de rendimiento',
        subtitle: 'Aún no se registraron métricas de rendimiento para este jugador',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppConstants.pagePadding),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Métricas técnicas'),
              const SizedBox(height: 10),
              MetricBarRow(
                  label: 'Pases completados',
                  value: (stats['passAccuracy'] ?? 0) / 100,
                  displayValue: '${stats['passAccuracy']}%',
                  color: AppColors.accent),
              MetricBarRow(
                  label: 'Duelos ganados',
                  value: (stats['duelsWon'] ?? 0).toDouble(),
                  displayValue: '${((stats['duelsWon'] ?? 0) * 100).toInt()}%',
                  color: AppColors.info),
              if (stats['interceptions'] != null)
                MetricBarRow(
                    label: 'Intercepciones',
                    value: (stats['interceptions'] as num) / 5,
                    displayValue: '${stats['interceptions']}/p',
                    color: AppColors.purple),
              if (stats['goals'] != null)
                MetricBarRow(
                    label: 'Goles',
                    value: (stats['goals'] as num) / 15,
                    displayValue: '${stats['goals']}',
                    color: AppColors.warning),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                  title: 'Evolución rating — últimas 8 jornadas'),
              const SizedBox(height: 12),
              _RatingMiniChart(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(
                    8,
                    (i) => Text('J${15 + i}',
                        style: const TextStyle(
                            fontSize: 9, color: AppColors.textMuted))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.8,
          children: [
            StatCard(
                data: StatCardData(
                    label: 'Partidos', value: '${player.matchesPlayed}')),
            StatCard(
                data: StatCardData(
                    label: 'Rating', value: '${player.rating.toInt()}')),
            if (stats['goals'] != null)
              StatCard(
                  data:
                      StatCardData(label: 'Goles', value: '${stats['goals']}')),
            StatCard(
                data: StatCardData(
                    label: 'Pases %', value: '${stats['passAccuracy']}%')),
          ],
        ),
      ],
    );
  }
}

class _RatingMiniChart extends StatelessWidget {
  final List<double> _data = const [68, 74, 71, 79, 82, 85, 88, 91];

  @override
  Widget build(BuildContext context) {
    final max = _data.reduce((a, b) => a > b ? a : b);
    final min = _data.reduce((a, b) => a < b ? a : b);
    final range = max - min;

    return SizedBox(
      height: 60,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _data.map((v) {
          final pct = range == 0 ? 0.5 : (v - min) / range;
          final isLast = v == _data.last;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                height: 12 + 44 * pct,
                decoration: BoxDecoration(
                  color: isLast
                      ? AppColors.accent
                      : AppColors.info.withValues(alpha: 0.5),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Load tab ───────────────────────────────────────────────────────────────

class _LoadTab extends StatelessWidget {
  final PlayerModel player;
  const _LoadTab({required this.player});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppConstants.pagePadding),
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.8,
          children: const [
            StatCard(
                data: StatCardData(
                    label: 'UA total semanal',
                    value: '850',
                    delta: 'Óptimo',
                    deltaPositive: true)),
            StatCard(
                data: StatCardData(
                    label: 'RPE promedio',
                    value: '7.2',
                    delta: 'Moderado',
                    deltaPositive: null)),
            StatCard(
                data: StatCardData(
                    label: 'Distancia total',
                    value: '42 km',
                    delta: 'Normal',
                    deltaPositive: true)),
            StatCard(
                data: StatCardData(
                    label: 'Ratio ac/cr',
                    value: '1.4',
                    delta: 'Seguro',
                    deltaPositive: true)),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Bienestar diario'),
              const SizedBox(height: 12),
              ...['Lun', 'Mar', 'Mié', 'Jue', 'Vie'].asMap().entries.map((e) {
                final values = [8.0, 7.5, 8.5, 7.0, 8.8];
                final v = values[e.key];
                return MetricBarRow(
                  label: e.value,
                  value: v / 10,
                  displayValue: v.toString(),
                  color: v >= 8
                      ? AppColors.accent
                      : (v >= 7 ? AppColors.warning : AppColors.danger),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Matches tab ────────────────────────────────────────────────────────────

class _MatchesTab extends StatelessWidget {
  final PlayerModel player;
  const _MatchesTab({required this.player});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppConstants.pagePadding),
      children: MockData.matches
          .where((m) => m.isFinished)
          .map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  child: Row(
                    children: [
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${m.homeTeam} vs ${m.awayTeam}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary)),
                            Text(
                                '${m.date.day}/${m.date.month}/${m.date.year} · ${m.venue}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Text('${m.homeScore} – ${m.awayScore}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary)),
                      const SizedBox(width: 12),
                      Text('${(75 + (m.homeScore * 3)).clamp(60, 95)}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.accent)),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

// ── Observations tab ───────────────────────────────────────────────────────

class _ObservationsTab extends StatelessWidget {
  final PlayerModel player;
  const _ObservationsTab({required this.player});

  @override
  Widget build(BuildContext context) {
    final obs =
        MockData.observations.where((o) => o.playerId == player.id).toList();

    if (obs.isEmpty) {
      return const EmptyState(
        icon: Icons.chat_bubble_outline,
        title: 'Sin observaciones',
        subtitle: 'Aún no se han registrado observaciones para este jugador',
        actionLabel: 'Añadir observación',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppConstants.pagePadding),
      children: obs
          .map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ObsCard(obs: o),
              ))
          .toList(),
    );
  }
}

class _ObsCard extends StatelessWidget {
  final ObservationModel obs;
  const _ObsCard({required this.obs});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (obs.tag) {
      'positive' => ('Positivo', AppColors.accent),
      'improve' => ('A mejorar', AppColors.warning),
      'physical' => ('Físico', AppColors.info),
      'tactical' => ('Táctica', AppColors.purple),
      _ => (obs.tag, AppColors.textMuted),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.w500)),
              ),
              const Spacer(),
              Text(obs.authorRole,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textMuted)),
              const SizedBox(width: 4),
              const Text('·',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
              const SizedBox(width: 4),
              Text('${obs.date.day}/${obs.date.month}',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          Text(obs.text,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: 6),
          Text('— ${obs.authorName}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
