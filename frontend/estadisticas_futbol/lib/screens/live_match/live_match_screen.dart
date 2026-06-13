import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../mock/mock_data.dart';
import '../../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class LiveMatchScreen extends StatefulWidget {
  final String matchId;
  const LiveMatchScreen({super.key, required this.matchId});

  @override
  State<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends State<LiveMatchScreen>
    with TickerProviderStateMixin {
  // ── Match data ─────────────────────────────────────────────────────────────
  late final MatchModel _match;
  final List<MatchEventModel> _events = [];
  int _minute = 34;
  int _homeScore = 2;
  final int _awayScore = 1;
  bool _isRunning = true;
  Timer? _matchTimer;

  // ── Pitch area key (used to get render-box for clamping) ───────────────────
  final _pitchKey = GlobalKey();

  // ── Radial menu state ──────────────────────────────────────────────────────
  /// Normalised position (0–1) where the user tapped on the pitch
  Offset? _tapNorm;

  /// Raw pixel offset inside the pitch widget where the tap occurred
  Offset? _tapLocal;

  bool _showRadial = false;

  /// Index of the sector currently highlighted by the ongoing drag (-1 = none)
  int _dragSector = -1;

  /// Event type chosen from the radial menu (before player is selected)
  String? _pendingEvent;

  late final AnimationController _radialAnimCtrl;
  late final Animation<double> _radialScaleAnim;
  late final Animation<double> _radialFadeAnim;

  // ── Player picker ──────────────────────────────────────────────────────────
  bool _showPlayerPicker = false;

  // ── Undo ───────────────────────────────────────────────────────────────────
  MatchEventModel? _lastRegistered;
  int _undoSeconds = 0;
  Timer? _undoTimer;

  // ── Timeline panel (persistent, collapsible) ───────────────────────────────
  bool _timelineExpanded = false;

  // ─────────────────────────────────────────────────────────────────────────
  //  LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _match = MockData.matches.firstWhere(
      (m) => m.id == widget.matchId,
      orElse: () => MockData.matches.first,
    );
    _events.addAll(List.from(MockData.liveEvents));

    // Radial animation: spring scale + fade
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

    _startMatchTimer();
  }

  @override
  void dispose() {
    _matchTimer?.cancel();
    _undoTimer?.cancel();
    _radialAnimCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  MATCH TIMER
  // ─────────────────────────────────────────────────────────────────────────

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

  // ─────────────────────────────────────────────────────────────────────────
  //  PITCH TAP  →  open radial menu
  // ─────────────────────────────────────────────────────────────────────────

  void _handlePitchTapDown(TapDownDetails details, BoxConstraints constraints) {
    // Close any existing state first
    if (_showRadial) {
      _closeRadial();
      return;
    }

    HapticFeedback.lightImpact();

    // Normalise tap position to 0–1 range (stored for the event dot)
    final norm = Offset(
      (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0),
      (details.localPosition.dy / constraints.maxHeight).clamp(0.0, 1.0),
    );

    // Clamp the pixel position so the radial menu stays inside the pitch
    final clampedLocal = _clampRadialCenter(
      details.localPosition,
      constraints,
    );

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

  /// Ensures the radial menu's bounding box stays within the pitch widget.
  Offset _clampRadialCenter(Offset raw, BoxConstraints c) {
    const r = AppConstants.radialMenuRadius;
    const margin = r + 8; // 8px safety margin
    return Offset(
      raw.dx.clamp(margin, c.maxWidth - margin),
      raw.dy.clamp(margin, c.maxHeight - margin),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  RADIAL MENU DRAG  →  highlight sector under finger
  // ─────────────────────────────────────────────────────────────────────────

  /// Called continuously while the user drags on the radial overlay.
  void _handleRadialDragUpdate(DragUpdateDetails details) {
    if (_tapLocal == null) return;

    final dx = details.localPosition.dx - _tapLocal!.dx;
    final dy = details.localPosition.dy - _tapLocal!.dy;
    final dist = math.sqrt(dx * dx + dy * dy);

    if (dist < AppConstants.radialCenterRadius) {
      // Inside the centre dead-zone → nothing highlighted
      if (_dragSector != -1) {
        HapticFeedback.selectionClick();
        setState(() => _dragSector = -1);
      }
      return;
    }

    // Convert angle to sector index (0–7 clockwise from top)
    // atan2 gives angle from positive X axis; we rotate -90° (subtract π/2)
    // so sector 0 is at the top.
    var angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;

    final sector = (angle / (2 * math.pi / 8)).floor() % 8;

    if (sector != _dragSector) {
      HapticFeedback.selectionClick();
      setState(() => _dragSector = sector);
    }
  }

  /// Called when the finger is lifted while a drag was in progress.
  void _handleRadialDragEnd(DragEndDetails _) {
    if (_dragSector >= 0) {
      _selectSector(_dragSector);
    } else {
      // Released inside dead-zone → just close
      _closeRadial();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  RADIAL SECTOR SELECTION
  // ─────────────────────────────────────────────────────────────────────────

  void _selectSector(int index) {
    HapticFeedback.mediumImpact();
    final event = EventTypes.radialPrimary[index];
    setState(() {
      _pendingEvent = event;
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

  // ─────────────────────────────────────────────────────────────────────────
  //  MORE EVENTS (all event types)
  // ─────────────────────────────────────────────────────────────────────────

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

  // ─────────────────────────────────────────────────────────────────────────
  //  PLAYER SELECTED  →  register event
  // ─────────────────────────────────────────────────────────────────────────

  void _onPlayerSelected(PlayerModel player) {
    if (_tapNorm == null || _pendingEvent == null) return;
    HapticFeedback.mediumImpact();

    final isGoal = _pendingEvent == EventTypes.goal;
    if (isGoal) HapticFeedback.heavyImpact();

    final event = MatchEventModel(
      id: 'ev_${DateTime.now().millisecondsSinceEpoch}',
      type: _pendingEvent!,
      playerId: player.id,
      playerName: player.shortName,
      minute: _minute,
      pitchX: _tapNorm!.dx,
      pitchY: _tapNorm!.dy,
    );

    setState(() {
      if (isGoal) _homeScore++;
      _events.insert(0, event);
      _lastRegistered = event;
      _showPlayerPicker = false;
      _pendingEvent = null;
      _tapNorm = null;
      _tapLocal = null;
    });

    _beginUndo();
  }

  void _dismissPlayerPicker() {
    setState(() {
      _showPlayerPicker = false;
      _pendingEvent = null;
      _tapNorm = null;
      _tapLocal = null;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  UNDO
  // ─────────────────────────────────────────────────────────────────────────

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

  void _undo() {
    if (_lastRegistered == null) return;
    HapticFeedback.lightImpact();
    final wasGoal = _lastRegistered!.type == EventTypes.goal;
    setState(() {
      _events.removeWhere((e) => e.id == _lastRegistered!.id);
      if (wasGoal) _homeScore--;
      _lastRegistered = null;
      _undoSeconds = 0;
    });
    _undoTimer?.cancel();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            // ① Scoreboard + timer
            _TopBar(
              match: _match,
              minute: _minute,
              homeScore: _homeScore,
              awayScore: _awayScore,
              isRunning: _isRunning,
              onToggle: _toggleTimer,
              onBack: () => Navigator.of(context).pop(),
            ),

            // ② Quick-action chips (last event + undo)
            _QuickBar(
              lastEvent: _lastRegistered,
              undoSeconds: _undoSeconds,
              onUndo: _undo,
              onHistory: _openTimeline,
              onMoreEvents: _openMoreEvents,
            ),

            // ③ Interactive pitch (main area)
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Pitch + GestureDetector
                  LayoutBuilder(
                    key: _pitchKey,
                    builder: (ctx, constraints) => GestureDetector(
                      // Primary tap to open menu
                      onTapDown: (d) => _handlePitchTapDown(d, constraints),
                      // Drag on pitch while radial is open → forward to radial logic
                      onPanUpdate: _showRadial ? _handleRadialDragUpdate : null,
                      onPanEnd: _showRadial ? _handleRadialDragEnd : null,
                      child: _PitchCanvas(
                        events: _events,
                        pendingTap: _tapNorm,
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                      ),
                    ),
                  ),

                  // Radial menu overlay
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

                  // Tap hint (only visible when idle)
                  if (!_showRadial && !_showPlayerPicker) const _TapHint(),

                  // Collapsible timeline panel (right side)
                  _TimelinePanel(
                    events: _events,
                    isExpanded: _timelineExpanded,
                    onToggle: () =>
                        setState(() => _timelineExpanded = !_timelineExpanded),
                  ),
                ],
              ),
            ),

            // ④ Player picker (inline bottom panel, slides up)
            AnimatedSize(
              duration: AppConstants.animNormal,
              curve: Curves.easeOutCubic,
              child: _showPlayerPicker && _pendingEvent != null
                  ? _PlayerPicker(
                      eventType: _pendingEvent!,
                      minute: _minute,
                      onSelect: _onPlayerSelected,
                      onDismiss: _dismissPlayerPicker,
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
  final MatchModel match;
  final int minute, homeScore, awayScore;
  final bool isRunning;
  final VoidCallback onToggle, onBack;

  const _TopBar({
    required this.match,
    required this.minute,
    required this.homeScore,
    required this.awayScore,
    required this.isRunning,
    required this.onToggle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgSurface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Back
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: AppColors.textSecondary),
            onPressed: onBack,
            padding: EdgeInsets.zero,
          ),

          // Score block
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TeamChip(
                    abbr: match.homeAbbr,
                    name: match.homeTeam,
                    color: AppColors.accent),
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ScoreBoard(homeScore: homeScore, awayScore: awayScore),
                    const SizedBox(height: 2),
                    const Text('1er tiempo',
                        style: TextStyle(
                            fontSize: 9,
                            color: AppColors.textMuted,
                            letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(width: 10),
                _TeamChip(
                    abbr: match.awayAbbr,
                    name: match.awayTeam,
                    color: AppColors.info),
              ],
            ),
          ),

          // Timer pill (tap to pause/resume)
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
        ],
      ),
    );
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
  const _TeamChip(
      {required this.abbr, required this.name, required this.color});

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
            style:
                const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
      ],
    );
  }
}

/// Animated green dot for "live" state
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
//  QUICK BAR  (last event + undo + shortcuts)
// =============================================================================

class _QuickBar extends StatelessWidget {
  final MatchEventModel? lastEvent;
  final int undoSeconds;
  final VoidCallback onUndo, onHistory, onMoreEvents;

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
            // Last event + undo
            if (lastEvent != null && undoSeconds > 0) ...[
              _QChip(
                icon: Icons.check_circle_outline_rounded,
                label: lastEvent!.type,
                color: AppColors.accent,
                filled: true,
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onUndo,
                child: _UndoChip(seconds: undoSeconds),
              ),
              const SizedBox(width: 6),
              Container(width: 0.5, height: 24, color: AppColors.borderDefault),
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
            color: filled ? color.withValues(alpha: 0.4) : AppColors.borderDefault,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13, color: filled ? color : AppColors.textSecondary),
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
        border:
            Border.all(color: AppColors.danger.withValues(alpha: 0.4), width: 0.5),
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
//  PITCH CANVAS  (CustomPainter)
// =============================================================================

/// Stateless widget that wraps CustomPaint for the football pitch.
class _PitchCanvas extends StatelessWidget {
  final List<MatchEventModel> events;
  final Offset? pendingTap; // normalised tap being processed (shows ghost dot)
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
  final List<MatchEventModel> events;
  final Offset? pendingTap;

  const _PitchPainter({required this.events, this.pendingTap});

  // ── helpers ──────────────────────────────────────────────────────────────

  static Color _colorFor(String type) {
    return switch (type) {
      EventTypes.passOk => AppColors.accent,
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

  // ── paint ─────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    _drawPitch(canvas, w, h);
    _drawEventDots(canvas, w, h);

    if (pendingTap != null) {
      _drawPendingDot(canvas, w, h);
    }
  }

  void _drawPitch(Canvas canvas, double w, double h) {
    // ── Alternating grass stripes ──────────────────────────────────────────
    const nStripes = 8;
    for (var i = 0; i < nStripes; i++) {
      final x = i * w / nStripes;
      final paint = Paint()
        ..color = i.isEven ? AppColors.pitchGreen : AppColors.pitchGreenAlt;
      canvas.drawRect(Rect.fromLTWH(x, 0, w / nStripes, h), paint);
    }

    // ── Line paint ─────────────────────────────────────────────────────────
    final lp = Paint()
      ..color = AppColors.pitchLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final pad = w * 0.05; // left/right padding

    // Outer boundary
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTRB(pad, 6, w - pad, h - 6), const Radius.circular(3)),
      lp,
    );

    // Halfway line
    lp.strokeWidth = 0.8;
    canvas.drawLine(Offset(w / 2, 6), Offset(w / 2, h - 6), lp);

    // Centre circle
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.10, lp);
    canvas.drawCircle(
        Offset(w / 2, h / 2), 3, Paint()..color = AppColors.pitchLine);

    // ── Penalty areas ──────────────────────────────────────────────────────
    final bW = w * 0.18; // penalty box width
    final bH = h * 0.44; // penalty box height
    final bY = (h - bH) / 2;

    // Small box proportions
    final sW = bW * 0.50;
    final sH = bH * 0.50;
    final sY = (h - sH) / 2;

    // Left penalty box
    canvas.drawRect(Rect.fromLTWH(pad, bY, bW, bH), lp..strokeWidth = 1.0);
    canvas.drawRect(Rect.fromLTWH(pad, sY, sW, sH), lp..strokeWidth = 0.7);

    // Left penalty arc (D)
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(pad + bW * 0.72, h / 2),
          width: bW * 0.6,
          height: h * 0.28),
      -math.pi * 0.5,
      math.pi,
      false,
      lp..strokeWidth = 0.7,
    );

    // Left goal
    canvas.drawRect(
      Rect.fromLTWH(pad - 7, (h - bH * 0.25) / 2, 7, bH * 0.25),
      lp
        ..strokeWidth = 1.2
        ..color = AppColors.pitchLine,
    );

    // Right penalty box
    canvas.drawRect(
        Rect.fromLTWH(w - pad - bW, bY, bW, bH), lp..strokeWidth = 1.0);
    canvas.drawRect(
        Rect.fromLTWH(w - pad - sW, sY, sW, sH), lp..strokeWidth = 0.7);

    // Right penalty arc (D)
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(w - pad - bW * 0.72, h / 2),
          width: bW * 0.6,
          height: h * 0.28),
      math.pi * 0.5,
      math.pi,
      false,
      lp..strokeWidth = 0.7,
    );

    // Right goal
    canvas.drawRect(
      Rect.fromLTWH(w - pad, (h - bH * 0.25) / 2, 7, bH * 0.25),
      lp..strokeWidth = 1.2,
    );

    // Corner arcs
    const cornerR = 6.0;
    for (final corner in [
      (pad, 6.0, 0.0, math.pi / 2), // top-left
      (w - pad, 6.0, math.pi / 2, math.pi / 2), // top-right
      (pad, h - 6.0, -math.pi / 2, math.pi / 2), // bottom-left
      (w - pad, h - 6.0, math.pi, math.pi / 2), // bottom-right
    ]) {
      canvas.drawArc(
        Rect.fromCenter(
            center: Offset(corner.$1, corner.$2),
            width: cornerR * 2,
            height: cornerR * 2),
        corner.$3,
        corner.$4,
        false,
        lp..strokeWidth = 0.8,
      );
    }
  }

  void _drawEventDots(Canvas canvas, double w, double h) {
    for (final ev in events) {
      final px = ev.pitchX * w;
      final py = ev.pitchY * h;
      final color = _colorFor(ev.type);
      _drawDot(canvas, Offset(px, py), color);
    }
  }

  void _drawPendingDot(Canvas canvas, double w, double h) {
    final px = pendingTap!.dx * w;
    final py = pendingTap!.dy * h;
    // Pulsing ghost ring
    canvas.drawCircle(
      Offset(px, py),
      12,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(px, py),
      5,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawDot(Canvas canvas, Offset center, Color color) {
    // Outer glow
    canvas.drawCircle(
      center,
      10,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Inner dot
    canvas.drawCircle(
        center,
        4.5,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill);
    // Dark outline
    canvas.drawCircle(
      center,
      4.5,
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

/// Data for each radial sector
class _SectorData {
  final String label;
  final String eventType;
  final IconData icon;
  final Color color;
  const _SectorData(this.label, this.eventType, this.icon, this.color);
}

const _sectors = [
  _SectorData(
      'Pase ✓', EventTypes.passOk, Icons.check_rounded, AppColors.accent),
  _SectorData(
      'Pase ✗', EventTypes.passBad, Icons.close_rounded, AppColors.danger),
  _SectorData('Remate', EventTypes.shot, Icons.sports_soccer_rounded,
      AppColors.warning),
  _SectorData(
      'Gol', EventTypes.goal, Icons.emoji_events_rounded, Color(0xFFFFEB3B)),
  _SectorData(
      'Falta', EventTypes.foul, Icons.warning_amber_rounded, AppColors.danger),
  _SectorData('Tarjeta', EventTypes.yellowCard, Icons.square_rounded,
      AppColors.warning),
  _SectorData(
      'Recup.', EventTypes.recovery, Icons.autorenew_rounded, AppColors.info),
  _SectorData('Centro', EventTypes.cross, Icons.swap_horiz_rounded,
      AppColors.textSecondary),
];

class _RadialOverlay extends StatelessWidget {
  final Offset center;
  final Animation<double> scaleAnim;
  final Animation<double> fadeAnim;
  final int hoveredSector; // -1 if none
  final ValueChanged<int> onSectorTap;
  final VoidCallback onMoreTap;
  final VoidCallback onDismiss;

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
          // Dim background — tap to dismiss
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

          // Radial menu widget
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
    const sectorOrbitR = r * 0.70; // distance from centre to sector icons

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Background ring ──────────────────────────────────────────────
          Positioned.fill(
            child: CustomPaint(painter: _RadialRingPainter(hoveredSector)),
          ),

          // ── Sector buttons ───────────────────────────────────────────────
          ...List.generate(_sectors.length, (i) {
            // Angle: 0 = top, clockwise
            // Subtract π/2 so 0 points up, not right
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
                        ? [
                            BoxShadow(
                                color: s.color.withValues(alpha: 0.3),
                                blurRadius: 8,
                                spreadRadius: 1)
                          ]
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
                            fontWeight:
                                isHovered ? FontWeight.w600 : FontWeight.w500,
                          ),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            );
          }),

          // ── Centre button (More events) ───────────────────────────────────
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
                  border: Border.all(color: AppColors.borderStrong, width: 1.0),
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

/// Draws the translucent ring background of the radial menu and
/// highlights the hovered sector as a pie-slice.
class _RadialRingPainter extends CustomPainter {
  final int hoveredSector;
  const _RadialRingPainter(this.hoveredSector);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const outerR = AppConstants.radialMenuRadius;
    const innerR = AppConstants.radialCenterRadius + 4.0;

    // Background ring
    canvas.drawCircle(
      center,
      outerR,
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );

    // Highlighted sector
    if (hoveredSector >= 0) {
      const n = 8;
      const segAngle = 2 * math.pi / n;
      // Rotate so sector 0 is at top (-π/2 offset) and each sector is centred
      final startAngle = hoveredSector * segAngle - math.pi / 2 - segAngle / 2;

      final color = _sectors[hoveredSector].color;
      final sectorPaint = Paint()
        ..color = color.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: outerR),
          startAngle,
          segAngle,
          false,
        )
        ..close();

      canvas.drawPath(path, sectorPaint);

      // Arc border
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerR),
        startAngle,
        segAngle,
        false,
        Paint()
          ..color = color.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Inner cutout
    canvas.drawCircle(
      center,
      innerR,
      Paint()
        ..color = AppColors.bgDeep
        ..blendMode = BlendMode.srcOver,
    );

    // Outer ring divider lines
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
                  style:
                      TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  COLLAPSIBLE TIMELINE PANEL  (right side, persistent)
// =============================================================================

class _TimelinePanel extends StatelessWidget {
  final List<MatchEventModel> events;
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
          // Toggle tab
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
                    child: Text(
                      '${events.length}',
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded panel
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
                                    color: AppColors.borderSubtle, width: 0.5)),
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
                                          color: AppColors.textMuted)),
                                )
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
  final MatchEventModel event;
  const _MiniEventRow({required this.event});

  Color get _color => _PitchPainter._colorFor(event.type);

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
                Text(event.type,
                    style: TextStyle(
                        fontSize: 9,
                        color: _color,
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(event.playerName,
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text("${event.minute}'",
              style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

// =============================================================================
//  PLAYER PICKER  (inline bottom panel)
// =============================================================================

class _PlayerPicker extends StatelessWidget {
  final String eventType;
  final int minute;
  final ValueChanged<PlayerModel> onSelect;
  final VoidCallback onDismiss;

  const _PlayerPicker({
    required this.eventType,
    required this.minute,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final available = MockData.players.where((p) => p.isAvailable).toList();

    // Infer color from event type
    final eventColor = _PitchPainter._colorFor(eventType);

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
          // ── Header ───────────────────────────────────────────────────────
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
                GestureDetector(
                  onTap: onDismiss,
                  child: const Icon(Icons.close_rounded,
                      size: 18, color: AppColors.textMuted),
                ),
              ],
            ),
          ),

          // ── Player grid ───────────────────────────────────────────────────
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
            itemCount: available.length,
            itemBuilder: (_, i) => _PlayerCell(
              player: available[i],
              eventColor: eventColor,
              onTap: () => onSelect(available[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerCell extends StatelessWidget {
  final PlayerModel player;
  final Color eventColor;
  final VoidCallback onTap;

  const _PlayerCell({
    required this.player,
    required this.eventColor,
    required this.onTap,
  });

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
            border: Border.all(color: AppColors.borderSubtle, width: 0.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: eventColor.withValues(alpha: 0.15),
                child: Text('${player.number}',
                    style: TextStyle(
                        fontSize: 10,
                        color: eventColor,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 4),
              Text(
                player.shortName.split(' ').last, // only surname
                style: const TextStyle(
                    fontSize: 9, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(player.position,
                  style:
                      const TextStyle(fontSize: 8, color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  MORE EVENTS  SHEET  (all 17 event types)
// =============================================================================

class _MoreEventsSheet extends StatelessWidget {
  final ValueChanged<String> onSelect;
  const _MoreEventsSheet({required this.onSelect});

  // Group events by category for better UX
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
          // Drag handle
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
                        final color = _PitchPainter._colorFor(type);
                        return GestureDetector(
                          onTap: () => onSelect(type),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: color.withValues(alpha: 0.35), width: 0.5),
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
//  FULL TIMELINE  MODAL  (history)
// =============================================================================

class _FullTimeline extends StatelessWidget {
  final List<MatchEventModel> events;
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
          // Handle
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
                      final color = _PitchPainter._colorFor(ev.type);
                      final isLast = i == events.length - 1;

                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Timeline spine
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
                                    child: Text("${ev.minute}'",
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

                            // Event card
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
                                          Text(ev.type,
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: color)),
                                          const SizedBox(height: 2),
                                          Text(ev.playerName,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary)),
                                        ],
                                      ),
                                    ),
                                    // Pitch zone indicator
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _zone(ev.pitchX),
                                          style: const TextStyle(
                                              fontSize: 9,
                                              color: AppColors.textMuted),
                                        ),
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

  /// Human-readable pitch zone from normalised X coordinate
  String _zone(double x) {
    if (x < 0.33) return 'Zona def.';
    if (x < 0.66) return 'Mediocamp.';
    return 'Zona of.';
  }
}
