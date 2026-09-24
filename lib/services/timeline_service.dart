import 'package:flutter/material.dart' show TimeOfDay;

import '../models/medicine.dart';
import '../models/water_log.dart';

/// How a scheduled dose turned out.
enum DoseStatus {
  /// Still to come later today.
  upcoming,

  /// Logged as taken.
  taken,

  /// The user explicitly said they skipped it.
  skipped,

  /// The slot came and went with nothing logged.
  missed,

  /// Logged, but with no scheduled slot left to attach it to — an extra dose, or
  /// one taken on a day the medicine is not normally due.
  extra,
}

/// One thing that happened (or should have happened) on a given day.
///
/// Sealed so the timeline UI has to handle every case; a new event type becomes
/// a compile error at every switch rather than a silently missing row.
sealed class TimelineEvent {
  const TimelineEvent({required this.at});

  /// When this sits on the day's clock. For a scheduled dose that is the
  /// scheduled time even if it was taken slightly late, so the timeline reads in
  /// plan order rather than jumping around.
  final DateTime at;
}

final class WaterEvent extends TimelineEvent {
  const WaterEvent({
    required super.at,
    required this.entry,
    required this.runningTotalMl,
  });

  final WaterEntry entry;

  /// Total for the day including this drink, so a row can show progress as it
  /// stood at that moment.
  final int runningTotalMl;

  int get amountMl => entry.amountMl;
  bool get fromNotification => entry.fromNotification;
}

final class DoseEvent extends TimelineEvent {
  const DoseEvent({
    required super.at,
    required this.medicine,
    required this.status,
    required this.isScheduled,
    this.loggedAt,
  });

  final Medicine medicine;
  final DoseStatus status;

  /// Whether this row stands for a slot on the day's plan.
  ///
  /// Passed in rather than derived from [status], because the two can disagree: a
  /// dose logged as skipped on a day the medicine was never due reads as
  /// [DoseStatus.skipped] — that is what the user said — while belonging to no
  /// slot at all. Inferring this from the status counted such a dose towards the
  /// adherence denominator, so the printed figure disagreed with the day view.
  final bool isScheduled;

  /// When it was actually logged, when that differs from [at].
  final DateTime? loggedAt;

  /// Minutes between the scheduled slot and the actual log. Negative is early.
  int? get driftMinutes {
    final logged = loggedAt;
    if (logged == null || !isScheduled) return null;
    return logged.difference(at).inMinutes;
  }
}

/// Everything about one day, ready to render.
class DayTimeline {
  const DayTimeline({
    required this.date,
    required this.events,
    required this.waterTotalMl,
    required this.goalMl,
    required this.drinkCount,
    required this.dosesScheduled,
    required this.dosesTaken,
    required this.dosesMissed,
  });

  final DateTime date;

  /// Chronological.
  final List<TimelineEvent> events;

  final int waterTotalMl;
  final int goalMl;
  final int drinkCount;

  final int dosesScheduled;
  final int dosesTaken;
  final int dosesMissed;

  bool get isEmpty => events.isEmpty;

  double get progress => goalMl <= 0 ? 0 : waterTotalMl / goalMl;
  bool get goalMet => goalMl > 0 && waterTotalMl >= goalMl;
  int get remainingMl {
    final left = goalMl - waterTotalMl;
    return left > 0 ? left : 0;
  }

  double get adherence =>
      dosesScheduled <= 0 ? 0 : dosesTaken / dosesScheduled;
}

/// One medicine's record over a reporting period.
class AdherenceRow {
  const AdherenceRow({
    required this.medicine,
    required this.scheduled,
    required this.taken,
    required this.skipped,
    required this.missed,
    required this.extra,
  });

  final Medicine medicine;
  final int scheduled;
  final int taken;
  final int skipped;
  final int missed;
  final int extra;

  /// Against slots that have actually come due, so a month report read on the
  /// 3rd is not marked down for the other 28 days.
  int get due => taken + skipped + missed;
  double get rate => due <= 0 ? 0 : taken / due;
}

/// Merges the water log and the medicine schedule into a single day view.
///
/// The interesting part is reconciling *planned* doses with *logged* ones. The
/// log only records "this medicine was taken at this instant", with no reference
/// to which of the day's scheduled slots it belonged to, so the pairing has to be
/// inferred: each logged intake is attached to the nearest unclaimed slot for
/// that medicine. Anything left over is reported as [DoseStatus.extra] rather
/// than being hidden, and any slot still unclaimed is upcoming or missed
/// depending on whether its time has passed.
class TimelineService {
  const TimelineService({
    required this.entries,
    required this.intakes,
    required this.medicines,
    required this.goalMl,
  });

  final List<WaterEntry> entries;
  final List<MedicineIntake> intakes;
  final List<Medicine> medicines;
  final int goalMl;

  /// A dose logged this far from its slot is still considered that dose. Wider
  /// than it sounds on purpose: people take the 8am tablet at 9:40 and still
  /// mean the 8am one.
  static const Duration graceWindow = Duration(hours: 3);

