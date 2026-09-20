import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medicine.dart';
import '../models/water_log.dart';
import '../models/water_settings.dart';
import '../theme.dart' show AppFont, appFontFromName;

/// Tolerant parse of a stored or imported theme-mode name. Anything unknown —
/// including null, from an older backup that predates the setting — means
/// "follow the system".
ThemeMode themeModeFromName(String? name) {
  switch (name) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

/// Everything lives on the device in SharedPreferences as JSON strings.
/// There is deliberately no network layer anywhere in this app.
class StorageService {
  StorageService(this._prefs);

  static const _kWaterSettings = 'water_settings_v1';
  static const _kMedicines = 'medicines_v1';
  static const _kWaterLog = 'water_log_v1';
  static const _kMedicineLog = 'medicine_log_v1';
  static const _kThemeMode = 'theme_mode_v1';
  static const _kFont = 'app_font_v1';

  final SharedPreferences _prefs;

  static Future<StorageService> open() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  /// Pulls in changes written by another isolate (the notification handler).
  /// SharedPreferences caches values per isolate, so this is required before
  /// re-reading anything the background handler may have touched.
  Future<void> reload() => _prefs.reload();

  // --- Water settings -------------------------------------------------------

  WaterSettings loadSettings() {
    final raw = _prefs.getString(_kWaterSettings);
    if (raw == null || raw.isEmpty) return const WaterSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return WaterSettings.fromJson(decoded);
      }
    } catch (_) {
      // Corrupt payload: fall back to defaults rather than crash on launch.
    }
    return const WaterSettings();
  }

  Future<void> saveSettings(WaterSettings settings) =>
      _prefs.setString(_kWaterSettings, jsonEncode(settings.toJson()));

  // --- Appearance -----------------------------------------------------------

  /// Stored as a name rather than an index so the value survives any future
  /// reordering of [ThemeMode].
  ThemeMode loadThemeMode() => themeModeFromName(_prefs.getString(_kThemeMode));

  Future<void> saveThemeMode(ThemeMode mode) =>
      _prefs.setString(_kThemeMode, mode.name);

  AppFont loadFont() => appFontFromName(_prefs.getString(_kFont));

  Future<void> saveFont(AppFont font) => _prefs.setString(_kFont, font.name);

  // --- Medicines ------------------------------------------------------------

  List<Medicine> loadMedicines() {
    final raw = _prefs.getString(_kMedicines);
    if (raw == null || raw.isEmpty) return const [];
    return _decodeMedicines(raw);
  }

  Future<void> saveMedicines(List<Medicine> medicines) => _prefs.setString(
    _kMedicines,
    jsonEncode(medicines.map((medicine) => medicine.toJson()).toList()),
  );

  // --- Water log ------------------------------------------------------------

  List<WaterEntry> loadWaterLog() {
    final raw = _prefs.getString(_kWaterLog);
    if (raw == null || raw.isEmpty) return const [];
    return decodeWaterEntries(raw);
  }

  Future<void> saveWaterLog(List<WaterEntry> entries) => _prefs.setString(
    _kWaterLog,
    jsonEncode(entries.map((entry) => entry.toJson()).toList()),
  );

  // --- Medicine intake log --------------------------------------------------

  List<MedicineIntake> loadMedicineLog() {
    final raw = _prefs.getString(_kMedicineLog);
    if (raw == null || raw.isEmpty) return const [];
    return _decodeIntakes(raw);
  }

  Future<void> saveMedicineLog(List<MedicineIntake> intakes) =>
      _prefs.setString(
        _kMedicineLog,
        jsonEncode(intakes.map((intake) => intake.toJson()).toList()),
      );

  Future<void> clearAll() async {
    await _prefs.remove(_kWaterSettings);
    await _prefs.remove(_kMedicines);
    await _prefs.remove(_kWaterLog);
    await _prefs.remove(_kMedicineLog);
    // The theme and font choices are preferences, not data: erasing the log
    // should not throw the user back into an appearance they did not pick.
  }

  // --- helpers --------------------------------------------------------------

  static List<Medicine> _decodeMedicines(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final medicines = <Medicine>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final medicine = Medicine.tryFromJson(item);
          if (medicine != null) medicines.add(medicine);
        }
      }
      return medicines;
    } catch (_) {
      return const [];
    }
  }

  static List<WaterEntry> decodeWaterEntries(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final entries = <WaterEntry>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final entry = WaterEntry.tryFromJson(item);
          if (entry != null) entries.add(entry);
        }
      }
      return entries;
    } catch (_) {
      return const [];
    }
  }

  static List<MedicineIntake> _decodeIntakes(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final intakes = <MedicineIntake>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final intake = MedicineIntake.tryFromJson(item);
          if (intake != null) intakes.add(intake);
        }
      }
      return intakes;
    } catch (_) {
      return const [];
    }
  }
}
