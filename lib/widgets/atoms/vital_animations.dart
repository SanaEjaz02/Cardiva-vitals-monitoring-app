import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SpO₂  –  pulsing blood-drop with O₂ text and ripple  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class Spo2AnimWidget extends StatefulWidget {
  final Color color;
  final double size;
  const Spo2AnimWidget({super.key, required this.color, this.size = 54});

  @override
  State<Spo2AnimWidget> createState() => _Spo2AnimWidgetState();
}

class _Spo2AnimWidgetState extends State<Spo2AnimWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _Spo2Painter(
            Curves.easeInOut.transform(_ctrl.value),
            widget.color,
          ),
        ),
      ),
    );
  }
}

class _Spo2Painter extends CustomPainter {
  final double t;
  final Color color;
  _Spo2Painter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final r = w * 0.21;
    final dropCy = h * 0.61;
    final tipY = h * 0.12;

    canvas.drawCircle(
      Offset(cx, dropCy),
      r * (1.05 + t * 0.75),
      Paint()
        ..color = color.withValues(alpha: (1 - t) * 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    final scale = 0.88 + 0.12 * t;
    canvas.save();
    canvas.translate(cx, dropCy);
    canvas.scale(scale);
    canvas.translate(-cx, -dropCy);

    final path = Path()
      ..moveTo(cx - r, dropCy)
      ..arcTo(Rect.fromCircle(center: Offset(cx, dropCy), radius: r),
          math.pi, -math.pi, false)
      ..quadraticBezierTo(cx + r * 0.52, dropCy - r * 0.98, cx, tipY)
      ..quadraticBezierTo(cx - r * 0.52, dropCy - r * 0.98, cx - r, dropCy)
      ..close();

    canvas.drawPath(path,
        Paint()
          ..color = color.withValues(alpha: 0.88)
          ..style = PaintingStyle.fill);

    final tp = TextPainter(
      text: TextSpan(
        text: 'O₂',
        style: TextStyle(
          color: Colors.white,
          fontSize: r * 0.90,
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, dropCy - tp.height * 0.52));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Spo2Painter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// HRV  –  animated R-R interval bar chart (heart-rate variability, not ECG)
// Each bar = one heartbeat interval; varying heights = the variability itself.
// A lit cursor sweeps bar-by-bar; a smooth curve connects the bar tops.
// ─────────────────────────────────────────────────────────────────────────────

class HrvAnimWidget extends StatefulWidget {
  final Color color;
  final double size;
  const HrvAnimWidget({super.key, required this.color, this.size = 54});

  @override
  State<HrvAnimWidget> createState() => _HrvAnimWidgetState();
}

class _HrvAnimWidgetState extends State<HrvAnimWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _RrBarPainter(_ctrl.value, widget.color),
        ),
      ),
    );
  }
}

class _RrBarPainter extends CustomPainter {
  final double t;
  final Color color;

  // 5 bars: R-R interval heights (shorter = faster beat, taller = longer interval)
  static const _rr = [0.54, 0.83, 0.61, 0.92, 0.70];

  _RrBarPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const n = 5;

    final padX = w * 0.07;
    final padTop = h * 0.09;
    final padBot = h * 0.14;
    final chartH = h - padTop - padBot;
    final totalW = w - 2 * padX;
    final slotW = totalW / n;
    final barW = slotW * 0.52;

    // Active bar index sweeps 0→n over [0..1]
    final rawIdx = t * n;
    final activeIdx = rawIdx.floor() % n;
    final barFrac = rawIdx - rawIdx.floor(); // progress within active bar (0..1)

    // ── mean dashed reference line ─────────────────────────────────────────
    final mean = _rr.fold(0.0, (s, v) => s + v) / n;
    final refY = padTop + chartH * (1 - mean);
    const dashLen = 3.0;
    const dashGap = 2.5;
    var dx = padX;
    while (dx < w - padX) {
      canvas.drawLine(
        Offset(dx, refY),
        Offset(math.min(dx + dashLen, w - padX), refY),
        Paint()
          ..color = color.withValues(alpha: 0.18)
          ..strokeWidth = 0.9,
      );
      dx += dashLen + dashGap;
    }

