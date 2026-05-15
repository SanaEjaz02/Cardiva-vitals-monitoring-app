import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/alert_class.dart';
import '../../models/analysis_record.dart';
import '../../models/health_report.dart';
import '../../providers/analysis_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/user_provider.dart';
import '../../router/app_router.dart';
import '../../services/groq_service.dart';
import '../../services/pdf_report_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/atoms/ring_widget.dart';

class ReportDetailScreen extends ConsumerStatefulWidget {
  final HealthReport report;
  final List<AnalysisRecord> records;

  const ReportDetailScreen({
    super.key,
    required this.report,
    required this.records,
  });

  @override
  ConsumerState<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends ConsumerState<ReportDetailScreen> {
  bool _exporting = false;
  bool _sharingWA = false;
  String? _aiSummary;
  bool _loadingAi = true;

  DailySummary get _summary => buildSummaryFromRecords(widget.records);

  @override
  void initState() {
    super.initState();
    if (widget.records.isNotEmpty) _fetchAiSummary();
  }

  Future<void> _fetchAiSummary() async {
    final s = _summary;
    final prompt =
        'Summarize this patient\'s health report in 2–3 sentences for a '
        'non-medical audience. Be encouraging but honest.\n\n'
        'Report stats:\n'
        '• Total analyses: ${s.totalAnalyses}\n'
        '• Normal: ${s.normalCount}  |  Warnings: ${s.warningCount}  |  Emergencies: ${s.emergencyCount}\n'
        '• Avg Heart Rate: ${s.avgHr.toStringAsFixed(0)} bpm\n'
        '• Avg SpO₂: ${s.avgSpo2.toStringAsFixed(1)}%\n'
        '• Avg HRV: ${s.avgHrv.toStringAsFixed(0)} ms\n'
        '• Avg Respiration: ${s.avgRr.toStringAsFixed(0)} /min\n'
        '• Health Score: ${s.healthScore} / 100\n\n'
        'Keep it under 60 words. No bullet points, just plain text.';

    final result = await GroqService.ask(prompt, maxTokens: 150);
    if (mounted) setState(() { _aiSummary = result; _loadingAi = false; });
  }

  Future<void> _exportPdf() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final user = ref.read(userProvider);
      // Generate file, share, then upload to Storage in background
      final file = await PdfReportService.generate(
        summary: _summary,
        records: widget.records,
        patientName: user?.name,
        gender: user?.gender,
        age: user?.age,
        heightCm: user?.heightCm,
        weightKg: user?.weightKg,
        bmi: user?.bmi,
      );
      await PdfReportService.shareFile(file);
      // Upload to Storage and save URL so patient can re-download from any device
      StorageService.uploadReportPdf(widget.report.id, file).then((url) {
        if (url != null) {
          ref.read(reportProvider.notifier).updatePdfUrl(widget.report.id, url);
        }
      }).catchError((_) {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _shareToWhatsApp() async {
    setState(() => _sharingWA = true);
    try {
      final user = ref.read(userProvider);
      final sent = await PdfReportService.shareTextToWhatsApp(
        _summary,
        name: user?.name,
      );
      if (!sent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp not found on this device.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharingWA = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    final scoreColor = s.healthScore >= 80
        ? AppColors.success
        : s.healthScore >= 60
            ? AppColors.warning
            : AppColors.danger;

    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        backgroundColor: AppColors.bgWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.report.name,
            style: AppTextStyles.h1,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        centerTitle: true,
      ),
      body: widget.records.isEmpty
          ? _buildEmptyState()
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  _buildDateHeader(),
                  const SizedBox(height: 16),
                  _buildScoreHero(s, scoreColor),
                  const SizedBox(height: 16),
                  _buildAiSummary(s),
                  const SizedBox(height: 16),
                  _buildBreakdown(s),
                  const SizedBox(height: 16),
                  _buildAvgVitals(s, scoreColor),
                  const SizedBox(height: 16),
                  _buildTimeline(),
                  const SizedBox(height: 16),
                  _buildExportButtons(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart_rounded,
                color: AppColors.primary, size: 48),
            const SizedBox(height: 16),
            Text('No analyses in this report',
                style: AppTextStyles.h2, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Run an AI analysis from the AI Monitor screen to populate this report.',
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader() {
    final parts = widget.report.dayKey.split('-');
    final day = DateTime(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(day.year, day.month, day.day);

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateStr = d == today
        ? 'Today, ${months[day.month - 1]} ${day.day}, ${day.year}'
        : d == yesterday
            ? 'Yesterday, ${months[day.month - 1]} ${day.day}, ${day.year}'
            : '${months[day.month - 1]} ${day.day}, ${day.year}';

    return Row(
      children: [
        const Icon(Icons.calendar_today_rounded,
            size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(dateStr,
            style: AppTextStyles.caption
                .copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildScoreHero(DailySummary s, Color scoreColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          transform: GradientRotation(2.356),
          colors: [AppColors.primary, AppColors.primaryDeep],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowLg,
              blurRadius: 28,
              offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Health Score',
                    style: AppTextStyles.caption
                        .copyWith(color: Colors.white.withValues(alpha: 0.7))),
                const SizedBox(height: 4),
                Text('${s.healthScore} / 100',
                    style: AppTextStyles.numericDisplay
                        .copyWith(color: Colors.white, fontSize: 36)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _StatPill(
                        label: '${s.totalAnalyses} analyses',
                        icon: Icons.psychology_rounded),
                    _StatPill(
                        label: '${s.normalCount} normal',
                        icon: Icons.check_circle_outline_rounded),
                    if (s.warningCount > 0)
                      _StatPill(
                          label: '${s.warningCount} warnings',
                          icon: Icons.warning_amber_rounded),
                    if (s.emergencyCount > 0)
                      _StatPill(
                          label: '${s.emergencyCount} emergency',
                          icon: Icons.emergency_rounded),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                RingWidget(
                  percent: s.healthScore / 100,
                  color: scoreColor,
                  size: 64,
                  strokeWidth: 7,
                ),
                Text(
                  '${s.healthScore}',
                  style: AppTextStyles.caption.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiSummary(DailySummary s) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: Color(0xFF8B5CF6), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: _loadingAi
                    ? const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ShimmerLine(width: double.infinity),
                          SizedBox(height: 6),
                          _ShimmerLine(width: 220),
                          SizedBox(height: 6),
                          _ShimmerLine(width: 160),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_aiSummary ?? s.summaryText,
                              style: AppTextStyles.body),
                          const SizedBox(height: 6),
                          Text('Generated by Cardiva AI',
                              style: AppTextStyles.caption),
                        ],
                      ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8B5CF6),
                side: const BorderSide(color: Color(0xFF8B5CF6)),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final query =
                    'I have a health report with the following summary:\n'
                    '${_aiSummary ?? s.summaryText}\n\n'
                    'Full stats — Total analyses: ${s.totalAnalyses}, '
                    'Normal: ${s.normalCount}, Warnings: ${s.warningCount}, '
                    'Emergencies: ${s.emergencyCount}. '
                    'Avg HR: ${s.avgHr.toStringAsFixed(0)} bpm, '
                    'SpO₂: ${s.avgSpo2.toStringAsFixed(1)}%, '
                    'HRV: ${s.avgHrv.toStringAsFixed(0)} ms, '
                    'Respiration: ${s.avgRr.toStringAsFixed(0)}/min. '
                    'Health Score: ${s.healthScore}/100.\n\n'
                    'What should I focus on to improve my health?';
                Navigator.pushNamed(context, AppRouter.chat, arguments: query);
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
              label: const Text('Ask Cardiva AI about this report'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdown(DailySummary s) {
    final total = s.totalAnalyses;
    return _SectionCard(
      title: 'Analysis Breakdown',
      child: Column(
        children: [
          _BreakdownBar(
              label: 'Normal',
              count: s.normalCount,
              total: total,
              color: AppColors.success),
          const SizedBox(height: 8),
          _BreakdownBar(
              label: 'Warning',
              count: s.warningCount,
              total: total,
              color: AppColors.warning),
          const SizedBox(height: 8),
          _BreakdownBar(
              label: 'Emergency',
              count: s.emergencyCount,
              total: total,
              color: AppColors.danger),
        ],
      ),
    );
  }

  Widget _buildAvgVitals(DailySummary s, Color scoreColor) {
    return _SectionCard(
      title: 'Average Vitals',
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          _VitalTile(
              icon: Icons.favorite_rounded,
              label: 'Heart Rate',
              value: '${s.avgHr.toStringAsFixed(0)} bpm',
              color: _hrColor(s.avgHr)),
          _VitalTile(
              icon: Icons.air_rounded,
              label: 'SpO₂',
              value: '${s.avgSpo2.toStringAsFixed(1)}%',
              color: _spo2Color(s.avgSpo2)),
          _VitalTile(
              icon: Icons.timeline_rounded,
              label: 'HRV',
              value: '${s.avgHrv.toStringAsFixed(0)} ms',
              color: _hrvColor(s.avgHrv)),
          _VitalTile(
              icon: Icons.waves_rounded,
              label: 'Respiration',
              value: '${s.avgRr.toStringAsFixed(0)}/min',
              color: _rrColor(s.avgRr)),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    if (widget.records.isEmpty) return const SizedBox.shrink();
    final shown = widget.records.reversed.take(20).toList();
    return _SectionCard(
      title: 'Analysis Timeline',
      child: Column(
        children: shown.map((r) => _TimelineEntry(record: r)).toList(),
      ),
    );
  }

  Widget _buildExportButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _exporting ? null : _exportPdf,
                icon: _exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary))
                    : const Icon(Icons.picture_as_pdf_outlined, size: 17),
                label: Text(_exporting ? 'Generating…' : 'Export PDF'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _sharingWA ? null : _shareToWhatsApp,
                icon: _sharingWA
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.chat_rounded, size: 17),
                label: Text(_sharingWA ? 'Opening…' : 'WhatsApp'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _exporting ? null : _exportPdf,
            icon: const Icon(Icons.share_outlined, size: 17),
            label: const Text('Share Report (PDF)'),
          ),
        ),
      ],
    );
  }

  Color _hrColor(double v) {
    if (v < 40 || v > 150) return AppColors.danger;
    if (v < 60 || v > 100) return AppColors.warning;
    return AppColors.success;
  }

  Color _spo2Color(double v) {
    if (v < 90) return AppColors.danger;
    if (v < 95) return AppColors.warning;
    return AppColors.success;
  }

  Color _hrvColor(double v) {
    if (v < 20) return AppColors.danger;
    if (v < 50) return AppColors.warning;
    return AppColors.success;
  }

  Color _rrColor(double v) {
    if (v < 5 || v > 30) return AppColors.danger;
    if (v < 12 || v > 20) return AppColors.warning;
    return AppColors.success;
  }
}

// ── Reusable section widgets ───────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  const _SectionCard({this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: AppTextStyles.h2),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 4),
          ],
          child,
        ],
      ),
    );
  }
}

class _BreakdownBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;
  const _BreakdownBar(
      {required this.label,
      required this.count,
      required this.total,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Row(
      children: [
        SizedBox(
            width: 72, child: Text(label, style: AppTextStyles.caption)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 10,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            '${(pct * 100).round()}%',
            style: AppTextStyles.caption
                .copyWith(color: color, fontWeight: FontWeight.w600),
            textAlign: TextAlign.end,
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 22,
          child: Text('($count)',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}

class _VitalTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _VitalTile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: AppTextStyles.caption,
                    overflow: TextOverflow.ellipsis),
                Text(value,
                    style: AppTextStyles.body.copyWith(
                        color: color, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final AnalysisRecord record;
  const _TimelineEntry({required this.record});

  @override
  Widget build(BuildContext context) {
    final ac = record.prediction.alertClass;
    final color = switch (ac) {
      AlertClass.emergency => AppColors.danger,
      AlertClass.fallAlert || AlertClass.vitalsAlert => AppColors.warning,
      AlertClass.normal => AppColors.success,
    };
    final h = record.timestamp.hour;
    final m = record.timestamp.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text('$h12:$m $period',
                style: AppTextStyles.caption
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(ac.label,
                style: AppTextStyles.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 10)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'HR ${record.heartRate.toStringAsFixed(0)}  ·  SpO₂ ${record.spo2.toStringAsFixed(0)}%',
              style: AppTextStyles.caption,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final IconData icon;
  const _StatPill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Colors.white.withValues(alpha: 0.8)),
        const SizedBox(width: 4),
        Text(label,
            style: AppTextStyles.caption
                .copyWith(color: Colors.white.withValues(alpha: 0.85))),
      ],
    );
  }
}

class _ShimmerLine extends StatelessWidget {
  final double width;
  const _ShimmerLine({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 12,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
