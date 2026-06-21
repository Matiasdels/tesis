import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/remote/auth_state.dart';
import '../../data/remote/event_api.dart';
import '../../data/remote/match_api.dart';
import '../../models/models.dart';

// =============================================================================
//  MAIN SCREEN
// =============================================================================

class LiveMatchScreen extends StatefulWidget {
  final String matchId;
  const LiveMatchScreen({super.key, required this.matchId});

  @override
  State<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends State<LiveMatchScreen>
    with TickerProviderStateMixin {
  // ── APIs ───────────────────────────────────────────────────────────────────
  final _matchApi = MatchApi();
  final _eventApi = EventApi();
  bool _finishing = false;

  // ── Match data (loaded from API) ───────────────────────────────────────────
  PartidoModel? _partido;
  List<AlineacionEntradaModel> _lineup = [];
  List<TipoEventoModel> _tiposEvento = [];
  List<EventoPartidoModel> _events = [];
  bool _loading = true;
  String? _loadError;

  // ── Live state ─────────────────────────────────────────────────────────────
  int _minute = 0;
  int _homeScore = 0;
  int _awayScore = 0;
  bool _isRunning = false;
  Timer? _matchTimer;

  // ── Pitch area key ─────────────────────────────────────────────────────────
  final _pitchKey = GlobalKey();

  // ── Radial menu state ──────────────────────────────────────────────────────
  Offset? _tapNorm;
  Offset? _tapLocal;
  bool _showRadial = false;
  int _dragSector = -1;
  String? _pendingEvent;

  late final AnimationController _radialAnimCtrl;
  late final Animation<double> _radialScaleAnim;
  late final Animation<double> _radialFadeAnim;

  // ── Player picker ──────────────────────────────────────────────────────────
  bool _showPlayerPicker = false;
  bool _savingEvent = false;

  // ── Undo ───────────────────────────────────────────────────────────────────
  EventoPartidoModel? _lastRegistered;
  int _undoSeconds = 0;
  Timer? _undoTimer;

  // ── Timeline panel ─────────────────────────────────────────────────────────
  bool _timelineExpanded = false;

  // ── Helpers ────────────────────────────────────────────────────────────────
  int get _matchId => int.tryParse(widget.matchId) ?? 0;
  String get _token =>
      context.read<AuthState>().session!.accessToken;

  Map<String, int> get _tipoEventoIds =>
      {for (final t in _tiposEvento) t.nombre: t.tipoEventoId};

  // ==========================================================================
  //  LIFECYCLE
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    _radialAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _radialScaleAnim = CurvedAnimation(
      parent: _radialAnimCtrl,
      curve: Curves.elasticOut,
      reverseCurve: Curves.easeIn,
    );
    _radialFadeAnim = CurvedAnimation(
      parent: _radialAnimCtrl,
      curve: Curves.easeOut,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading && _partido == null) _loadData();
  }

  @override
  void dispose() {
    _matchTimer?.cancel();
    _undoTimer?.cancel();
    _radialAnimCtrl.dispose();
    super.dispose();
  }

  // ==========================================================================
  //  DATA LOADING
  // ==========================================================================

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final token = _token;
      final results = await Future.wait([
        _matchApi.getMatch(_matchId, token),
        _matchApi.getLineup(_matchId, token),
        _eventApi.getTiposEvento(token),
        _eventApi.getEventos(_matchId, token),
      ]);

      final partido = results[0] as PartidoModel;
      final lineup = results[1] as List<AlineacionEntradaModel>;
      final tipos = results[2] as List<TipoEventoModel>;
      final events = results[3] as List<EventoPartidoModel>;

      if (!mounted) return;
      setState(() {
        _partido = partido;
        _lineup = lineup;
        _tiposEvento = tipos;
        _events = List.from(events.reversed);
        _minute = partido.minutoActual ?? 0;
        _homeScore = partido.golesEquipo ?? 0;
        _awayScore = partido.golesRival ?? 0;
        _isRunning = partido.isEnJuego;
        _loading = false;
      });

      if (_isRunning) _startMatchTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  // ==========================================================================
  //  MATCH TIMER
  // ==========================================================================

