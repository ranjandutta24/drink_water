import 'package:flutter/material.dart';

import 'time_of_day_x.dart';
import 'volume_unit.dart';

/// User configuration for the hydration reminders.
@immutable
class WaterSettings {
  const WaterSettings({
    this.remindersEnabled = true,
    this.intervalMinutes = 60,
    this.startTime = const TimeOfDay(hour: 8, minute: 0),
    this.endTime = const TimeOfDay(hour: 22, minute: 0),
    this.dailyGoalMl = 2000,
    this.displayUnit = VolumeUnit.ml,
    this.glassSizeMl = 250,
    this.bottleSizeMl = 750,
    this.amountPerReminderMl,
    this.use24hClock = false,
    this.vibrate = true,
  });

  final bool remindersEnabled;

  /// Gap between reminders, in minutes. Fully user controlled.
  final int intervalMinutes;

  /// Reminders are only scheduled inside this window so the user is not woken
  /// at 3am. Set start == end for a full 24 hour window.
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  final int dailyGoalMl;

  final VolumeUnit displayUnit;

  /// Custom container sizes, so "1 glass" means whatever the user's glass holds.
  final int glassSizeMl;
  final int bottleSizeMl;

  /// Optional. When set, the notification suggests a specific amount and the
  /// "Drank it" action logs exactly this much.
  final int? amountPerReminderMl;

  final bool use24hClock;
  final bool vibrate;

  /// Size in millilitres of one unit of [displayUnit].
  int get unitSizeMl => switch (displayUnit) {
    VolumeUnit.ml => 1,
    VolumeUnit.liter => 1000,
    VolumeUnit.glass => glassSizeMl <= 0 ? 250 : glassSizeMl,
    VolumeUnit.bottle => bottleSizeMl <= 0 ? 750 : bottleSizeMl,
  };

  /// The amount a single "Drank it" tap logs.
  int get effectiveReminderAmountMl {
    final amount = amountPerReminderMl;
    if (amount != null && amount > 0) return amount;
    return switch (displayUnit) {
      VolumeUnit.ml || VolumeUnit.liter => glassSizeMl,
      VolumeUnit.glass => glassSizeMl,
      VolumeUnit.bottle => bottleSizeMl,
    };
  }

  /// Quick-add buttons offered on the home screen, in millilitres.
  List<int> get quickAddAmountsMl {
    final glass = glassSizeMl <= 0 ? 250 : glassSizeMl;
    final bottle = bottleSizeMl <= 0 ? 750 : bottleSizeMl;
    final amounts = <int>{
      (glass / 2).round(),
      glass,
      glass * 2,
      bottle,
    }.where((value) => value > 0).toList()..sort();
    return amounts;
  }

  /// Total minutes the reminder window spans. Handles windows that cross
  /// midnight (e.g. 22:00 -> 06:00 for night-shift workers).
  int get windowLengthMinutes {
    final start = startTime.minutesOfDay;
    final end = endTime.minutesOfDay;
    if (start == end) return 24 * 60;
    if (end > start) return end - start;
    return (24 * 60) - start + end;
  }

  /// How many reminders a day this configuration produces.
  int get remindersPerDay {
    if (intervalMinutes <= 0) return 0;
    return (windowLengthMinutes ~/ intervalMinutes) + 1;
  }

  WaterSettings copyWith({
    bool? remindersEnabled,
    int? intervalMinutes,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    int? dailyGoalMl,
    VolumeUnit? displayUnit,
    int? glassSizeMl,
    int? bottleSizeMl,
    int? amountPerReminderMl,
    bool clearAmountPerReminder = false,
    bool? use24hClock,
    bool? vibrate,
  }) {
    return WaterSettings(
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      dailyGoalMl: dailyGoalMl ?? this.dailyGoalMl,
      displayUnit: displayUnit ?? this.displayUnit,
      glassSizeMl: glassSizeMl ?? this.glassSizeMl,
      bottleSizeMl: bottleSizeMl ?? this.bottleSizeMl,
      amountPerReminderMl: clearAmountPerReminder
          ? null
          : (amountPerReminderMl ?? this.amountPerReminderMl),
      use24hClock: use24hClock ?? this.use24hClock,
      vibrate: vibrate ?? this.vibrate,
    );
  }

  Map<String, dynamic> toJson() => {
    'remindersEnabled': remindersEnabled,
    'intervalMinutes': intervalMinutes,
    'startTime': startTime.hhmm,
    'endTime': endTime.hhmm,
    'dailyGoalMl': dailyGoalMl,
    'displayUnit': displayUnit.name,
    'glassSizeMl': glassSizeMl,
    'bottleSizeMl': bottleSizeMl,
    'amountPerReminderMl': amountPerReminderMl,
    'use24hClock': use24hClock,
    'vibrate': vibrate,
  };

  factory WaterSettings.fromJson(Map<String, dynamic> json) {
    const fallback = WaterSettings();
    return WaterSettings(
      remindersEnabled: _asBool(json['remindersEnabled'], true),
      intervalMinutes: _clampInt(
        _asInt(json['intervalMinutes'], 60),
        5,
        24 * 60,
      ),
      startTime:
          TimeOfDayJson.tryParse(json['startTime'] as String?) ??
          fallback.startTime,
      endTime:
          TimeOfDayJson.tryParse(json['endTime'] as String?) ??
          fallback.endTime,
      dailyGoalMl: _clampInt(_asInt(json['dailyGoalMl'], 2000), 200, 20000),
      displayUnit: VolumeUnit.fromName(json['displayUnit'] as String?),
      glassSizeMl: _clampInt(_asInt(json['glassSizeMl'], 250), 10, 5000),
      bottleSizeMl: _clampInt(_asInt(json['bottleSizeMl'], 750), 10, 10000),
      amountPerReminderMl: json['amountPerReminderMl'] == null
          ? null
          : _clampInt(_asInt(json['amountPerReminderMl'], 250), 10, 5000),
      use24hClock: _asBool(json['use24hClock'], false),
      vibrate: _asBool(json['vibrate'], true),
    );
  }
}

bool _asBool(Object? value, bool fallback) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return fallback;
}

int _clampInt(int value, int min, int max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

int _asInt(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}
