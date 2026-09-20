import 'package:drink_water/models/medicine.dart';
import 'package:drink_water/models/time_of_day_x.dart';
import 'package:drink_water/models/volume_unit.dart';
import 'package:drink_water/models/water_log.dart';
import 'package:drink_water/models/water_settings.dart';
import 'package:drink_water/services/backup_service.dart';
import 'package:drink_water/services/notification_service.dart';
import 'package:drink_water/services/report_service.dart';
import 'package:drink_water/services/storage_service.dart'
    show themeModeFromName;
import 'package:drink_water/theme.dart';
import 'package:drink_water/utils/format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reminder slots', () {
    test('fills the window at the chosen interval', () {
      const settings = WaterSettings(
        intervalMinutes: 120,
        startTime: TimeOfDay(hour: 8, minute: 0),
        endTime: TimeOfDay(hour: 16, minute: 0),
      );

      final slots = NotificationService.waterReminderSlots(settings);

      expect(slots.map((slot) => slot.label(true)).toList(), [
        '08:00',
        '10:00',
        '12:00',
        '14:00',
        '16:00',
      ]);
    });

    test('handles a window that crosses midnight', () {
      const settings = WaterSettings(
        intervalMinutes: 180,
        startTime: TimeOfDay(hour: 22, minute: 0),
        endTime: TimeOfDay(hour: 4, minute: 0),
      );

      final slots = NotificationService.waterReminderSlots(settings);

      expect(slots.map((slot) => slot.label(true)).toList(), [
        '22:00',
        '01:00',
        '04:00',
      ]);
    });

    test('never produces an unbounded number of slots', () {
      const settings = WaterSettings(
        intervalMinutes: 5,
        startTime: TimeOfDay(hour: 0, minute: 0),
        endTime: TimeOfDay(hour: 0, minute: 0),
      );

      expect(
        NotificationService.waterReminderSlots(settings).length,
        lessThanOrEqualTo(96),
      );
    });
  });

  group('medicine notification ids', () {
    test('are unique across medicines, weekdays and times', () {
      final ids = <int>{};
      for (var medicine = 0; medicine < 40; medicine++) {
        for (var weekday = 1; weekday <= 7; weekday++) {
          for (var time = 0; time < 12; time++) {
            final id = NotificationService.medicineNotificationId(
              medicine,
              weekday,
              time,
            );
            expect(ids.add(id), isTrue, reason: 'collision on id $id');
          }
        }
      }
    });

    test('never collide with the water reminder id range', () {
      final lowest = NotificationService.medicineNotificationId(0, 1, 0);
      expect(lowest, greaterThan(2000));
    });
  });

  group('unit conversion', () {
    test('formats glasses using the user configured glass size', () {
      const settings = WaterSettings(
        displayUnit: VolumeUnit.glass,
        glassSizeMl: 200,
      );
      expect(formatVolume(600, settings), '3 glasses');
      expect(formatVolume(200, settings), '1 glass');
    });

    test('formats litres without trailing zeroes', () {
      const settings = WaterSettings(displayUnit: VolumeUnit.liter);
      expect(formatVolume(2000, settings), '2 L');
      expect(formatVolume(1500, settings), '1.5 L');
    });

    test('reminder amount falls back to one glass when unset', () {
      const settings = WaterSettings(glassSizeMl: 300);
      expect(settings.effectiveReminderAmountMl, 300);
      expect(
        settings.copyWith(amountPerReminderMl: 450).effectiveReminderAmountMl,
        450,
      );
    });
  });

  group('reports', () {
    List<WaterEntry> entriesFor(Map<int, int> daysAgoToMl) {
      final now = DateTime.now();
      final entries = <WaterEntry>[];
      daysAgoToMl.forEach((daysAgo, ml) {
        final date = DateTime(
          now.year,
          now.month,
          now.day,
          12,
        ).subtract(Duration(days: daysAgo));
        entries.add(WaterEntry(id: 'e$daysAgo', timestamp: date, amountMl: ml));
      });
      return entries;
    }

    test('buckets entries into the right day', () {
      final service = ReportService(
        entries: entriesFor({0: 1200, 1: 800}),
        goalMl: 2000,
      );
      expect(service.todayTotalMl, 1200);
      expect(
        service.totalForDay(DateTime.now().subtract(const Duration(days: 1))),
        800,
      );
    });

    test('counts a streak only from days that met the goal', () {
      final service = ReportService(
        entries: entriesFor({0: 2000, 1: 2100, 2: 900}),
        goalMl: 2000,
      );
      expect(service.currentStreak, 2);
    });

    test('a weekly report always covers seven days', () {
      final service = ReportService(
        entries: entriesFor({0: 500}),
        goalMl: 2000,
      );
      expect(service.weekReport().days.length, 7);
      expect(service.weekReport(weeksAgo: 1).days.length, 7);
    });

    test('monthly report length matches the calendar month', () {
      final service = ReportService(entries: const [], goalMl: 2000);
      final report = service.monthReport();
      final expected = DateTime(
        DateTime.now().year,
        DateTime.now().month + 1,
        0,
      ).day;
      expect(report.days.length, expected);
    });
  });

  group('medicine interval schedule', () {
    test('steps from the start time up to and including the end', () {
      final times = Medicine.buildIntervalTimes(
        intervalHours: 4,
        start: const TimeOfDay(hour: 8, minute: 0),
        end: const TimeOfDay(hour: 20, minute: 0),
      );

      expect(times.map((t) => t.hhmm), ['08:00', '12:00', '16:00', '20:00']);
    });

    test('a window that crosses midnight wraps the clock', () {
      final times = Medicine.buildIntervalTimes(
        intervalHours: 3,
        start: const TimeOfDay(hour: 22, minute: 0),
        end: const TimeOfDay(hour: 4, minute: 0),
      );

      expect(times.map((t) => t.hhmm), ['22:00', '01:00', '04:00']);
    });

    test('equal start and end covers the whole day', () {
      final times = Medicine.buildIntervalTimes(
        intervalHours: 12,
        start: const TimeOfDay(hour: 9, minute: 0),
        end: const TimeOfDay(hour: 9, minute: 0),
      );

      // The wrap back onto 09:00 is dropped rather than fired twice.
      expect(times.map((t) => t.hhmm), ['09:00', '21:00']);
    });

    test('never generates more than the id scheme allows', () {
      final times = Medicine.buildIntervalTimes(
        intervalHours: 1,
        start: const TimeOfDay(hour: 0, minute: 0),
        end: const TimeOfDay(hour: 0, minute: 0),
      );

      expect(times.length, Medicine.maxIntervalTimes);
    });

    test('a zero or negative interval yields nothing rather than looping', () {
      expect(
        Medicine.buildIntervalTimes(
          intervalHours: 0,
          start: const TimeOfDay(hour: 8, minute: 0),
          end: const TimeOfDay(hour: 20, minute: 0),
        ),
        isEmpty,
      );
    });

    test('json keeps the rule and regenerates the times on the way back', () {
      final medicine = Medicine(
        id: 'm-int',
        name: 'Paracetamol',
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        times: const [TimeOfDay(hour: 9, minute: 0)],
        schedule: MedicineSchedule.interval,
        intervalHours: 6,
        intervalStart: const TimeOfDay(hour: 6, minute: 0),
        intervalEnd: const TimeOfDay(hour: 22, minute: 0),
      );

      final restored = Medicine.tryFromJson(medicine.toJson())!;

      expect(restored.schedule, MedicineSchedule.interval);
      expect(restored.intervalHours, 6);
      expect(restored.intervalStart.hhmm, '06:00');
      expect(restored.intervalEnd.hhmm, '22:00');
      // 06:00, 12:00, 18:00 — 24:00 falls outside the window.
      expect(restored.times.map((t) => t.hhmm), ['06:00', '12:00', '18:00']);
      expect(restored.dosesPerWeek, 21);
    });

    test('a medicine without the new keys stays on explicit times', () {
      final restored = Medicine.tryFromJson({
        'id': 'legacy',
        'name': 'Old entry',
        'weekdays': [1, 2],
        'times': ['07:15', '19:45'],
      })!;

      expect(restored.schedule, MedicineSchedule.times);
      expect(restored.effectiveTimes.map((t) => t.hhmm), ['07:15', '19:45']);
    });

    test('an out-of-range interval falls back to the default', () {
      final restored = Medicine.tryFromJson({
        'id': 'bad',
        'name': 'Nonsense',
        'weekdays': [1],
        'times': ['08:00'],
        'schedule': 'interval',
        'intervalHours': 0,
        'intervalStart': '08:00',
        'intervalEnd': '16:00',
      })!;

      expect(restored.intervalHours, Medicine.kDefaultIntervalHours);
      expect(restored.effectiveTimes.map((t) => t.hhmm), [
        '08:00',
        '12:00',
        '16:00',
      ]);
    });

    test('scheduleLabel describes the rule, not every time', () {
      final medicine = Medicine(
        id: 'm-int',
        name: 'Paracetamol',
        weekdays: const {1},
        times: const [TimeOfDay(hour: 8, minute: 0)],
        schedule: MedicineSchedule.interval,
        intervalHours: 2,
        intervalStart: const TimeOfDay(hour: 8, minute: 0),
        intervalEnd: const TimeOfDay(hour: 22, minute: 0),
      );

      expect(medicine.scheduleLabel(use24h: true), 'Every 2 h · 08:00–22:00');
      expect(
        medicine
            .copyWith(schedule: MedicineSchedule.times)
            .scheduleLabel(use24h: true),
        '08:00',
      );
    });
  });

  group('backup', () {
    test('round-trips settings, medicines and history without loss', () {
      const settings = WaterSettings(
        intervalMinutes: 45,
        startTime: TimeOfDay(hour: 7, minute: 30),
        endTime: TimeOfDay(hour: 21, minute: 15),
        dailyGoalMl: 2750,
        displayUnit: VolumeUnit.bottle,
        glassSizeMl: 220,
        bottleSizeMl: 900,
        amountPerReminderMl: 330,
        use24hClock: true,
        vibrate: false,
        soundOnLog: false,
      );

      final medicines = [
        Medicine(
          id: 'm1',
          name: 'Metformin',
          dosage: '500 mg',
          notes: 'With a full glass of water',
          mealRelation: MealRelation.afterFood,
          weekdays: const {1, 3, 5},
          times: const [
            TimeOfDay(hour: 8, minute: 0),
            TimeOfDay(hour: 20, minute: 30),
          ],
          colorIndex: 2,
        ),
      ];

      final waterLog = [
        WaterEntry(
          id: 'w1',
          timestamp: DateTime(2026, 9, 18, 9, 5),
          amountMl: 250,
          fromNotification: true,
        ),
      ];

      final medicineLog = [
        MedicineIntake(
          medicineId: 'm1',
          timestamp: DateTime(2026, 9, 18, 8, 2),
        ),
      ];

      final json = BackupService.encode(
        settings: settings,
        medicines: medicines,
        waterLog: waterLog,
        medicineLog: medicineLog,
      );

      final restored = BackupService.decode(json);

      expect(restored.settings.intervalMinutes, 45);
      expect(restored.settings.startTime, const TimeOfDay(hour: 7, minute: 30));
      expect(restored.settings.displayUnit, VolumeUnit.bottle);
      expect(restored.settings.bottleSizeMl, 900);
      expect(restored.settings.amountPerReminderMl, 330);
      expect(restored.settings.vibrate, isFalse);
      expect(restored.settings.soundOnLog, isFalse);

      expect(restored.medicines.length, 1);
      final medicine = restored.medicines.single;
      expect(medicine.name, 'Metformin');
      expect(medicine.weekdays, {1, 3, 5});
      expect(medicine.times.length, 2);
      expect(medicine.mealRelation, MealRelation.afterFood);
      expect(medicine.colorIndex, 2);

      expect(restored.waterLog.single.amountMl, 250);
      expect(restored.waterLog.single.fromNotification, isTrue);
      expect(restored.medicineLog.single.medicineId, 'm1');
    });

    test('a backup written before the sound flag existed keeps it on', () {
      final settings = WaterSettings.fromJson(
        const WaterSettings().toJson()..remove('soundOnLog'),
      );

      expect(settings.soundOnLog, isTrue);
    });

    test('rejects a file that is not JSON', () {
      expect(
        () => BackupService.decode('not json at all'),
        throwsA(isA<BackupParseException>()),
      );
    });

    test('rejects a backup from a newer schema', () {
      expect(
        () => BackupService.decode('{"app":"drink_water","schemaVersion":99}'),
        throwsA(isA<BackupParseException>()),
      );
    });

    test('drops malformed medicines instead of failing the whole import', () {
      final bundle = BackupService.decode('''
        {
          "app": "drink_water",
          "schemaVersion": 1,
          "waterSettings": {"intervalMinutes": 90},
          "medicines": [
            {"name": "Good", "weekdays": [1], "times": ["08:00"]},
            {"name": "No times", "weekdays": [1], "times": []},
            {"weekdays": [1], "times": ["09:00"]}
          ]
        }
      ''');

      expect(bundle.medicines.map((m) => m.name).toList(), ['Good']);
      expect(bundle.settings.intervalMinutes, 90);
    });

    test('carries the theme choice through an export and back', () {
      final json = BackupService.encode(
        settings: const WaterSettings(),
        medicines: const [],
        waterLog: const [],
        medicineLog: const [],
        themeMode: ThemeMode.dark,
      );

      expect(BackupService.decode(json).themeMode, ThemeMode.dark);
    });

    test('leaves the theme alone when the backup has no appearance', () {
      final bundle = BackupService.decode(
        '{"app":"drink_water","schemaVersion":1,'
        '"waterSettings":{"intervalMinutes":60}}',
      );

      expect(bundle.themeMode, isNull);
    });

    test('ignores an unrecognised theme name', () {
      final bundle = BackupService.decode(
        '{"app":"drink_water","schemaVersion":1,'
        '"appearance":{"themeMode":"sepia"},'
        '"waterSettings":{"intervalMinutes":60}}',
      );

      expect(bundle.themeMode, isNull);
    });

    test('carries the font choice through an export and back', () {
      final json = BackupService.encode(
        settings: const WaterSettings(),
        medicines: const [],
        waterLog: const [],
        medicineLog: const [],
        font: AppFont.play,
      );

      expect(BackupService.decode(json).font, AppFont.play);
    });

    test('leaves the font alone when the value is missing or unknown', () {
      final noAppearance = BackupService.decode(
        '{"app":"drink_water","schemaVersion":1,'
        '"waterSettings":{"intervalMinutes":60}}',
      );
      final nonsense = BackupService.decode(
        '{"app":"drink_water","schemaVersion":1,'
        '"appearance":{"font":"comic"},'
        '"waterSettings":{"intervalMinutes":60}}',
      );

      expect(noAppearance.font, isNull);
      expect(nonsense.font, isNull);
    });
  });

  group('font', () {
    test('stored names map back, unknown values fall back to the default', () {
      expect(appFontFromName('play'), AppFont.play);
      expect(appFontFromName('mono'), AppFont.mono);
      expect(appFontFromName('roboto'), AppFont.roboto);
      expect(appFontFromName(null), AppFont.system);
      expect(appFontFromName('comic'), AppFont.system);
    });

    test('the chosen family reaches the styles the app actually uses', () {
      final theme = buildLightTheme(AppFont.play);

      expect(theme.textTheme.bodyMedium?.fontFamily, 'Play');
      expect(theme.textTheme.displayLarge?.fontFamily, 'Play');
      expect(theme.appBarTheme.titleTextStyle?.fontFamily, 'Play');
      // The default must pin nothing, so the platform gets to choose. Asserted
      // on the input rather than the built theme: ThemeData always merges in
      // Typography, which names a family (Roboto on Android) regardless.
      expect(AppFont.system.family, isNull);
    });
  });

  group('theme', () {
    test(
      'stored names map back to modes, unknown values follow the system',
      () {
        expect(themeModeFromName('dark'), ThemeMode.dark);
        expect(themeModeFromName('light'), ThemeMode.light);
        expect(themeModeFromName('system'), ThemeMode.system);
        expect(themeModeFromName(null), ThemeMode.system);
        expect(themeModeFromName('nonsense'), ThemeMode.system);
      },
    );

    test('both themes expose a palette and matching brightness', () {
      final light = buildLightTheme();
      final dark = buildDarkTheme();

      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.extension<AppPalette>(), AppPalette.light);
      expect(dark.extension<AppPalette>(), AppPalette.dark);
    });

    test('the dark palette is actually dark and has full token coverage', () {
      expect(
        AppPalette.dark.canvas.computeLuminance(),
        lessThan(AppPalette.light.canvas.computeLuminance()),
      );
      expect(
        AppPalette.dark.ink.computeLuminance(),
        greaterThan(AppPalette.light.ink.computeLuminance()),
      );
      expect(
        AppPalette.dark.medicinePalette.length,
        AppPalette.light.medicinePalette.length,
      );
    });
  });
}
