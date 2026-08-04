import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/remote/auth_state.dart';
import '../../data/remote/player_api.dart';
import '../../models/models.dart';
import '../../widgets/common/app_widgets.dart';

class ObservationsScreen extends StatefulWidget {
  const ObservationsScreen({super.key});

  @override
  State<ObservationsScreen> createState() => _ObservationsScreenState();
}

class _ObservationsScreenState extends State<ObservationsScreen> {
  final _api = PlayerApi();

  List<PlayerModel> _players = [];
  List<PlayerObservacionModel> _observations = [];
  PlayerModel? _selectedPlayer;
  bool _loadingPlayers = true;
  bool _loadingObservations = false;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  List<PlayerModel> get _filteredPlayers {
    final term = _query.trim().toLowerCase();
    if (term.isEmpty) return _players;
    return _players
        .where((player) => player.name.toLowerCase().contains(term))
        .toList();
  }

  Future<void> _loadPlayers() async {
    setState(() {
      _loadingPlayers = true;
      _error = null;
    });

    try {
      final token = context.read<AuthState>().session!.accessToken;
      final players = await _api.getPlayers(accessToken: token);
      if (!mounted) return;
      players.sort((a, b) => a.name.compareTo(b.name));
      setState(() {
        _players = players;
        _selectedPlayer = players.isEmpty ? null : players.first;
        _loadingPlayers = false;
      });
      if (players.isNotEmpty) {
        await _loadObservations(players.first);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar la plantilla. Intente nuevamente.';
        _loadingPlayers = false;
      });
    }
  }

  Future<void> _loadObservations(PlayerModel player) async {
    setState(() {
      _selectedPlayer = player;
      _loadingObservations = true;
      _error = null;
    });

    try {
      final token = context.read<AuthState>().session!.accessToken;
      final observations = await _api.getPlayerObservations(player.id, token);
      if (!mounted) return;
      setState(() {
        _observations = observations;
        _loadingObservations = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _observations = [];
        _loadingObservations = false;
        _error = 'No pudimos cargar las observaciones del jugador.';
      });
    }
  }

  Future<void> _openAddSheet() async {
    final player = _selectedPlayer;
    if (player == null) return;

    final draft = await showModalBottomSheet<_ObservationDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      showDragHandle: true,
      builder: (_) => _AddObservationSheet(playerName: player.name),
    );
    if (draft == null || draft.text.trim().isEmpty || !mounted) return;

    try {
      final token = context.read<AuthState>().session!.accessToken;
      final observation = await _api.createPlayerObservation(
        player.id,
        draft.text.trim(),
        token,
        tipo: draft.type,
      );
      if (!mounted) return;
      setState(() => _observations.insert(0, observation));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Observacion guardada.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos guardar la observacion.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Observaciones',
      subtitle: 'Seguimiento tecnico por jugador',
      actions: [
        ElevatedButton.icon(
          onPressed: _selectedPlayer == null ? null : _openAddSheet,
          icon: const Icon(Icons.add_comment_outlined, size: 16),
          label: const Text('Nueva'),
        ),
      ],
      body: _loadingPlayers
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _players.isEmpty
              ? EmptyState(
                  icon: Icons.error_outline,
                  title: 'Error al cargar',
                  subtitle: _error!,
                  actionLabel: 'Reintentar',
                  onAction: _loadPlayers,
                )
              : _players.isEmpty
                  ? const EmptyState(
                      icon: Icons.people_outline,
                      title: 'Sin jugadores',
                      subtitle:
                          'Carga jugadores para poder registrar observaciones.',
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 760;
                        final playersPanel = _PlayersPanel(
                          query: _query,
                          players: _filteredPlayers,
                          selected: _selectedPlayer,
                          onQueryChanged: (value) {
                            setState(() => _query = value);
                          },
                          onSelected: _loadObservations,
                        );
                        final observationsPanel = _ObservationsPanel(
                          player: _selectedPlayer,
                          observations: _observations,
                          loading: _loadingObservations,
                          error: _error,
                          onRetry: _selectedPlayer == null
                              ? null
                              : () => _loadObservations(_selectedPlayer!),
                          onAdd: _openAddSheet,
                        );

                        if (isWide) {
                          return Row(
                            children: [
                              SizedBox(width: 300, child: playersPanel),
                              VerticalDivider(
                                width: 1,
                                color: AppColors.borderSubtle,
                              ),
                              Expanded(child: observationsPanel),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            SizedBox(height: 246, child: playersPanel),
                            Divider(height: 1, color: AppColors.borderSubtle),
                            Expanded(child: observationsPanel),
                          ],
                        );
                      },
                    ),
    );
  }
}

