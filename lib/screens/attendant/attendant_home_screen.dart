import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../models/in_app_message.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import '../../services/local_chat_db.dart';
import '../../services/messaging_service.dart';
import '../../theme/app_text_styles.dart';
import '../auth/auth_screen.dart';

// ── Provider ────────────────────────────────────────────────────────────────

final _patientAlertsProvider =
    StreamProvider.family<List<InAppMessage>, String>((ref, patientUid) {
  return MessagingService.alertStream(patientUid);
});

// ── Screen ──────────────────────────────────────────────────────────────────

class AttendantHomeScreen extends ConsumerStatefulWidget {
  const AttendantHomeScreen({super.key});

  @override
  ConsumerState<AttendantHomeScreen> createState() =>
      _AttendantHomeScreenState();
}

class _AttendantHomeScreenState extends ConsumerState<AttendantHomeScreen> {
  final _patientIdCtrl = TextEditingController();
  bool _linking = false;

  @override
  void dispose() {
    _patientIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _linkPatient() async {
    final id = _patientIdCtrl.text.trim();
    if (id.isEmpty) return;
    setState(() => _linking = true);
    final profile = ref.read(userProvider)!;
    final updated = profile.copyWith(monitoredPatientId: id);
    ref.read(userProvider.notifier).updateProfile(updated);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _linking = false);
  }

  Future<void> _signOut() async {
    await LocalChatDb.instance.clearAll();
    await AuthService.signOut();
    if (!mounted) return;
    ref.read(userProvider.notifier).clearUser();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProvider);
    final patientId = profile?.monitoredPatientId;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: AppColors.bgWhite,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attendant Dashboard', style: AppTextStyles.h2),
            if (profile != null)
              Text(profile.name,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded,
                color: AppColors.textSecondary),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: patientId == null || patientId.isEmpty
          ? _LinkPatientView(
              ctrl: _patientIdCtrl,
              linking: _linking,
              onLink: _linkPatient,
            )
          : _AlertsView(patientId: patientId, onUnlink: () {
              final p = ref.read(userProvider)!;
              ref
                  .read(userProvider.notifier)
                  .updateProfile(p.copyWith(clearMonitoredPatientId: true));
            }),
    );
  }
}

// ── Link patient panel ───────────────────────────────────────────────────────

class _LinkPatientView extends StatelessWidget {
  final TextEditingController ctrl;
  final bool linking;
  final VoidCallback onLink;

  const _LinkPatientView({
    required this.ctrl,
    required this.linking,
    required this.onLink,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.link_rounded,
                  color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 20),
            Text('Link a Patient', style: AppTextStyles.h1),
            const SizedBox(height: 8),
            Text(
              'Enter the Patient ID shared by the patient.\nThe patient can find their ID in Settings → Patient ID.',
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            TextField(
              controller: ctrl,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                hintText: 'Paste Patient ID here',
                hintStyle: AppTextStyles.caption
                    .copyWith(color: AppColors.accentTint),
                prefixIcon: const Icon(Icons.person_search_rounded,
                    color: AppColors.accentTint, size: 20),
                filled: true,
                fillColor: AppColors.bgWhite,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: linking ? null : onLink,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: linking
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text('Link Patient',
                        style: AppTextStyles.body.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Alerts list ──────────────────────────────────────────────────────────────

class _AlertsView extends ConsumerWidget {
  final String patientId;
  final VoidCallback onUnlink;

  const _AlertsView({required this.patientId, required this.onUnlink});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(_patientAlertsProvider(patientId));

    return alertsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  color: AppColors.accentTint, size: 48),
              const SizedBox(height: 12),
              Text('Could not load alerts.\nCheck your connection.',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
      data: (alerts) => Column(
        children: [
          // Patient ID bar
          Container(
            color: AppColors.bgWhite,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.person_pin_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Monitoring patient: ${patientId.substring(0, patientId.length.clamp(0, 12))}…',
                    style: AppTextStyles.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: onUnlink,
                  child: Text('Unlink',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.danger)),
                ),
              ],
            ),
          ),
          // Unread badge
          if (alerts.any((a) => !a.isRead)) ...[
            const SizedBox(height: 4),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${alerts.where((a) => !a.isRead).length} new alert(s)',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.danger),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () =>
                        MessagingService.markAllRead(patientId),
                    child: Text('Mark all read',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.primary)),
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: alerts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            color: AppColors.success, size: 56),
                        const SizedBox(height: 12),
                        Text('No alerts yet',
                            style: AppTextStyles.h2
                                .copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text('Patient is all clear.',
                            style: AppTextStyles.caption),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: alerts.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (_, i) =>
                        _AlertCard(alert: alerts[i], patientId: patientId),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Single alert card ────────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  final InAppMessage alert;
  final String patientId;

  const _AlertCard({required this.alert, required this.patientId});

  Color get _typeColor => switch (alert.type) {
        'fall'    => AppColors.danger,
        'lowSpo2' => const Color(0xFFE65100),
        'highHr'  => AppColors.danger,
        'manual'  => AppColors.danger,
        'report'  => AppColors.primary,
        _         => AppColors.textSecondary,
      };

  IconData get _typeIcon => switch (alert.type) {
        'fall'    => Icons.personal_injury_rounded,
        'lowSpo2' => Icons.water_drop_rounded,
        'highHr'  => Icons.favorite_rounded,
        'manual'  => Icons.sos_rounded,
        'report'  => Icons.description_rounded,
        _         => Icons.notifications_rounded,
      };

  String _timeAgo() {
    final diff = DateTime.now().difference(alert.timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!alert.isRead) {
          MessagingService.markRead(patientId, alert.id);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(16),
          border: alert.isRead
              ? null
              : Border.all(color: _typeColor.withValues(alpha: 0.4), width: 1),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowSm,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_typeIcon, color: _typeColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(alert.typeLabel,
                          style: AppTextStyles.h2
                              .copyWith(color: _typeColor)),
                      if (!alert.isRead) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _typeColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(alert.content,
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(_timeAgo(), style: AppTextStyles.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
