import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/link_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'attendant_patient_chat_screen.dart';
import 'scan_qr_screen.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _guardianAuthUidProvider = StreamProvider.autoDispose<String>((ref) =>
    FirebaseAuth.instance.authStateChanges().map((u) => u?.uid ?? ''));

final _linkedPatientsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
        (ref, attendantUid) => LinkService.linkedPatientsStream(attendantUid));

final _patientVitalsProvider =
    StreamProvider.family<Map<String, dynamic>?, String>(
        (ref, patientUid) => LinkService.patientVitalsStream(patientUid));

// ── Tab ──────────────────────────────────────────────────────────────────────

class AttendantDashboardTab extends ConsumerWidget {
  const AttendantDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(_guardianAuthUidProvider).valueOrNull ?? '';
    final patientsAsync = ref.watch(_linkedPatientsProvider(uid));

    return Container(
      color: const Color(0xFFF0F4F8),
      child: patientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('Could not load patients')),
        data: (patients) => CustomScrollView(
          slivers: [
            // ── Scan QR hero card ──────────────────────────────────────────
            const SliverToBoxAdapter(child: _ScanQrHeroCard()),
            // ── Section header ─────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    const Icon(Icons.monitor_heart_rounded,
                        size: 16, color: AppColors.primaryDeep),
                    const SizedBox(width: 6),
                    Text('Monitored Patients',
                        style: AppTextStyles.h2.copyWith(
                            fontSize: 15, color: AppColors.primaryDeep)),
                    const Spacer(),
                    if (patients.isNotEmpty)
                      Text('${patients.length} linked',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
            // ── Patient cards or empty state ───────────────────────────────
            if (patients.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_search_rounded,
                        size: 56, color: AppColors.accentTint),
                    const SizedBox(height: 14),
                    Text('No patients linked yet',
                        style: AppTextStyles.h2
                            .copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Text(
                      'Tap "Scan Patient QR" above to\nstart monitoring a patient.',
                      style: AppTextStyles.caption,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                sliver: SliverList.separated(
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: patients.length,
                  itemBuilder: (ctx, i) {
                    final p = patients[i];
                    final patientUid = p['patient_uid'] as String;
                    final patientName =
                        p['patient_name'] as String? ?? 'Patient';
                    return _PatientCard(
                      patientUid: patientUid,
                      patientName: patientName,
                      onChat: () => Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) => AttendantPatientChatScreen(
                            patientUid: patientUid,
                            patientName: patientName,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Scan QR hero card (matches patient's dashboard hero card style) ────────────

class _ScanQrHeroCard extends StatelessWidget {
  const _ScanQrHeroCard();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ScanQrScreen()),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF050A2E), Color(0xFF0A2F5A), Color(0xFF0D4F78)],
            stops: [0.0, 0.55, 1.0],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
                color: AppColors.shadowLg,
                blurRadius: 16,
                offset: Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('GUARDIAN',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Scan Patient QR',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.2)),
                  const SizedBox(height: 6),
                  Text(
                    'Link a new patient to monitor\ntheir vitals in real-time.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                        height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_scanner_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Tap to Scan',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.qr_code_scanner_rounded,
              size: 88,
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Patient card ─────────────────────────────────────────────────────────────

class _PatientCard extends ConsumerWidget {
  final String patientUid;
  final String patientName;
  final VoidCallback onChat;

  const _PatientCard({
    required this.patientUid,
    required this.patientName,
    required this.onChat,
  });

  Color _statusColor(String? status) => switch (status) {
        'Emergency'    => AppColors.danger,
        'Fall Alert'   => AppColors.danger,
        'Vitals Alert' => AppColors.warning,
        _              => AppColors.success,
      };

  IconData _statusIcon(String? status) => switch (status) {
        'Emergency'    => Icons.emergency_rounded,
        'Fall Alert'   => Icons.personal_injury_rounded,
        'Vitals Alert' => Icons.warning_rounded,
        _              => Icons.check_circle_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vitalsAsync = ref.watch(_patientVitalsProvider(patientUid));

    return vitalsAsync.when(
      loading: () => _CardShell(
        patientName: patientName,
        onChat: onChat,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (_, __) => _CardShell(
        patientName: patientName,
        onChat: onChat,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('No data yet',
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        ),
      ),
      data: (v) {
        if (v == null) {
          return _CardShell(
            patientName: patientName,
            onChat: onChat,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Waiting for patient data…',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
            ),
          );
        }

        final status  = v['health_status'] as String? ?? 'Normal';
        final score   = (v['health_score'] as num?)?.toDouble() ?? 0;
        final hr      = (v['heart_rate'] as num?)?.toDouble() ?? 0;
        final spo2    = (v['spo2'] as num?)?.toDouble() ?? 0;
        final hrv     = (v['hrv'] as num?)?.toDouble() ?? 0;
        final rr      = (v['respiration_rate'] as num?)?.toDouble() ?? 0;
        final updated = (v['updated_at'] as dynamic)?.toDate() as DateTime?;
        final ago     = updated == null ? '' : _ago(updated);
        final sc      = _statusColor(status);

        return _CardShell(
          patientName: patientName,
          onChat: onChat,
          statusColor: sc,
          statusIcon: _statusIcon(status),
          statusLabel: status,
          child: Column(
            children: [
              // Health score bar
              Row(
                children: [
                  Text('Health Score',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary)),
                  const Spacer(),
                  Text('${score.toStringAsFixed(0)}%',
                      style: AppTextStyles.body
                          .copyWith(color: sc, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: score / 100,
                  backgroundColor: AppColors.bgLight,
                  color: sc,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 14),
              // Vitals row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _VitalChip('HR', '${hr.toStringAsFixed(0)} bpm'),
                  _VitalChip('SpO₂', '${spo2.toStringAsFixed(0)}%'),
                  _VitalChip('HRV', '${hrv.toStringAsFixed(0)} ms'),
                  _VitalChip('RR', '${rr.toStringAsFixed(0)}/m'),
                ],
              ),
              if (ago.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('Updated $ago',
                      style: AppTextStyles.caption
                          .copyWith(fontSize: 10, color: AppColors.textSecondary)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

class _CardShell extends StatelessWidget {
  final String patientName;
  final VoidCallback onChat;
  final Color? statusColor;
  final IconData? statusIcon;
  final String? statusLabel;
  final Widget child;

  const _CardShell({
    required this.patientName,
    required this.onChat,
    required this.child,
    this.statusColor,
    this.statusIcon,
    this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final sc = statusColor ?? AppColors.success;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowLg, blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryBg,
                child: Text(
                  patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
                  style: AppTextStyles.h2.copyWith(color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(patientName, style: AppTextStyles.h2),
              ),
              if (statusLabel != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sc.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: sc, size: 12),
                      const SizedBox(width: 4),
                      Text(statusLabel!,
                          style: AppTextStyles.caption.copyWith(
                              color: sc, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onChat,
                icon: const Icon(Icons.chat_rounded, color: AppColors.primary),
                tooltip: 'Chat',
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _VitalChip extends StatelessWidget {
  final String label;
  final String value;
  const _VitalChip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: AppTextStyles.body
                .copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
        Text(label,
            style: AppTextStyles.caption.copyWith(fontSize: 10)),
      ],
    );
  }
}