class _PlayersPanel extends StatelessWidget {
  final String query;
  final List<PlayerModel> players;
  final PlayerModel? selected;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<PlayerModel> onSelected;

  const _PlayersPanel({
    required this.query,
    required this.players,
    required this.selected,
    required this.onQueryChanged,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgSurface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              onChanged: onQueryChanged,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar jugador...',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ),
            ),
          ),
          Expanded(
            child: players.isEmpty
                ? Center(
                    child: Text(
                      'Sin resultados',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: players.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final player = players[index];
                      final active = selected?.id == player.id;
                      return _PlayerObservationTile(
                        player: player,
                        active: active,
                        onTap: () => onSelected(player),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PlayerObservationTile extends StatelessWidget {
  final PlayerModel player;
  final bool active;
  final VoidCallback onTap;

  const _PlayerObservationTile({
    required this.player,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.accentDim : AppColors.bgCard,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    active ? AppColors.accentDim : AppColors.bgMuted,
                child: Text(
                  player.initials,
                  style: TextStyle(
                    color: active ? AppColors.accent : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name.isEmpty ? 'Jugador' : player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      player.position.isEmpty ? 'Sin posicion' : player.position,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (active)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.accent,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ObservationsPanel extends StatelessWidget {
  final PlayerModel? player;
  final List<PlayerObservacionModel> observations;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final VoidCallback onAdd;

  const _ObservationsPanel({
    required this.player,
    required this.observations,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    if (player == null) {
      return const EmptyState(
        icon: Icons.person_search_rounded,
        title: 'Elegir jugador',
        subtitle: 'Selecciona un jugador para ver sus observaciones.',
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: AppColors.bgDeep,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player!.name,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${observations.length} observaciones registradas',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                onPressed: onAdd,
                tooltip: 'Nueva observacion',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? EmptyState(
                      icon: Icons.error_outline,
                      title: 'Error al cargar',
                      subtitle: error!,
                      actionLabel: onRetry == null ? null : 'Reintentar',
                      onAction: onRetry,
                    )
                  : observations.isEmpty
                      ? EmptyState(
                          icon: Icons.chat_bubble_outline,
                          title: 'Sin observaciones',
                          subtitle:
                              'Todavia no hay observaciones para este jugador.',
                          actionLabel: 'Nueva observacion',
                          onAction: onAdd,
                        )
                      : RefreshIndicator(
                          onRefresh: () async => onRetry?.call(),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(
                              AppConstants.pagePadding,
                            ),
                            itemCount: observations.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, index) => _ObservationCard(
                              observation: observations[index],
                            ),
                          ),
                        ),
        ),
      ],
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
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (observation.autorNombre.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    observation.autorNombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  observation.tipo,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            observation.contenido,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddObservationSheet extends StatefulWidget {
  final String playerName;

  const _AddObservationSheet({required this.playerName});

  @override
  State<_AddObservationSheet> createState() => _AddObservationSheetState();
}

class _AddObservationSheetState extends State<_AddObservationSheet> {
  static const _types = ['General', 'Tecnica', 'Tactica', 'Fisica'];

  final _controller = TextEditingController();
  String _selectedType = _types.first;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(
      _ObservationDraft(text: text, type: _selectedType),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nueva observacion',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              widget.playerName,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in _types)
                  ChoiceChip(
                    label: Text(type),
                    selected: _selectedType == type,
                    onSelected: (_) => setState(() => _selectedType = type),
                    selectedColor: AppColors.accent.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: _selectedType == type
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide(
                      color: _selectedType == type
                          ? AppColors.accent
                          : AppColors.borderSubtle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              maxLines: 5,
              maxLength: 1000,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Escribi la observacion tecnica...',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Guardar observacion'),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _ObservationDraft {
  final String text;
  final String type;

  const _ObservationDraft({required this.text, required this.type});
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
