import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// Run this once to generate app icons:
//   flutter test test/generate_icon_test.dart
// Then apply them:
//   dart run flutter_launcher_icons

void main() {
  testWidgets('generate_app_icons', (WidgetTester tester) async {
    await _saveIcon(tester, const _FullIcon(), 'assets/icon/app_icon.png');
    await _saveIcon(tester, const _ForegroundIcon(), 'assets/icon/app_icon_foreground.png', transparent: true);
    // ignore: avoid_print
    print('\n✅  Icons saved to assets/icon/ — now run: dart run flutter_launcher_icons\n');
  });
}

Future<void> _saveIcon(
  WidgetTester tester,
  Widget child,
  String path, {
  bool transparent = false,
}) async {
  final key = GlobalKey();

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: key,
        child: SizedBox(width: 1024, height: 1024, child: child),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

// ── Full icon: blue gradient + white ECG trace ────────────────────────────────

class _FullIcon extends StatelessWidget {
  const _FullIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0096C7), Color(0xFF023E8A)],
        ),
      ),
      child: const Center(
        child: CustomPaint(
          size: Size(780, 340),
          painter: _EcgPainter(color: Colors.white, strokeWidth: 36),
        ),
      ),
    );
  }
}

// ── Foreground only: transparent + white ECG (for adaptive icon) ──────────────

class _ForegroundIcon extends StatelessWidget {
  const _ForegroundIcon();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CustomPaint(
        size: Size(560, 240),
        painter: _EcgPainter(color: Colors.white, strokeWidth: 26),
      ),
    );
  }
}

// ── ECG trace painter ─────────────────────────────────────────────────────────

class _EcgPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _EcgPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    // ECG heartbeat trace
    final path = Path()
      ..moveTo(0, h * 0.55)
      ..lineTo(w * 0.14, h * 0.55)
      ..lineTo(w * 0.22, h * 0.38)
      ..lineTo(w * 0.30, h * 0.72)
      ..lineTo(w * 0.38, h * 0.02)   // sharp peak
      ..lineTo(w * 0.46, h * 0.90)
      ..lineTo(w * 0.54, h * 0.42)
      ..lineTo(w * 0.62, h * 0.55)
      ..lineTo(w, h * 0.55);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_EcgPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
