import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/realtime_database_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'attendant_patient_chat_screen.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _guardianAuthUidProvider = StreamProvider.autoDispose<String>((ref) =>
    FirebaseAuth.instance.authStateChanges().map((u) => u?.uid ?? ''));

// Source 1: patient roster — available as soon as a link is created.
// Populated by the patient (on setup) or the guardian (on auto-link at login).
// guardian_patients/{guardianUid}/{patientUid} — never empty after first link.
final _rosterProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
        (ref, uid) => uid.isEmpty
            ? Stream.value([])
            : RealtimeDatabaseService.watchGuardianPatients(uid));

// Source 2: vitals overlay — keyed by patientUid.
// Only populated after patient pushes vitals from analysis/BLE.
final _vitalsMapProvider =
    StreamProvider.family<Map<String, Map<String, dynamic>>, String>(
        (ref, uid) => uid.isEmpty
            ? Stream.value({})
            : RealtimeDatabaseService.watchGuardianFeedAsMap(uid));

// ── Tab ──────────────────────────────────────────────────────────────────────

class AttendantDashboardTab extends ConsumerWidget {
  const AttendantDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(_guardianAuthUidProvider).valueOrNull ?? '';

    // Source 1: patient names/ids — always present after linking.
    final rosterAsync = ref.watch(_rosterProvider(uid));
    final roster = rosterAsync.valueOrNull ?? [];

    // Source 2: vitals map keyed by patientUid — populated after analysis.
    final vitalsMap = ref.watch(_vitalsMapProvider(uid)).valueOrNull ?? {};

    // Merge: for each known patient, overlay their latest vitals if available.
    final patients = roster.map((p) {
      final pUid = p['patient_uid'] as String? ?? '';
      final vitals = vitalsMap[pUid] ?? {};
      return {...p, ...vitals};
    }).toList();

    final isLoading = rosterAsync.isLoading;

    return Container(
      color: const Color(0xFFF0F4F8),
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // ── Section header ───────────────────────────────────────────
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
                // ── Patient cards or empty state ─────────────────────────────
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
                          'Ask your patient to add you as a guardian\nusing your registered email address.',
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
                        final patientUid = p['patient_uid'] as String? ?? '';
                        final patientName = p['patient_name'] as String? ?? 'Patient';
                        return _PatientCard(
                          patientUid: patientUid,
                          patientName: patientName,
                          vitals: p,
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
    );
  }
}

// ── Patient card ─────────────────────────────────────────────────────────────

class _PatientCard extends StatelessWidget {
  final String patientUid;
  final String patientName;
  final Map<String, dynamic> vitals;
  final VoidCallback onChat;

  const _PatientCard({
    required this.patientUid,
    required this.patientName,
    required this.vitals,
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
  Widget build(BuildContext context) {
    // vitals come from RTDB guardian_feeds — fields are pushed by the patient.
    final v = vitals;
    final hasData = v['heart_rate'] != null;

    final status = v['health_status'] as String? ?? 'Normal';
    final score  = (v['health_score'] as num?)?.toDouble() ?? 0;
    final hr     = (v['heart_rate'] as num?)?.toDouble();
    final spo2   = (v['spo2'] as num?)?.toDouble();
    final hrv    = (v['hrv'] as num?)?.toDouble();
    final rr     = (v['rr'] as num?)?.toDouble();
    // RTDB stores updated_at as epoch milliseconds (int).
    final updatedMs = v['updated_at'] as int?;
    final updated = updatedMs != null
        ? DateTime.fromMillisecondsSinceEpoch(updatedMs)
        : null;
    final ago = updated == null ? '' : _ago(updated);
    final sc  = hasData ? _statusColor(status) : AppColors.accentTint;

    return _CardShell(
      patientName: patientName,
      onChat: onChat,
      statusColor: hasData ? sc : null,
      statusIcon: hasData ? _statusIcon(status) : null,
      statusLabel: hasData ? status : null,
      child: Column(
        children: [
          // Health score bar
          Row(
            children: [
              Text('Health Score',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
              const Spacer(),
              Text(hasData ? '${score.toStringAsFixed(0)}%' : '--',
                  style: AppTextStyles.body.copyWith(
                      color: sc, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: hasData ? score / 100 : 0,
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
              _VitalChip('HR', hr != null ? '${hr.toStringAsFixed(0)} bpm' : '--'),
              _VitalChip('SpO₂', spo2 != null ? '${spo2.toStringAsFixed(0)}%' : '--'),
              _VitalChip('HRV', hrv != null ? '${hrv.toStringAsFixed(0)} ms' : '--'),
              _VitalChip('RR', rr != null ? '${rr.toStringAsFixed(0)}/m' : '--'),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              ago.isNotEmpty ? 'Updated $ago' : 'No readings yet',
              style: AppTextStyles.caption
                  .copyWith(fontSize: 10, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
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
