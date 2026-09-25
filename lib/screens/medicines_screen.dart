import 'package:flutter/material.dart';

import '../models/medicine.dart';
import '../models/time_of_day_x.dart';
import '../services/timeline_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/shell_nav.dart';
import 'medicine_editor_screen.dart';

class MedicinesScreen extends StatelessWidget {
  const MedicinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final medicines = state.medicines;
    final use24h = state.settings.use24hClock;
    final todayDoses = _dosesToday(state);

    return Scaffold(
      appBar: AppBar(
        leading: const NavMenuButton(),
        title: const Text('Medicines'),
        actions: [
          if (medicines.isNotEmpty)
            IconButton(
              tooltip: 'Add medicine',
              icon: const Icon(Icons.add),
              onPressed: () => _openEditor(context),
            ),
        ],
      ),
      body: medicines.isEmpty
          ? ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
              children: [
                EmptyState(
                  icon: Icons.medication_outlined,
                  title: 'No medicines yet',
                  message:
                      'Add a medicine and pick the days and times you need to '
                      'take it. Reminders fire even when the app is closed.',
                  action: FilledButton(
                    onPressed: () => _openEditor(context),
                    child: const Text('Add a medicine'),
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
              children: [
                if (todayDoses.isNotEmpty) ...[
                  const SectionHeader(title: 'Due today'),
                  _TodayDoses(doses: todayDoses, use24h: use24h),
                  const SizedBox(height: 24),
                ],
                SectionHeader(
                  title: 'All medicines',
                  trailing: Text(
                    '${medicines.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                for (final medicine in medicines) ...[
                  _MedicineCard(medicine: medicine, use24h: use24h),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _openEditor(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add another medicine'),
                ),
              ],
            ),
    );
  }

  /// Today's scheduled doses, already paired with whatever has been logged
  /// against them.
  ///
  /// Read from [TimelineService] rather than walked out of the medicine list
  /// here, so this screen and the dashboard cannot disagree about which dose is
  /// still outstanding — the matching rules exist in exactly one place. No water
  /// entries are passed because this screen has no use for the drink rows.
  static List<DoseEvent> _dosesToday(AppState state) {
    final timeline = TimelineService(
      entries: const [],
      intakes: state.medicineLog,
      medicines: state.medicines,
      goalMl: state.settings.dailyGoalMl,
    ).forDay(DateTime.now());

    return [
      for (final event in timeline.events)
        if (event is DoseEvent && event.isScheduled) event,
    ];
  }

  static void _openEditor(BuildContext context, [Medicine? medicine]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MedicineEditorScreen(existing: medicine),
      ),
    );
  }
}

/// The day's doses, one row per scheduled time.
///
/// Each row answers for its own slot and nothing else. It used to ask "has this
/// medicine been taken today", which turned every remaining row green the moment
/// one of them was tapped — a medicine due four times a day could only ever be
/// marked once.
class _TodayDoses extends StatelessWidget {
  const _TodayDoses({required this.doses, required this.use24h});

  final List<DoseEvent> doses;
  final bool use24h;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < doses.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _DoseRow(dose: doses[i], use24h: use24h, palette: palette),
          ],
        ],
      ),
    );
  }
}

class _DoseRow extends StatelessWidget {
  const _DoseRow({
    required this.dose,
    required this.use24h,
    required this.palette,
  });

  final DoseEvent dose;
  final bool use24h;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    final settled =
        dose.status == DoseStatus.taken || dose.status == DoseStatus.skipped;

    return ListTile(
      leading: SizedBox(
        width: 62,
        child: Text(
          formatClock(dose.at, use24h: use24h),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: dose.status == DoseStatus.upcoming
                ? palette.ink
                : palette.inkSoft,
          ),
        ),
      ),
      title: Text(
        dose.medicine.name,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(_note(), style: Theme.of(context).textTheme.bodySmall),
      trailing: settled
          ? Icon(
              dose.status == DoseStatus.taken
                  ? Icons.check_circle
                  : Icons.remove_circle_outline,
              color: dose.status == DoseStatus.taken
                  ? palette.kelp
                  : palette.inkSoft,
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => _record(context, state, skipped: true),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: palette.inkSoft,
                  ),
                  child: const Text('Skip'),
                ),
                TextButton(
                  onPressed: () => _record(context, state, skipped: false),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: palette.aquaDeep,
                  ),
                  child: const Text('Taken'),
                ),
              ],
            ),
    );
  }

  /// The dosage when there is one, otherwise how the slot stands — a row with no
  /// dosage and no note reads as though something failed to load.
  String _note() {
    final dosage = dose.medicine.dosage.trim();
    final status = switch (dose.status) {
      DoseStatus.taken => 'Taken',
      DoseStatus.skipped => 'Skipped',
      DoseStatus.missed => 'Not logged',
      DoseStatus.upcoming => 'Due',
      // Unreachable: this list only carries scheduled slots.
      DoseStatus.extra => 'Extra dose',
    };
    return dosage.isEmpty ? status : '$dosage · $status';
  }

  Future<void> _record(
    BuildContext context,
    AppState state, {
    required bool skipped,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    // The slot, not the clock: this is what keeps the answer on the row that
    // was tapped even when the tap comes hours after the dose was due.
    await state.recordMedicineTaken(
      dose.medicine.id,
      scheduledFor: dose.at,
      skipped: skipped,
    );
    if (!context.mounted) return;
    final clock = formatClock(dose.at, use24h: use24h);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          skipped
              ? '${dose.medicine.name} at $clock marked as skipped'
              : '${dose.medicine.name} at $clock marked as taken',
        ),
      ),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard({required this.medicine, required this.use24h});

  final Medicine medicine;
  final bool use24h;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    final accent =
        AppColors.of(context).medicinePalette[medicine.colorIndex %
            AppColors.of(context).medicinePalette.length];

    return Panel(
      accent: medicine.enabled ? accent : AppColors.of(context).hairline,
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MedicineEditorScreen(existing: medicine),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicine.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: medicine.enabled
                            ? AppColors.of(context).ink
                            : AppColors.of(context).inkSoft,
                      ),
                    ),
                    if (medicine.dosage.trim().isNotEmpty ||
                        medicine.mealRelation != MealRelation.none)
                      Text(
                        [
                          if (medicine.dosage.trim().isNotEmpty)
                            medicine.dosage.trim(),
                          if (medicine.mealRelation != MealRelation.none)
                            medicine.mealRelation.label,
                        ].join(', '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              Switch(
                value: medicine.enabled,
                onChanged: (value) => state.toggleMedicine(medicine.id, value),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // An interval medicine gets one chip describing the rule. Listing
              // its generated times would fill the card with a dozen of them and
              // still not say "every 4 hours".
              for (final label
                  in medicine.schedule == MedicineSchedule.interval
                      ? [medicine.scheduleLabel(use24h: use24h)]
                      : medicine.sortedTimes
                            .map((time) => formatTime(time, use24h: use24h))
                            .toList())
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: medicine.enabled
                        ? accent.withValues(alpha: 0.10)
                        : AppColors.of(context).canvas,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: medicine.enabled
                          ? accent
                          : AppColors.of(context).inkSoft,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: AppColors.of(context).inkSoft,
              ),
              const SizedBox(width: 6),
              Text(
                medicine.weekdaysLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                '${medicine.dosesPerWeek} a week',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
    );
  }
}
