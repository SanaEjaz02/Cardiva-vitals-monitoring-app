import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/alert_class.dart';
import '../../models/analysis_record.dart';
import '../../models/health_report.dart';
import '../../providers/analysis_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/pdf_report_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'report_detail_screen.dart';

class HealthReportScreen extends ConsumerStatefulWidget {
  const HealthReportScreen({super.key});

  @override
  ConsumerState<HealthReportScreen> createState() => _HealthReportScreenState();
}

class _HealthReportScreenState extends ConsumerState<HealthReportScreen> {
  final _searchCtrl = TextEditingController();
  DateTime? _filterDate;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Delete (lives here so widget stays mounted for undo snackbar) ─────────

  Future<void> _deleteReport(HealthReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Report', style: AppTextStyles.h2),
        content: Text(
          'Delete "${report.name}" and all its analysis records?\nYou can undo for 6 seconds.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Capture messenger BEFORE delete (tile widget will be removed)
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(reportProvider.notifier);

    final deleted = await notifier.delete(report.id);

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('"${report.name}" deleted'),
        backgroundColor: AppColors.textPrimary,
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.primary,
          onPressed: () => notifier.restore(report, deleted),
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  // ── Rename ────────────────────────────────────────────────────────────────

  Future<void> _renameReport(HealthReport report) async {
    final ctrl = TextEditingController(text: report.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Rename Report', style: AppTextStyles.h2),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Report name',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      ref.read(reportProvider.notifier).rename(report.id, result);
    }
  }

  // ── Calendar date picker ──────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _filterDate = picked);
    }
  }

  // ── Filtering ─────────────────────────────────────────────────────────────

