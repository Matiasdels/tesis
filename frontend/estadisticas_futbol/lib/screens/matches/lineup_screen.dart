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

// Roles para la selección de alineación
enum _Rol { ninguno, titular, suplente }

class LineupScreen extends StatefulWidget {
  final int matchId;
  const LineupScreen({super.key, required this.matchId});

  @override
  State<LineupScreen> createState() => _LineupScreenState();
}

class _LineupScreenState extends State<LineupScreen> {
  final _matchApi = MatchApi();
  final _playerApi = PlayerApi();

  PartidoModel? _match;
  List<PlayerModel> _players = [];
  // jugadorId → rol asignado
  final Map<int, _Rol> _roles = {};

  bool _loading = true;
  bool _saving = false;
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

      final match = await _matchApi.getMatch(widget.matchId, token);
      final allPlayers = await _playerApi.getPlayers(accessToken: token);
      final existing = await _matchApi.getLineup(widget.matchId, token);

      final categoryPlayers = allPlayers
          .where((p) => p.categoryId == match.categoriaId && p.active)
          .toList();

      final rolesMap = <int, _Rol>{};
      for (final p in categoryPlayers) {
        rolesMap[p.id.hashCode] = _Rol.ninguno;
      }

      // Pre-populate with existing lineup
      for (final entry in existing) {
        rolesMap[entry.jugadorId] = entry.esTitular ? _Rol.titular : _Rol.suplente;
      }

      // Build id map from playerModel (id is String, but jugadorId is int)
      final idMap = <int, _Rol>{};
      for (final p in categoryPlayers) {
        final intId = int.tryParse(p.id) ?? 0;
        idMap[intId] = _Rol.ninguno;
      }
      for (final entry in existing) {
        idMap[entry.jugadorId] =
            entry.esTitular ? _Rol.titular : _Rol.suplente;
      }

      if (!mounted) return;
      setState(() {
        _match = match;
        _players = categoryPlayers;
        _roles.clear();
        _roles.addAll(idMap);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar los datos. Intente nuevamente.';
        _loading = false;
      });
    }
  }

  void _setRol(int jugadorId, _Rol rol) {
    setState(() => _roles[jugadorId] = rol);
  }

  int get _titularCount =>
      _roles.values.where((r) => r == _Rol.titular).length;
  int get _suplenteCount =>
      _roles.values.where((r) => r == _Rol.suplente).length;

  Future<void> _save() async {
    final selected = _roles.entries
        .where((e) => e.value != _Rol.ninguno)
        .toList();

    if (!_roles.values.any((r) => r == _Rol.titular)) {
      setState(() => _error = 'La alineación debe incluir al menos un titular.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final entries = selected
        .map((e) => {
              'jugadorId': e.key,
              'esTitular': e.value == _Rol.titular,
              'posicionAsignada': null,
            })
        .toList();

    try {
      final token = context.read<AuthState>().session!.accessToken;
      await _matchApi.setLineup(widget.matchId, entries, token);
      if (mounted) context.pop(true);
    } on MatchApiException catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    } catch (_) {
      setState(() {
        _error = 'No pudimos guardar la alineación. Intente nuevamente.';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(false),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alineación',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_match != null)
              Text(
                _match!.rival,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        actions: [
          if (!_loading && !_saving)
            TextButton(
              onPressed: _save,
              child: const Text(
                'Guardar',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _players.isEmpty
              ? EmptyState(
                  icon: Icons.error_outline,
                  title: 'Error al cargar',
                  subtitle: _error!,
                  actionLabel: 'Reintentar',
                  onAction: _load,
                )
              : Column(
                  children: [
                    _SummaryBar(
                        titulares: _titularCount, suplentes: _suplenteCount),
                    if (_error != null)
                      _ErrorBanner(message: _error!),
                    Expanded(
                      child: _players.isEmpty
                          ? const EmptyState(
                              icon: Icons.people_outline,
                              title: 'Sin jugadores en esta categoría',
                              subtitle:
                                  'No hay jugadores activos en la categoría del partido.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(
                                  AppConstants.pagePadding),
                              itemCount: _players.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final p = _players[i];
                                final id = int.tryParse(p.id) ?? 0;
                                final rol = _roles[id] ?? _Rol.ninguno;
                                return _PlayerRolTile(
                                  player: p,
                                  rol: rol,
                                  onRolChanged: (r) => _setRol(id, r),
                                  enabled: !_saving,
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final int titulares;
  final int suplentes;

  const _SummaryBar({required this.titulares, required this.suplentes});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgSurface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          _CountChip(
              label: 'Titulares',
              count: titulares,
              color: AppColors.accent,
              bg: AppColors.accentDim),
          const SizedBox(width: 10),
          _CountChip(
              label: 'Suplentes',
              count: suplentes,
              color: AppColors.info,
              bg: AppColors.infoDim),
          const Spacer(),
          const Text(
            'Toca para asignar rol',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color bg;

  const _CountChip({
    required this.label,
    required this.count,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _PlayerRolTile extends StatelessWidget {
  final PlayerModel player;
  final _Rol rol;
  final ValueChanged<_Rol> onRolChanged;
  final bool enabled;

  const _PlayerRolTile({
    required this.player,
    required this.rol,
    required this.onRolChanged,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          PlayerAvatar(player: player, radius: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (player.position.isNotEmpty)
                  Text(
                    player.position,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _RolSelector(rol: rol, onChanged: enabled ? onRolChanged : null),
        ],
      ),
    );
  }
}

class _RolSelector extends StatelessWidget {
  final _Rol rol;
  final ValueChanged<_Rol>? onChanged;

  const _RolSelector({required this.rol, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RolChip(
          label: 'T',
          tooltip: 'Titular',
          selected: rol == _Rol.titular,
          color: AppColors.accent,
          bg: AppColors.accentDim,
          onTap: onChanged == null
              ? null
              : () => onChanged!(
                    rol == _Rol.titular ? _Rol.ninguno : _Rol.titular,
                  ),
        ),
        const SizedBox(width: 6),
        _RolChip(
          label: 'S',
          tooltip: 'Suplente',
          selected: rol == _Rol.suplente,
          color: AppColors.info,
          bg: AppColors.infoDim,
          onTap: onChanged == null
              ? null
              : () => onChanged!(
                    rol == _Rol.suplente ? _Rol.ninguno : _Rol.suplente,
                  ),
        ),
      ],
    );
  }
}

class _RolChip extends StatelessWidget {
  final String label;
  final String tooltip;
  final bool selected;
  final Color color;
  final Color bg;
  final VoidCallback? onTap;

  const _RolChip({
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.color,
    required this.bg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppConstants.animFast,
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: selected ? color : AppColors.bgMuted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? color : AppColors.borderDefault,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.black : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppConstants.pagePadding, 8, AppConstants.pagePadding, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
