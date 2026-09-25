import 'dart:convert';

// material (not just foundation) for Color; ValueNotifier and debugPrint come
// along with it.
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/medicine.dart';
import '../models/time_of_day_x.dart';
import '../models/water_log.dart';
import '../models/water_settings.dart';

/// Payload actions understood by the tap handlers.
const String kActionDrank = 'water_drank';
const String kActionSnooze = 'water_snooze';
const String kActionTaken = 'medicine_taken';
const String kActionSkip = 'medicine_skip';

/// Notification ID ranges. Kept disjoint so cancelling one family never
/// touches another.
const int _waterIdBase = 1000;
const int _waterSnoozeId = 999;
const int _selfTestId = 998;
const int _medicineIdBase = 100000;

/// Tint Android applies to the small icon and the app name in the shade. Hard
/// coded rather than read from the theme: notifications are built in a
/// background isolate that has no BuildContext, and the brand colour is the same
/// in both themes.
const Color _notificationAccent = Color(0xFF1B9AAA);

/// Signals the UI (when it is alive) that a background isolate changed data.
const String kPendingRefreshKey = 'pending_refresh_v1';

/// Handles a notification action that arrives while the app process is not
/// running. This must be a top-level function annotated as an entry point,
/// otherwise it is tree-shaken out of release builds.
@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse response) {
  // Fire and forget: the isolate is kept alive by the plugin until the future
  // completes.
  _recordFromAction(response);
}

/// Which dose a medicine notification stands for.
@immutable
class MedicineDosePayload {
  const MedicineDosePayload({
    required this.medicineId,
    required this.scheduledFor,
  });

  final String medicineId;

  /// Null for a notification queued by an older build, whose payload carried
  /// only the medicine id.
  final DateTime? scheduledFor;
}

/// Packs the slot in front of the id, separated by a bar.
///
/// That order is deliberate: the time is a fixed five characters, so the split
/// is unambiguous even if a medicine id ever contains a bar itself.
String encodeMedicinePayload(String medicineId, int hour, int minute) {
  final hh = hour.toString().padLeft(2, '0');
  final mm = minute.toString().padLeft(2, '0');
  return '$hh:$mm|$medicineId';
}

/// Reverses [encodeMedicinePayload], tolerating a bare id from a notification
/// that was scheduled before the slot was part of the payload. Those alarms sit
/// in AlarmManager across an app update and cannot be rewritten in place.
MedicineDosePayload? decodeMedicinePayload(String? payload, {DateTime? now}) {
  if (payload == null || payload.isEmpty) return null;

  final bar = payload.indexOf('|');
  if (bar != 5) {
    return MedicineDosePayload(medicineId: payload, scheduledFor: null);
  }
  final hour = int.tryParse(payload.substring(0, 2));
  final minute = int.tryParse(payload.substring(3, 5));
  final medicineId = payload.substring(6);
  if (hour == null || minute == null || medicineId.isEmpty) {
    return MedicineDosePayload(medicineId: payload, scheduledFor: null);
  }

  return MedicineDosePayload(
    medicineId: medicineId,
    scheduledFor: _resolveSlotDay(hour, minute, now ?? DateTime.now()),
  );
}

/// Turns the slot's time of day into a real date.
///
/// A notification is answered after it fires, so the slot is normally earlier
/// the same day. The exception is the late-night dose answered after midnight:
/// today's copy of 23:30 is still most of a day away, and the dose actually
/// being answered is yesterday's. Two hours of slack keeps a tap on a
/// notification the user let sit on the lock screen for a while on the right day.
///
/// Built by calendar arithmetic rather than by subtracting a Duration, because
/// taking 24 hours off a wall-clock time lands an hour out across a daylight
/// saving change.
DateTime _resolveSlotDay(int hour, int minute, DateTime now) {
  final today = DateTime(now.year, now.month, now.day, hour, minute);
  if (today.difference(now) > const Duration(hours: 2)) {
    return DateTime(now.year, now.month, now.day - 1, hour, minute);
  }
  return today;
}

