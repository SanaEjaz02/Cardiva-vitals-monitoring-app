import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_navigator.dart';
import '../../engine/emergency_trigger.dart';
import '../../engine/health_status_engine.dart';
import '../../models/vital_reading.dart';
import '../../providers/user_provider.dart';
import '../../providers/vital_provider.dart';
import '../../services/link_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class EmergencyPopup extends ConsumerStatefulWidget {
  final String triggerType; // fall | lowSpo2 | highHr | manual
  const EmergencyPopup({
    super.key,
    required this.triggerType,
  });

  static Future<void> show(BuildContext context, String triggerType) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim, _) => EmergencyPopup(
        triggerType: triggerType,
      ),
      transitionBuilder: (ctx, anim, _, child) {
        return BackdropFilter(
          filter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.1 * anim.value),
            BlendMode.srcOver,
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: FadeTransition(opacity: anim, child: child),
          ),
        );
      },
    );
  }

  @override
  ConsumerState<EmergencyPopup> createState() => _EmergencyPopupState();
}

class _EmergencyPopupState extends ConsumerState<EmergencyPopup>
    with TickerProviderStateMixin {
  int _countdown = 25;
  Timer? _timer;
  bool _alertSent = false;
  bool _show1122 = false;

  // Loaded from SharedPreferences (user-scoped)
  List<_AlertContact> _contacts = [];

  late List<AnimationController> _ringControllers;

  String get _bodyText {
    switch (widget.triggerType) {
      case 'fall':
        return 'A fall has been detected.';
      case 'lowSpo2':
      case 'highHr':
        return 'Critical vitals detected.';
      case 'manual':
        return 'SOS activated.';
      default:
        return 'Emergency detected.';
    }
  }

  @override
  void initState() {
    super.initState();
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
    _loadContacts();
    _startCountdown();
  }

  Future<void> _loadContacts() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Load linked guardians from Firestore — they serve as the emergency recipients
    try {
      final guardians = await LinkService.guardianContactDetails(uid);
      final contacts = <_AlertContact>[];
      for (final g in guardians) {
        final phone = (g['phone'] as String? ?? '').trim();
        final name = g['name'] as String? ?? 'Guardian';
        if (phone.isNotEmpty) {
          contacts.add(_AlertContact(name: name, phone: phone));
        } else {
          // Include guardian even without phone so the "Will notify" card shows
          contacts.add(_AlertContact(name: name, phone: ''));
        }
      }
      if (mounted) setState(() => _contacts = contacts);
    } catch (_) {
      if (mounted) setState(() => _contacts = []);
    }
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 1) {
        t.cancel();
        _sendAlert();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _sendAlert() {
    _timer?.cancel();
    setState(() {
      _alertSent = true;
      _countdown = 0;
    });

    // Build a HealthEvent from the current live reading (or safe defaults).
    // fallDetected = true signals manual SOS / critical condition.
    final liveReading = ref.read(latestReadingProvider).valueOrNull;
    final reading = VitalReading(
      heartRate: liveReading?.heartRate ?? 75,
      spO2: liveReading?.spO2 ?? 98,
      hrv: liveReading?.hrv ?? 40,
      respirationRate: liveReading?.respirationRate ?? 16,
      activity: liveReading?.activity ?? ActivityType.resting,
      fallDetected: widget.triggerType == 'fall' || liveReading?.fallDetected == true,
    );
    final event = HealthStatusEngine.analyze(reading);

    final user = ref.read(userProvider);
    final userName = user?.name ??
        FirebaseAuth.instance.currentUser?.displayName ?? 'Patient';

    // Delegates SMS, in-app chat, RTDB push, and local notification to
    // EmergencyTrigger — same path as the AI analysis emergency flow.
    EmergencyTrigger.handle(
      event: event,
      userName: userName,
      userPhone: user?.phone ?? '',
      userId: user?.id ??
          FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
      force: true, // manual SOS always sends regardless of cooldown
    ).catchError((_) {});

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _show1122 = true);
    });
  }

  void _cancel() {
    _timer?.cancel();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Alert cancelled.', style: AppTextStyles.body),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.of(context).pop();
  }

  void _openChat() {
    // Signal MainNavScreen to switch to the chat tab BEFORE popping,
    // so the listener fires while the screen is still fully mounted.
    mainNavTabNotifier.value = 3;
    // popUntil clears the dialog AND any screens pushed on top of MainNavScreen
    // (e.g. PredictionResultScreen, VitalsAiScreen) so the user lands cleanly
    // on the chat tab without seeing intermediate screens.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ringControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.bgWhite,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadowLg,
                  blurRadius: 40,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulse rings
                SizedBox(
                  height: 120,
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
                                width: 80 + t * 40,
                                height: 80 + t * 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppColors.danger, width: 2),
                                ),
                              ),
                            );
                          },
                        );
                      }),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: AppColors.dangerBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.warning_rounded,
                            color: AppColors.danger, size: 36),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text('Emergency Detected',
                    style:
                        AppTextStyles.h1.copyWith(color: AppColors.danger)),
                const SizedBox(height: 8),
                Text(_bodyText,
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                // Countdown or sent state
                if (!_alertSent) ...[
                  _AnimatedCountdown(seconds: _countdown),
                  Text('seconds remaining', style: AppTextStyles.caption),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.success, size: 24),
                      const SizedBox(width: 8),
                      Text('Alert Sent',
                          style: AppTextStyles.h2
                              .copyWith(color: AppColors.success)),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                // 1122 prompt
                if (_show1122 && _alertSent) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Nearest guardian is 23 minutes away. Call 1122 emergency services?',
                      style:
                          AppTextStyles.body.copyWith(color: AppColors.danger),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger),
                      onPressed: () async {
                        final uri = Uri.parse('tel:1122');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                      child: const Text('Call 1122 Now'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.danger),
                        foregroundColor: AppColors.danger,
                      ),
                      onPressed: _openChat,
                      child: const Text('Open Cardiva Chat'),
                    ),
                  ),
                ] else if (!_alertSent) ...[
                  // Action buttons
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.danger),
                        foregroundColor: AppColors.danger,
                      ),
                      onPressed: _cancel,
                      child: const Text("Cancel — I'm Okay"),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger),
                      onPressed: _sendAlert,
                      child: const Text('Send Alert Now'),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success),
                      onPressed: _openChat,
                      child: const Text('OK — Open Chat'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Dismiss',
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // Will notify card — shows real contacts
                _buildNotifyCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotifyCard() {
    if (_contacts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No guardian linked yet. Add a guardian in Settings → Attendants to receive in-app alerts.',
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ),
      );
    }

    final primary = _contacts.first;
    final extra = _contacts.length - 1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primaryBg,
            child: Text(
              primary.name.isNotEmpty ? primary.name[0].toUpperCase() : '?',
              style: AppTextStyles.body.copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Will notify via Cardiva Chat:',
                    style: AppTextStyles.caption),
                Text(primary.name, style: AppTextStyles.h2),
                Text('In-app message',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.primary)),
                if (extra > 0)
                  Text(
                    '+$extra more guardian${extra > 1 ? 's' : ''}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.primary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertContact {
  final String name;
  final String phone;
  const _AlertContact({required this.name, required this.phone});
}

class _AnimatedCountdown extends StatefulWidget {
  final int seconds;
  const _AnimatedCountdown({required this.seconds});

  @override
  State<_AnimatedCountdown> createState() => _AnimatedCountdownState();
}

class _AnimatedCountdownState extends State<_AnimatedCountdown>
    with SingleTickerProviderStateMixin {
  late AnimationController _tick;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _tick = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _tick, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(_AnimatedCountdown old) {
    super.didUpdateWidget(old);
    if (old.seconds != widget.seconds) {
      _tick.forward().then((_) => _tick.reverse());
    }
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.seconds;
    final mins = (s ~/ 60).toString().padLeft(2, '0');
    final secs = (s % 60).toString().padLeft(2, '0');
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Text(
          '$mins : $secs',
          style: AppTextStyles.numericDisplay
              .copyWith(color: AppColors.danger),
        ),
      ),
    );
  }
}