    // ── smooth connecting curve through bar tops ───────────────────────────
    final topOffsets = List.generate(n, (i) {
      final x = padX + i * slotW + barW / 2;
      final y = padTop + chartH * (1 - _rr[i]);
      return Offset(x, y);
    });
    if (topOffsets.length >= 2) {
      final curvePath = Path()..moveTo(topOffsets[0].dx, topOffsets[0].dy);
      for (int i = 1; i < topOffsets.length; i++) {
        final prev = topOffsets[i - 1];
        final curr = topOffsets[i];
        final cpX = (prev.dx + curr.dx) / 2;
        curvePath.cubicTo(cpX, prev.dy, cpX, curr.dy, curr.dx, curr.dy);
      }
      canvas.drawPath(
        curvePath,
        Paint()
          ..color = color.withValues(alpha: 0.28)
          ..strokeWidth = 1.1
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // ── bars ──────────────────────────────────────────────────────────────
    for (int i = 0; i < n; i++) {
      final isActive = i == activeIdx;
      // Active bar grows slightly on its beat
      final heightMul = isActive
          ? 1.0 + math.sin(barFrac * math.pi) * 0.06
          : 1.0;
      final barH = chartH * _rr[i] * heightMul;
      final x = padX + i * slotW;
      final y = h - padBot - barH;

      final alpha = isActive ? 1.0 : (i < activeIdx ? 0.45 : 0.20);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barW, barH),
          const Radius.circular(2.5),
        ),
        Paint()..color = color.withValues(alpha: alpha),
      );

      // Glowing cap on active bar
      if (isActive) {
        canvas.drawCircle(
          Offset(x + barW / 2, y),
          2.6,
          Paint()
            ..color = color
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
        );
        canvas.drawCircle(
          Offset(x + barW / 2, y),
          1.4,
          Paint()..color = Colors.white.withValues(alpha: 0.85),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RrBarPainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// Respiration  –  smooth capnography-style breathing wave
// Looks exactly like an ICU respiratory monitor trace.
// Half-rectified sine (hills above baseline) scrolls left; gradient fills
// the lung-volume area under each breath curve.
// ─────────────────────────────────────────────────────────────────────────────

class LungsAnimWidget extends StatefulWidget {
  final Color color;
  final double size;
  const LungsAnimWidget({super.key, required this.color, this.size = 54});

  @override
  State<LungsAnimWidget> createState() => _LungsAnimWidgetState();
}

class _LungsAnimWidgetState extends State<LungsAnimWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _BreathingWavePainter(_ctrl.value, widget.color),
        ),
      ),
    );
  }
}

class _BreathingWavePainter extends CustomPainter {
  final double t;
  final Color color;
  _BreathingWavePainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Capnography: hills above a flat baseline. Each hill = one exhaled breath.
    const freq = 1.4;         // cycles visible across the canvas width
    final baseline = h * 0.80;
    final amp = h * 0.58;     // full range from baseline to peak

    const steps = 64;

    final wavePath = Path();
    final fillPath = Path()..moveTo(0, baseline);