  void _startMatchTimer() {
    _matchTimer?.cancel();
    _matchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isRunning && mounted) setState(() => _minute++);
    });
  }

  void _toggleTimer() {
    setState(() => _isRunning = !_isRunning);
    if (!_isRunning) {
      _matchTimer?.cancel();
    } else {
      _startMatchTimer();
    }
    HapticFeedback.selectionClick();
  }

  // ==========================================================================
  //  PITCH TAP → open radial menu
  // ==========================================================================

  void _handlePitchTapDown(TapDownDetails details, BoxConstraints constraints) {
    if (_showRadial) {
      _closeRadial();
      return;
    }
    HapticFeedback.lightImpact();

    final norm = Offset(
      (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0),
      (details.localPosition.dy / constraints.maxHeight).clamp(0.0, 1.0),
    );
    final clampedLocal = _clampRadialCenter(details.localPosition, constraints);

    setState(() {
      _tapNorm = norm;
      _tapLocal = clampedLocal;
      _showRadial = true;
      _dragSector = -1;
      _pendingEvent = null;
      _showPlayerPicker = false;
    });

    _radialAnimCtrl.forward(from: 0);
  }

  Offset _clampRadialCenter(Offset raw, BoxConstraints c) {
    const r = AppConstants.radialMenuRadius;
    const margin = r + 8;
    return Offset(
      raw.dx.clamp(margin, c.maxWidth - margin),
      raw.dy.clamp(margin, c.maxHeight - margin),
    );
  }

  // ==========================================================================
  //  RADIAL DRAG
  // ==========================================================================

  void _handleRadialDragUpdate(DragUpdateDetails details) {
    if (_tapLocal == null) return;
    final dx = details.localPosition.dx - _tapLocal!.dx;
    final dy = details.localPosition.dy - _tapLocal!.dy;
    final dist = math.sqrt(dx * dx + dy * dy);

    if (dist < AppConstants.radialCenterRadius) {
      if (_dragSector != -1) {
        HapticFeedback.selectionClick();
        setState(() => _dragSector = -1);
      }
      return;
    }

    var angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;
    final sector = (angle / (2 * math.pi / 8)).floor() % 8;

    if (sector != _dragSector) {
      HapticFeedback.selectionClick();
      setState(() => _dragSector = sector);
    }
  }

  void _handleRadialDragEnd(DragEndDetails _) {
    if (_dragSector >= 0) {
      _selectSector(_dragSector);
    } else {
      _closeRadial();
    }
  }

  // ==========================================================================
  //  RADIAL SECTOR SELECTION
  // ==========================================================================

  void _selectSector(int index) {
    HapticFeedback.mediumImpact();
    final eventName = _sectors[index].eventType;
    setState(() {
      _pendingEvent = eventName;
      _showRadial = false;
      _showPlayerPicker = true;
      _dragSector = -1;
    });
    _radialAnimCtrl.reverse();
  }

  void _closeRadial() {
    setState(() {
      _showRadial = false;
      _dragSector = -1;
    });
    _radialAnimCtrl.reverse();
  }

  void _openMoreEvents() {
    _radialAnimCtrl.reverse();
    setState(() => _showRadial = false);

    showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _MoreEventsSheet(onSelect: (e) => Navigator.pop(context, e)),
    ).then((chosen) {
      if (chosen == null || !mounted) return;
      setState(() {
        _pendingEvent = chosen;
        _showPlayerPicker = true;
      });
    });
  }

  // ==========================================================================
  //  PLAYER SELECTED → register event via API
  // ==========================================================================

  Future<void> _onPlayerSelected(AlineacionEntradaModel player) async {
    if (_tapNorm == null || _pendingEvent == null) return;
    if (_savingEvent) return;

    final tipoId = _tipoEventoIds[_pendingEvent];
    if (tipoId == null) {
      _showError('Tipo de evento "$_pendingEvent" no encontrado en la base de datos.');
      return;
    }

    HapticFeedback.mediumImpact();
    if (_pendingEvent == EventTypes.goal) HapticFeedback.heavyImpact();

    setState(() => _savingEvent = true);

    try {
      final evento = await _eventApi.createEvento(
        partidoId: _matchId,
        jugadorId: player.jugadorId,
        tipoEventoId: tipoId,
        minuto: _minute,
        pitchX: _tapNorm!.dx,
        pitchY: _tapNorm!.dy,
        accessToken: _token,
      );

      if (!mounted) return;
      setState(() {
        if (_pendingEvent == EventTypes.goal) _homeScore++;
        _events.insert(0, evento);
        _lastRegistered = evento;
        _showPlayerPicker = false;
        _pendingEvent = null;
        _tapNorm = null;
        _tapLocal = null;
        _savingEvent = false;
      });

      _beginUndo();
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingEvent = false);
      _showError(e.toString());
    }
  }

  Future<void> _onNoPlayerSelected() async {
    if (_tapNorm == null || _pendingEvent == null) return;
    if (_savingEvent) return;

    final tipoId = _tipoEventoIds[_pendingEvent];
    if (tipoId == null) {
      _showError('Tipo de evento "$_pendingEvent" no encontrado en la base de datos.');
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() => _savingEvent = true);

    try {
      final evento = await _eventApi.createEvento(
        partidoId: _matchId,
        jugadorId: null,
        tipoEventoId: tipoId,
        minuto: _minute,
        pitchX: _tapNorm!.dx,
        pitchY: _tapNorm!.dy,
        accessToken: _token,
      );

      if (!mounted) return;
      setState(() {
        if (_pendingEvent == EventTypes.goal) _homeScore++;
        _events.insert(0, evento);
        _lastRegistered = evento;
        _showPlayerPicker = false;
        _pendingEvent = null;
        _tapNorm = null;
        _tapLocal = null;
        _savingEvent = false;
      });

      _beginUndo();
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingEvent = false);
      _showError(e.toString());
    }
  }

  void _dismissPlayerPicker() {
    setState(() {
      _showPlayerPicker = false;
      _pendingEvent = null;
      _tapNorm = null;
      _tapLocal = null;
    });
  }

  // ==========================================================================
  //  UNDO
  // ==========================================================================

  void _beginUndo() {
    _undoTimer?.cancel();
    setState(() => _undoSeconds = 5);
    _undoTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _undoSeconds--;
        if (_undoSeconds <= 0) {
          _lastRegistered = null;
          t.cancel();
        }
      });
    });
  }

  Future<void> _undo() async {
    if (_lastRegistered == null) return;
    HapticFeedback.lightImpact();

    final evento = _lastRegistered!;
    final wasGoal = evento.tipoEventoNombre == EventTypes.goal;

    setState(() {
      _events.removeWhere((e) => e.eventoId == evento.eventoId);
      if (wasGoal) _homeScore--;
      _lastRegistered = null;
      _undoSeconds = 0;
    });
    _undoTimer?.cancel();

    try {
      await _eventApi.deleteEvento(
        partidoId: _matchId,
        eventoId: evento.eventoId,
        accessToken: _token,
      );
    } catch (_) {
      // Si falla el DELETE, volvemos a insertar el evento en la lista
      if (mounted) {
        setState(() {
          _events.insert(0, evento);
          if (wasGoal) _homeScore++;
        });
        _showError('No se pudo deshacer. Intente nuevamente.');
      }
    }
  }

  Future<void> _finishMatch() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text('Finalizar partido',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '¿Confirmás el resultado $_homeScore - $_awayScore?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finalizar',
                style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _finishing = true);
    _matchTimer?.cancel();

    try {
      await _matchApi.patchEstado(
        _matchId,
        'Finalizado',
        _token,
        golesEquipo: _homeScore,
        golesRival: _awayScore,
        minutoActual: _minute,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        _showError('No se pudo finalizar el partido. Intente nuevamente.');
        setState(() {
          _finishing = false;
          _isRunning = false;
        });
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================================================
  //  BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bgDeep,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: AppColors.bgDeep,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.danger, size: 48),
                const SizedBox(height: 16),
                Text(_loadError!,
                    style: const TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(
                    onPressed: _loadData, child: const Text('Reintentar')),
              ],
            ),
          ),
        ),
      );
    }

    final partido = _partido!;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            // ① Scoreboard + timer
            _TopBar(
              partido: partido,
              minute: _minute,
              homeScore: _homeScore,
              awayScore: _awayScore,
              isRunning: _isRunning,
              finishing: _finishing,
              onToggle: _toggleTimer,
              onBack: () => Navigator.of(context).pop(),
              onFinish: _finishMatch,
            ),

            // ② Quick-action chips (last event + undo)
            _QuickBar(
              lastEvent: _lastRegistered,
              undoSeconds: _undoSeconds,
              onUndo: _undo,
              onHistory: _openTimeline,
              onMoreEvents: _openMoreEvents,
            ),

            // ③ Interactive pitch
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  LayoutBuilder(
                    key: _pitchKey,
                    builder: (ctx, constraints) => GestureDetector(
                      onTapDown: (d) => _handlePitchTapDown(d, constraints),
                      onPanUpdate:
                          _showRadial ? _handleRadialDragUpdate : null,
                      onPanEnd: _showRadial ? _handleRadialDragEnd : null,
                      child: _PitchCanvas(
                        events: _events,
                        pendingTap: _tapNorm,
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                      ),
                    ),
                  ),

                  if (_showRadial && _tapLocal != null)
                    _RadialOverlay(
                      center: _tapLocal!,
                      scaleAnim: _radialScaleAnim,
                      fadeAnim: _radialFadeAnim,
                      hoveredSector: _dragSector,
                      onSectorTap: _selectSector,
                      onMoreTap: _openMoreEvents,
                      onDismiss: _closeRadial,
                    ),

                  if (!_showRadial && !_showPlayerPicker) const _TapHint(),

                  _TimelinePanel(
                    events: _events,
                    isExpanded: _timelineExpanded,
                    onToggle: () =>
                        setState(() => _timelineExpanded = !_timelineExpanded),
                  ),
                ],
              ),
            ),

            // ④ Player picker (bottom panel)
            AnimatedSize(
              duration: AppConstants.animNormal,
              curve: Curves.easeOutCubic,
              child: _showPlayerPicker && _pendingEvent != null
                  ? _PlayerPicker(
                      eventType: _pendingEvent!,
                      minute: _minute,
                      lineup: _lineup,
                      saving: _savingEvent,
                      onSelect: _onPlayerSelected,
                      onDismiss: _dismissPlayerPicker,
                      onSelectNone: _onNoPlayerSelected,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  void _openTimeline() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FullTimeline(events: _events),
    );
  }
}

