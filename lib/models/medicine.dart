import 'package:flutter/material.dart';

import 'time_of_day_x.dart';

/// Guidance shown in the reminder body.
enum MealRelation {
  none('Any time'),
  beforeFood('Before food'),
  afterFood('After food'),
  withFood('With food'),
  emptyStomach('Empty stomach');

  const MealRelation(this.label);

  final String label;

  static MealRelation fromName(String? name) => MealRelation.values.firstWhere(
    (relation) => relation.name == name,
    orElse: () => MealRelation.none,
  );
}

/// How the times of day for a medicine are decided.
enum MedicineSchedule {
  times('Set times', 'Pick each time of day yourself'),
  interval('Every few hours', 'Repeat through a window of the day');

  const MedicineSchedule(this.label, this.note);

  final String label;
  final String note;

  static MedicineSchedule fromName(String? name) =>
      MedicineSchedule.values.firstWhere(
        (schedule) => schedule.name == name,
        orElse: () => MedicineSchedule.times,
      );
}

/// One medicine with a fully customisable day + time schedule.
///
/// [times] is always the concrete list of reminder times, even in
/// [MedicineSchedule.interval] mode — the interval fields describe how that list
/// was produced, and are kept so the editor can show "every 2 hours" again
/// instead of eight unexplained rows. Everything downstream (scheduling,
/// reports, the cards) reads [times] and needs to know nothing about intervals.
@immutable
class Medicine {
  const Medicine({
    required this.id,
    required this.name,
    required this.weekdays,
    required this.times,
    this.dosage = '',
    this.notes = '',
    this.mealRelation = MealRelation.none,
    this.enabled = true,
    this.colorIndex = 0,
    this.schedule = MedicineSchedule.times,
    this.intervalHours = kDefaultIntervalHours,
    this.intervalStart = const TimeOfDay(hour: 8, minute: 0),
    this.intervalEnd = const TimeOfDay(hour: 22, minute: 0),
  });

  /// Offered in the editor. Anything finer than an hour is a stopwatch, not a
  /// medicine schedule.
  static const List<int> intervalChoices = [1, 2, 3, 4, 6, 8, 12];
  static const int kDefaultIntervalHours = 4;

  /// A hard ceiling on generated times. The notification id scheme allots two
  /// digits per time slot, and nobody takes a tablet more than this often.
  static const int maxIntervalTimes = 24;

  final String id;
  final String name;

  /// Free text, e.g. "1 tablet", "5 ml", "2 puffs".
  final String dosage;
  final String notes;
  final MealRelation mealRelation;

  /// ISO weekdays: 1 = Monday ... 7 = Sunday.
  final Set<int> weekdays;

  /// Every time of day this medicine should fire, on each selected weekday.
  final List<TimeOfDay> times;

  final bool enabled;

  /// Index into the palette used for the card accent.
  final int colorIndex;

  final MedicineSchedule schedule;

  /// Only meaningful when [schedule] is [MedicineSchedule.interval].
  final int intervalHours;
  final TimeOfDay intervalStart;
  final TimeOfDay intervalEnd;

  bool get isDaily => weekdays.length == 7;

  /// Builds the reminder times for an interval schedule. The window may cross
  /// midnight (22:00 to 06:00), in which case it is measured forwards.
  static List<TimeOfDay> buildIntervalTimes({
    required int intervalHours,
    required TimeOfDay start,
    required TimeOfDay end,
  }) {
    final times = <TimeOfDay>[];
    final step = intervalHours * 60;
    if (step <= 0) return times;

    final startMinutes = start.minutesOfDay;
    var span = end.minutesOfDay - startMinutes;
    // Equal start and end reads as "the whole day", which is what a user
    // dragging both ends together means.
    if (span <= 0) span += 24 * 60;

    // A whole-day window lands back on the start time; firing twice at the same
    // minute is never what was meant, so the clock position is deduplicated.
    final seen = <int>{};
    for (
      var offset = 0;
      offset <= span && times.length < maxIntervalTimes;
      offset += step
    ) {
      final time = TimeOfDayJson.fromMinutes(startMinutes + offset);
      if (!seen.add(time.minutesOfDay)) continue;
      times.add(time);
    }
    return times;
  }

  /// The times this medicine should actually fire, derived for interval
  /// schedules and taken as-is otherwise.
  List<TimeOfDay> get effectiveTimes {
    if (schedule != MedicineSchedule.interval) return sortedTimes;
    final generated = buildIntervalTimes(
      intervalHours: intervalHours,
      start: intervalStart,
      end: intervalEnd,
    );
    return generated.isEmpty ? sortedTimes : generated;
  }

  /// One line for the cards, so an interval medicine shows its rule rather than
  /// a wall of eight times.
  String scheduleLabel({bool use24h = false}) {
    if (schedule != MedicineSchedule.interval) {
      return sortedTimes
          .map((time) => formatTime(time, use24h: use24h))
          .join(' · ');
    }
    final every = intervalHours == 1 ? 'Every hour' : 'Every $intervalHours h';
    return '$every · ${formatTime(intervalStart, use24h: use24h)}'
        '–${formatTime(intervalEnd, use24h: use24h)}';
  }

