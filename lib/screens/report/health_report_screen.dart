import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/alert_class.dart';
import '../../models/analysis_record.dart';
import '../../models/health_report.dart';
import '../../providers/report_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'report_detail_screen.dart';

class HealthReportScreen extends ConsumerWidget {
  const HealthReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportProvider);

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
      body: reports.isEmpty
          ? _EmptyState()
          : ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: reports.length,
              itemBuilder: (ctx, i) => _ReportTile(report: reports[i]),
            ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
            Text('No reports yet',
                style: AppTextStyles.h2, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Reports are created automatically when AI analyses run.\nOpen AI Monitor to start.',
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Report list tile (WPS/Word style) ─────────────────────────────────────

class _ReportTile extends ConsumerStatefulWidget {
  final HealthReport report;
  const _ReportTile({required this.report});

  @override
  ConsumerState<_ReportTile> createState() => _ReportTileState();
}

class _ReportTileState extends ConsumerState<_ReportTile> {
  Color _iconColor(List<AnalysisRecord> records) {
    if (records.isEmpty) return AppColors.primary;
    final hasEmergency = records
        .any((r) => r.prediction.alertClass == AlertClass.emergency);
    final hasWarn = records.any((r) =>
        r.prediction.alertClass == AlertClass.fallAlert ||
        r.prediction.alertClass == AlertClass.vitalsAlert);
    if (hasEmergency) return AppColors.danger;
    if (hasWarn) return AppColors.warning;
    return AppColors.success;
  }

  String _subtitle(List<AnalysisRecord> records) {
    final parts = widget.report.dayKey.split('-');
    final day = DateTime(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(day.year, day.month, day.day);

    final dateLabel = d == today
        ? 'Today'
        : d == yesterday
            ? 'Yesterday'
            : _fmtDate(day);

    final t = widget.report.createdAt;
    final h = t.hour, m = t.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    final timeStr = '$h12:$m $period';

    final count = records.length;
    final countLabel = count == 0
        ? 'No analyses'
        : '$count anal${count == 1 ? 'ysis' : 'yses'}';
    return '$dateLabel  ·  $timeStr  ·  $countLabel';
  }

  String _fmtDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  void _openDetail(List<AnalysisRecord> records) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportDetailScreen(
          report: widget.report,
          records: records,
        ),
      ),
    );
  }

  Future<void> _rename() async {
    final ctrl = TextEditingController(text: widget.report.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Rename Report', style: AppTextStyles.h2),
        content: TextField(
          controller: ctrl,
          autofocus: true,
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
                style:
                    AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      ref.read(reportProvider.notifier).rename(widget.report.id, result);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Report', style: AppTextStyles.h2),
        content: Text(
          'Delete "${widget.report.name}" and all its analysis records? This cannot be undone after the undo window.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style:
                    AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
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

    final deleted = await ref
        .read(reportProvider.notifier)
        .delete(widget.report.id);
    final report = widget.report;

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${report.name}" deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              ref
                  .read(reportProvider.notifier)
                  .restore(report, deleted);
            },
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(reportProvider.notifier).recordsFor(widget.report);
    final color = _iconColor(records);

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: AppColors.bgWhite,
        child: InkWell(
          onTap: () => _openDetail(records),
          borderRadius: BorderRadius.circular(0),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Document icon
                Container(
                  width: 44,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: color.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Stack(
                    children: [
                      // Folded corner decoration
                      Positioned(
                        top: 0,
                        right: 0,
                        child: CustomPaint(
                          size: const Size(10, 10),
                          painter: _FoldedCornerPainter(color: color),
                        ),
                      ),
                      Center(
                        child: Icon(Icons.favorite_rounded,
                            color: color, size: 20),
                      ),
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
                        widget.report.name,
                        style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _subtitle(records),
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Three-dot menu
                PopupMenuButton<_MenuAction>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: AppColors.textSecondary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onSelected: (action) async {
                    switch (action) {
                      case _MenuAction.open:
                        _openDetail(records);
                      case _MenuAction.rename:
                        await _rename();
                      case _MenuAction.share:
                        _openDetail(records); // detail screen has share
                      case _MenuAction.delete:
                        await _delete();
                    }
                  },
                  itemBuilder: (_) => [
                    _menuItem(_MenuAction.open, Icons.open_in_new_rounded,
                        'Open'),
                    _menuItem(_MenuAction.share,
                        Icons.share_outlined, 'Share / Export PDF'),
                    _menuItem(_MenuAction.rename,
                        Icons.drive_file_rename_outline_rounded, 'Rename'),
                    _menuItem(_MenuAction.delete,
                        Icons.delete_outline_rounded, 'Delete',
                        color: AppColors.danger),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<_MenuAction> _menuItem(
    _MenuAction action,
    IconData icon,
    String label, {
    Color color = AppColors.textPrimary,
  }) {
    return PopupMenuItem<_MenuAction>(
      value: action,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(label,
              style: AppTextStyles.body.copyWith(color: color)),
        ],
      ),
    );
  }
}

enum _MenuAction { open, share, rename, delete }

// ── Folded corner painter (document icon decoration) ──────────────────────

class _FoldedCornerPainter extends CustomPainter {
  final Color color;
  const _FoldedCornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_FoldedCornerPainter old) => old.color != color;
}
