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

/// One medicine with a fully customisable day + time schedule.
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
  });

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

  bool get isDaily => weekdays.length == 7;

  int get dosesPerWeek => weekdays.length * times.length;

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
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dosage': dosage,
    'notes': notes,
    'mealRelation': mealRelation.name,
    'weekdays': (weekdays.toList()..sort()),
    'times': sortedTimes.map((time) => time.hhmm).toList(),
    'enabled': enabled,
    'colorIndex': colorIndex,
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
    );
  }
}
