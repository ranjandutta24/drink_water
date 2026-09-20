import 'package:flutter/material.dart';

import '../models/medicine.dart';
import '../models/time_of_day_x.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'medicine_editor_screen.dart';

class MedicinesScreen extends StatelessWidget {
  const MedicinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final medicines = state.medicines;
    final use24h = state.settings.use24hClock;
    final todayDoses = _dosesToday(medicines);

    return Scaffold(
      appBar: AppBar(
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

  static List<_Dose> _dosesToday(List<Medicine> medicines) {
    final weekday = DateTime.now().weekday;
    final doses = <_Dose>[];
    for (final medicine in medicines) {
      if (!medicine.enabled) continue;
      if (!medicine.weekdays.contains(weekday)) continue;
      for (final time in medicine.sortedTimes) {
        doses.add(_Dose(medicine: medicine, time: time));
      }
    }
    doses.sort((a, b) => a.time.minutesOfDay.compareTo(b.time.minutesOfDay));
    return doses;
  }

  static void _openEditor(BuildContext context, [Medicine? medicine]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MedicineEditorScreen(existing: medicine),
      ),
    );
  }
}

class _Dose {
  _Dose({required this.medicine, required this.time});

  final Medicine medicine;
  final TimeOfDay time;
}

class _TodayDoses extends StatelessWidget {
  const _TodayDoses({required this.doses, required this.use24h});

  final List<_Dose> doses;
  final bool use24h;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    final now = TimeOfDay.now().minutesOfDay;

    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < doses.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              leading: SizedBox(
                width: 62,
                child: Text(
                  formatTime(doses[i].time, use24h: use24h),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: doses[i].time.minutesOfDay < now
                        ? AppColors.of(context).inkSoft
                        : AppColors.of(context).ink,
                  ),
                ),
              ),
              title: Text(
                doses[i].medicine.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: doses[i].medicine.dosage.trim().isEmpty
                  ? null
                  : Text(
                      doses[i].medicine.dosage,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
              trailing: state.takenToday(doses[i].medicine.id)
                  ? Icon(Icons.check_circle, color: AppColors.of(context).kelp)
                  : TextButton(
                      onPressed: () async {
                        await state.recordMedicineTaken(doses[i].medicine.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${doses[i].medicine.name} marked as taken',
                            ),
                          ),
                        );
                      },
                      child: const Text('Mark taken'),
                    ),
            ),
          ],
        ],
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
              for (final time in medicine.sortedTimes)
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
                    formatTime(time, use24h: use24h),
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