    for (int i = 0; i <= steps; i++) {
      final xf = i / steps;
      final x = xf * w;
      final phase = (xf * freq - t) * 2 * math.pi;
      // Half-rectified sine: only positive lobes form the hills
      final yOff = amp * math.max(0.0, math.sin(phase));
      final y = baseline - yOff;

      if (i == 0) {
        wavePath.moveTo(x, y);
      } else {
        wavePath.lineTo(x, y);
      }
      fillPath.lineTo(x, y);
    }
    fillPath.lineTo(w, baseline);
    fillPath.close();

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, w, h));

    // Gradient fill under the wave (lung-volume area)
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.30),
            color.withValues(alpha: 0.04),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Wave stroke
    canvas.drawPath(
      wavePath,
      Paint()
        ..color = color.withValues(alpha: 0.92)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Live dot riding the rightmost visible point of the wave
    final dotPhase = (1.0 * freq - t) * 2 * math.pi;
    final dotY = baseline - amp * math.max(0.0, math.sin(dotPhase));
    // Glow
    canvas.drawCircle(
      Offset(w * 0.93, dotY),
      4.5,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
    );
    // Core
    canvas.drawCircle(Offset(w * 0.93, dotY), 2.2,
        Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset(w * 0.93, dotY),
      2.2,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BreathingWavePainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity  –  Apple Watch-style activity ring with activity icon inside
// The ring arc fills to a state-appropriate target, holds, then resets.
// Speed & fill-target differ for Walking / Running / Resting.
// ─────────────────────────────────────────────────────────────────────────────

class ActivityAnimWidget extends StatefulWidget {
  final Color color;
  final double size;
  final String activityState;
  const ActivityAnimWidget({
    super.key,
    required this.color,
    this.size = 54,
    this.activityState = 'Walking',
  });

  @override
  State<ActivityAnimWidget> createState() => _ActivityAnimWidgetState();
}

class _ActivityAnimWidgetState extends State<ActivityAnimWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    final ms = widget.activityState.toLowerCase() == 'running'
        ? 1500
        : widget.activityState.toLowerCase() == 'resting'
            ? 4200
            : 2400;
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ms),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  IconData _icon() {
    switch (widget.activityState.toLowerCase()) {
      case 'running':
        return Icons.directions_run_rounded;
      case 'resting':
        return Icons.self_improvement_rounded;
      default:
        return Icons.directions_walk_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ActivityRingPainter(
                  _ctrl.value,
                  widget.color,
                  widget.activityState,
                ),
              ),
            ),
            Icon(
              _icon(),
              color: widget.color,
              size: widget.size * 0.31,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityRingPainter extends CustomPainter {
  final double t;
  final Color color;
  final String state;
  _ActivityRingPainter(this.t, this.color, this.state);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r = math.min(w, h) * 0.41;
    final sw = math.min(w, h) * 0.092;

    // Target fill fraction per state
    final target = state.toLowerCase() == 'running'
        ? 0.93
        : state.toLowerCase() == 'resting'
            ? 0.30
            : 0.78;

    // Background ring
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = color.withValues(alpha: 0.13)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw,
    );

    // Animated progress: fill → hold → empty
    double progress;
    if (t < 0.62) {
      progress = Curves.easeInOut.transform(t / 0.62) * target;
    } else if (t < 0.80) {
      progress = target;
    } else {
      progress = target * Curves.easeIn.transform(1 - (t - 0.80) / 0.20);
    }

    if (progress > 0.005) {
      // Main arc
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round,
      );

      // Glowing white tip at arc end
      final tipAngle = -math.pi / 2 + 2 * math.pi * progress;
      final tipX = cx + r * math.cos(tipAngle);
      final tipY = cy + r * math.sin(tipAngle);
      canvas.drawCircle(
        Offset(tipX, tipY),
        sw * 0.38,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.80)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }
  }

  @override
  bool shouldRepaint(_ActivityRingPainter old) => old.t != t || old.state != state;
}

// ─────────────────────────────────────────────────────────────────────────────
// Shield  –  digital security scan: sweep line reveals secure fill,
// then a checkmark strokes itself in, holds, fades, repeats.
// ─────────────────────────────────────────────────────────────────────────────

class ShieldAnimWidget extends StatefulWidget {
  final Color color;
  final double size;
  const ShieldAnimWidget({super.key, required this.color, this.size = 54});

  @override
  State<ShieldAnimWidget> createState() => _ShieldAnimWidgetState();
}

class _ShieldAnimWidgetState extends State<ShieldAnimWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _ScanShieldPainter(_ctrl.value, widget.color),
        ),
      ),
    );
  }
}

class _ScanShieldPainter extends CustomPainter {
  final double t;
  final Color color;
  _ScanShieldPainter(this.t, this.color);

  Path _shieldPath(double w, double h) {
    final cx = w / 2;
    final top = h * 0.07;
    final bot = h * 0.93;
    final left = w * 0.12;
    final right = w * 0.88;
    return Path()
      ..moveTo(cx, top)
      ..lineTo(right, top + h * 0.13)
      ..lineTo(right, h * 0.50)
      ..cubicTo(right, h * 0.76, cx + w * 0.13, h * 0.87, cx, bot)
      ..cubicTo(cx - w * 0.13, h * 0.87, left, h * 0.76, left, h * 0.50)
      ..lineTo(left, top + h * 0.13)
      ..close();
  }

