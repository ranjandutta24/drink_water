import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/water_settings.dart';
import '../utils/format.dart';
import 'report_service.dart';
import 'timeline_service.dart';

/// Builds the weekly / monthly report as a PDF, entirely on device.
///
/// The document is deliberately *not* themed from the app palette: a report gets
/// printed, emailed and read on other people's screens, so it is always the light
/// ink-on-paper version regardless of what the app itself looks like.
class PdfReportService {
  const PdfReportService._();

  static const PdfColor _ink = PdfColor.fromInt(0xFF1B2733);
  static const PdfColor _inkSoft = PdfColor.fromInt(0xFF6B7A8A);
  static const PdfColor _aqua = PdfColor.fromInt(0xFF2E9BC4);
  static const PdfColor _aquaWash = PdfColor.fromInt(0xFFE3F2F8);
  static const PdfColor _kelp = PdfColor.fromInt(0xFF3E9C74);
  static const PdfColor _clay = PdfColor.fromInt(0xFFC2724E);
  static const PdfColor _hairline = PdfColor.fromInt(0xFFDDE4EA);

  static Future<Uint8List> build({
    required PeriodReport report,
    required WaterSettings settings,
    List<AdherenceRow> adherence = const [],
    int currentStreak = 0,
  }) async {
    final theme = await _theme();
    final document = pw.Document(
      title: 'Hydration report — ${report.label}',
      creator: 'Drink Water',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 44, 40, 40),
        theme: theme,
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: _inkSoft),
          ),
        ),
        build: (context) => [
          _header(report),
          pw.SizedBox(height: 22),
          _summaryRow(report, settings, currentStreak),
          pw.SizedBox(height: 26),
          _sectionTitle('Daily intake'),
          pw.SizedBox(height: 12),
          _chart(report, settings),
          pw.SizedBox(height: 26),
          _sectionTitle('Day by day'),
          pw.SizedBox(height: 10),
          _dayTable(report, settings),
          if (adherence.isNotEmpty) ...[
            pw.SizedBox(height: 26),
            _sectionTitle('Medicines'),
            pw.SizedBox(height: 10),
            _adherenceTable(adherence),
          ],
        ],
      ),
    );

    return document.save();
  }

  /// Uses the app's own typeface when it can, so a shared report looks like it
  /// came from the app. Falls back to the built-in font rather than failing the
  /// export if the asset cannot be read.
  static Future<pw.ThemeData?> _theme() async {
    try {
      final regular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Play-Regular.ttf'),
      );
      final bold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Play-Bold.ttf'),
      );
      return pw.ThemeData.withFont(base: regular, bold: bold);
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _header(PeriodReport report) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Hydration report',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              '${report.label} · ${_range(report)}',
              style: const pw.TextStyle(fontSize: 11, color: _inkSoft),
            ),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            color: _aquaWash,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text(
            'Drink Water',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: _aqua,
            ),
          ),
        ),
      ],
    );
  }

  /// Heading above each block. A left rule rather than a bigger typeface, so the
  /// sections stay distinguishable in grayscale — these get printed.
  static pw.Widget _sectionTitle(String title) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(width: 3, height: 13, color: _aqua),
        pw.SizedBox(width: 7),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 12.5,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
      ],
    );
  }

  static String _range(PeriodReport report) {
    final start = report.start;
    final end = report.end;
    return '${start.day} ${monthShort(start)} – ${end.day} ${monthShort(end)} '
        '${end.year}';
  }

  static pw.Widget _summaryRow(
    PeriodReport report,
    WaterSettings settings,
    int streak,
  ) {
    final elapsed = report.daysElapsed;
    return pw.Row(
      children: [
        _figure('Total', formatVolume(report.totalMl, settings)),
        _figure('Daily average', formatVolume(report.averageMl, settings)),
        _figure(
          'Goal met',
          elapsed == 0 ? '—' : '${report.goalsMet} of $elapsed days',
        ),
        _figure(
          'Hit rate',
          elapsed == 0 ? '—' : '${(report.goalHitRate * 100).round()}%',
        ),
        _figure('Streak', streak == 0 ? '—' : '$streak days'),
      ],
    );
  }

  static pw.Widget _figure(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: const pw.TextStyle(
              fontSize: 7.5,
              color: _inkSoft,
              letterSpacing: 0.6,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12.5,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  /// Hand-drawn bars rather than a charting widget: one bar per day, scaled to
  /// whichever is taller — the best day or the goal — so the goal line always
  /// has somewhere to sit.
  static pw.Widget _chart(PeriodReport report, WaterSettings settings) {
    const height = 120.0;
    final ceiling = [
      report.peakMl,
      report.days.isEmpty ? 0 : report.days.first.goalMl,
      1,
    ].reduce((a, b) => a > b ? a : b);
    final goalMl = report.days.isEmpty ? 0 : report.days.first.goalMl;
    final goalFraction = goalMl <= 0 ? null : goalMl / ceiling;

    // A month of 31 bars needs thinner labels than a week of 7.
    final dense = report.days.length > 10;

    return pw.Column(
      children: [
        pw.Stack(
          children: [
            pw.Container(
              height: height,
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: _hairline)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  for (final day in report.days)
                    pw.Expanded(
                      child: pw.Padding(
                        padding: pw.EdgeInsets.symmetric(
                          horizontal: dense ? 0.7 : 3,
                        ),
                        child: pw.Container(
                          height: (day.totalMl / ceiling * height).clamp(
                            day.totalMl > 0 ? 1.5 : 0.0,
                            height,
                          ),
                          decoration: pw.BoxDecoration(
                            color: day.goalMet ? _kelp : _aqua,
                            borderRadius: const pw.BorderRadius.vertical(
                              top: pw.Radius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (goalFraction != null)
              pw.Positioned(
                left: 0,
                right: 0,
                bottom: goalFraction.clamp(0.0, 1.0) * height,
                child: pw.Container(height: 0.7, color: _clay),
              ),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Row(
          children: [
            for (final day in report.days)
              pw.Expanded(
                child: pw.Center(
                  child: pw.Text(
                    dense ? '${day.date.day}' : weekdayShort(day.date),
                    style: pw.TextStyle(
                      fontSize: dense ? 5.5 : 8,
                      color: _inkSoft,
                    ),
                  ),
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 8),
        if (goalFraction != null)
          pw.Row(
            children: [
              pw.Container(width: 14, height: 0.7, color: _clay),
              pw.SizedBox(width: 5),
              pw.Text(
                'Goal ${formatVolume(goalMl, settings)}',
                style: const pw.TextStyle(fontSize: 8, color: _inkSoft),
              ),
            ],
          ),
      ],
    );
  }

  static pw.Widget _dayTable(PeriodReport report, WaterSettings settings) {
    return _table(
      headers: const ['Date', 'Intake', 'Goal', 'Progress', ''],
      rows: [
        for (final day in report.days)
          [
            '${weekdayShort(day.date)} ${day.date.day} ${monthShort(day.date)}',
            formatVolume(day.totalMl, settings),
            day.goalMl <= 0 ? '—' : formatVolume(day.goalMl, settings),
            day.goalMl <= 0 ? '—' : '${(day.progress * 100).round()}%',
            day.goalMet ? 'Met' : '',
          ],
      ],
    );
  }

  static pw.Widget _adherenceTable(List<AdherenceRow> rows) {
    return _table(
      headers: const ['Medicine', 'Due', 'Taken', 'Skipped', 'Not logged'],
      rows: [
        for (final row in rows)
          [
            row.medicine.name,
            '${row.due}',
            row.due == 0
                ? '${row.taken}'
                : '${row.taken}  (${(row.rate * 100).round()}%)',
            '${row.skipped}',
            '${row.missed}',
          ],
      ],
    );
  }

  /// Built by hand out of [pw.Table] rather than the fromTextArray helper, whose
  /// name and home have moved between pdf releases.
  static pw.Widget _table({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    pw.Widget cell(String text, {required bool header, required bool first}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4.5),
        child: pw.Text(
          text,
          textAlign: first ? pw.TextAlign.left : pw.TextAlign.right,
          style: pw.TextStyle(
            fontSize: 9,
            color: header ? _inkSoft : _ink,
            fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    return pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _hairline, width: 0.5),
        bottom: pw.BorderSide(color: _hairline, width: 0.5),
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        for (var i = 1; i < headers.length; i++)
          i: const pw.FlexColumnWidth(1.2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 0.8)),
          ),
          children: [
            for (var i = 0; i < headers.length; i++)
              cell(headers[i], header: true, first: i == 0),
          ],
        ),
        for (final row in rows)
          pw.TableRow(
            children: [
              for (var i = 0; i < row.length; i++)
                cell(row[i], header: false, first: i == 0),
            ],
          ),
      ],
    );
  }

  static String suggestedFileName(PeriodReport report) {
    final start = report.start;
    final stamp =
        '${start.year}-${_two(start.month)}-${_two(start.day)}';
    return 'hydration-report-$stamp.pdf';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