// =============================================================================
//  TOP BAR
// =============================================================================

class _TopBar extends StatelessWidget {
  final PartidoModel partido;
  final int minute, homeScore, awayScore;
  final bool isRunning;
  final bool finishing;
  final VoidCallback onToggle, onBack;
  final Future<void> Function() onFinish;

  const _TopBar({
    required this.partido,
    required this.minute,
    required this.homeScore,
    required this.awayScore,
    required this.isRunning,
    required this.finishing,
    required this.onToggle,
    required this.onBack,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgSurface,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: _buildScoreRow()),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: ElevatedButton.icon(
              onPressed: finishing ? null : onFinish,
              icon: finishing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.flag_rounded, size: 16),
              label: Text(finishing ? 'Finalizando...' : 'Finalizar partido'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  List<Widget> _buildScoreRow() {
    final homeTeam =
        partido.esLocal ? 'Kancha' : partido.rival;
    final awayTeam =
        partido.esLocal ? partido.rival : 'Kancha';
    final homeAbbr =
        homeTeam.substring(0, math.min(3, homeTeam.length)).toUpperCase();
    final awayAbbr =
        awayTeam.substring(0, math.min(3, awayTeam.length)).toUpperCase();
    return [
      IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 18, color: AppColors.textSecondary),
        onPressed: onBack,
        padding: EdgeInsets.zero,
      ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TeamChip(abbr: homeAbbr, name: homeTeam, color: AppColors.accent),
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ScoreBoard(homeScore: homeScore, awayScore: awayScore),
                    const SizedBox(height: 2),
                    Text(
                      partido.tipoCompeticion,
                      style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                _TeamChip(abbr: awayAbbr, name: awayTeam, color: AppColors.info),
              ],
            ),
          ),
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: AppConstants.animFast,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isRunning ? AppColors.accentDim : AppColors.bgMuted,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isRunning
                      ? AppColors.accent.withValues(alpha: 0.45)
                      : AppColors.borderDefault,
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isRunning) ...[
                    _PulsingDot(),
                    const SizedBox(width: 5),
                  ] else ...[
                    const Icon(Icons.pause_rounded,
                        size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    "$minute'",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isRunning
                          ? AppColors.accent
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];
  }
}

