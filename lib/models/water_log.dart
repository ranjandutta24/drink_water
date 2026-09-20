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
    this.skipped = false,
  });

  final String medicineId;
  final DateTime timestamp;
  final bool skipped;

  String get dayKey => WaterEntry.dayKeyFor(timestamp);

  Map<String, dynamic> toJson() => {
    'medicineId': medicineId,
    'timestamp': timestamp.toIso8601String(),
    'skipped': skipped,
  };

  static MedicineIntake? tryFromJson(Map<String, dynamic> json) {
    final timestamp = DateTime.tryParse('${json['timestamp']}');
    final medicineId = json['medicineId'];
    if (timestamp == null || medicineId == null) return null;
    return MedicineIntake(
      medicineId: '$medicineId',
      timestamp: timestamp,
      skipped: json['skipped'] == true,
    );
  }
}