  void _drawCheckmark(Canvas canvas, Size size, double progress, double alpha) {
    if (progress <= 0) return;
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    final p0 = Offset(cx - w * 0.19, cy + h * 0.04);
    final p1 = Offset(cx - w * 0.03, cy + h * 0.17);
    final p2 = Offset(cx + w * 0.21, cy - h * 0.11);

    final seg1 = (p1 - p0).distance;
    final seg2 = (p2 - p1).distance;
    final total = seg1 + seg2;
    final drawn = (progress * total).clamp(0.0, total);

    final ck = Path();
    if (drawn <= seg1) {
      final f = seg1 > 0 ? drawn / seg1 : 0.0;
      ck.moveTo(p0.dx, p0.dy);
      ck.lineTo(p0.dx + (p1.dx - p0.dx) * f, p0.dy + (p1.dy - p0.dy) * f);
    } else {
      final f = seg2 > 0 ? (drawn - seg1) / seg2 : 0.0;
      ck.moveTo(p0.dx, p0.dy);
      ck.lineTo(p1.dx, p1.dy);
      ck.lineTo(p1.dx + (p2.dx - p1.dx) * f, p1.dy + (p2.dy - p1.dy) * f);
    }

    canvas.drawPath(
      ck,
      Paint()
        ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0))
        ..strokeWidth = 2.3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shield = _shieldPath(w, h);

    // Always draw shield outline
    canvas.drawPath(
      shield,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // ── Phase 1: scan line descends  (t 0.00 → 0.48) ──────────────────────
    if (t < 0.48) {
      final sp = Curves.linear.transform(t / 0.48);
      final top = h * 0.07;
      final bot = h * 0.93;
      final scanY = top + (bot - top) * sp;

      // Revealed fill (above scan line)
      canvas.save();
      canvas.clipPath(shield);
      canvas.clipRect(Rect.fromLTWH(0, 0, w, scanY));
      canvas.drawPath(
        shield,
        Paint()
          ..color = color.withValues(alpha: 0.16)
          ..style = PaintingStyle.fill,
      );
      canvas.restore();

      // Scan line glow
      canvas.save();
      canvas.clipPath(shield);
      canvas.drawLine(
        Offset(w * 0.12, scanY),
        Offset(w * 0.88, scanY),
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
      );
      // Sharp line on top of glow
      canvas.drawLine(
        Offset(w * 0.12, scanY),
        Offset(w * 0.88, scanY),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.60)
          ..strokeWidth = 0.8,
      );
      canvas.restore();
    }

    // ── Phase 2: checkmark strokes in  (t 0.48 → 0.72) ────────────────────
    else if (t < 0.72) {
      canvas.save();
      canvas.clipPath(shield);
      canvas.drawPath(shield,
          Paint()
            ..color = color.withValues(alpha: 0.16)
            ..style = PaintingStyle.fill);
      canvas.restore();

      final cp = Curves.easeOut.transform((t - 0.48) / 0.24);
      _drawCheckmark(canvas, size, cp, 1.0);
    }

    // ── Phase 3: hold  (t 0.72 → 0.88) ────────────────────────────────────
    else if (t < 0.88) {
      canvas.save();
      canvas.clipPath(shield);
      canvas.drawPath(shield,
          Paint()
            ..color = color.withValues(alpha: 0.16)
            ..style = PaintingStyle.fill);
      canvas.restore();
      _drawCheckmark(canvas, size, 1.0, 1.0);
    }

    // ── Phase 4: fade out  (t 0.88 → 1.00) ────────────────────────────────
    else {
      final fade = 1.0 - (t - 0.88) / 0.12;
      canvas.save();
      canvas.clipPath(shield);
      canvas.drawPath(shield,
          Paint()
            ..color = color.withValues(alpha: 0.16 * fade)
            ..style = PaintingStyle.fill);
      canvas.restore();
      _drawCheckmark(canvas, size, 1.0, fade);
    }
  }

  @override
  bool shouldRepaint(_ScanShieldPainter old) => old.t != t;
}
