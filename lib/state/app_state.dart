import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medicine.dart';
import '../models/water_log.dart';
import '../models/water_settings.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../theme.dart' show AppFont;

/// Single source of truth for the UI. Deliberately dependency-free —
/// exposed through [AppScope] below instead of a state-management package.
class AppState extends ChangeNotifier {
  AppState(this._storage, this._notifications);

  final StorageService _storage;
  final NotificationService _notifications;

  WaterSettings _settings = const WaterSettings();
  List<Medicine> _medicines = const [];
  List<WaterEntry> _waterLog = const [];
  List<MedicineIntake> _medicineLog = const [];
  ThemeMode _themeMode = ThemeMode.system;
  AppFont _font = AppFont.system;

  WaterSettings get settings => _settings;
  ThemeMode get themeMode => _themeMode;
  AppFont get font => _font;
  List<Medicine> get medicines => List.unmodifiable(_medicines);
  List<WaterEntry> get waterLog => List.unmodifiable(_waterLog);
  List<MedicineIntake> get medicineLog => List.unmodifiable(_medicineLog);

  static Future<AppState> create() async {
    final storage = await StorageService.open();
    final notifications = NotificationService.instance;
    final state = AppState(storage, notifications);
    await state._load();

    // Notifications must never take the whole app down with them. A platform
    // problem here (a missing icon resource, a revoked permission, an OEM alarm
    // quirk) used to surface as "the app could not load your data" even though
    // the data was fine. Log it and carry on with a usable UI instead.
    try {
      await notifications.init();
      // Re-commit the schedule on every cold start. Android drops pending
      // alarms on force-stop and some OEM battery optimisations, so this is the
      // cheapest possible self-healing.
      await state.applySchedule();
      notifications.dataChanged.addListener(state.reloadFromDisk);
    } catch (error, stack) {
      debugPrint('Notification setup failed at startup: $error\n$stack');
    }

    return state;
  }

  Future<void> _load() async {
    _themeMode = _storage.loadThemeMode();
    _font = _storage.loadFont();
    _settings = _storage.loadSettings();
    _medicines = _storage.loadMedicines();
    _waterLog = _pruneOldEntries(_storage.loadWaterLog());
    _medicineLog = _storage.loadMedicineLog();
  }

  /// Picks up writes made by the background notification isolate.
  /// The reload is essential: SharedPreferences keeps an in-memory snapshot per
  /// isolate, so without it we would re-read our own stale copy.
  Future<void> reloadFromDisk() async {
    await _storage.reload();
    _waterLog = _pruneOldEntries(_storage.loadWaterLog());
    _medicineLog = _storage.loadMedicineLog();
    notifyListeners();
  }

