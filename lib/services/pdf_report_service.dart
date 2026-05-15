import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/alert_class.dart';
import '../models/analysis_record.dart';
import '../providers/analysis_provider.dart';

class PdfReportService {
  PdfReportService._();

  static const _blue = PdfColor.fromInt(0xFF0077B6);
  static const _green = PdfColor.fromInt(0xFF10B981);
  static const _amber = PdfColor.fromInt(0xFFF59E0B);
  static const _red = PdfColor.fromInt(0xFFEF4444);

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Generates the PDF, saves it to the temp directory, and returns the File.
  static Future<File> generate({
    required DailySummary summary,
    required List<AnalysisRecord> records,
    String? patientName,
    String? gender,
    int? age,
    double? heightCm,
    double? weightKg,
    double? bmi,
  }) async {
    final doc = pw.Document();
    final now = DateTime.now();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 40),
        header: (_) => _buildHeader(now),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          _patientSection(patientName, gender, age, heightCm, weightKg, bmi),
          pw.SizedBox(height: 14),
          _scoreSection(summary),
          pw.SizedBox(height: 14),
          _aiSummarySection(summary),
          pw.SizedBox(height: 14),
          _breakdownSection(summary),
          pw.SizedBox(height: 14),
          _vitalsSection(summary),
          pw.SizedBox(height: 14),
          _timelineSection(records),
        ],
      ),
    );

    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final file = File('${dir.path}/cardiva_report_$stamp.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Opens the system share sheet for an already-generated PDF file.
  static Future<void> shareFile(File file) async {
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Cardiva Daily Health Report',
      text: 'Please find my Cardiva health report attached.',
    );
  }

  /// Generates the PDF and opens the system share sheet (WhatsApp, email, etc.).
  static Future<void> shareViaSheet({
    required DailySummary summary,
    required List<AnalysisRecord> records,
    String? patientName,
    String? gender,
    int? age,
    double? heightCm,
    double? weightKg,
    double? bmi,
  }) async {
    final file = await generate(
      summary: summary,
      records: records,
      patientName: patientName,
      gender: gender,
      age: age,
      heightCm: heightCm,
      weightKg: weightKg,
      bmi: bmi,
    );
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Cardiva Daily Health Report',
      text: 'Please find my Cardiva health report attached.',
    );
  }

  /// Opens WhatsApp directly with a formatted text summary (no PDF).
  static Future<bool> shareTextToWhatsApp(
      DailySummary s, {String? name}) async {
    final text = _buildWhatsAppText(s, name: name);
    final encoded = Uri.encodeComponent(text);
    final uri = Uri.parse('https://wa.me/?text=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  // ── WhatsApp text builder ─────────────────────────────────────────────────

  static String _buildWhatsAppText(DailySummary s, {String? name}) {
    final now = DateTime.now();
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final dateStr = '${months[now.month - 1]} ${now.day}, ${now.year}';
    final nameStr =
        (name != null && name.trim().isNotEmpty) ? name.trim() : 'Patient';

    return '*Cardiva Health Report — $dateStr*\n\n'
        '*Patient:* $nameStr\n'
        '*Health Score:* ${s.healthScore}/100\n\n'
        '${s.summaryText}\n\n'
        '*Today\'s Analyses:* ${s.totalAnalyses}\n'
        '  ✅ Normal: ${s.normalCount}\n'
        '  ⚠️ Warnings: ${s.warningCount}\n'
        '  🚨 Emergency: ${s.emergencyCount}\n\n'
        '*Average Vitals:*\n'
        '  • Heart Rate: ${s.avgHr.toStringAsFixed(0)} bpm\n'
        '  • SpO2: ${s.avgSpo2.toStringAsFixed(1)}%\n'
        '  • HRV: ${s.avgHrv.toStringAsFixed(0)} ms\n'
        '  • Respiration: ${s.avgRr.toStringAsFixed(0)}/min\n\n'
        '_Sent from Cardiva Health Monitor_';
  }

  // ── PDF section builders ──────────────────────────────────────────────────

  static pw.Widget _buildHeader(DateTime date) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'CARDIVA',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: _blue,
              ),
            ),
            pw.Text(
              'Health Report  ·  ${months[date.month - 1]} ${date.day}, ${date.year}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Divider(color: _blue, thickness: 1.5),
        pw.SizedBox(height: 8),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Generated by Cardiva AI',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _patientSection(String? name, String? gender, int? age,
      double? heightCm, double? weightKg, double? bmi) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFEBF8FF),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Patient Information',
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _infoChip('Name', name ?? 'Patient'),
              pw.SizedBox(width: 20),
              _infoChip('Gender', gender ?? '—'),
              pw.SizedBox(width: 20),
              _infoChip('Age', age != null ? '$age yrs' : '—'),
              pw.SizedBox(width: 20),
              _infoChip(
                  'Height', heightCm != null ? '${heightCm.toStringAsFixed(0)} cm' : '—'),
              pw.SizedBox(width: 20),
              _infoChip(
                  'Weight', weightKg != null ? '${weightKg.toStringAsFixed(1)} kg' : '—'),
              pw.SizedBox(width: 20),
              _infoChip('BMI', bmi != null ? bmi.toStringAsFixed(1) : '—'),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoChip(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style:
                pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _scoreSection(DailySummary s) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _blue,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Health Score',
              style: pw.TextStyle(color: PdfColors.white, fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text('${s.healthScore} / 100',
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(
            '${s.totalAnalyses} analyses today  ·  '
            '${s.normalCount} normal  ·  '
            '${s.warningCount} warnings  ·  '
            '${s.emergencyCount} emergency',
            style: pw.TextStyle(
                color: const PdfColor.fromInt(0xCCFFFFFF), fontSize: 9),
          ),
        ],
      ),
    );
  }

  static pw.Widget _aiSummarySection(DailySummary s) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('AI Summary',
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(s.summaryText,
              style:
                  pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
        ],
      ),
    );
  }

  static pw.Widget _breakdownSection(DailySummary s) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Analysis Breakdown',
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          _barRow('Normal', s.normalCount, s.totalAnalyses, _green),
          pw.SizedBox(height: 6),
          _barRow('Warning', s.warningCount, s.totalAnalyses, _amber),
          pw.SizedBox(height: 6),
          _barRow('Emergency', s.emergencyCount, s.totalAnalyses, _red),
        ],
      ),
    );
  }

  static pw.Widget _barRow(
      String label, int count, int total, PdfColor color) {
    final pct = total > 0 ? count / total : 0.0;
    final filled = (pct * 100).round().clamp(0, 100);
    final empty = (100 - filled).clamp(0, 100);

    return pw.Row(
      children: [
        pw.SizedBox(
          width: 68,
          child: pw.Text(label,
              style: pw.TextStyle(fontSize: 9)),
        ),
        pw.Expanded(
          child: pw.Row(
            children: [
              if (filled > 0)
                pw.Expanded(
                  flex: filled,
                  child: pw.Container(height: 9, color: color),
                ),
              if (empty > 0)
                pw.Expanded(
                  flex: empty,
                  child:
                      pw.Container(height: 9, color: PdfColors.grey200),
                ),
            ],
          ),
        ),
        pw.SizedBox(width: 8),
        pw.SizedBox(
          width: 70,
          child: pw.Text(
            '${(pct * 100).round()}%  ($count)',
            style: pw.TextStyle(
                fontSize: 8,
                color: color,
                fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    );
  }

  static pw.Widget _vitalsSection(DailySummary s) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Average Vitals Today',
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _vitalCol('Heart Rate', '${s.avgHr.toStringAsFixed(0)} bpm'),
              _vitalCol('SpO2', '${s.avgSpo2.toStringAsFixed(1)}%'),
              _vitalCol('HRV', '${s.avgHrv.toStringAsFixed(0)} ms'),
              _vitalCol('Resp. Rate', '${s.avgRr.toStringAsFixed(0)}/min'),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _vitalCol(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(label,
            style:
                pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.SizedBox(height: 3),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _blue)),
      ],
    );
  }

  static pw.Widget _timelineSection(List<AnalysisRecord> records) {
    if (records.isEmpty) return pw.SizedBox();

    final shown = records.reversed.take(20).toList();

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Analysis Timeline',
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table(
            columnWidths: {
              0: const pw.FixedColumnWidth(55),
              1: const pw.FixedColumnWidth(85),
              2: const pw.FlexColumnWidth(),
            },
            children: [
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  _cell('Time', bold: true),
                  _cell('Status', bold: true),
                  _cell('Vitals', bold: true),
                ],
              ),
              ...shown.map((r) {
                final ac = r.prediction.alertClass;
                final c = switch (ac) {
                  AlertClass.emergency => _red,
                  AlertClass.fallAlert ||
                  AlertClass.vitalsAlert =>
                    _amber,
                  AlertClass.normal => _green,
                };
                return pw.TableRow(
                  children: [
                    _cell(_fmtTime(r.timestamp)),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 4, horizontal: 4),
                      child: pw.Text(ac.label,
                          style: pw.TextStyle(
                              fontSize: 8,
                              color: c,
                              fontWeight: pw.FontWeight.bold)),
                    ),
                    _cell(
                      'HR ${r.heartRate.toStringAsFixed(0)}  '
                      'SpO2 ${r.spo2.toStringAsFixed(0)}%  '
                      'HRV ${r.hrv.toStringAsFixed(0)} ms',
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 8,
              fontWeight:
                  bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }

  static String _fmtTime(DateTime t) {
    final h = t.hour;
    final m = t.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m $period';
  }
}