class _ScoreBoard extends StatelessWidget {
  final int homeScore, awayScore;
  const _ScoreBoard({required this.homeScore, required this.awayScore});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.bgMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderDefault, width: 0.5),
      ),
      child: Text(
        '$homeScore : $awayScore',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _TeamChip extends StatelessWidget {
  final String abbr, name;
  final Color color;
  const _TeamChip({required this.abbr, required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Text(abbr,
              style: TextStyle(
                  fontSize: 9, color: color, fontWeight: FontWeight.w500)),
        ),
        const SizedBox(height: 2),
        Text(name,
            style: const TextStyle(
                fontSize: 9, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.accent.withValues(alpha: 0.4 + 0.6 * _ctrl.value),
        ),
      ),
    );
  }
}

// =============================================================================
//  QUICK BAR
// =============================================================================

class _QuickBar extends StatelessWidget {
  final EventoPartidoModel? lastEvent;
  final int undoSeconds;
  final VoidCallback onHistory, onMoreEvents;
  final Future<void> Function() onUndo;

  const _QuickBar({
    required this.lastEvent,
    required this.undoSeconds,
    required this.onUndo,
    required this.onHistory,
    required this.onMoreEvents,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgSurface,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (lastEvent != null && undoSeconds > 0) ...[
              _QChip(
                icon: Icons.check_circle_outline_rounded,
                label: lastEvent!.tipoEventoNombre,
                color: AppColors.accent,
                filled: true,
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onUndo,
                child: _UndoChip(seconds: undoSeconds),
              ),
              const SizedBox(width: 6),
              Container(
                  width: 0.5, height: 24, color: AppColors.borderDefault),
              const SizedBox(width: 6),
            ],
            _QChip(
                icon: Icons.history_rounded,
                label: 'Historial',
                onTap: onHistory),
            const SizedBox(width: 6),
            _QChip(
                icon: Icons.add_circle_outline_rounded,
                label: 'Más eventos',
                onTap: onMoreEvents),
          ],
        ),
      ),
    );
  }
}

class _QChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback? onTap;

  const _QChip({
    required this.icon,
    required this.label,
    this.color = AppColors.textSecondary,
    this.filled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: filled ? color.withValues(alpha: 0.15) : AppColors.bgMuted,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                filled ? color.withValues(alpha: 0.4) : AppColors.borderDefault,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: filled ? color : AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  color: filled ? color : AppColors.textSecondary,
                )),
          ],
        ),
      ),
    );
  }
}

class _UndoChip extends StatelessWidget {
  final int seconds;
  const _UndoChip({required this.seconds});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.dangerDim,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.danger.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.undo_rounded, size: 13, color: AppColors.danger),
          const SizedBox(width: 5),
          Text('Deshacer ($seconds)',
              style: const TextStyle(fontSize: 12, color: AppColors.danger)),
        ],
      ),
    );
  }
}

// =============================================================================
//  PITCH CANVAS (CustomPainter)
// =============================================================================

class _PitchCanvas extends StatelessWidget {
  final List<EventoPartidoModel> events;
  final Offset? pendingTap;
  final double width, height;

  const _PitchCanvas({
    required this.events,
    required this.pendingTap,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _PitchPainter(events: events, pendingTap: pendingTap),
    );
  }
}

class _PitchPainter extends CustomPainter {
  final List<EventoPartidoModel> events;
  final Offset? pendingTap;

  const _PitchPainter({required this.events, this.pendingTap});

