import 'dart:convert';

import '../models/medicine.dart';
import '../models/water_log.dart';
import '../models/water_settings.dart';

/// Result of parsing a user-supplied backup file.
class BackupBundle {
  BackupBundle({
    required this.settings,
    required this.medicines,
    required this.waterLog,
    required this.medicineLog,
    required this.exportedAt,
    required this.schemaVersion,
  });

  final WaterSettings settings;
  final List<Medicine> medicines;
  final List<WaterEntry> waterLog;
  final List<MedicineIntake> medicineLog;
  final DateTime? exportedAt;
  final int schemaVersion;

  String get summary {
    final parts = <String>[
      '${medicines.length} medicine${medicines.length == 1 ? '' : 's'}',
      '${waterLog.length} water entr${waterLog.length == 1 ? 'y' : 'ies'}',
    ];
    return parts.join(' · ');
  }
}

class BackupParseException implements Exception {
  BackupParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Serialises / deserialises the complete app state as a single JSON document.
class BackupService {
  static const int schemaVersion = 1;
  static const String _appId = 'drink_water';

  /// Pretty-printed so the exported file is human-readable and diffable.
  static String encode({
    required WaterSettings settings,
    required List<Medicine> medicines,
    required List<WaterEntry> waterLog,
    required List<MedicineIntake> medicineLog,
  }) {
    final payload = <String, dynamic>{
      'app': _appId,
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'waterSettings': settings.toJson(),
      'medicines': medicines.map((medicine) => medicine.toJson()).toList(),
      'waterLog': waterLog.map((entry) => entry.toJson()).toList(),
      'medicineLog': medicineLog.map((intake) => intake.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Throws [BackupParseException] with a message worth showing to the user.
  static BackupBundle decode(String raw) {
    if (raw.trim().isEmpty) {
      throw BackupParseException('The file is empty.');
    }

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw BackupParseException('This is not a valid JSON file.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw BackupParseException(
        'Expected a JSON object at the top level of the file.',
      );
    }

    final app = decoded['app'];
    if (app != null && app != _appId) {
      throw BackupParseException('This backup was created by a different app.');
    }

    final rawVersion = decoded['schemaVersion'];
    final version = rawVersion is num ? rawVersion.round() : schemaVersion;
    if (version > schemaVersion) {
      throw BackupParseException(
        'This backup was made by a newer version of the app '
        '(format v$version). Update the app and try again.',
      );
    }

    final settingsJson = decoded['waterSettings'];
    final settings = settingsJson is Map<String, dynamic>
        ? WaterSettings.fromJson(settingsJson)
        : const WaterSettings();

    final medicines = <Medicine>[];
    final rawMedicines = decoded['medicines'];
    if (rawMedicines is List) {
      for (final item in rawMedicines) {
        if (item is Map<String, dynamic>) {
          final medicine = Medicine.tryFromJson(item);
          if (medicine != null) medicines.add(medicine);
        }
      }
    }

    final waterLog = <WaterEntry>[];
    final rawWaterLog = decoded['waterLog'];
    if (rawWaterLog is List) {
      for (final item in rawWaterLog) {
        if (item is Map<String, dynamic>) {
          final entry = WaterEntry.tryFromJson(item);
          if (entry != null) waterLog.add(entry);
        }
      }
    }

    final medicineLog = <MedicineIntake>[];
    final rawMedicineLog = decoded['medicineLog'];
    if (rawMedicineLog is List) {
      for (final item in rawMedicineLog) {
        if (item is Map<String, dynamic>) {
          final intake = MedicineIntake.tryFromJson(item);
          if (intake != null) medicineLog.add(intake);
        }
      }
    }

    if (settingsJson == null && medicines.isEmpty && waterLog.isEmpty) {
      throw BackupParseException(
        'No settings or history found in this file.',
      );
    }

    return BackupBundle(
      settings: settings,
      medicines: medicines,
      waterLog: waterLog,
      medicineLog: medicineLog,
      exportedAt: DateTime.tryParse('${decoded['exportedAt']}'),
      schemaVersion: version,
    );
  }

  static String suggestedFileName([DateTime? now]) {
    final date = (now ?? DateTime.now()).toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'drink-water-backup-'
        '${date.year}${two(date.month)}${two(date.day)}-'
        '${two(date.hour)}${two(date.minute)}.json';
  }
}
