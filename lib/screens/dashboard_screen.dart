import 'package:flutter/material.dart';

import '../models/water_log.dart';
import '../models/water_settings.dart';
import '../services/report_service.dart';
import '../services/timeline_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/day_timeline_view.dart';
import '../widgets/hydration_calendar.dart';
import '../widgets/shell_nav.dart';
import 'share_card_screen.dart';

/// The home screen: pick a day, see what happened on it.
///
/// The calendar and the timeline are two views of the same selection — tapping a
/// day in the strip is what "any specific date" means here, so there is no
/// separate date picker screen to keep in sync.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime _selected = _today();

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _isToday => _selected == _today();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final settings = state.settings;
    final reports = ReportService(
      entries: state.waterLog,
      goalMl: settings.dailyGoalMl,
    );
    final timeline = TimelineService(
      entries: state.waterLog,
      intakes: state.medicineLog,
      medicines: state.medicines,
      goalMl: settings.dailyGoalMl,
    ).forDay(_selected);

    return Scaffold(
      appBar: AppBar(
        leading: const NavMenuButton(),
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Share this day',
            icon: const Icon(Icons.ios_share),
            onPressed: timeline.isEmpty
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ShareCardScreen(
                        timeline: timeline,
                        settings: settings,
                        // Only today's card can honestly claim a live streak.
                        streak: _isToday ? reports.currentStreak : 0,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
        children: [
          HydrationCalendar(
            selected: _selected,
            onSelect: (day) => setState(() => _selected = day),
            totalsByDay: reports.totalsByDay,
            goalMl: settings.dailyGoalMl,
            firstLoggedDay: _firstLoggedDay(state.waterLog),
          ),
          const SizedBox(height: 18),
          _DaySummary(timeline: timeline, settings: settings),
          const SizedBox(height: 22),
          SectionHeader(
            title: _isToday ? 'Today' : formatDayLabel(_selected),
            trailing: timeline.dosesScheduled > 0
                ? Text(
                    '${timeline.dosesTaken} of ${timeline.dosesScheduled} doses',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                : null,
          ),
          DayTimelineView(
            timeline: timeline,
            settings: settings,
            // Only today can be answered; a past day is a record, not a form.
            onMarkTaken: _isToday
                ? (dose) => _recordDose(state, dose, skipped: false)
                : null,
            onSkip: _isToday
                ? (dose) => _recordDose(state, dose, skipped: true)
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _recordDose(
    AppState state,
    DoseEvent dose, {
    required bool skipped,
  }) async {
    // `dose.at` is the slot this row stands for, which is what makes the answer
    // land on this dose alone. Without it a medicine due four times a day would
    // have every remaining row tick itself off along with the one tapped.
    await state.recordMedicineTaken(
      dose.medicine.id,
      scheduledFor: dose.isScheduled ? dose.at : null,
      skipped: skipped,
    );
    if (!mounted) return;
    final clock = formatClock(dose.at, use24h: state.settings.use24hClock);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          skipped
              ? '${dose.medicine.name} at $clock marked as skipped'
              : '${dose.medicine.name} at $clock marked as taken',
        ),
      ),
    );
  }

  /// Oldest day with a drink on it, so the calendar's back arrow stops there
  /// instead of paging into years of blank months.
  DateTime? _firstLoggedDay(List<WaterEntry> log) {
    DateTime? oldest;
    for (final entry in log) {
      if (oldest == null || entry.timestamp.isBefore(oldest)) {
        oldest = entry.timestamp;
      }
    }
    return oldest;
  }
}

class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.timeline, required this.settings});

  final DayTimeline timeline;
  final WaterSettings settings;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final progress = timeline.progress.clamp(0.0, 1.0);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatVolume(timeline.waterTotalMl, settings),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      timeline.goalMl <= 0
                          ? 'No goal set'
                          : timeline.goalMet
                          ? 'Goal reached'
                          : '${formatVolume(timeline.remainingMl, settings)} '
                                'short of goal',
                      style: TextStyle(fontSize: 12.5, color: palette.inkSoft),
                    ),
                  ],
                ),
              ),
              if (timeline.goalMet)
                Icon(Icons.check_circle, size: 22, color: palette.kelp),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 7,
              color: palette.aquaWash,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: timeline.goalMet ? palette.kelp : palette.aqua,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Figure(
                value: '${timeline.drinkCount}',
                label: timeline.drinkCount == 1 ? 'drink' : 'drinks',
              ),
              _Figure(
                value: timeline.goalMl <= 0
                    ? '—'
                    : '${(timeline.progress * 100).round()}%',
                label: 'of goal',
              ),
              if (timeline.dosesScheduled > 0)
                _Figure(
                  value: '${timeline.dosesTaken}/${timeline.dosesScheduled}',
                  label: 'doses',
                ),
              if (timeline.dosesMissed > 0)
                _Figure(
                  value: '${timeline.dosesMissed}',
                  label: 'missed',
                  colour: palette.clay,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label, this.colour});

  final String value;
  final String label;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colour ?? palette.ink,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 11, color: palette.inkSoft)),
        ],
      ),
    );
  }
}
