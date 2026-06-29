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

// =============================================================================
//  FORMATION DATA
// =============================================================================

class _SlotDef {
  final String slot;
  final String position;
  final double x;
  final double y;
  const _SlotDef(this.slot, this.position, this.x, this.y);
}

const _formations = <String, List<_SlotDef>>{
  '4-3-3': [
    _SlotDef('ARQ',  'ARQ', 0.50, 0.87),
    _SlotDef('LD',   'LD',  0.85, 0.70),
    _SlotDef('DFC1', 'DFC', 0.62, 0.73),
    _SlotDef('DFC2', 'DFC', 0.38, 0.73),
    _SlotDef('LI',   'LI',  0.15, 0.70),
    _SlotDef('MC1',  'MC',  0.77, 0.52),
    _SlotDef('MC2',  'MC',  0.50, 0.52),
    _SlotDef('MC3',  'MC',  0.23, 0.52),
    _SlotDef('ED',   'ED',  0.82, 0.27),
    _SlotDef('DC',   'DC',  0.50, 0.27),
    _SlotDef('EI',   'EI',  0.18, 0.27),
  ],
  '4-4-2': [
    _SlotDef('ARQ',  'ARQ', 0.50, 0.87),
    _SlotDef('LD',   'LD',  0.85, 0.70),
    _SlotDef('DFC1', 'DFC', 0.62, 0.73),
    _SlotDef('DFC2', 'DFC', 0.38, 0.73),
    _SlotDef('LI',   'LI',  0.15, 0.70),
    _SlotDef('MD',   'MD',  0.83, 0.44),
    _SlotDef('MC1',  'MC',  0.60, 0.52),
    _SlotDef('MC2',  'MC',  0.40, 0.52),
    _SlotDef('MI',   'MI',  0.17, 0.44),
    _SlotDef('DC1',  'DC',  0.65, 0.25),
    _SlotDef('DC2',  'DC',  0.35, 0.25),
  ],
  '4-2-3-1': [
    _SlotDef('ARQ',  'ARQ', 0.50, 0.87),
    _SlotDef('LD',   'LD',  0.85, 0.70),
    _SlotDef('DFC1', 'DFC', 0.62, 0.73),
    _SlotDef('DFC2', 'DFC', 0.38, 0.73),
    _SlotDef('LI',   'LI',  0.15, 0.70),
    _SlotDef('MCD1', 'MCD', 0.64, 0.57),
    _SlotDef('MCD2', 'MCD', 0.36, 0.57),
    _SlotDef('ED',   'ED',  0.82, 0.40),
    _SlotDef('MCO',  'MCO', 0.50, 0.40),
    _SlotDef('EI',   'EI',  0.18, 0.40),
    _SlotDef('DC',   'DC',  0.50, 0.22),
  ],
  '3-5-2': [
    _SlotDef('ARQ',  'ARQ', 0.50, 0.87),
    _SlotDef('DFC1', 'DFC', 0.73, 0.73),
    _SlotDef('DFC2', 'DFC', 0.50, 0.76),
    _SlotDef('DFC3', 'DFC', 0.27, 0.73),
    _SlotDef('MD',   'MD',  0.88, 0.44),
    _SlotDef('MC1',  'MC',  0.68, 0.52),
    _SlotDef('MC2',  'MC',  0.50, 0.52),
    _SlotDef('MC3',  'MC',  0.32, 0.52),
    _SlotDef('MI',   'MI',  0.12, 0.44),
    _SlotDef('DC1',  'DC',  0.65, 0.25),
    _SlotDef('DC2',  'DC',  0.35, 0.25),
  ],
  '3-4-3': [
    _SlotDef('ARQ',  'ARQ', 0.50, 0.87),
    _SlotDef('DFC1', 'DFC', 0.73, 0.73),
    _SlotDef('DFC2', 'DFC', 0.50, 0.76),
    _SlotDef('DFC3', 'DFC', 0.27, 0.73),
    _SlotDef('MD',   'MD',  0.83, 0.44),
    _SlotDef('MC1',  'MC',  0.60, 0.52),
    _SlotDef('MC2',  'MC',  0.40, 0.52),
    _SlotDef('MI',   'MI',  0.17, 0.44),
    _SlotDef('ED',   'ED',  0.82, 0.27),
    _SlotDef('DC',   'DC',  0.50, 0.25),
    _SlotDef('EI',   'EI',  0.18, 0.27),
  ],
};

