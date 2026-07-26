import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/realtime_database_service.dart';
import '../../services/sos_alarm_service.dart';
import '../../theme/app_text_styles.dart';

/// Full-screen, unmissable SOS alarm shown on a guardian's device the moment
/// a patient's emergency alert arrives. Keeps ringing (loud looping siren +
/// haptic pulse) until the guardian explicitly acknowledges it.
class GuardianSosScreen extends StatefulWidget {
  final String notificationId;
  final String title;
  final String body;

  const GuardianSosScreen({
    super.key,
    required this.notificationId,
    required this.title,
    required this.body,
  });

  @override
  State<GuardianSosScreen> createState() => _GuardianSosScreenState();
}

class _GuardianSosScreenState extends State<GuardianSosScreen>
    with TickerProviderStateMixin {
  late final List<AnimationController> _ringControllers;
  Timer? _hapticTimer;

  @override
  void initState() {
    super.initState();
    SosAlarmService.start();
    _hapticTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      HapticFeedback.heavyImpact();
    });
    _ringControllers = List.generate(3, (i) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2),
      );
      Future.delayed(Duration(milliseconds: i * 600), () {
        if (mounted) ctrl.repeat();
      });
      return ctrl;
    });
  }

  @override
  void dispose() {
    SosAlarmService.stop();
    _hapticTimer?.cancel();
    for (final c in _ringControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _acknowledge() {
    RealtimeDatabaseService.markNotificationRead(widget.notificationId);
    Navigator.of(context).pop();
  }

  Future<void> _call1122() async {
    final uri = Uri.parse('tel:1122');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFF7F1D1D),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ...List.generate(3, (i) {
                        final ctrl = _ringControllers[i];
                        return AnimatedBuilder(
                          animation: ctrl,
                          builder: (_, __) {
                            final t = ctrl.value;
                            return Opacity(
                              opacity: (1 - t) * [1.0, 0.6, 0.3][i],
                              child: Container(
                                width: 120 + t * 60,
                                height: 120 + t * 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 3),
                                ),
                              ),
                            );
                          },
                        );
                      }),
                      Container(
                        width: 120,
                        height: 120,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.sos_rounded,
                            color: Color(0xFFDC2626), size: 60),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.title.isNotEmpty ? widget.title : 'SOS ALERT',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h1White()
                      .copyWith(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        widget.body,
                        style: AppTextStyles.bodyWhite()
                            .copyWith(height: 1.6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFDC2626),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _acknowledge,
                    child: Text(
                      "I've Seen This — Stop Alarm",
                      style: AppTextStyles.h2Color(const Color(0xFFDC2626)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white, width: 1.5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _call1122,
                    child: const Text('Call 1122 Emergency Services'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
