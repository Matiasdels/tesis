import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/models.dart';

abstract class PitchEventColors {
  static Color colorFor(String type) {
    return switch (type) {
      EventTypes.passOk => AppColors.accent,
      EventTypes.passKey => AppColors.accent,
      EventTypes.passBad => AppColors.danger,
      EventTypes.shot => AppColors.warning,
      EventTypes.goal => const Color(0xFFFFEB3B),
      EventTypes.goalRival => AppColors.danger,
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
}

class MatchPitchView extends StatelessWidget {
  final List<EventoPartidoModel> events;
  final Offset? pendingTap;
  final double width;
  final double height;
  final bool showEventDots;
  final bool showHeatMap;

  const MatchPitchView({
    super.key,
    required this.events,
    required this.width,
    required this.height,
    this.pendingTap,
    this.showEventDots = true,
    this.showHeatMap = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: MatchPitchPainter(
        events: events,
        pendingTap: pendingTap,
        showEventDots: showEventDots,
        showHeatMap: showHeatMap,
      ),
    );
  }
}

class MatchPitchPainter extends CustomPainter {
  final List<EventoPartidoModel> events;
  final Offset? pendingTap;
  final bool showEventDots;
  final bool showHeatMap;

  const MatchPitchPainter({
    required this.events,
    this.pendingTap,
    this.showEventDots = true,
    this.showHeatMap = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _drawPitch(canvas, w, h);
    if (showHeatMap) _drawHeatMap(canvas, w, h);
    if (showEventDots) _drawEventDots(canvas, w, h);
    if (pendingTap != null) _drawPendingDot(canvas, w, h);
  }

  void _drawPitch(Canvas canvas, double w, double h) {
    const nStripes = 8;
    for (var i = 0; i < nStripes; i++) {
      final y = i * h / nStripes;
      canvas.drawRect(
        Rect.fromLTWH(0, y, w, h / nStripes),
        Paint()
          ..color = i.isEven ? AppColors.pitchGreen : AppColors.pitchGreenAlt,
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

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(padH, padV, w - padH, h - padV),
        const Radius.circular(3),
      ),
      lp,
    );

    lp.strokeWidth = 0.8;
    canvas.drawLine(Offset(padH, h / 2), Offset(w - padH, h / 2), lp);
    canvas.drawCircle(Offset(w / 2, h / 2), innerW * 0.15, lp);
    canvas.drawCircle(
      Offset(w / 2, h / 2),
      3,
      Paint()..color = AppColors.pitchLine,
    );

    final paW = innerW * 0.59;
    final paD = halfH * 0.31;
    final gaW = innerW * 0.27;
    final gaD = halfH * 0.105;
    final goalW = innerW * 0.18;
    const goalH = 10.0;
    final arcR = halfH * 0.22;

    final paL = (w - paW) / 2;
    final paR = paL + paW;
    final gaL = (w - gaW) / 2;
    final gaR = gaL + gaW;
    final goalL = (w - goalW) / 2;
    final goalR = goalL + goalW;

    final paTopBot = padV + paD;
    final topSpotY = padV + halfH * 0.21;

    canvas.drawRect(
      Rect.fromLTRB(paL, padV, paR, paTopBot),
      lp..strokeWidth = 1.0,
    );
    canvas.drawRect(
      Rect.fromLTRB(gaL, padV, gaR, padV + gaD),
      lp..strokeWidth = 0.7,
    );
    canvas.drawRect(
      Rect.fromLTRB(goalL, padV - goalH, goalR, padV),
      lp..strokeWidth = 1.2,
    );
    canvas.drawCircle(
      Offset(w / 2, topSpotY),
      2,
      Paint()..color = AppColors.pitchLine,
    );

    final topRatio = (paTopBot - topSpotY).clamp(-arcR, arcR) / arcR;
    final topStart = math.asin(topRatio);
    final topSweep = math.pi - 2 * topStart;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w / 2, topSpotY),
        width: arcR * 2,
        height: arcR * 2,
      ),
      topStart,
      topSweep,
      false,
      lp..strokeWidth = 0.7,
    );

    final paBotTop = h - padV - paD;
    final botSpotY = h - padV - halfH * 0.21;

    canvas.drawRect(
      Rect.fromLTRB(paL, paBotTop, paR, h - padV),
      lp..strokeWidth = 1.0,
    );
    canvas.drawRect(
      Rect.fromLTRB(gaL, h - padV - gaD, gaR, h - padV),
      lp..strokeWidth = 0.7,
    );
    canvas.drawRect(
      Rect.fromLTRB(goalL, h - padV, goalR, h - padV + goalH),
      lp..strokeWidth = 1.2,
    );
    canvas.drawCircle(
      Offset(w / 2, botSpotY),
      2,
      Paint()..color = AppColors.pitchLine,
    );

    final botRatio = (botSpotY - paBotTop).clamp(-arcR, arcR) / arcR;
    final botArcSin = math.asin(botRatio);
    final botStart = math.pi + botArcSin;
    final botSweep = math.pi - 2 * botArcSin;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w / 2, botSpotY),
        width: arcR * 2,
        height: arcR * 2,
      ),
      botStart,
      botSweep,
      false,
      lp..strokeWidth = 0.7,
    );

    const cR = 7.0;
    for (final (cx, cy, start) in [
      (padH, padV, 0.0),
      (w - padH, padV, math.pi / 2),
      (padH, h - padV, -math.pi / 2),
      (w - padH, h - padV, math.pi),
    ]) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, cy), width: cR * 2, height: cR * 2),
        start,
        math.pi / 2,
        false,
        lp..strokeWidth = 0.8,
      );
    }
  }

  void _drawHeatMap(Canvas canvas, double w, double h) {
    if (events.isEmpty) return;

    final points = events
        .map((event) => Offset(event.pitchX.clamp(0, 1) * w,
            event.pitchY.clamp(0, 1) * h))
        .toList();

    const cols = 38;
    const rows = 58;
    final cellW = w / cols;
    final cellH = h / rows;
    final radius = math.min(w, h) * 0.18;
    final sigma = radius * 0.45;
    final values = List<double>.filled(cols * rows, 0);
    var maxDensity = 0.0;

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final center = Offset((col + 0.5) * cellW, (row + 0.5) * cellH);
        var density = 0.0;
        for (final point in points) {
          final distance = (center - point).distance;
          if (distance > radius) continue;
          density += math.exp(-(distance * distance) / (2 * sigma * sigma));
        }
        values[row * cols + col] = density;
        if (density > maxDensity) maxDensity = density;
      }
    }

    if (maxDensity <= 0) return;

    final heatPaint = Paint()..style = PaintingStyle.fill;
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final intensity = values[row * cols + col] / maxDensity;
        if (intensity < 0.08) continue;
        heatPaint.color = _heatColor(intensity);
        canvas.drawRect(
          Rect.fromLTWH(col * cellW, row * cellH, cellW + 1, cellH + 1),
          heatPaint,
        );
      }
    }
  }

  Color _heatColor(double intensity) {
    final value = intensity.clamp(0.0, 1.0);
    final color = value < 0.35
        ? Color.lerp(
            const Color(0xFF16A34A),
            const Color(0xFFFFEB3B),
            value / 0.35,
          )!
        : value < 0.7
            ? Color.lerp(
                const Color(0xFFFFEB3B),
                const Color(0xFFF97316),
                (value - 0.35) / 0.35,
              )!
            : Color.lerp(
                const Color(0xFFF97316),
                const Color(0xFFDC2626),
                (value - 0.7) / 0.3,
              )!;
    return color.withValues(alpha: 0.12 + value * 0.5);
  }

  void _drawEventDots(Canvas canvas, double w, double h) {
    for (final ev in events) {
      final px = ev.pitchX * w;
      final py = ev.pitchY * h;
      final color = PitchEventColors.colorFor(ev.tipoEventoNombre);
      _drawDot(canvas, Offset(px, py), color);
    }
  }

  void _drawPendingDot(Canvas canvas, double w, double h) {
    final px = pendingTap!.dx * w;
    final py = pendingTap!.dy * h;
    canvas.drawCircle(
      Offset(px, py),
      12,
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
    canvas.drawCircle(
      Offset(px, py),
      5,
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
  }

  void _drawDot(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(
      center,
      10,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      center,
      4.5,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
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
  bool shouldRepaint(MatchPitchPainter old) =>
      old.events != events ||
      old.pendingTap != pendingTap ||
      old.showEventDots != showEventDots ||
      old.showHeatMap != showHeatMap;
}
