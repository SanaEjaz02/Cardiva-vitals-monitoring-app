import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/atoms/pill_widget.dart';
import '../../router/app_router.dart';

class AlertSentScreen extends StatefulWidget {
  const AlertSentScreen({super.key});

  @override
  State<AlertSentScreen> createState() => _AlertSentScreenState();
}

class _AlertSentScreenState extends State<AlertSentScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkController;
  late Animation<double> _checkScale;
  bool _smsExpanded = false;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _checkScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.elasticOut),
    );
    _checkController.forward();
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 48),
              // Check circle
              AnimatedBuilder(
                animation: _checkScale,
                builder: (_, __) => Transform.scale(
                  scale: _checkScale.value,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.success, width: 2),
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: AppColors.success, size: 48),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Alert Sent', style: AppTextStyles.h1),
              const SizedBox(height: 8),
              Text(
                'Your emergency contacts and attendants have been notified.',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Contact cards
              _ContactAlertCard(
                  initial: 'A', name: 'Ayesha Khan', phone: '+92-333-1234567'),
              const SizedBox(height: 12),
              _ContactAlertCard(
                  initial: 'M', name: 'Dr. M. Tariq', phone: '+92-301-9876543'),
              const SizedBox(height: 24),
              // SMS preview
              _SmsPreviewRow(
                expanded: _smsExpanded,
                onToggle: () =>
                    setState(() => _smsExpanded = !_smsExpanded),
              ),
              const SizedBox(height: 32),
              // Return button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRouter.dashboard,
                    (_) => false,
                  ),
                  child: const Text('Return to Dashboard'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Mark as false alarm',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.danger),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactAlertCard extends StatelessWidget {
  final String initial;
  final String name;
  final String phone;

  const _ContactAlertCard({
    required this.initial,
    required this.name,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowSm, blurRadius: 12, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primaryBg,
            child: Text(initial,
                style:
                    AppTextStyles.h2.copyWith(color: AppColors.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.h2),
                Text(phone, style: AppTextStyles.caption),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PillWidget('SMS Sent', variant: PillVariant.success),
              const SizedBox(height: 4),
              Text(timeStr, style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmsPreviewRow extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;

  const _SmsPreviewRow({required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowSm, blurRadius: 12, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Text('View message sent', style: AppTextStyles.body),
                  const Spacer(),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 220),
                    turns: expanded ? 0.25 : 0,
                    child: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'EMERGENCY: Sarah may need help.\n'
                'Trigger: Fall detected.\n'
                'Location: 31.5°N, 74.3°E — Lahore.\n'
                'Time: ${TimeOfDay.now().format(context)}.\n'
                'Please respond immediately. — Sent by Cardiva.',
                style: AppTextStyles.caption.copyWith(
                  fontFamily: 'monospace',
                  height: 1.6,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