  List<HealthReport> _filtered(List<HealthReport> all) {
    var list = all;
    if (_filterDate != null) {
      final dk =
          '${_filterDate!.year}-${_filterDate!.month.toString().padLeft(2, '0')}-${_filterDate!.day.toString().padLeft(2, '0')}';
      list = list.where((r) => r.dayKey == dk).toList();
    }
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((r) =>
              r.name.toLowerCase().contains(q) || r.dayKey.contains(q))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(reportProvider);
    final filtered = _filtered(all);

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: AppColors.bgWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Health Reports', style: AppTextStyles.h1),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Search + Calendar bar ─────────────────────────────────────────
          Container(
            color: AppColors.bgWhite,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search reports…',
                      hintStyle: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 18, color: AppColors.textSecondary),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.bgLight,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Calendar filter
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _filterDate != null
                          ? AppColors.primaryBg
                          : AppColors.bgLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.calendar_month_rounded,
                      size: 20,
                      color: _filterDate != null
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                if (_filterDate != null) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() => _filterDate = null),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.bgLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.filter_alt_off_rounded,
                          size: 20, color: AppColors.danger),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // ── Active date filter chip ───────────────────────────────────────
          if (_filterDate != null)
            Container(
              color: AppColors.bgWhite,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text(
                  'Date: ${_fmtDate(_filterDate!)}',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.primary),
                ),
                backgroundColor: AppColors.primaryBg,
                deleteIcon: const Icon(Icons.close_rounded,
                    size: 14, color: AppColors.primary),
                onDeleted: () => setState(() => _filterDate = null),
              ),
            ),
          const Divider(height: 1, color: AppColors.divider),
          // ── Report list ───────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? _buildEmpty(all.isEmpty)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (ctx, i) => _ReportTile(
                      report: filtered[i],
                      onDelete: () => _deleteReport(filtered[i]),
                      onRename: () => _renameReport(filtered[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool noReports) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                  color: AppColors.primaryBg, shape: BoxShape.circle),
              child: const Icon(Icons.description_outlined,
                  color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              noReports ? 'No reports yet' : 'No reports match your search',
              style: AppTextStyles.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              noReports
                  ? 'Reports are created automatically when AI analyses run.\nOpen AI Monitor to start.'
                  : 'Try a different date or clear the search filter.',
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ── Report tile (WPS/Word style) ──────────────────────────────────────────

class _ReportTile extends ConsumerStatefulWidget {
  final HealthReport report;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const _ReportTile({
    required this.report,
    required this.onDelete,
    required this.onRename,
  });

  @override
  ConsumerState<_ReportTile> createState() => _ReportTileState();
}

class _ReportTileState extends ConsumerState<_ReportTile> {
  bool _downloading = false;

  HealthReport get report => widget.report;
  VoidCallback get onDelete => widget.onDelete;
  VoidCallback get onRename => widget.onRename;

  Color _iconColor(List<AnalysisRecord> records) {
    if (records.isEmpty) return AppColors.primary;
    final hasEmergency =
        records.any((r) => r.prediction.alertClass == AlertClass.emergency);
    final hasWarn = records.any((r) =>
        r.prediction.alertClass == AlertClass.fallAlert ||
        r.prediction.alertClass == AlertClass.vitalsAlert);
    if (hasEmergency) return AppColors.danger;
    if (hasWarn) return AppColors.warning;
    return AppColors.success;
  }

  String _subtitle(List<AnalysisRecord> records) {
    final parts = report.dayKey.split('-');
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
    final dateLabel = d == today
        ? 'Today'
        : d == yesterday
            ? 'Yesterday'
            : '${months[day.month - 1]} ${day.day}, ${day.year}';

    final t = report.createdAt;
    final h = t.hour;
    final m = t.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;

    final count = records.length;
    return '$dateLabel  ·  $h12:$m $period  ·  ${count == 0 ? 'No analyses' : '$count anal${count == 1 ? 'ysis' : 'yses'}'}';
  }

  void _open(BuildContext context, List<AnalysisRecord> records) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportDetailScreen(report: report, records: records),
      ),
    );
  }

  Future<void> _download(
      BuildContext context, List<AnalysisRecord> records) async {
    setState(() => _downloading = true);
    try {
      final user = ref.read(userProvider);
      final summary = buildSummaryFromRecords(records);
      final file = await PdfReportService.generate(
        summary: summary,
        records: records,
        patientName: user?.name,
        gender: user?.gender,
        age: user?.age,
        heightCm: user?.heightCm,
        weightKg: user?.weightKg,
        bmi: user?.bmi,
      );
      await PdfReportService.shareFile(file);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(reportProvider.notifier).recordsFor(report);
    final color = _iconColor(records);

    return Material(
      color: AppColors.bgWhite,
      child: InkWell(
        onTap: () => _open(context, records),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Document icon with folded corner
              SizedBox(
                width: 44,
                height: 50,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: color.withValues(alpha: 0.3), width: 1),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: CustomPaint(
                        size: const Size(10, 10),
                        painter: _FoldPainter(color: color),
                      ),
                    ),
                    Center(
                        child:
                            Icon(Icons.favorite_rounded, color: color, size: 20)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Name + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.name,
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _subtitle(records),
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Export & share PDF
              _downloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.download_outlined,
                          color: AppColors.primary, size: 22),
                      tooltip: 'Export & share PDF',
                      onPressed: () => _download(context, records),
                    ),
              // Three-dot menu
              PopupMenuButton<_Act>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppColors.textSecondary, size: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (act) {
                  switch (act) {
                    case _Act.open:
                      _open(context, records);
                    case _Act.share:
                      _open(context, records);
                    case _Act.rename:
                      onRename();
                    case _Act.delete:
                      onDelete();
                  }
                },
                itemBuilder: (_) => [
                  _item(_Act.open, Icons.open_in_new_rounded, 'Open'),
                  _item(_Act.share, Icons.share_outlined, 'Share / Export PDF'),
                  _item(_Act.rename,
                      Icons.drive_file_rename_outline_rounded, 'Rename'),
                  _item(_Act.delete, Icons.delete_outline_rounded, 'Delete',
                      color: AppColors.danger),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<_Act> _item(_Act act, IconData icon, String label,
      {Color color = AppColors.textPrimary}) {
    return PopupMenuItem<_Act>(
      value: act,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(label, style: AppTextStyles.body.copyWith(color: color)),
        ],
      ),
    );
  }
}

enum _Act { open, share, rename, delete }

class _FoldPainter extends CustomPainter {
  final Color color;
  const _FoldPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..close(),
      Paint()..color = color.withValues(alpha: 0.4),
    );
  }
  @override
  bool shouldRepaint(_FoldPainter old) => old.color != color;
}