  int get dosesPerWeek => weekdays.length * effectiveTimes.length;

  /// Times sorted chronologically — the UI always shows them in order.
  List<TimeOfDay> get sortedTimes {
    final sorted = [...times]
      ..sort((a, b) => a.minutesOfDay.compareTo(b.minutesOfDay));
    return sorted;
  }

  String get weekdaysLabel {
    if (weekdays.isEmpty) return 'No days selected';
    if (isDaily) return 'Every day';
    const names = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    final ordered = weekdays.toList()..sort();
    if (ordered.length == 5 && !weekdays.contains(6) && !weekdays.contains(7)) {
      return 'Weekdays';
    }
    if (ordered.length == 2 && weekdays.contains(6) && weekdays.contains(7)) {
      return 'Weekends';
    }
    return ordered.map((day) => names[day]).join(', ');
  }

  Medicine copyWith({
    String? name,
    String? dosage,
    String? notes,
    MealRelation? mealRelation,
    Set<int>? weekdays,
    List<TimeOfDay>? times,
    bool? enabled,
    int? colorIndex,
    MedicineSchedule? schedule,
    int? intervalHours,
    TimeOfDay? intervalStart,
    TimeOfDay? intervalEnd,
  }) {
    return Medicine(
      id: id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      notes: notes ?? this.notes,
      mealRelation: mealRelation ?? this.mealRelation,
      weekdays: weekdays ?? this.weekdays,
      times: times ?? this.times,
      enabled: enabled ?? this.enabled,
      colorIndex: colorIndex ?? this.colorIndex,
      schedule: schedule ?? this.schedule,
      intervalHours: intervalHours ?? this.intervalHours,
      intervalStart: intervalStart ?? this.intervalStart,
      intervalEnd: intervalEnd ?? this.intervalEnd,
    );
  }

  /// The interval keys are additive: an older build reads only `times`, which is
  /// still the full materialised list, so it keeps working and just loses the
  /// ability to say "every 2 hours" in the editor.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dosage': dosage,
    'notes': notes,
    'mealRelation': mealRelation.name,
    'weekdays': (weekdays.toList()..sort()),
    'times': effectiveTimes.map((time) => time.hhmm).toList(),
    'enabled': enabled,
    'colorIndex': colorIndex,
    'schedule': schedule.name,
    'intervalHours': intervalHours,
    'intervalStart': intervalStart.hhmm,
    'intervalEnd': intervalEnd.hhmm,
  };

  static Medicine? tryFromJson(Map<String, dynamic> json) {
    final name = '${json['name'] ?? ''}'.trim();
    if (name.isEmpty) return null;

    final rawDays = json['weekdays'];
    final weekdays = <int>{};
    if (rawDays is List) {
      for (final day in rawDays) {
        final value = day is num ? day.round() : int.tryParse('$day');
        if (value != null && value >= 1 && value <= 7) weekdays.add(value);
      }
    }

    final rawTimes = json['times'];
    final times = <TimeOfDay>[];
    if (rawTimes is List) {
      for (final entry in rawTimes) {
        final parsed = TimeOfDayJson.tryParse('$entry');
        if (parsed != null) times.add(parsed);
      }
    }

    final schedule = MedicineSchedule.fromName(json['schedule'] as String?);
    final rawInterval = json['intervalHours'];
    var intervalHours = rawInterval is num
        ? rawInterval.round()
        : kDefaultIntervalHours;
    if (intervalHours < 1 || intervalHours > 24) {
      intervalHours = kDefaultIntervalHours;
    }
    final intervalStart =
        TimeOfDayJson.tryParse('${json['intervalStart']}') ??
        const TimeOfDay(hour: 8, minute: 0);
    final intervalEnd =
        TimeOfDayJson.tryParse('${json['intervalEnd']}') ??
        const TimeOfDay(hour: 22, minute: 0);

    // An interval medicine regenerates its times from the rule rather than
    // trusting the stored list, so a hand-edited or half-migrated file can never
    // leave the two disagreeing.
    if (schedule == MedicineSchedule.interval) {
      final generated = buildIntervalTimes(
        intervalHours: intervalHours,
        start: intervalStart,
        end: intervalEnd,
      );
      if (generated.isNotEmpty) {
        times
          ..clear()
          ..addAll(generated);
      }
    }

    if (weekdays.isEmpty || times.isEmpty) return null;

    final rawColor = json['colorIndex'];
    return Medicine(
      id: '${json['id'] ?? DateTime.now().microsecondsSinceEpoch}',
      name: name,
      dosage: '${json['dosage'] ?? ''}',
      notes: '${json['notes'] ?? ''}',
      mealRelation: MealRelation.fromName(json['mealRelation'] as String?),
      weekdays: weekdays,
      times: times,
      enabled: json['enabled'] != false,
      colorIndex: rawColor is num ? rawColor.round().abs() : 0,
      schedule: schedule,
      intervalHours: intervalHours,
      intervalStart: intervalStart,
      intervalEnd: intervalEnd,
    );
  }
}
