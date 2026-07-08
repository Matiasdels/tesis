import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/remote/auth_state.dart';
import '../../data/remote/player_api.dart';
import '../../models/models.dart';
import '../../widgets/common/app_widgets.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  final _api = PlayerApi();

  String _query = '';
  String _filterStatus = 'all';
  String _filterPosition = 'all';

  List<PlayerModel> _players = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = context.read<AuthState>().session!.accessToken;
      final players = await _api.getPlayers(accessToken: token);
      setState(() {
        _players = players;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'No pudimos cargar la plantilla. Intentá nuevamente.';
        _loading = false;
      });
    }
  }

  List<PlayerModel> get _filtered => _players.where((p) {
    final matchQuery = p.name.toLowerCase().contains(_query.toLowerCase());
    final matchStatus = _filterStatus == 'all' || p.status == _filterStatus;
    final matchPos = _filterPosition == 'all' ||
        (PlayerPositions.groups[_filterPosition]?.contains(p.position) ?? false);
    return matchQuery && matchStatus && matchPos;
  }).toList();

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Jugadores',
      subtitle: '${_players.length} en plantilla',
      actions: [
        ElevatedButton.icon(
          onPressed: () async {
            final created = await context.push<bool>(AppConstants.routePlayerCreate);
            if (created == true) _load();
          },
          icon: const Icon(Icons.person_add_outlined, size: 16),
          label: const Text('Añadir'),
        ),
      ],
      body: Column(
        children: [
          _FilterBar(
            query: _query,
            filterStatus: _filterStatus,
            filterPosition: _filterPosition,
            onQuery: (v) => setState(() => _query = v),
            onStatus: (v) => setState(() => _filterStatus = v),
            onPosition: (v) => setState(() => _filterPosition = v),
          ),
          if (!_loading && _error == null)
            _StatusReviewBanner(players: _players),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? EmptyState(
                        icon: Icons.error_outline,
                        title: 'Algo salió mal',
                        subtitle: _error!,
                        actionLabel: 'Reintentar',
                        onAction: _load,
                      )
                    : _filtered.isEmpty
                        ? const EmptyState(
                            icon: Icons.person_search,
                            title: 'Sin resultados',
                            subtitle: 'Prueba con otro filtro o búsqueda',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(AppConstants.pagePadding),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) => _PlayerCard(player: _filtered[i]),
                          ),
          ),
        ],
      ),
    );
  }
}

class _StatusReviewBanner extends StatelessWidget {
  final List<PlayerModel> players;
  const _StatusReviewBanner({required this.players});

  @override
  Widget build(BuildContext context) {
    final needsReview = players.where((p) => p.statusNeedsReview).toList();
    if (needsReview.isEmpty) return const SizedBox.shrink();

    final names = needsReview.map((p) => p.name).join(', ');
    final plural = needsReview.length == 1;
    final msg = plural
        ? '${needsReview.first.name} podría haber cumplido su sanción o recuperado su lesión. Revisá su estado.'
        : '$names podrían haber cumplido su sanción o recuperado su lesión. Revisá sus estados.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.warning.withValues(alpha: 0.12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.warning, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String query;
  final String filterStatus;
  final String filterPosition;
  final ValueChanged<String> onQuery;
  final ValueChanged<String> onStatus;
  final ValueChanged<String> onPosition;

  const _FilterBar({
    required this.query, required this.filterStatus, required this.filterPosition,
    required this.onQuery, required this.onStatus, required this.onPosition,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgSurface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          TextField(
            onChanged: onQuery,
            style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Buscar jugador...',
              prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Chip('Todos', filterStatus == 'all', () => onStatus('all')),
                _Chip('Disponibles', filterStatus == 'available', () => onStatus('available')),
                _Chip('Lesionados', filterStatus == 'injured', () => onStatus('injured')),
                _Chip('Suspendidos', filterStatus == 'suspended', () => onStatus('suspended')),
                const SizedBox(width: 10),
                VerticalDivider(color: AppColors.borderDefault, width: 1),
                const SizedBox(width: 10),
                _Chip('Todas', filterPosition == 'all', () => onPosition('all')),
                ...PlayerPositions.groups.keys.map((g) =>
                    _Chip(g, filterPosition == g, () => onPosition(g))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip(this.label, this.active, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => onTap(),
        backgroundColor: AppColors.bgMuted,
        selectedColor: AppColors.accentDim,
        checkmarkColor: AppColors.accent,
        side: BorderSide(
          color: active ? AppColors.accent.withValues(alpha: 0.4) : AppColors.borderDefault,
          width: 0.5,
        ),
        labelStyle: TextStyle(
          fontSize: 12,
          color: active ? AppColors.accent : AppColors.textSecondary,
          fontWeight: active ? FontWeight.w500 : FontWeight.w400,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final PlayerModel player;
  const _PlayerCard({required this.player});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final changed = await context.push<bool>('/players/${player.id}');
          if (changed == true && context.mounted) {
            (context.findAncestorStateOfType<_PlayersScreenState>())?._load();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderSubtle, width: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              PlayerAvatar(player: player, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(player.name,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.bgMuted,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('#${player.number}',
                              style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                        '${player.position} · '
                        '${player.hasPerformanceData ? '${player.matchesPlayed} partidos' : '— partidos'}',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                      player.hasPerformanceData
                          ? '${player.rating.toInt()}'
                          : '—',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: player.hasPerformanceData
                            ? _ratingColor(player.rating)
                            : AppColors.textMuted,
                      )),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (player.statusNeedsReview)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.warning_amber_rounded,
                              color: AppColors.warning, size: 14),
                        ),
                      StatusBadge(status: player.status),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Color _ratingColor(double r) {
    if (r >= 85) return AppColors.accent;
    if (r >= 75) return AppColors.info;
    if (r >= 65) return AppColors.warning;
    return AppColors.danger;
  }
}