import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/remote/auth_state.dart';
import '../../data/remote/player_api.dart';
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
      if (!mounted) return;
      setState(() {
        _player = player;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar el jugador. Intenta nuevamente.';
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
        await _api.updatePlayer(
            player.id, player.copyWith(active: true), token);
      }
      _changed = true;
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos actualizar el estado del jugador.'),
          ),
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
                  title: 'Algo salio mal',
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
                final updated =
                    await context.push<bool>('/players/${player.id}/edit');
                if (updated == true) {
                  _changed = true;
                  _load();
                }
              },
            ),
            IconButton(
              icon: Icon(
                player.active
                    ? Icons.person_remove_outlined
                    : Icons.person_add_alt_1_outlined,
              ),
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
              Tab(text: 'Datos'),
              Tab(text: 'Carga fisica'),
              Tab(text: 'Partidos'),
              Tab(text: 'Observaciones'),
            ],
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabs,
        children: [
          _RealDataTab(player: player),
          const _PendingTab(
            icon: Icons.fitness_center_outlined,
            title: 'Sin datos de carga fisica',
            subtitle:
                'Todavia no hay registros reales de entrenamientos o carga conectados a este jugador.',
          ),
          const _PendingTab(
            icon: Icons.sports_soccer_outlined,
            title: 'Sin partidos reales',
            subtitle:
                'Los partidos del jugador se van a mostrar cuando exista gestion real de partidos en la API.',
          ),
          const _PendingTab(
            icon: Icons.chat_bubble_outline,
            title: 'Sin observaciones',
            subtitle:
                'Todavia no se registraron observaciones reales para este jugador.',
          ),
        ],
      ),
    );
  }
}

class _PlayerHeader extends StatelessWidget {
  final PlayerModel player;

  const _PlayerHeader({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgSurface,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 56,
        20,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.accentDim,
            child: Text(
              player.initials,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    StatusBadge(status: player.status),
                    _InfoChip(
                      '${player.position.isEmpty ? '-' : player.position} / #${player.number == 0 ? '-' : player.number}',
                    ),
                    if (!player.active) const _InfoChip('Inactivo'),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _MetaItem(
                      Icons.calendar_today_outlined,
                      player.age == 0 ? '- anios' : '${player.age} anios',
                    ),
                    _MetaItem(
                      Icons.height_outlined,
                      player.heightCm == 0
                          ? '- cm'
                          : '${player.heightCm.toInt()} cm',
                    ),
                    _MetaItem(
                      Icons.fitness_center_outlined,
                      player.weightKg == 0
                          ? '- kg'
                          : '${player.weightKg.toInt()} kg',
                    ),
                    _MetaItem(
                      Icons.flag_outlined,
                      player.nationality.isEmpty ? '-' : player.nationality,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.infoDim,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.info.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.info,
          fontWeight: FontWeight.w500,
        ),
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
        Text(
          text,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _RealDataTab extends StatelessWidget {
  final PlayerModel player;

  const _RealDataTab({required this.player});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppConstants.pagePadding),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Datos registrados'),
              const SizedBox(height: 10),
              _DataRow('Nombre', player.firstName),
              _DataRow('Apellido', player.lastName),
              _DataRow('Categoria', player.categoryName ?? '-'),
              _DataRow(
                'Fecha de nacimiento',
                player.birthDate == null ? '-' : _formatDate(player.birthDate!),
              ),
              _DataRow('Nacionalidad', player.nationality),
              _DataRow('Posicion', player.position),
              _DataRow('Numero', player.number == 0 ? '-' : '${player.number}'),
              _DataRow(
                'Altura',
                player.heightCm == 0 ? '-' : '${player.heightCm.toInt()} cm',
              ),
              _DataRow(
                'Peso',
                player.weightKg == 0 ? '-' : '${player.weightKg.toInt()} kg',
              ),
              _DataRow('Pierna habil', player.dominantFoot ?? '-'),
              _DataRow('Estado', PlayerModel.statusToApi(player.status)),
              _DataRow('Activo', player.active ? 'Si' : 'No'),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;

  const _DataRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final display = value.trim().isEmpty ? '-' : value.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              display,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PendingTab({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(icon: icon, title: title, subtitle: subtitle);
  }
}
