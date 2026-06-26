import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import '../../services/link_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class ScanQrScreen extends ConsumerStatefulWidget {
  const ScanQrScreen({super.key});

  @override
  ConsumerState<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends ConsumerState<ScanQrScreen> {
  final _controller = MobileScannerController();
  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final patientUid = barcode.rawValue!.trim();
    if (patientUid.isEmpty) return;

    setState(() => _processing = true);
    await _controller.stop();

    final myUid = AuthService.currentUser?.uid ?? '';
    final myName = ref.read(userProvider)?.name ?? 'Guardian';

    try {
      // Look up patient name from patients/{patientUid} document
      final patientName = await LinkService.getPatientName(patientUid);

      await LinkService.linkAttendantToPatient(
        patientUid: patientUid,
        patientName: patientName,
        attendantUid: myUid,
        attendantName: myName,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Linked to $patientName successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to link: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
      setState(() => _processing = false);
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Scan Patient QR'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Overlay
          CustomPaint(
            painter: _ScanOverlayPainter(),
            child: const SizedBox.expand(),
          ),
          // Bottom label
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (_processing)
                  const CircularProgressIndicator(color: Colors.white)
                else ...[
                  const Icon(Icons.qr_code_scanner_rounded,
                      color: Colors.white, size: 28),
                  const SizedBox(height: 12),
                  Text(
                    'Point camera at the patient\'s QR code',
                    style: AppTextStyles.body.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ask the patient to show their QR from the Profile tab',
                    style: AppTextStyles.caption
                        .copyWith(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cutSize = 260.0;
    final left  = (size.width - cutSize) / 2;
    final top   = (size.height - cutSize) / 2;
    final rect  = Rect.fromLTWH(left, top, cutSize, cutSize);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));

    final paint = Paint()..color = Colors.black54;
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);

    // Corner accent lines
    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 32.0;
    final r = rect;

    // TL
    canvas.drawLine(Offset(r.left, r.top + len), Offset(r.left, r.top), linePaint);
    canvas.drawLine(Offset(r.left, r.top), Offset(r.left + len, r.top), linePaint);
    // TR
    canvas.drawLine(Offset(r.right - len, r.top), Offset(r.right, r.top), linePaint);
    canvas.drawLine(Offset(r.right, r.top), Offset(r.right, r.top + len), linePaint);
    // BL
    canvas.drawLine(Offset(r.left, r.bottom - len), Offset(r.left, r.bottom), linePaint);
    canvas.drawLine(Offset(r.left, r.bottom), Offset(r.left + len, r.bottom), linePaint);
    // BR
    canvas.drawLine(Offset(r.right - len, r.bottom), Offset(r.right, r.bottom), linePaint);
    canvas.drawLine(Offset(r.right, r.bottom - len), Offset(r.right, r.bottom), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