  DayTimeline forDay(DateTime date, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final dayKey = WaterEntry.dayKeyFor(date);
    final events = <TimelineEvent>[];

    // --- Water ---------------------------------------------------------------
    final drinks =
        entries.where((entry) => entry.dayKey == dayKey).toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    var running = 0;
    for (final drink in drinks) {
      running += drink.amountMl;
      events.add(
        WaterEvent(
          at: drink.timestamp,
          entry: drink,
          runningTotalMl: running,
        ),
      );
    }

    // --- Medicines -----------------------------------------------------------
    var scheduled = 0;
    var taken = 0;
    var missed = 0;

    for (final medicine in medicines) {
      final logged =
          intakes
              .where(
                (intake) =>
                    intake.medicineId == medicine.id && intake.dayKey == dayKey,
              )
              .toList()
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // A disabled medicine has no plan for the day, but anything already logged
      // against it still belongs on the timeline.
      final slots = medicine.enabled && medicine.weekdays.contains(date.weekday)
          ? medicine.effectiveTimes
          : const <TimeOfDay>[];

      final slotTimes = [
        for (final time in slots)
          DateTime(date.year, date.month, date.day, time.hour, time.minute),
      ];

      final claimed = List<MedicineIntake?>.filled(slotTimes.length, null);
      final leftovers = <MedicineIntake>[];

      for (final intake in logged) {
        final index = _nearestFreeSlot(slotTimes, claimed, intake.timestamp);
        if (index == null) {
          leftovers.add(intake);
        } else {
          claimed[index] = intake;
        }
      }

      for (var i = 0; i < slotTimes.length; i++) {
        scheduled++;
        final intake = claimed[i];
        final DoseStatus status;
        if (intake == null) {
          status = slotTimes[i].isAfter(clock)
              ? DoseStatus.upcoming
              : DoseStatus.missed;
          if (status == DoseStatus.missed) missed++;
        } else if (intake.skipped) {
          status = DoseStatus.skipped;
        } else {
          status = DoseStatus.taken;
          taken++;
        }

        events.add(
          DoseEvent(
            at: slotTimes[i],
            medicine: medicine,
            status: status,
            isScheduled: true,
            loggedAt: intake?.timestamp,
          ),
        );
      }

      for (final intake in leftovers) {
        events.add(
          DoseEvent(
            at: intake.timestamp,
            medicine: medicine,
            status: intake.skipped ? DoseStatus.skipped : DoseStatus.extra,
            // No slot claimed this one, whatever the user called it.
            isScheduled: false,
            loggedAt: intake.timestamp,
          ),
        );
      }
    }

    // Water before a dose when they land on the same minute: the drink is the
    // thing the user did, the dose slot is a plan, and a stable tie-break keeps
    // the list from reshuffling between rebuilds.
    events.sort((a, b) {
      final byTime = a.at.compareTo(b.at);
      if (byTime != 0) return byTime;
      return _tieBreak(a).compareTo(_tieBreak(b));
    });

    return DayTimeline(
      date: DateTime(date.year, date.month, date.day),
      events: events,
      waterTotalMl: running,
      goalMl: goalMl,
      drinkCount: drinks.length,
      dosesScheduled: scheduled,
      dosesTaken: taken,
      dosesMissed: missed,
    );
  }

  /// Per-medicine tallies across an inclusive date range.
  ///
  /// Deliberately built by walking [forDay] rather than counting the intake log
  /// directly: the slot-matching rules live in one place, so the adherence figure
  /// in a PDF can never disagree with what the timeline showed on screen.
  List<AdherenceRow> adherenceBetween(
    DateTime start,
    DateTime end, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final tallies = <String, List<int>>{};
    final byId = <String, Medicine>{};

    var cursor = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    var guard = 0;
    while (!cursor.isAfter(last) && guard < 400) {
      guard++;
      for (final event in forDay(cursor, now: clock).events) {
        if (event is! DoseEvent) continue;
        byId[event.medicine.id] = event.medicine;
        final counts = tallies.putIfAbsent(
          event.medicine.id,
          () => List<int>.filled(5, 0),
        );
        // [scheduled, taken, skipped, missed, extra]
        //
        // Everything off the plan lands in `extra` regardless of its status,
        // because [AdherenceRow.due] adds taken + skipped + missed: letting an
        // unscheduled dose through to any of those three would put it in the
        // denominator of a rate it was never part of.
        if (!event.isScheduled) {
          counts[4]++;
          continue;
        }
        counts[0]++;
        switch (event.status) {
          case DoseStatus.taken:
            counts[1]++;
          case DoseStatus.skipped:
            counts[2]++;
          case DoseStatus.missed:
            counts[3]++;
          case DoseStatus.upcoming:
            break;
          case DoseStatus.extra:
            // Unreachable: an extra dose is never scheduled.
            break;
        }
      }
      // Adding 25 hours then truncating steps one calendar day even across a DST
      // change, where adding exactly 24 hours can land back on the same date.
      cursor = DateTime(cursor.year, cursor.month, cursor.day)
          .add(const Duration(hours: 25));
      cursor = DateTime(cursor.year, cursor.month, cursor.day);
    }

    final rows = [
      for (final entry in tallies.entries)
        AdherenceRow(
          medicine: byId[entry.key]!,
          scheduled: entry.value[0],
          taken: entry.value[1],
          skipped: entry.value[2],
          missed: entry.value[3],
          extra: entry.value[4],
        ),
    ]..sort((a, b) => a.medicine.name.toLowerCase().compareTo(
        b.medicine.name.toLowerCase(),
      ));
    return rows;
  }

  static int _tieBreak(TimelineEvent event) => event is WaterEvent ? 0 : 1;

  /// Index of the unclaimed slot closest to [when], or null if none is within
  /// [graceWindow]. Ties go to the earlier slot.
  static int? _nearestFreeSlot(
    List<DateTime> slots,
    List<MedicineIntake?> claimed,
    DateTime when,
  ) {
    int? best;
    int? bestDistance;
    for (var i = 0; i < slots.length; i++) {
      if (claimed[i] != null) continue;
      final distance = slots[i].difference(when).inMinutes.abs();
      if (distance > graceWindow.inMinutes) continue;
      if (bestDistance == null || distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    return best;
  }
}
