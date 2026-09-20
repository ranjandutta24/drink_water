import 'package:flutter/material.dart';

/// Serialisation helpers for [TimeOfDay] so it can live inside JSON.
extension TimeOfDayJson on TimeOfDay {
  /// Minutes since midnight. Used as the canonical stored form.
  int get minutesOfDay => hour * 60 + minute;

  String get hhmm =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static TimeOfDay fromMinutes(int minutes) {
    final normalised = minutes % (24 * 60);
    return TimeOfDay(hour: normalised ~/ 60, minute: normalised % 60);
  }

  static TimeOfDay? tryParse(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }
}

/// Formats a [TimeOfDay] without needing a BuildContext.
String formatTime(TimeOfDay time, {bool use24h = false}) {
  if (use24h) return time.hhmm;
  final period = time.hour < 12 ? 'AM' : 'PM';
  var hour = time.hour % 12;
  if (hour == 0) hour = 12;
  return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
}