// =============================================================================
//  SCREEN
// =============================================================================

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
  bool _loading = true;
  bool _saving = false;
  String? _error;

  String _formation = '4-3-3';
  final Map<String, PlayerModel?> _slots = {};
  final List<PlayerModel> _suplentes = [];

  List<_SlotDef> get _currentSlots => _formations[_formation]!;

  int get _assignedCount => _slots.values.where((p) => p != null).length;

  // All players currently taken (titulares + suplentes)
  Set<String> get _allAssignedIds => {
        ..._slots.values.whereType<PlayerModel>().map((p) => p.id),
        ..._suplentes.map((p) => p.id),
      };

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

      // All active players in category — used for reconstruction (ignores status
      // so a player who became injured after saving still shows in their slot)
      final categoryPlayers = allPlayers
          .where((p) => p.categoryId == match.categoriaId && p.active)
          .toList();

      // Only available (not injured/suspended) — shown in picker
      final eligiblePlayers = categoryPlayers
          .where((p) => p.isAvailable)
          .toList();

      String formation = match.formacion ?? '4-3-3';
      if (!_formations.containsKey(formation)) formation = '4-3-3';

      // Build empty slot map
      final slotMap = <String, PlayerModel?>{};
      for (final s in _formations[formation]!) {
        slotMap[s.slot] = null;
      }

      // Reconstruct titulares using posicionAsignada as slot key
      for (final entry in existing.where((e) => e.esTitular)) {
        final slotKey = entry.posicionAsignada;
        if (slotKey != null && slotMap.containsKey(slotKey)) {
          final player = categoryPlayers
              .where((p) => int.tryParse(p.id) == entry.jugadorId)
              .firstOrNull;
          if (player != null) slotMap[slotKey] = player;
        }
      }

      // Reconstruct suplentes
      final loadedSuplentes = <PlayerModel>[];
      for (final entry in existing.where((e) => !e.esTitular)) {
        final player = categoryPlayers
            .where((p) => int.tryParse(p.id) == entry.jugadorId)
            .firstOrNull;
        if (player != null) loadedSuplentes.add(player);
      }

      if (!mounted) return;
      setState(() {
        _match = match;
        _players = eligiblePlayers;
        _formation = formation;
        _slots
          ..clear()
          ..addAll(slotMap);
        _suplentes
          ..clear()
          ..addAll(loadedSuplentes);
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

  void _changeFormation(String f) {
    setState(() {
      _formation = f;
      _slots.clear();
      for (final s in _formations[f]!) {
        _slots[s.slot] = null;
      }
      // Suplentes are independent of formation — keep them
    });
  }

  void _openPlayerPicker(_SlotDef slot) {
    // "Assigned elsewhere" = other slots + suplentes (shown but marked)
    final assignedElsewhere = <PlayerModel>{
      ..._slots.entries
          .where((e) => e.key != slot.slot && e.value != null)
          .map((e) => e.value!),
      ..._suplentes,
    };

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PlayerPickerSheet(
        slotDef: slot,
        players: _players,
        currentPlayer: _slots[slot.slot],
        assignedElsewhere: assignedElsewhere,
        onSelect: (player) {
          Navigator.pop(context);
          setState(() {
            // Remove from any other titular slot
            for (final key in _slots.keys.toList()) {
              if (_slots[key]?.id == player.id) _slots[key] = null;
            }
            // Remove from suplentes if was there
            _suplentes.removeWhere((p) => p.id == player.id);
            _slots[slot.slot] = player;
          });
        },
        onRemove: () {
          Navigator.pop(context);
          setState(() => _slots[slot.slot] = null);
        },
      ),
    );
  }

  void _openSuplentesSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (_, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.85,
            expand: false,
            builder: (_, controller) => Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderDefault,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz,
                          size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        'Suplentes (${_suplentes.length})',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          Future.microtask(_openSuplentePicker);
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Agregar'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.accent,
                          textStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: AppColors.borderSubtle, height: 0.5),
                Expanded(
                  child: _suplentes.isEmpty
                      ? const Center(
                          child: Text(
                            'Sin suplentes seleccionados',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      : ListView.separated(
                          controller: controller,
                          padding:
                              const EdgeInsets.fromLTRB(12, 10, 12, 20),
                          itemCount: _suplentes.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (_, i) => _SuplenteTile(
                            player: _suplentes[i],
                            number: i + 1,
                            onRemove: () {
                              setState(
                                  () => _suplentes.removeAt(i));
                              setSheetState(() {});
                            },
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openSuplentePicker() {
    final excluded = _allAssignedIds;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SubstitutePickerSheet(
        players: _players,
        excludedIds: excluded,
        onSelect: (player) {
          Navigator.pop(context);
          setState(() => _suplentes.add(player));
        },
      ),
    );
  }

  Future<void> _save() async {
    if (_assignedCount < 11) {
      setState(
          () => _error = 'Completá los 11 titulares antes de guardar.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final titularEntries = _slots.entries
        .where((e) => e.value != null)
        .map((e) => {
              'jugadorId': int.tryParse(e.value!.id) ?? 0,
              'esTitular': true,
              'posicionAsignada': e.key,
            })
        .toList();

    final suplenteEntries = _suplentes
        .map((p) => {
              'jugadorId': int.tryParse(p.id) ?? 0,
              'esTitular': false,
              'posicionAsignada': null,
            })
        .toList();

    try {
      final token = context.read<AuthState>().session!.accessToken;
      await _matchApi.setLineup(
        widget.matchId,
        [...titularEntries, ...suplenteEntries],
        token,
        formacion: _formation,
      );
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
          icon: const Icon(Icons.arrow_back,
              color: AppColors.textSecondary),
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
                'vs ${_match!.rival}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11),
              ),
          ],
        ),
        actions: [
          if (!_loading)
            _saving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: _save,
                    child: Text(
                      'Guardar ($_assignedCount/11)',
                      style: TextStyle(
                        color: _assignedCount == 11
                            ? AppColors.accent
                            : AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
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
                    _FormationSelector(
                      selected: _formation,
                      onChanged: _changeFormation,
                    ),
                    if (_error != null) _ErrorBanner(message: _error!),
                    if (_players.isEmpty)
                      const Expanded(
                        child: EmptyState(
                          icon: Icons.people_outline,
                          title: 'Sin jugadores en esta categoría',
                          subtitle:
                              'No hay jugadores activos en la categoría del partido.',
                        ),
                      )
                    else ...[
                      Expanded(
                        child: _PitchView(
                          slots: _currentSlots,
                          assignments: _slots,
                          onSlotTap: _openPlayerPicker,
                        ),
                      ),
                      _SubstitutesBar(
                        count: _suplentes.length,
                        onTap: _openSuplentesSheet,
                      ),
                    ],
                  ],
                ),
    );
  }
}

// =============================================================================
//  FORMATION SELECTOR
// =============================================================================

class _FormationSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _FormationSelector(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgSurface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _formations.keys.map((f) {
            final active = f == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onChanged(f),
                child: AnimatedContainer(
                  duration: AppConstants.animFast,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.accentDim
                        : AppColors.bgMuted,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active
                          ? AppColors.accent.withValues(alpha: 0.5)
                          : AppColors.borderDefault,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    f,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? AppColors.accent
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// =============================================================================
//  PITCH VIEW
// =============================================================================

class _PitchView extends StatelessWidget {
  final List<_SlotDef> slots;
  final Map<String, PlayerModel?> assignments;
  final ValueChanged<_SlotDef> onSlotTap;

  const _PitchView({
    required this.slots,
    required this.assignments,
    required this.onSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        const slotRadius = 26.0;
        return ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _PitchPainter()),
              ),
              ...slots.map((s) {
                final cx = s.x * w;
                final cy = s.y * h;
                return Positioned(
                  left: cx - slotRadius,
                  top: cy - slotRadius,
                  width: slotRadius * 2,
                  height: slotRadius * 2,
                  child: _PositionSlot(
                    slotDef: s,
                    player: assignments[s.slot],
                    onTap: () => onSlotTap(s),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
//  PITCH PAINTER
// =============================================================================

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF1B5E20));

    final stripePaint = Paint()..color = const Color(0xFF1A5C1E);
    final stripeH = h / 8;
    for (int i = 0; i < 8; i += 2) {
      canvas.drawRect(
          Rect.fromLTWH(0, i * stripeH, w, stripeH), stripePaint);
    }

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawRect(Rect.fromLTRB(8, 8, w - 8, h - 8), linePaint);
    canvas.drawLine(Offset(8, h / 2), Offset(w - 8, h / 2), linePaint);
    canvas.drawCircle(Offset(w / 2, h / 2), h * 0.1, linePaint);

    final paW = w * 0.55;
    final paH = h * 0.18;
    canvas.drawRect(
        Rect.fromLTRB(
            (w - paW) / 2, h - 8 - paH, (w + paW) / 2, h - 8),
        linePaint);
    canvas.drawRect(
        Rect.fromLTRB((w - paW) / 2, 8, (w + paW) / 2, 8 + paH),
        linePaint);

    final gaW = w * 0.28;
    final gaH = h * 0.07;
    canvas.drawRect(
        Rect.fromLTRB(
            (w - gaW) / 2, h - 8 - gaH, (w + gaW) / 2, h - 8),
        linePaint);
    canvas.drawRect(
        Rect.fromLTRB((w - gaW) / 2, 8, (w + gaW) / 2, 8 + gaH),
        linePaint);

    canvas.drawCircle(Offset(w / 2, h / 2), 3,
        linePaint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_PitchPainter old) => false;
}

// =============================================================================
//  POSITION SLOT
// =============================================================================

class _PositionSlot extends StatelessWidget {
  final _SlotDef slotDef;
  final PlayerModel? player;
  final VoidCallback onTap;

  const _PositionSlot({
    required this.slotDef,
    required this.player,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final assigned = player != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: assigned
              ? AppColors.accent.withValues(alpha: 0.92)
              : AppColors.bgCard.withValues(alpha: 0.82),
          border: Border.all(
            color: assigned
                ? AppColors.accent
                : Colors.white.withValues(alpha: 0.5),
            width: assigned ? 2.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (assigned) ...[
              Text(
                _lastName(player!.name),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 7,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (player!.number > 0)
                Text(
                  '${player!.number}',
                  style: const TextStyle(
                      color: Colors.black54, fontSize: 7, height: 1.0),
                ),
            ] else ...[
              Text(
                slotDef.position,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(Icons.add,
                  size: 10, color: Colors.white.withValues(alpha: 0.6)),
            ],
          ],
        ),
      ),
    );
  }

  String _lastName(String fullName) {
    final parts = fullName.trim().split(' ');
    return parts.length > 1 ? parts.last : fullName;
  }
}

// =============================================================================
//  SUBSTITUTES BAR (fixed bottom strip)
// =============================================================================

class _SubstitutesBar extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _SubstitutesBar({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: AppColors.bgSurface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(color: AppColors.borderSubtle, height: 0.5),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.swap_horiz,
                      size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Text(
                    count == 0 ? 'Suplentes' : 'Suplentes ($count)',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.keyboard_arrow_up,
                      size: 18, color: AppColors.textMuted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuplenteTile extends StatelessWidget {
  final PlayerModel player;
  final int number;
  final VoidCallback onRemove;

  const _SuplenteTile({
    required this.player,
    required this.number,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.bgMuted,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          PlayerAvatar(player: player, radius: 14),
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
                Text(
                  player.position.isNotEmpty ? player.position : '—',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (player.number > 0)
            Text(
              '#${player.number}',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 11),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close,
                color: AppColors.danger, size: 18),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  SUBSTITUTE PICKER SHEET
// =============================================================================

class _SubstitutePickerSheet extends StatefulWidget {
  final List<PlayerModel> players;
  final Set<String> excludedIds;
  final ValueChanged<PlayerModel> onSelect;

  const _SubstitutePickerSheet({
    required this.players,
    required this.excludedIds,
    required this.onSelect,
  });

  @override
  State<_SubstitutePickerSheet> createState() =>
      _SubstitutePickerSheetState();
}

class _SubstitutePickerSheetState
    extends State<_SubstitutePickerSheet> {
  String _query = '';

  List<PlayerModel> get _available {
    final q = _query.toLowerCase();
    return widget.players
        .where((p) => !widget.excludedIds.contains(p.id))
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) {
        final pos = a.position.compareTo(b.position);
        return pos != 0 ? pos : a.name.compareTo(b.name);
      });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderDefault,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                Icon(Icons.swap_horiz,
                    size: 18, color: AppColors.accent),
                SizedBox(width: 8),
                Text(
                  'Agregar suplente',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Buscar jugador...',
                prefixIcon: Icon(Icons.search,
                    size: 18, color: AppColors.textMuted),
              ),
            ),
          ),
          const Divider(color: AppColors.borderSubtle, height: 0.5),
          Expanded(
            child: _available.isEmpty
                ? const Center(
                    child: Text('Sin jugadores disponibles',
                        style: TextStyle(color: AppColors.textMuted)))
                : ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                    itemCount: _available.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final p = _available[i];
                      return _PlayerPickerTile(
                        player: p,
                        isSelected: false,
                        isAssignedElsewhere: false,
                        isPreferred: false,
                        onTap: () => widget.onSelect(p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  PLAYER PICKER SHEET (for titular slots)
// =============================================================================

class _PlayerPickerSheet extends StatefulWidget {
  final _SlotDef slotDef;
  final List<PlayerModel> players;
  final PlayerModel? currentPlayer;
  final Set<PlayerModel> assignedElsewhere;
  final ValueChanged<PlayerModel> onSelect;
  final VoidCallback onRemove;

  const _PlayerPickerSheet({
    required this.slotDef,
    required this.players,
    required this.currentPlayer,
    required this.assignedElsewhere,
    required this.onSelect,
    required this.onRemove,
  });

  @override
  State<_PlayerPickerSheet> createState() => _PlayerPickerSheetState();
}

class _PlayerPickerSheetState extends State<_PlayerPickerSheet> {
  String _query = '';

  List<PlayerModel> get _sorted {
    final q = _query.toLowerCase();
    final filtered = widget.players
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
        .toList();

    final preferred =
        filtered.where((p) => p.position == widget.slotDef.position).toList();
    final others =
        filtered.where((p) => p.position != widget.slotDef.position).toList();

    preferred.sort((a, b) => a.name.compareTo(b.name));
    others.sort((a, b) => a.name.compareTo(b.name));

    return [...preferred, ...others];
  }

  @override
  Widget build(BuildContext context) {
    final slotLabel = widget.slotDef.slot;
    final posLabel = widget.slotDef.position;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderDefault,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Slot $slotLabel',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Posición esperada: $posLabel',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                if (widget.currentPlayer != null)
                  TextButton(
                    onPressed: widget.onRemove,
                    child: const Text('Quitar',
                        style: TextStyle(color: AppColors.danger)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Buscar jugador...',
                prefixIcon: Icon(Icons.search,
                    size: 18, color: AppColors.textMuted),
              ),
            ),
          ),
          const Divider(color: AppColors.borderSubtle, height: 0.5),
          Expanded(
            child: _sorted.isEmpty
                ? const Center(
                    child: Text('Sin resultados',
                        style: TextStyle(color: AppColors.textMuted)))
                : ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                    itemCount: _sorted.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final p = _sorted[i];
                      final isCurrentlyHere =
                          widget.currentPlayer?.id == p.id;
                      final isAssignedElsewhere = widget
                          .assignedElsewhere
                          .any((a) => a.id == p.id);
                      final isPreferred =
                          p.position == widget.slotDef.position;

                      return _PlayerPickerTile(
                        player: p,
                        isSelected: isCurrentlyHere,
                        isAssignedElsewhere: isAssignedElsewhere,
                        isPreferred: isPreferred,
                        onTap: () => widget.onSelect(p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  PLAYER PICKER TILE (shared)
// =============================================================================

class _PlayerPickerTile extends StatelessWidget {
  final PlayerModel player;
  final bool isSelected;
  final bool isAssignedElsewhere;
  final bool isPreferred;
  final VoidCallback onTap;

  const _PlayerPickerTile({
    required this.player,
    required this.isSelected,
    required this.isAssignedElsewhere,
    required this.isPreferred,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.accentDim : AppColors.bgCard,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
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
                      style: TextStyle(
                        color: isAssignedElsewhere && !isSelected
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          player.position.isNotEmpty
                              ? player.position
                              : '—',
                          style: TextStyle(
                            color: isPreferred
                                ? AppColors.accent
                                : AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: isPreferred
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        if (isAssignedElsewhere && !isSelected) ...[
                          const SizedBox(width: 6),
                          const Text(
                            'asignado',
                            style: TextStyle(
                                fontSize: 10, color: AppColors.warning),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (player.number > 0)
                Text(
                  '#${player.number}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted),
                ),
              const SizedBox(width: 6),
              if (isSelected)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.accent, size: 18)
              else
                const Icon(Icons.chevron_right,
                    color: AppColors.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  ERROR BANNER
// =============================================================================

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
        border:
            Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              color: AppColors.danger, size: 18),
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
