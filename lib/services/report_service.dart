import '../models/water_log.dart';

/// One day's worth of water intake.
class DayTotal {
  DayTotal({required this.date, required this.totalMl, required this.goalMl});

  final DateTime date;
  final int totalMl;
  final int goalMl;

  double get progress => goalMl <= 0 ? 0 : totalMl / goalMl;
  bool get goalMet => goalMl > 0 && totalMl >= goalMl;
}

/// Aggregated figures for a reporting period.
class PeriodReport {
  PeriodReport({
    required this.label,
    required this.start,
    required this.end,
    required this.days,
  });

  final String label;
  final DateTime start;
  final DateTime end;
  final List<DayTotal> days;

  int get totalMl => days.fold(0, (sum, day) => sum + day.totalMl);

  /// Average across days that have already happened, not the whole window —
  /// otherwise a report viewed on Monday looks terrible.
  int get averageMl {
    final elapsed = daysElapsed;
    if (elapsed == 0) return 0;
    final consumed = days
        .take(elapsed)
        .fold(0, (sum, day) => sum + day.totalMl);
    return (consumed / elapsed).round();
  }

  int get daysElapsed {
    final today = DateTime.now();
    var count = 0;
    for (final day in days) {
      if (!day.date.isAfter(DateTime(today.year, today.month, today.day))) {
        count++;
      }
    }
    return count;
  }

  int get goalsMet => days.where((day) => day.goalMet).length;

  DayTotal? get bestDay {
    if (days.isEmpty) return null;
    return days.reduce((a, b) => b.totalMl > a.totalMl ? b : a);
  }

  DayTotal? get worstDay {
    final elapsed = days.take(daysElapsed).toList();
    if (elapsed.isEmpty) return null;
    return elapsed.reduce((a, b) => b.totalMl < a.totalMl ? b : a);
  }

  double get goalHitRate {
    final elapsed = daysElapsed;
    if (elapsed == 0) return 0;
    return days.take(elapsed).where((day) => day.goalMet).length / elapsed;
  }

  /// Highest intake of any single day, used to scale the chart.
  int get peakMl =>
      days.fold(0, (max, day) => day.totalMl > max ? day.totalMl : max);
}

/// Turns the raw water log into weekly / monthly reports.
class ReportService {
  const ReportService({required this.entries, required this.goalMl});

  final List<WaterEntry> entries;
  final int goalMl;

  Map<String, int> get _totalsByDay {
    final totals = <String, int>{};
    for (final entry in entries) {
      totals.update(
        entry.dayKey,
        (value) => value + entry.amountMl,
        ifAbsent: () => entry.amountMl,
      );
    }
    return totals;
  }

  int totalForDay(DateTime date) =>
      _totalsByDay[WaterEntry.dayKeyFor(date)] ?? 0;

  int get todayTotalMl => totalForDay(DateTime.now());

  /// Week starting on Monday. [weeksAgo] 0 is the current week.
  PeriodReport weekReport({int weeksAgo = 0}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today
        .subtract(Duration(days: today.weekday - 1))
        .subtract(Duration(days: 7 * weeksAgo));
    final totals = _totalsByDay;

    final days = List.generate(7, (index) {
      final date = monday.add(Duration(days: index));
      return DayTotal(
        date: date,
        totalMl: totals[WaterEntry.dayKeyFor(date)] ?? 0,
        goalMl: goalMl,
      );
    });

    return PeriodReport(
      label: weeksAgo == 0
          ? 'This week'
          : weeksAgo == 1
          ? 'Last week'
          : '$weeksAgo weeks ago',
      start: monday,
      end: monday.add(const Duration(days: 6)),
      days: days,
    );
  }

  /// Calendar month. [monthsAgo] 0 is the current month.
  PeriodReport monthReport({int monthsAgo = 0}) {
    final now = DateTime.now();
    final anchor = DateTime(now.year, now.month - monthsAgo, 1);
    final daysInMonth = DateTime(anchor.year, anchor.month + 1, 0).day;
    final totals = _totalsByDay;

    final days = List.generate(daysInMonth, (index) {
      final date = DateTime(anchor.year, anchor.month, index + 1);
      return DayTotal(
        date: date,
        totalMl: totals[WaterEntry.dayKeyFor(date)] ?? 0,
        goalMl: goalMl,
      );
    });

    return PeriodReport(
      label: monthsAgo == 0 ? 'This month' : _monthName(anchor),
      start: anchor,
      end: DateTime(anchor.year, anchor.month, daysInMonth),
      days: days,
    );
  }

  /// Consecutive days up to today where the goal was met.
  int get currentStreak {
    final totals = _totalsByDay;
    if (goalMl <= 0) return 0;
    var streak = 0;
    var cursor = DateTime.now();
    // Today only counts once the goal is actually hit, so the streak never
    // shows a day the user has not earned yet.
    while (streak < 3650) {
      final total = totals[WaterEntry.dayKeyFor(cursor)] ?? 0;
      if (total >= goalMl) {
        streak++;
      } else if (streak > 0 || !_isSameDay(cursor, DateTime.now())) {
        break;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Longest run of goal-met days anywhere in the history.
  int get bestStreak {
    final totals = _totalsByDay;
    if (goalMl <= 0 || totals.isEmpty) return 0;
    final keys = totals.keys.toList()..sort();
    var best = 0;
    var run = 0;
    DateTime? previous;
    for (final key in keys) {
      final date = DateTime.parse(key);
      final met = (totals[key] ?? 0) >= goalMl;
      if (!met) {
        run = 0;
        previous = date;
        continue;
      }
      if (previous != null && date.difference(previous).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > best) best = run;
      previous = date;
    }
    return best;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _monthName(DateTime date) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${names[date.month - 1]} ${date.year}';
  }
}