  /// Called when the app resumes — the background isolate sets a flag rather
  /// than trying to reach into the UI isolate.
  Future<void> consumePendingBackgroundWrites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (prefs.getBool(kPendingRefreshKey) == true) {
      await prefs.setBool(kPendingRefreshKey, false);
      await reloadFromDisk();
    }
  }

  /// Keeps two years of history so reports stay fast and prefs stay small.
  List<WaterEntry> _pruneOldEntries(List<WaterEntry> entries) {
    final cutoff = DateTime.now().subtract(const Duration(days: 730));
    final kept =
        entries.where((entry) => entry.timestamp.isAfter(cutoff)).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return kept;
  }

  // --- Appearance -----------------------------------------------------------

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _storage.saveThemeMode(mode);
  }

  Future<void> setFont(AppFont font) async {
    if (font == _font) return;
    _font = font;
    notifyListeners();
    await _storage.saveFont(font);
  }

  // --- Water settings -------------------------------------------------------

  Future<void> updateSettings(WaterSettings settings) async {
    _settings = settings;
    notifyListeners();
    await _storage.saveSettings(settings);
    await applySchedule();
  }

  // --- Water log ------------------------------------------------------------

  Future<void> addWater(int amountMl, {DateTime? at}) async {
    if (amountMl <= 0) return;
    final entry = WaterEntry(
      id: 'w${DateTime.now().microsecondsSinceEpoch}',
      timestamp: at ?? DateTime.now(),
      amountMl: amountMl,
    );
    _waterLog = [entry, ..._waterLog];
    notifyListeners();
    await _storage.saveWaterLog(_waterLog);
  }

  Future<void> removeWaterEntry(String id) async {
    _waterLog = _waterLog.where((entry) => entry.id != id).toList();
    notifyListeners();
    await _storage.saveWaterLog(_waterLog);
  }

  Future<void> undoLastEntry() async {
    if (_waterLog.isEmpty) return;
    await removeWaterEntry(_waterLog.first.id);
  }

  // --- Medicines ------------------------------------------------------------

  Future<void> upsertMedicine(Medicine medicine) async {
    final index = _medicines.indexWhere((item) => item.id == medicine.id);
    final updated = [..._medicines];
    if (index >= 0) {
      updated[index] = medicine;
    } else {
      updated.add(medicine);
    }
    _medicines = updated;
    notifyListeners();
    await _storage.saveMedicines(_medicines);
    await applySchedule();
  }

  Future<void> deleteMedicine(String id) async {
    _medicines = _medicines.where((item) => item.id != id).toList();
    notifyListeners();
    await _storage.saveMedicines(_medicines);
    await applySchedule();
  }

  Future<void> toggleMedicine(String id, bool enabled) async {
    final index = _medicines.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final updated = [..._medicines];
    updated[index] = updated[index].copyWith(enabled: enabled);
    _medicines = updated;
    notifyListeners();
    await _storage.saveMedicines(_medicines);
    await applySchedule();
  }

  Future<void> recordMedicineTaken(
    String medicineId, {
    bool skipped = false,
  }) async {
    _medicineLog = [
      MedicineIntake(
        medicineId: medicineId,
        timestamp: DateTime.now(),
        skipped: skipped,
      ),
      ..._medicineLog,
    ];
    notifyListeners();
    await _storage.saveMedicineLog(_medicineLog);
  }

  /// True when this medicine has already been logged today.
  bool takenToday(String medicineId) {
    final today = WaterEntry.dayKeyFor(DateTime.now());
    return _medicineLog.any(
      (intake) =>
          intake.medicineId == medicineId &&
          !intake.skipped &&
          intake.dayKey == today,
    );
  }

  // --- Scheduling -----------------------------------------------------------

  Future<void> applySchedule() async {
    await _notifications.rescheduleAll(
      settings: _settings,
      medicines: _medicines,
    );
  }

  // --- Backup ---------------------------------------------------------------

  String exportJson() => BackupService.encode(
    settings: _settings,
    medicines: _medicines,
    waterLog: _waterLog,
    medicineLog: _medicineLog,
    themeMode: _themeMode,
    font: _font,
  );

  /// [merge] keeps existing data and adds anything new; otherwise the backup
  /// replaces everything.
  Future<void> importBundle(BackupBundle bundle, {bool merge = false}) async {
    if (merge) {
      final existingMedicineIds = _medicines.map((m) => m.id).toSet();
      final mergedMedicines = [..._medicines];
      for (final medicine in bundle.medicines) {
        if (existingMedicineIds.contains(medicine.id)) {
          final index = mergedMedicines.indexWhere((m) => m.id == medicine.id);
          mergedMedicines[index] = medicine;
        } else {
          mergedMedicines.add(medicine);
        }
      }
      _medicines = mergedMedicines;

      final seen = _waterLog.map((entry) => entry.id).toSet();
      final mergedLog = [..._waterLog];
      for (final entry in bundle.waterLog) {
        if (seen.add(entry.id)) mergedLog.add(entry);
      }
      _waterLog = _pruneOldEntries(mergedLog);

      final seenIntakes = _medicineLog
          .map((intake) => '${intake.medicineId}@${intake.timestamp}')
          .toSet();
      final mergedIntakes = [..._medicineLog];
      for (final intake in bundle.medicineLog) {
        if (seenIntakes.add('${intake.medicineId}@${intake.timestamp}')) {
          mergedIntakes.add(intake);
        }
      }
      _medicineLog = mergedIntakes;
    } else {
      _medicines = bundle.medicines;
      _waterLog = _pruneOldEntries(bundle.waterLog);
      _medicineLog = bundle.medicineLog;
    }

    _settings = bundle.settings;
    final restoredTheme = bundle.themeMode;
    if (restoredTheme != null) _themeMode = restoredTheme;
    final restoredFont = bundle.font;
    if (restoredFont != null) _font = restoredFont;
    notifyListeners();

    if (restoredTheme != null) await _storage.saveThemeMode(restoredTheme);
    if (restoredFont != null) await _storage.saveFont(restoredFont);
    await _storage.saveSettings(_settings);
    await _storage.saveMedicines(_medicines);
    await _storage.saveWaterLog(_waterLog);
    await _storage.saveMedicineLog(_medicineLog);
    await applySchedule();
  }

  Future<void> resetEverything() async {
    await _storage.clearAll();
    _settings = const WaterSettings();
    _medicines = const [];
    _waterLog = const [];
    _medicineLog = const [];
    notifyListeners();
    await _notifications.cancelAll();
  }

  @override
  void dispose() {
    _notifications.dataChanged.removeListener(reloadFromDisk);
    super.dispose();
  }
}

/// Minimal InheritedWidget so any screen can reach the state with
/// `AppScope.of(context)` and rebuild when it changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    return _require(scope);
  }

  /// Reads the state without subscribing to changes — for callbacks.
  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    return _require(scope);
  }

  /// Fails loudly and legibly. A bare `!` here produced an opaque
  /// "Null check operator used on a null value" that said nothing about the
  /// actual problem, which is always a widget built outside the scope.
  static AppState _require(AppScope? scope) {
    final state = scope?.notifier;
    if (state == null) {
      throw FlutterError(
        'AppScope was not found above this widget.\n'
        'AppScope must sit above MaterialApp so that pushed routes can reach '
        'it. See main.dart.',
      );
    }
    return state;
  }
}
