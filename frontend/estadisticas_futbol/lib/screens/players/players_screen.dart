import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../mock/mock_data.dart';
import '../../models/models.dart';
import '../../widgets/common/app_widgets.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  String _query = '';
  String _filterStatus = 'all';
  String _filterPosition = 'all';

  List<PlayerModel> get _filtered => MockData.players.where((p) {
    final matchQuery = p.name.toLowerCase().contains(_query.toLowerCase());
    final matchStatus = _filterStatus == 'all' || p.status == _filterStatus;
    final matchPos = _filterPosition == 'all' || p.position == _filterPosition;
    return matchQuery && matchStatus && matchPos;
  }).toList();

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Jugadores',
      subtitle: '${MockData.players.length} en plantilla',
      actions: [
        ElevatedButton.icon(
          onPressed: () {},
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
          Expanded(
            child: _filtered.isEmpty
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
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: const InputDecoration(
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
                const VerticalDivider(color: AppColors.borderDefault, width: 1),
                const SizedBox(width: 10),
                _Chip('Posición: Todas', filterPosition == 'all', () => onPosition('all')),
                _Chip('PT', filterPosition == 'PT', () => onPosition('PT')),
                _Chip('DC', filterPosition == 'DC', () => onPosition('DC')),
                _Chip('MC', filterPosition == 'MC', () => onPosition('MC')),
                _Chip('DEL', filterPosition == 'DEL', () => onPosition('DEL')),
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
        onTap: () => context.push('/players/${player.id}'),
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
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.bgMuted,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('#${player.number}',
                              style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text('${player.position} · ${player.matchesPlayed} partidos',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${player.rating.toInt()}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: _ratingColor(player.rating),
                      )),
                  const SizedBox(height: 4),
                  StatusBadge(status: player.status),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
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