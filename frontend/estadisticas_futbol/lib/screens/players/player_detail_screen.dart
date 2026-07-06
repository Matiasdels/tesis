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
          _MatchesTab(playerId: player.id),
          _ObservationsTab(playerId: player.id),
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

class _MatchesTab extends StatefulWidget {
  final String playerId;

  const _MatchesTab({required this.playerId});

  @override
  State<_MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<_MatchesTab>
    with AutomaticKeepAliveClientMixin {
  final _api = PlayerApi();
  List<PlayerMatchModel>? _matches;
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

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
      final matches = await _api.getPlayerMatches(widget.playerId, token);
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar los partidos.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Algo salio mal',
        subtitle: _error!,
        actionLabel: 'Reintentar',
        onAction: _load,
      );
    }
    final matches = _matches!;
    if (matches.isEmpty) {
      return const EmptyState(
        icon: Icons.sports_soccer_outlined,
        title: 'Sin partidos',
        subtitle: 'Este jugador todavia no tiene partidos registrados.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppConstants.pagePadding),
      itemCount: matches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _MatchCard(
        match: matches[i],
        onTap: () => context.push(
          '/matches/${matches[i].partidoId}',
          extra: matches[i],
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final PlayerMatchModel match;
  final VoidCallback onTap;

  const _MatchCard({required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final resultado = _resultado();
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'vs ${match.rival}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (resultado != null)
                  Text(
                    resultado,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_formatDate(match.fecha)}  ·  ${match.tipoCompeticion}  ·  ${match.esLocal ? 'Local' : 'Visitante'}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _RolBadge(
                  esTitular: match.esTitular,
                  posicion: match.posicionAsignada,
                ),
                if (match.estadisticas.hasActivity) ...[
                  const Spacer(),
                  Text(
                    _statsText(match.estadisticas),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _resultado() {
    if (match.golesEquipo == null || match.golesRival == null) return null;
    return '${match.golesEquipo} - ${match.golesRival}';
  }

  String _formatDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }

  String _statsText(PlayerMatchStats s) {
    final parts = <String>[];
    if (s.goles > 0) parts.add('${s.goles} gol${s.goles > 1 ? 'es' : ''}');
    if (s.asistencias > 0) parts.add('${s.asistencias} ast.');
    if (s.remates > 0) parts.add('${s.remates} rem.');
    if (s.amarillas > 0) parts.add('${s.amarillas} AM');
    if (s.rojas > 0) parts.add('${s.rojas} RJ');
    return parts.join(' · ');
  }
}

class _RolBadge extends StatelessWidget {
  final bool esTitular;
  final String? posicion;

  const _RolBadge({required this.esTitular, this.posicion});

  @override
  Widget build(BuildContext context) {
    final label = esTitular
        ? (posicion != null && posicion!.isNotEmpty
            ? 'Titular · $posicion'
            : 'Titular')
        : 'Suplente';
    final color = esTitular ? AppColors.accent : AppColors.textSecondary;
    final bg = esTitular ? AppColors.accentDim : AppColors.bgMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─── Observaciones ───────────────────────────────────────────────────────────

class _ObservationsTab extends StatefulWidget {
  final String playerId;

  const _ObservationsTab({required this.playerId});

  @override
  State<_ObservationsTab> createState() => _ObservationsTabState();
}

class _ObservationsTabState extends State<_ObservationsTab>
    with AutomaticKeepAliveClientMixin {
  final _api = PlayerApi();
  List<PlayerObservacionModel> _observations = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

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
      final obs = await _api.getPlayerObservations(widget.playerId, token);
      if (!mounted) return;
      setState(() {
        _observations = obs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar las observaciones.';
        _loading = false;
      });
    }
  }

  Future<void> _openAddSheet() async {
    final token = context.read<AuthState>().session!.accessToken;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => _AddObservationSheet(
        onSave: (texto) async {
          final nueva = await _api.createPlayerObservation(
              widget.playerId, texto, token);
          if (!mounted) return;
          setState(() => _observations.insert(0, nueva));
          if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Observacion guardada.')),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Algo salio mal',
        subtitle: _error!,
        actionLabel: 'Reintentar',
        onAction: _load,
      );
    }

    if (_observations.isEmpty) {
      return EmptyState(
        icon: Icons.chat_bubble_outline,
        title: 'Sin observaciones',
        subtitle: 'Todavia no hay observaciones para este jugador.',
        actionLabel: 'Nueva observacion',
        onAction: _openAddSheet,
      );
    }

    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.pagePadding,
            AppConstants.pagePadding,
            AppConstants.pagePadding,
            80,
          ),
          itemCount: _observations.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) =>
              _ObservationCard(observation: _observations[i]),
        ),
        Positioned(
          right: AppConstants.pagePadding,
          bottom: AppConstants.pagePadding,
          child: FloatingActionButton.small(
            onPressed: _openAddSheet,
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
            tooltip: 'Nueva observacion',
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _AddObservationSheet extends StatefulWidget {
  final Future<void> Function(String texto) onSave;

  const _AddObservationSheet({required this.onSave});

  @override
  State<_AddObservationSheet> createState() => _AddObservationSheetState();
}

class _AddObservationSheetState extends State<_AddObservationSheet> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final texto = _controller.text.trim();
    if (texto.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(texto);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos guardar la observacion.')),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nueva observacion',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (_, value, __) => TextField(
              controller: _controller,
              maxLines: 5,
              maxLength: 1000,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Escribi tu observacion aqui...',
                hintStyle:
                    const TextStyle(color: AppColors.textMuted, fontSize: 14),
                filled: true,
                fillColor: AppColors.bgMuted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                  borderSide: BorderSide.none,
                ),
                counterStyle:
                    const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.cardRadius),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('Guardar',
                      style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ObservationCard extends StatelessWidget {
  final PlayerObservacionModel observation;

  const _ObservationCard({required this.observation});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _formatDate(observation.fecha),
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (observation.autorNombre.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '·  ${observation.autorNombre}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            observation.contenido,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }
}