Future<void> _recordFromAction(NotificationResponse response) async {
  final actionId = response.actionId;
  if (actionId == null) return;

  try {
    if (actionId == kActionSnooze) {
      // Nothing was logged, so there is no data for the UI to pick up — just
      // lay down a new alarm. Works from the background isolate too because
      // snoozeWater initialises the plugin and time zone itself.
      await NotificationService.instance.snoozeWater(response.payload);
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    if (actionId == kActionDrank) {
      final amount = int.tryParse('${response.payload}') ?? 250;
      final raw = prefs.getString('water_log_v1') ?? '[]';
      final decoded = jsonDecode(raw);
      final entries = decoded is List ? [...decoded] : <dynamic>[];
      entries.add(
        WaterEntry(
          id: 'n${DateTime.now().microsecondsSinceEpoch}',
          timestamp: DateTime.now(),
          amountMl: amount,
          fromNotification: true,
        ).toJson(),
      );
      await prefs.setString('water_log_v1', jsonEncode(entries));
    } else if (actionId == kActionTaken || actionId == kActionSkip) {
      final dose = decodeMedicinePayload(response.payload);
      if (dose == null) return;
      final raw = prefs.getString('medicine_log_v1') ?? '[]';
      final decoded = jsonDecode(raw);
      final entries = decoded is List ? [...decoded] : <dynamic>[];
      entries.add(
        MedicineIntake(
          medicineId: dose.medicineId,
          timestamp: DateTime.now(),
          // The slot the reminder was queued for, so answering it settles that
          // dose and not whichever one happens to be nearest the clock.
          scheduledFor: dose.scheduledFor,
          skipped: actionId == kActionSkip,
        ).toJson(),
      );
      await prefs.setString('medicine_log_v1', jsonEncode(entries));
    }

    await prefs.setBool(kPendingRefreshKey, true);
  } catch (error, stack) {
    debugPrint('Background notification action failed: $error\n$stack');
  }
}

/// Wraps flutter_local_notifications and owns all reminder scheduling.
///
/// Every reminder is committed to the Android AlarmManager up front, which is
/// what allows notifications to arrive when the app has been closed or killed.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;

  /// Set when the user taps a notification action while the UI is running, so
  /// the app can refresh itself.
  final ValueNotifier<int> dataChanged = ValueNotifier<int>(0);

  static const AndroidNotificationChannel _waterChannel =
      AndroidNotificationChannel(
        'water_reminders',
        'Water reminders',
        description: 'Periodic nudges to drink water.',
        importance: Importance.high,
      );

  static const AndroidNotificationChannel _medicineChannel =
      AndroidNotificationChannel(
        'medicine_reminders',
        'Medicine reminders',
        description: 'Reminders for each scheduled medicine dose.',
        importance: Importance.max,
      );

  Future<void> init() async {
    if (_initialised) return;

    tzdata.initializeTimeZones();
    await _configureLocalTimeZone();

    // A dedicated status-bar icon rather than the launcher icon: Android masks
    // small icons to their alpha channel, so a full-colour launcher icon with
    // an opaque plate renders as a solid white square.
    //
    // The name must be bare — no '@drawable/' prefix. The plugin resolves it
    // with Resources.getIdentifier(name, "drawable", package), which treats the
    // prefix as part of the name and then fails initialise() with
    // 'invalid_icon'. The file lives in res/drawable-{mdpi…xxxhdpi}.
    const androidSettings = AndroidInitializationSettings('ic_notification');
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: _onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(_waterChannel);
    await android?.createNotificationChannel(_medicineChannel);

    _initialised = true;
  }

  Future<void> _configureLocalTimeZone() async {
    try {
      // flutter_timezone changed this return type between major versions: older
      // releases hand back a plain String, newer ones a TimezoneInfo. Reading it
      // dynamically keeps this working either way.
      final dynamic info = await FlutterTimezone.getLocalTimezone();
      final name = info is String ? info : '${info.identifier}';
      tz.setLocalLocation(tz.getLocation(name));
    } catch (error) {
      // Falls back to UTC. Scheduling still works, just without DST awareness.
      debugPrint('Could not resolve local time zone: $error');
    }
  }

  void _onForegroundResponse(NotificationResponse response) {
    if (response.actionId != null) {
      _recordFromAction(response).then((_) {
        dataChanged.value++;
      });
    }
  }

  /// Asks for the runtime permissions this app needs. Safe to call repeatedly.
  Future<bool> requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true;

    final granted = await android.requestNotificationsPermission() ?? false;
    // Exact alarms are what make a reminder land at :00 instead of whenever
    // Android feels like it. Denied is not fatal — we degrade to inexact.
    await android.requestExactAlarmsPermission();
    return granted;
  }

  Future<bool> areNotificationsEnabled() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true;
    return await android.areNotificationsEnabled() ?? false;
  }

  Future<bool> canScheduleExactAlarms() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true;
    return await android.canScheduleExactNotifications() ?? false;
  }

  // --- Scheduling -----------------------------------------------------------

  /// Rebuilds the entire schedule from scratch. Called after any settings or
  /// medicine change — simpler and far less bug-prone than diffing.
  Future<void> rescheduleAll({
    required WaterSettings settings,
    required List<Medicine> medicines,
  }) async {
    await init();
    // Not cancelAll(): that also killed a pending one-minute self test, so
    // toggling any setting during the test made it look like the phone had
    // dropped the alarm — a false negative in the one diagnostic meant to rule
    // that out.
    await _cancelWhere((id) => id != _selfTestId);
    await scheduleWaterReminders(settings);
    await scheduleMedicineReminders(medicines, use24h: settings.use24hClock);
  }

  /// Computes the reminder times inside the active window and schedules one
  /// daily-repeating alarm per slot.
  Future<void> scheduleWaterReminders(WaterSettings settings) async {
    await init();
    await _cancelWhere((id) => id >= _waterIdBase && id <= _waterIdBase + 400);
    await _plugin.cancel(_waterSnoozeId);

    if (!settings.remindersEnabled || settings.intervalMinutes <= 0) return;

    final slots = waterReminderSlots(settings);
    final exact = await canScheduleExactAlarms();
    final amount = settings.effectiveReminderAmountMl;

    for (var index = 0; index < slots.length; index++) {
      final slot = slots[index];
      await _plugin.zonedSchedule(
        _waterIdBase + index,
        'Time to drink water',
        _waterBody(settings, amount),
        _nextInstanceOf(slot),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _waterChannel.id,
            _waterChannel.name,
            channelDescription: _waterChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            color: _notificationAccent,
            enableVibration: settings.vibrate,
            category: AndroidNotificationCategory.reminder,
            actions: const [
              AndroidNotificationAction(
                kActionDrank,
                'Drank it',
                showsUserInterface: false,
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                kActionSnooze,
                'Snooze 15 min',
                showsUserInterface: false,
                cancelNotification: true,
              ),
            ],
          ),
        ),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '$amount',
        // Repeats every day at this wall-clock time.
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  String _waterBody(WaterSettings settings, int amount) {
    final unit = settings.displayUnit;
    final size = settings.unitSizeMl;
    if (size > 1 && amount % size == 0) {
      final count = amount ~/ size;
      return 'Have $count ${unit.shortLabel}${count == 1 ? '' : 's'} '
          'to stay on track.';
    }
    if (amount >= 1000 && amount % 1000 == 0) {
      return 'Have ${amount ~/ 1000} L to stay on track.';
    }
    return 'Have $amount ml to stay on track.';
  }

  /// One alarm per (medicine, weekday, time) combination, repeating weekly.
  Future<void> scheduleMedicineReminders(
    List<Medicine> medicines, {
    bool use24h = false,
  }) async {
    await init();
    final exact = await canScheduleExactAlarms();

    for (var medIndex = 0; medIndex < medicines.length; medIndex++) {
      final medicine = medicines[medIndex];
      if (!medicine.enabled) continue;

      // effectiveTimes, not sortedTimes: an interval medicine derives its times
      // from the rule, so this stays right even if the stored list is stale.
      final times = medicine.effectiveTimes;
      for (final weekday in medicine.weekdays) {
        for (var timeIndex = 0; timeIndex < times.length; timeIndex++) {
          final id = medicineNotificationId(medIndex, weekday, timeIndex);
          final slot = TimeOfDayLike(
            times[timeIndex].hour,
            times[timeIndex].minute,
          );
          await _plugin.zonedSchedule(
            id,
            _medicineTitle(medicine),
            _medicineBody(medicine, slot, use24h),
            _nextInstanceOfWeekday(weekday, slot),
            NotificationDetails(
              android: AndroidNotificationDetails(
                _medicineChannel.id,
                _medicineChannel.name,
                channelDescription: _medicineChannel.description,
                importance: Importance.max,
                priority: Priority.high,
                color: _notificationAccent,
                category: AndroidNotificationCategory.alarm,
                actions: const [
                  AndroidNotificationAction(
                    kActionTaken,
                    'Taken',
                    showsUserInterface: false,
                    cancelNotification: true,
                  ),
                  AndroidNotificationAction(
                    kActionSkip,
                    'Skip',
                    showsUserInterface: false,
                    cancelNotification: true,
                  ),
                ],
              ),
            ),
            androidScheduleMode: exact
                ? AndroidScheduleMode.exactAllowWhileIdle
                : AndroidScheduleMode.inexactAllowWhileIdle,
            // Carries the slot as well as the medicine: the action buttons are
            // answered from a background isolate that has no idea which of the
            // day's doses this notification was for, and guessing from the clock
            // settled the wrong one on a closely spaced schedule.
            payload: encodeMedicinePayload(medicine.id, slot.hour, slot.minute),
            // Repeats weekly on the same weekday at the same time.
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        }
      }
    }
  }

  String _medicineTitle(Medicine medicine) {
    final dosage = medicine.dosage.trim();
    return dosage.isEmpty
        ? 'Take ${medicine.name}'
        : 'Take ${medicine.name} — $dosage';
  }

  String _medicineBody(Medicine medicine, TimeOfDayLike time, bool use24h) {
    final bits = <String>[
      'Scheduled for ${time.label(use24h)}',
      if (medicine.mealRelation != MealRelation.none)
        medicine.mealRelation.label,
      if (medicine.notes.trim().isNotEmpty) medicine.notes.trim(),
    ];
    return bits.join(' · ');
  }

  /// Re-fires the water reminder a quarter of an hour later. Public because the
  /// background isolate reaches it through the singleton.
  Future<void> snoozeWater(String? payload) async {
    await init();
    final amount = int.tryParse('$payload') ?? 250;
    final exact = await canScheduleExactAlarms();
    await _plugin.zonedSchedule(
      _waterSnoozeId,
      'Water reminder (snoozed)',
      'Have $amount ml now.',
      tz.TZDateTime.now(tz.local).add(const Duration(minutes: 15)),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _waterChannel.id,
          _waterChannel.name,
          channelDescription: _waterChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          color: _notificationAccent,
          actions: const [
            AndroidNotificationAction(
              kActionDrank,
              'Drank it',
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ],
        ),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: '$amount',
    );
  }

  /// Sends a notification right now so the user can confirm the setup works.
  Future<void> showTestNotification() async {
    await init();
    await _plugin.show(
      1,
      'Reminders are working',
      'This is what a water reminder will look like.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _waterChannel.id,
          _waterChannel.name,
          channelDescription: _waterChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          color: _notificationAccent,
          actions: const [
            AndroidNotificationAction(
              kActionDrank,
              'Drank it',
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ],
        ),
      ),
      payload: '250',
    );
  }

  /// Schedules one reminder a minute out through exactly the same AlarmManager
  /// path a real reminder uses, so it can be used to prove delivery while the
  /// app is closed or swiped away. [showTestNotification] cannot prove that: it
  /// posts immediately from the running process, which is the one case that was
  /// never in doubt.
  Future<DateTime> scheduleSelfTest() async {
    await init();
    final when = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));
    final exact = await canScheduleExactAlarms();
    await _plugin.zonedSchedule(
      _selfTestId,
      'Reminders survive a closed app',
      'This was scheduled a minute ago and fired on its own.',
      when,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _waterChannel.id,
          _waterChannel.name,
          channelDescription: _waterChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          color: _notificationAccent,
          category: AndroidNotificationCategory.reminder,
        ),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
    return DateTime.fromMillisecondsSinceEpoch(when.millisecondsSinceEpoch);
  }

  /// How many reminders Android is currently holding for us. Zero while
  /// reminders are on is the tell-tale that something dropped the schedule —
  /// usually a force-stop or an aggressive battery optimiser.
  Future<int> pendingCount() async {
    await init();
    final requests = await _plugin.pendingNotificationRequests();
    // A snooze or a self test is not part of the schedule, so counting them
    // would overstate how healthy it is.
    return requests
        .where((r) => r.id != _selfTestId && r.id != _waterSnoozeId)
        .length;
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  /// Cancels only the alarms Android is actually holding, rather than firing a
  /// cancel at every id in a range: asking once and cancelling what comes back
  /// replaces ~400 platform calls per settings change with a handful.
  Future<void> _cancelWhere(bool Function(int id) matches) async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (matches(request.id)) await _plugin.cancel(request.id);
    }
  }

  // --- pure helpers (unit-testable) ----------------------------------------

  static int medicineNotificationId(
    int medicineIndex,
    int weekday,
    int timeIndex,
  ) {
    return _medicineIdBase +
        (medicineIndex * 1000) +
        (weekday * 100) +
        timeIndex;
  }

  /// All reminder times for a day, derived from the interval and the window.
  static List<TimeOfDayLike> waterReminderSlots(WaterSettings settings) {
    final slots = <TimeOfDayLike>[];
    if (settings.intervalMinutes <= 0) return slots;

    final start = settings.startTime.minutesOfDay;
    final span = settings.windowLengthMinutes;

    for (
      var offset = 0;
      offset <= span && slots.length < 96;
      offset += settings.intervalMinutes
    ) {
      slots.add(TimeOfDayLike.fromMinutes(start + offset));
    }
    return slots;
  }

  static tz.TZDateTime _nextInstanceOf(TimeOfDayLike time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static tz.TZDateTime _nextInstanceOfWeekday(int weekday, TimeOfDayLike time) {
    var scheduled = _nextInstanceOf(time);
    // Walk forward at most 7 days to land on the requested ISO weekday.
    var guard = 0;
    while (scheduled.weekday != weekday && guard < 8) {
      scheduled = scheduled.add(const Duration(days: 1));
      guard++;
    }
    return scheduled;
  }
}

/// A framework-free hour/minute pair, so the scheduling logic does not depend
/// on Flutter's material library.
@immutable
class TimeOfDayLike {
  const TimeOfDayLike(this.hour, this.minute);

  factory TimeOfDayLike.fromMinutes(int minutes) {
    final normalised = minutes % (24 * 60);
    return TimeOfDayLike(normalised ~/ 60, normalised % 60);
  }

  final int hour;
  final int minute;

  int get minutesOfDay => hour * 60 + minute;

  String label(bool use24h) {
    if (use24h) {
      return '${hour.toString().padLeft(2, '0')}:'
          '${minute.toString().padLeft(2, '0')}';
    }
    final period = hour < 12 ? 'AM' : 'PM';
    var displayHour = hour % 12;
    if (displayHour == 0) displayHour = 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  bool operator ==(Object other) =>
      other is TimeOfDayLike && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}
