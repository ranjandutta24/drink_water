import 'package:flutter/foundation.dart';

/// A single drink recorded by the user.
@immutable
class WaterEntry {
  const WaterEntry({
    required this.id,
    required this.timestamp,
    required this.amountMl,
    this.fromNotification = false,
  });

  final String id;
  final DateTime timestamp;
  final int amountMl;

  /// True when logged straight from a notification action button.
  final bool fromNotification;

  /// `yyyy-MM-dd` in local time — the bucket key used by the reports.
  String get dayKey => dayKeyFor(timestamp);

  static String dayKeyFor(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'amountMl': amountMl,
    'fromNotification': fromNotification,
  };

  static WaterEntry? tryFromJson(Map<String, dynamic> json) {
    final timestamp = DateTime.tryParse('${json['timestamp']}');
    final amount = json['amountMl'];
    if (timestamp == null) return null;
    final amountMl = amount is num ? amount.round() : int.tryParse('$amount');
    if (amountMl == null || amountMl <= 0) return null;
    return WaterEntry(
      id: '${json['id'] ?? timestamp.microsecondsSinceEpoch}',
      timestamp: timestamp,
      amountMl: amountMl,
      fromNotification: json['fromNotification'] == true,
    );
  }
}

/// A recorded medicine dose, used for the adherence line in the reports.
@immutable
class MedicineIntake {
  const MedicineIntake({
    required this.medicineId,
    required this.timestamp,
    this.scheduledFor,
    this.skipped = false,
  });

  final String medicineId;

  /// When the user actually logged it.
  final DateTime timestamp;

  /// Which scheduled slot this dose settles, as that slot's local date and time.
  ///
  /// Null means "we do not know", which covers records written before the field
  /// existed and doses logged with no slot in mind at all. Without it the log
  /// only said *that* a medicine was taken, never *which* of the day's doses,
  /// so a medicine due four times a day had no way to show three still
  /// outstanding — one tap marked the whole day done.
  final DateTime? scheduledFor;

  final bool skipped;

  String get dayKey => WaterEntry.dayKeyFor(timestamp);

  /// The day this dose belongs to on the plan, which is not always the day it
  /// was logged: the 23:30 tablet taken at 00:10 is still last night's dose.
  String get planDayKey => WaterEntry.dayKeyFor(scheduledFor ?? timestamp);

  /// True when this dose was explicitly logged against [slot].
  ///
  /// Compared to the minute rather than by instant equality, because a slot is
  /// rebuilt from a [TimeOfDay] and carries no seconds.
  bool claims(DateTime slot) {
    final mine = scheduledFor?.toLocal();
    if (mine == null) return false;
    return mine.year == slot.year &&
        mine.month == slot.month &&
        mine.day == slot.day &&
        mine.hour == slot.hour &&
        mine.minute == slot.minute;
  }

  Map<String, dynamic> toJson() => {
    'medicineId': medicineId,
    'timestamp': timestamp.toIso8601String(),
    // Left out entirely when unknown, so an export stays shaped the way older
    // builds expect and the schema version does not have to move.
    if (scheduledFor != null) 'scheduledFor': scheduledFor!.toIso8601String(),
    'skipped': skipped,
  };

  static MedicineIntake? tryFromJson(Map<String, dynamic> json) {
    final timestamp = DateTime.tryParse('${json['timestamp']}');
    final medicineId = json['medicineId'];
    if (timestamp == null || medicineId == null) return null;
    final rawSlot = json['scheduledFor'];
    return MedicineIntake(
      medicineId: '$medicineId',
      timestamp: timestamp,
      // A malformed slot degrades to null, which falls back to the old
      // nearest-slot matching rather than dropping the dose.
      scheduledFor: rawSlot == null ? null : DateTime.tryParse('$rawSlot'),
      skipped: json['skipped'] == true,
    );
  }
}
