import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/water_settings.dart';
import '../services/report_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

enum _Range { week, month }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _Range _range = _Range.week;

  /// 0 = current period, 1 = previous, and so on.
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final settings = state.settings;
    final service = ReportService(
      entries: state.waterLog,
      goalMl: settings.dailyGoalMl,
    );
    final report = _range == _Range.week
        ? service.weekReport(weeksAgo: _offset)
        : service.monthReport(monthsAgo: _offset);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
        children: [
          SegmentedButton<_Range>(
            segments: const [
              ButtonSegment(value: _Range.week, label: Text('Weekly')),
              ButtonSegment(value: _Range.month, label: Text('Monthly')),
            ],
            selected: {_range},
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              backgroundColor: Colors.white,
              selectedBackgroundColor: AppColors.aquaWash,
              selectedForegroundColor: AppColors.aquaDeep,
              side: const BorderSide(color: AppColors.hairline),
            ),
            onSelectionChanged: (selection) => setState(() {
              _range = selection.first;
              _offset = 0;
            }),
          ),
          const SizedBox(height: 16),
          _PeriodNav(
            label: report.label,
            subtitle: _rangeSubtitle(report),
            canGoForward: _offset > 0,
            onBack: () => setState(() => _offset++),
            onForward: () => setState(() => _offset--),
          ),
          const SizedBox(height: 16),
          _SummaryPanel(report: report, settings: settings),
          const SizedBox(height: 16),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _range == _Range.week
                      ? 'Each day this week'
                      : 'Each day of the month',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'The dashed line is your ${formatVolume(settings.dailyGoalMl, settings)} goal.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 190,
                  child: _range == _Range.week
                      ? _WeekBars(report: report, settings: settings)
                      : _MonthBars(report: report, settings: settings),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _StreakPanel(service: service),
          const SizedBox(height: 16),
          _ExtremesPanel(report: report, settings: settings),
          if (state.medicineLog.isNotEmpty) ...[
            const SizedBox(height: 16),
            _MedicinePanel(state: state, report: report),
          ],
        ],
      ),
    );
  }

  String _rangeSubtitle(PeriodReport report) {
    if (_range == _Range.week) {
      return '${report.start.day} ${monthShort(report.start)} – '
          '${report.end.day} ${monthShort(report.end)}';
    }
    return '${report.days.length} days';
  }
}

class _PeriodNav extends StatelessWidget {
  const _PeriodNav({
    required this.label,
    required this.subtitle,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
  });

  final String label;
  final String subtitle;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Earlier',
          onPressed: onBack,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Column(
            children: [
              Text(label, style: Theme.of(context).textTheme.titleLarge),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Later',
          onPressed: canGoForward ? onForward : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.report, required this.settings});

  final PeriodReport report;
  final WaterSettings settings;