  static Color colorFor(String type) {
    return switch (type) {
      EventTypes.passOk => AppColors.accent,
      EventTypes.passKey => AppColors.accent,
      EventTypes.passBad => AppColors.danger,
      EventTypes.shot => AppColors.warning,
      EventTypes.goal => const Color(0xFFFFEB3B),
      EventTypes.foul => AppColors.danger,
      EventTypes.recovery => AppColors.info,
      EventTypes.yellowCard => AppColors.warning,
      EventTypes.redCard => AppColors.danger,
      EventTypes.save => AppColors.purple,
      EventTypes.assist => const Color(0xFF67E8F9),
      EventTypes.corner => AppColors.warning,
      EventTypes.interception => AppColors.info,
      EventTypes.cross => AppColors.textSecondary,
      _ => AppColors.textSecondary,
    };
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _drawPitch(canvas, w, h);
    _drawEventDots(canvas, w, h);
    if (pendingTap != null) _drawPendingDot(canvas, w, h);
  }

  void _drawPitch(Canvas canvas, double w, double h) {
    const nStripes = 8;
    // Horizontal stripes for portrait orientation
    for (var i = 0; i < nStripes; i++) {
      final y = i * h / nStripes;
      canvas.drawRect(
        Rect.fromLTWH(0, y, w, h / nStripes),
        Paint()..color = i.isEven ? AppColors.pitchGreen : AppColors.pitchGreenAlt,
      );
    }

    final lp = Paint()
      ..color = AppColors.pitchLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    const padV = 8.0;
    final padH = w * 0.05;
    final innerW = w - 2 * padH;
    final innerH = h - 2 * padV;
    final halfH = innerH / 2;

    // Outer boundary
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(padH, padV, w - padH, h - padV),
        const Radius.circular(3),
      ),
      lp,
    );

    // Center line (horizontal) + circle
    lp.strokeWidth = 0.8;
    canvas.drawLine(Offset(padH, h / 2), Offset(w - padH, h / 2), lp);
    canvas.drawCircle(Offset(w / 2, h / 2), innerW * 0.15, lp);
    canvas.drawCircle(Offset(w / 2, h / 2), 3, Paint()..color = AppColors.pitchLine);

    // Real proportions (FIFA):
    // Penalty area: 40.32m wide / 68m pitch = 0.593; 16.5m deep / 52.5m half = 0.314
    // Goal area:    18.32m wide / 68m = 0.269;  5.5m deep / 52.5m = 0.105
    // Goal:         7.32m wide  / 68m = 0.108 (enlarged for visibility → 0.18)
    // Penalty spot: 11m / 52.5m = 0.21 of half-length from goal line
    // Arc radius:   9.15m / 52.5m = 0.174 of half-length

    final paW    = innerW * 0.59;
    final paD    = halfH  * 0.31;
    final gaW    = innerW * 0.27;
    final gaD    = halfH  * 0.105;
    final goalW  = innerW * 0.18;
    const goalH  = 10.0;
    final arcR   = halfH  * 0.22; // slightly larger for visibility

    final paL    = (w - paW) / 2;
    final paR    = paL + paW;
    final gaL    = (w - gaW) / 2;
    final gaR    = gaL + gaW;
    final goalL  = (w - goalW) / 2;
    final goalR  = goalL + goalW;

    // ── TOP GOAL ─────────────────────────────────────────────────────────────
    final paTopBot  = padV + paD;
    final topSpotY  = padV + halfH * 0.21;

    canvas.drawRect(Rect.fromLTRB(paL, padV, paR, paTopBot), lp..strokeWidth = 1.0);
    canvas.drawRect(Rect.fromLTRB(gaL, padV, gaR, padV + gaD), lp..strokeWidth = 0.7);
    canvas.drawRect(Rect.fromLTRB(goalL, padV - goalH, goalR, padV), lp..strokeWidth = 1.2);
    canvas.drawCircle(Offset(w / 2, topSpotY), 2, Paint()..color = AppColors.pitchLine);

    // Arc: only the portion below paTopBot (outside the penalty area)
    final topRatio = (paTopBot - topSpotY).clamp(-arcR, arcR) / arcR;
    final topStart = math.asin(topRatio);
    final topSweep = math.pi - 2 * topStart;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w / 2, topSpotY), width: arcR * 2, height: arcR * 2),
      topStart, topSweep, false, lp..strokeWidth = 0.7,
    );

    // ── BOTTOM GOAL ──────────────────────────────────────────────────────────
    final paBotTop  = h - padV - paD;
    final botSpotY  = h - padV - halfH * 0.21;

    canvas.drawRect(Rect.fromLTRB(paL, paBotTop, paR, h - padV), lp..strokeWidth = 1.0);
    canvas.drawRect(Rect.fromLTRB(gaL, h - padV - gaD, gaR, h - padV), lp..strokeWidth = 0.7);
    canvas.drawRect(Rect.fromLTRB(goalL, h - padV, goalR, h - padV + goalH), lp..strokeWidth = 1.2);
    canvas.drawCircle(Offset(w / 2, botSpotY), 2, Paint()..color = AppColors.pitchLine);

    // Arc: only the portion above paBotTop (outside the penalty area)
    final botRatio = (botSpotY - paBotTop).clamp(-arcR, arcR) / arcR;
    final botArcSin = math.asin(botRatio);
    final botStart = math.pi + botArcSin;
    final botSweep = math.pi - 2 * botArcSin;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w / 2, botSpotY), width: arcR * 2, height: arcR * 2),
      botStart, botSweep, false, lp..strokeWidth = 0.7,
    );

    // ── CORNER ARCS ──────────────────────────────────────────────────────────
    const cR = 7.0;
    for (final (cx, cy, start) in [
      (padH,     padV,     0.0),
      (w - padH, padV,     math.pi / 2),
      (padH,     h - padV, -math.pi / 2),
      (w - padH, h - padV, math.pi),
    ]) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, cy), width: cR * 2, height: cR * 2),
        start, math.pi / 2, false, lp..strokeWidth = 0.8,
      );
    }
  }

  void _drawEventDots(Canvas canvas, double w, double h) {
    for (final ev in events) {
      final px = ev.pitchX * w;
      final py = ev.pitchY * h;
      final color = colorFor(ev.tipoEventoNombre);
      _drawDot(canvas, Offset(px, py), color);
    }
  }

  void _drawPendingDot(Canvas canvas, double w, double h) {
    final px = pendingTap!.dx * w;
    final py = pendingTap!.dy * h;
    canvas.drawCircle(Offset(px, py), 12,
        Paint()..color = Colors.white.withValues(alpha: 0.18));
    canvas.drawCircle(Offset(px, py), 5,
        Paint()..color = Colors.white.withValues(alpha: 0.6));
  }

  void _drawDot(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(
      center, 10,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(center, 4.5,
        Paint()..color = color..style = PaintingStyle.fill);
    canvas.drawCircle(
      center, 4.5,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_PitchPainter old) =>
      old.events != events || old.pendingTap != pendingTap;
}

// =============================================================================
//  RADIAL MENU OVERLAY
// =============================================================================

class _SectorData {
  final String label;
  final String eventType;
  final IconData icon;
  final Color color;
  const _SectorData(this.label, this.eventType, this.icon, this.color);
}

const _sectors = [
  _SectorData('Pase clave', EventTypes.passKey, Icons.key_rounded, AppColors.accent),
  _SectorData('Pase ✗', EventTypes.passBad, Icons.close_rounded, AppColors.danger),
  _SectorData('Remate', EventTypes.shot, Icons.sports_soccer_rounded, AppColors.warning),
  _SectorData('Gol', EventTypes.goal, Icons.emoji_events_rounded, Color(0xFFFFEB3B)),
  _SectorData('Falta', EventTypes.foul, Icons.warning_amber_rounded, AppColors.danger),
  _SectorData('Tarjeta', EventTypes.yellowCard, Icons.square_rounded, AppColors.warning),
  _SectorData('Recup.', EventTypes.recovery, Icons.autorenew_rounded, AppColors.info),
  _SectorData('Centro', EventTypes.cross, Icons.swap_horiz_rounded, AppColors.textSecondary),
];

class _RadialOverlay extends StatelessWidget {
  final Offset center;
  final Animation<double> scaleAnim;
  final Animation<double> fadeAnim;
  final int hoveredSector;
  final ValueChanged<int> onSectorTap;
  final VoidCallback onMoreTap, onDismiss;

  const _RadialOverlay({
    required this.center,
    required this.scaleAnim,
    required this.fadeAnim,
    required this.hoveredSector,
    required this.onSectorTap,
    required this.onMoreTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onDismiss,
              behavior: HitTestBehavior.opaque,
              child: FadeTransition(
                opacity: fadeAnim,
                child: Container(color: Colors.black.withValues(alpha: 0.35)),
              ),
            ),
          ),
          Positioned(
            left: center.dx - AppConstants.radialMenuRadius,
            top: center.dy - AppConstants.radialMenuRadius,
            child: ScaleTransition(
              scale: scaleAnim,
              child: FadeTransition(
                opacity: fadeAnim,
                child: _RadialMenu(
                  hoveredSector: hoveredSector,
                  onSectorTap: onSectorTap,
                  onMoreTap: onMoreTap,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadialMenu extends StatelessWidget {
  final int hoveredSector;
  final ValueChanged<int> onSectorTap;
  final VoidCallback onMoreTap;

  const _RadialMenu({
    required this.hoveredSector,
    required this.onSectorTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    const r = AppConstants.radialMenuRadius;
    const size = r * 2;
    const sectorOrbitR = r * 0.70;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _RadialRingPainter(hoveredSector)),
          ),
          ...List.generate(_sectors.length, (i) {
            final angle = (i / _sectors.length) * 2 * math.pi - math.pi / 2;
            final dx = r + sectorOrbitR * math.cos(angle);
            final dy = r + sectorOrbitR * math.sin(angle);
            final s = _sectors[i];
            final isHovered = hoveredSector == i;

            return Positioned(
              left: dx - 28,
              top: dy - 28,
              child: GestureDetector(
                onTap: () => onSectorTap(i),
                child: AnimatedContainer(
                  duration: AppConstants.animFast,
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isHovered
                        ? s.color.withValues(alpha: 0.30)
                        : s.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: s.color.withValues(alpha: isHovered ? 0.80 : 0.35),
                      width: isHovered ? 1.5 : 0.5,
                    ),
                    boxShadow: isHovered
                        ? [BoxShadow(
                            color: s.color.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 1)]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(s.icon, size: isHovered ? 20 : 17, color: s.color),
                      const SizedBox(height: 2),
                      Text(s.label,
                          style: TextStyle(
                            fontSize: 8,
                            color: s.color,
                            fontWeight: isHovered
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            );
          }),
          Positioned(
            left: r - AppConstants.radialCenterRadius,
            top: r - AppConstants.radialCenterRadius,
            child: GestureDetector(
              onTap: onMoreTap,
              child: Container(
                width: AppConstants.radialCenterRadius * 2,
                height: AppConstants.radialCenterRadius * 2,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: AppColors.borderStrong, width: 1.0),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.more_horiz_rounded,
                        size: 16, color: AppColors.textSecondary),
                    Text('Más',
                        style: TextStyle(
                            fontSize: 8, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadialRingPainter extends CustomPainter {
  final int hoveredSector;
  const _RadialRingPainter(this.hoveredSector);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const outerR = AppConstants.radialMenuRadius;
    const innerR = AppConstants.radialCenterRadius + 4.0;

    canvas.drawCircle(center, outerR,
        Paint()..color = Colors.black.withValues(alpha: 0.45));

    if (hoveredSector >= 0) {
      const n = 8;
      const segAngle = 2 * math.pi / n;
      final startAngle =
          hoveredSector * segAngle - math.pi / 2 - segAngle / 2;
      final color = _sectors[hoveredSector].color;

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(Rect.fromCircle(center: center, radius: outerR),
            startAngle, segAngle, false)
        ..close();

      canvas.drawPath(path,
          Paint()..color = color.withValues(alpha: 0.22)..style = PaintingStyle.fill);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerR),
        startAngle, segAngle, false,
        Paint()
          ..color = color.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    canvas.drawCircle(center, innerR,
        Paint()..color = AppColors.bgDeep..blendMode = BlendMode.srcOver);

    final divPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 0.5;
    const n = 8;
    for (var i = 0; i < n; i++) {
      final a = i * 2 * math.pi / n - math.pi / 2 - math.pi / n;
      canvas.drawLine(
        center + Offset(innerR * math.cos(a), innerR * math.sin(a)),
        center + Offset(outerR * math.cos(a), outerR * math.sin(a)),
        divPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RadialRingPainter old) =>
      old.hoveredSector != hoveredSector;
}

// =============================================================================
//  TAP HINT
// =============================================================================

class _TapHint extends StatelessWidget {
  const _TapHint();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 14,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderDefault, width: 0.5),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app_rounded,
                  size: 13, color: AppColors.textMuted),
              SizedBox(width: 6),
              Text('Toca la cancha para registrar un evento',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  COLLAPSIBLE TIMELINE PANEL
// =============================================================================

class _TimelinePanel extends StatelessWidget {
  final List<EventoPartidoModel> events;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _TimelinePanel({
    required this.events,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Container(
              margin: const EdgeInsets.only(top: 60),
              width: 20,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(8)),
                border: Border.all(color: AppColors.borderSubtle, width: 0.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isExpanded
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 2),
                  RotatedBox(
                    quarterTurns: 3,
                    child: Text('${events.length}',
                        style: const TextStyle(
                            fontSize: 9, color: AppColors.textMuted)),
                  ),
                ],
              ),
            ),
          ),
          AnimatedContainer(
            duration: AppConstants.animNormal,
            curve: Curves.easeOutCubic,
            width: isExpanded ? 160 : 0,
            child: isExpanded
                ? Container(
                    color: AppColors.bgCard,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(10, 10, 6, 6),
                          decoration: const BoxDecoration(
                            border: Border(
                                bottom: BorderSide(
                                    color: AppColors.borderSubtle,
                                    width: 0.5)),
                          ),
                          child: const Text('Eventos',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary)),
                        ),
                        Expanded(
                          child: events.isEmpty
                              ? const Center(
                                  child: Text('Sin eventos',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted)))
                              : ListView.builder(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  itemCount: events.length,
                                  itemBuilder: (_, i) =>
                                      _MiniEventRow(event: events[i]),
                                ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _MiniEventRow extends StatelessWidget {
  final EventoPartidoModel event;
  const _MiniEventRow({required this.event});

  Color get _color => _PitchPainter.colorFor(event.tipoEventoNombre);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.tipoEventoNombre,
                    style: TextStyle(
                        fontSize: 9,
                        color: _color,
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(event.nombreJugador ?? 'Sin jugador',
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text("${event.minuto}'",
              style:
                  const TextStyle(fontSize: 9, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

// =============================================================================
//  PLAYER PICKER (inline bottom panel)
// =============================================================================

class _PlayerPicker extends StatelessWidget {
  final String eventType;
  final int minute;
  final List<AlineacionEntradaModel> lineup;
  final bool saving;
  final ValueChanged<AlineacionEntradaModel> onSelect;
  final VoidCallback onDismiss;
  final VoidCallback onSelectNone;

  const _PlayerPicker({
    required this.eventType,
    required this.minute,
    required this.lineup,
    required this.saving,
    required this.onSelect,
    required this.onDismiss,
    required this.onSelectNone,
  });

  @override
  Widget build(BuildContext context) {
    final eventColor = _PitchPainter.colorFor(eventType);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border(
          top: BorderSide(color: eventColor.withValues(alpha: 0.3), width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: const BoxDecoration(
              border: Border(
                  bottom:
                      BorderSide(color: AppColors.borderSubtle, width: 0.5)),
            ),
            child: Row(
              children: [
                const Text('Registrando:',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: eventColor.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: eventColor.withValues(alpha: 0.4), width: 0.5),
                  ),
                  child: Text(eventType,
                      style: TextStyle(
                          fontSize: 11,
                          color: eventColor,
                          fontWeight: FontWeight.w500)),
                ),
                const Spacer(),
                Text("$minute'",
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(width: 8),
                if (saving)
                  const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  GestureDetector(
                    onTap: onDismiss,
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
              childAspectRatio: 0.88,
            ),
            itemCount: lineup.length + 1,
            itemBuilder: (_, i) {
              if (i == lineup.length) {
                return _NoPlayerCell(
                  onTap: saving ? null : onSelectNone,
                );
              }
              return _PlayerCell(
                player: lineup[i],
                eventColor: eventColor,
                onTap: saving ? null : () => onSelect(lineup[i]),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PlayerCell extends StatelessWidget {
  final AlineacionEntradaModel player;
  final Color eventColor;
  final VoidCallback? onTap;

  const _PlayerCell({
    required this.player,
    required this.eventColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surname = player.nombreJugador.split(' ').last;
    final number = player.numeroCamiseta;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: AppColors.bgMuted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderSubtle, width: 0.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: eventColor.withValues(alpha: 0.15),
                child: Text(
                  number != null ? '$number' : '?',
                  style: TextStyle(
                      fontSize: 10,
                      color: eventColor,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                surname,
                style: const TextStyle(
                    fontSize: 9, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                player.posicionAsignada ?? '',
                style: const TextStyle(fontSize: 8, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoPlayerCell extends StatelessWidget {
  final VoidCallback? onTap;
  const _NoPlayerCell({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: AppColors.bgMuted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: AppColors.textMuted.withValues(alpha: 0.4), width: 0.5),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.bgSurface,
                child: Icon(Icons.person_off_rounded,
                    size: 14, color: AppColors.textMuted),
              ),
              SizedBox(height: 4),
              Text(
                'Sin\njugador',
                style:
                    TextStyle(fontSize: 9, color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  MORE EVENTS SHEET
// =============================================================================

class _MoreEventsSheet extends StatelessWidget {
  final ValueChanged<String> onSelect;
  const _MoreEventsSheet({required this.onSelect});

  static const _categories = {
    'Pase / Distribución': [
      EventTypes.passOk,
      EventTypes.passBad,
      EventTypes.cross,
      EventTypes.assist,
    ],
    'Remate / Gol': [
      EventTypes.shot,
      EventTypes.goal,
    ],
    'Defensivo': [
      EventTypes.recovery,
      EventTypes.interception,
      EventTypes.tackleOk,
      EventTypes.tackleBad,
      EventTypes.save,
    ],
    'Infracción': [
      EventTypes.foul,
      EventTypes.yellowCard,
      EventTypes.redCard,
      EventTypes.offside,
    ],
    'Juego parado': [
      EventTypes.corner,
      EventTypes.loss,
    ],
  };

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
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
                Text('Todos los eventos',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
          const Divider(color: AppColors.borderSubtle, height: 0.5),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
              children: _categories.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 6),
                      child: Text(entry.key.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 9,
                              letterSpacing: 0.8,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500)),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: entry.value.map((type) {
                        final color = _PitchPainter.colorFor(type);
                        return GestureDetector(
                          onTap: () => onSelect(type),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: color.withValues(alpha: 0.35),
                                  width: 0.5),
                            ),
                            child: Text(type,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: color,
                                    fontWeight: FontWeight.w500)),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  FULL TIMELINE MODAL
// =============================================================================

class _FullTimeline extends StatelessWidget {
  final List<EventoPartidoModel> events;
  const _FullTimeline({required this.events});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderDefault,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                const Text('Timeline de eventos',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.bgMuted,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${events.length} eventos',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.borderSubtle, height: 0.5),
          Expanded(
            child: events.isEmpty
                ? const Center(
                    child: Text('No hay eventos registrados',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)))
                : ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: events.length,
                    itemBuilder: (_, i) {
                      final ev = events[i];
                      final color = _PitchPainter.colorFor(ev.tipoEventoNombre);
                      final isLast = i == events.length - 1;

                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: 48,
                              child: Column(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: color.withValues(alpha: 0.35),
                                          width: 0.5),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text("${ev.minuto}'",
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: color,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  if (!isLast)
                                    Expanded(
                                      child: Container(
                                        width: 1,
                                        color: AppColors.borderSubtle,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 23.5),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.fromLTRB(0, 0, 16, 10),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.bgMuted,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: AppColors.borderSubtle,
                                      width: 0.5),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(ev.tipoEventoNombre,
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: color)),
                                          const SizedBox(height: 2),
                                          Text(ev.nombreJugador ?? 'Sin jugador',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary)),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(_zone(ev.pitchX),
                                            style: const TextStyle(
                                                fontSize: 9,
                                                color: AppColors.textMuted)),
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _zone(double x) {
    if (x < 0.33) return 'Zona def.';
    if (x < 0.66) return 'Mediocamp.';
    return 'Zona of.';
  }
}
