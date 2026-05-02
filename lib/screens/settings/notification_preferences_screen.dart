import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  // Local-only preferences (not yet persisted in settingsProvider)
  bool _dailySummary = true;
  bool _soundEnabled = true;
  bool _vibration = true;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Notification Preferences', style: AppTextStyles.h1),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // ── Critical alerts ────────────────────────────────────────
            _SectionHeader('Critical Alerts'),
            _Card(children: [
              _ToggleRow(
                icon: Icons.warning_rounded,
                iconColor: AppColors.danger,
                label: 'Emergency Alerts',
                subtitle: 'Notify contacts when an emergency is detected',
                value: settings.emergencyAlertsEnabled,
                onChanged: notifier.setEmergencyAlerts,
              ),
              const _Divider(),
              _ToggleRow(
                icon: Icons.favorite_rounded,
                iconColor: AppColors.warning,
                label: 'Warning Vitals',
                subtitle:
                    'Alert when readings enter the warning range',
                value: settings.warningAlertsEnabled,
                onChanged: notifier.setWarningAlerts,
              ),
            ]),

            const SizedBox(height: 16),

            // ── Health updates ─────────────────────────────────────────
            _SectionHeader('Health Updates'),
            _Card(children: [
              _ToggleRow(
                icon: Icons.monitor_heart_outlined,
                iconColor: AppColors.primary,
                label: 'Live Monitoring Updates',
                subtitle: 'Notify when device connects or disconnects',
                value: settings.vitalMonitoringEnabled,
                onChanged: notifier.setVitalMonitoring,
              ),
              const _Divider(),
              _ToggleRow(
                icon: Icons.summarize_outlined,
                iconColor: AppColors.success,
                label: 'Daily Summary',
                subtitle: 'Receive a daily health score digest at 8 PM',
                value: _dailySummary,
                onChanged: (v) => setState(() => _dailySummary = v),
              ),
            ]),

            const SizedBox(height: 16),

            // ── Sound & haptics ────────────────────────────────────────
            _SectionHeader('Sound & Haptics'),
            _Card(children: [
              _ToggleRow(
                icon: Icons.volume_up_outlined,
                iconColor: AppColors.primary,
                label: 'Notification Sound',
                subtitle: 'Play a sound for incoming alerts',
                value: _soundEnabled,
                onChanged: (v) => setState(() => _soundEnabled = v),
              ),
              const _Divider(),
              _ToggleRow(
                icon: Icons.vibration_rounded,
                iconColor: AppColors.primary,
                label: 'Vibration',
                subtitle: 'Vibrate for critical and warning alerts',
                value: _vibration,
                onChanged: (v) => setState(() => _vibration = v),
              ),
            ]),

            const SizedBox(height: 16),

            // Info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Emergency alerts are always delivered regardless of '
                      'Do Not Disturb settings to ensure your safety.',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: AppTextStyles.caption
              .copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowSm,
              blurRadius: 12,
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const Divider(
      height: 1, indent: 64, endIndent: 16, color: AppColors.divider);
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.body),
                const SizedBox(height: 1),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