  @override
  Widget build(BuildContext context) {
    final rate = (report.goalHitRate * 100).round();

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: StatTile(
                  value: formatVolume(report.totalMl, settings),
                  label: 'total',
                ),
              ),
              Expanded(
                child: StatTile(
                  value: formatVolume(report.averageMl, settings),
                  label: 'daily average',
                ),
              ),
              Expanded(
                child: StatTile(
                  value: '${report.goalsMet}/${report.daysElapsed}',
                  label: 'days on goal',
                  color: report.goalsMet > 0
                      ? AppColors.kelp
                      : AppColors.marine,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: report.goalHitRate.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.aquaWash,
              valueColor: const AlwaysStoppedAnimation(AppColors.kelp),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            report.daysElapsed == 0
                ? 'This period has not started yet.'
                : 'You hit your goal on $rate% of the days so far.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.report, required this.settings});

  final PeriodReport report;
  final WaterSettings settings;

  @override
  Widget build(BuildContext context) {
    final maxValue = _chartMax(report, settings);

    return BarChart(
      BarChartData(
        maxY: maxValue,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.marine,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final day = report.days[group.x];
              return BarTooltipItem(
                '${formatDayLabel(day.date)}\n'
                '${formatVolume(day.totalMl, settings)}',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxValue / 3,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.hairline, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= report.days.length) {
                  return const SizedBox.shrink();
                }
                final day = report.days[index].date;
                final isToday = _isToday(day);
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    weekdayShort(day),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      color: isToday ? AppColors.aquaDeep : AppColors.slate,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: settings.dailyGoalMl.toDouble(),
              color: AppColors.kelp.withValues(alpha: 0.7),
              strokeWidth: 1.4,
              dashArray: const [5, 4],
            ),
          ],
        ),
        barGroups: [
          for (var i = 0; i < report.days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: report.days[i].totalMl.toDouble(),
                  width: 20,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                  color: report.days[i].goalMet
                      ? AppColors.kelp
                      : AppColors.aqua,
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxValue,
                    color: AppColors.mist,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MonthBars extends StatelessWidget {
  const _MonthBars({required this.report, required this.settings});

  final PeriodReport report;
  final WaterSettings settings;

  @override
  Widget build(BuildContext context) {
    final maxValue = _chartMax(report, settings);

    return BarChart(
      BarChartData(
        maxY: maxValue,
        alignment: BarChartAlignment.spaceBetween,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.marine,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final day = report.days[group.x];
              return BarTooltipItem(
                '${day.date.day} ${monthShort(day.date)}\n'
                '${formatVolume(day.totalMl, settings)}',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxValue / 3,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.hairline, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                final dayNumber = index + 1;
                // Only label every 5th day, otherwise the axis is unreadable.
                if (dayNumber != 1 && dayNumber % 5 != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '$dayNumber',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.slate,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: settings.dailyGoalMl.toDouble(),
              color: AppColors.kelp.withValues(alpha: 0.7),
              strokeWidth: 1.4,
              dashArray: const [5, 4],
            ),
          ],
        ),
        barGroups: [
          for (var i = 0; i < report.days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: report.days[i].totalMl.toDouble(),
                  width: 6,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                  color: report.days[i].goalMet
                      ? AppColors.kelp
                      : AppColors.aqua,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

double _chartMax(PeriodReport report, WaterSettings settings) {
  final peak = report.peakMl;
  final goal = settings.dailyGoalMl;
  final base = (peak > goal ? peak : goal).toDouble();
  // Head-room above the tallest bar so the goal line never sits on the ceiling.
  return base * 1.18;
}

bool _isToday(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year && date.month == now.month && date.day == now.day;
}

class _StreakPanel extends StatelessWidget {
  const _StreakPanel({required this.service});

  final ReportService service;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Row(
        children: [
          Expanded(
            child: StatTile(
              value: '${service.currentStreak}',
              label: 'day streak now',
              color: AppColors.aquaDeep,
            ),
          ),
          Expanded(
            child: StatTile(
              value: '${service.bestStreak}',
              label: 'best streak',
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtremesPanel extends StatelessWidget {
  const _ExtremesPanel({required this.report, required this.settings});

  final PeriodReport report;
  final WaterSettings settings;

  @override
  Widget build(BuildContext context) {
    final best = report.bestDay;
    final worst = report.worstDay;
    if (best == null || best.totalMl == 0) {
      return const EmptyState(
        icon: Icons.insights_outlined,
        title: 'Nothing to chart yet',
        message: 'Log a few drinks and your weekly pattern will show up here.',
      );
    }

    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.trending_up, color: AppColors.kelp),
            title: Text('Best day: ${formatDayLabel(best.date)}'),
            trailing: Text(
              formatVolume(best.totalMl, settings),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (worst != null && worst.date != best.date) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.trending_down, color: AppColors.clay),
              title: Text('Lightest day: ${formatDayLabel(worst.date)}'),
              trailing: Text(
                formatVolume(worst.totalMl, settings),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MedicinePanel extends StatelessWidget {
  const _MedicinePanel({required this.state, required this.report});

  final AppState state;
  final PeriodReport report;

  @override
  Widget build(BuildContext context) {
    final start = DateTime(
      report.start.year,
      report.start.month,
      report.start.day,
    );
    final end = DateTime(
      report.end.year,
      report.end.month,
      report.end.day,
    ).add(const Duration(days: 1));

    final inPeriod = state.medicineLog.where(
      (intake) =>
          intake.timestamp.isAfter(start) && intake.timestamp.isBefore(end),
    );
    final taken = inPeriod.where((intake) => !intake.skipped).length;
    final skipped = inPeriod.where((intake) => intake.skipped).length;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Medicines this period',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: '$taken',
                  label: 'doses taken',
                  color: AppColors.kelp,
                ),
              ),
              Expanded(
                child: StatTile(
                  value: '$skipped',
                  label: 'doses skipped',
                  color: skipped > 0 ? AppColors.clay : AppColors.marine,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
