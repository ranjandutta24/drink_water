import 'package:flutter/material.dart';

import '../models/volume_unit.dart';
import '../models/water_log.dart';
import '../models/water_settings.dart';
import '../services/notification_service.dart';
import '../services/report_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/water_vessel.dart';
import 'water_settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final settings = state.settings;
    final reports = ReportService(
      entries: state.waterLog,
      goalMl: settings.dailyGoalMl,
    );
    final todayMl = reports.todayTotalMl;
    final progress = settings.dailyGoalMl <= 0
        ? 0.0
        : todayMl / settings.dailyGoalMl;
    final remaining = settings.dailyGoalMl - todayMl;

    final todayEntries = state.waterLog
        .where((entry) => entry.dayKey == WaterEntry.dayKeyFor(DateTime.now()))
        .toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          children: [
            _Greeting(streak: reports.currentStreak),
            const SizedBox(height: 18),
            Center(
              child: WaterVessel(
                progress: progress,
                primaryLabel: _vesselPrimary(todayMl, settings),
                secondaryLabel: remaining > 0
                    ? '${formatVolume(remaining, settings)} to go'
                    : 'Goal reached',
              ),
            ),
            const SizedBox(height: 22),
            _NextReminderLine(settings: settings),
            const SizedBox(height: 18),
            _QuickAddRow(settings: settings),
            const SizedBox(height: 12),
            _CustomAmountButton(settings: settings),
            const SizedBox(height: 26),
            SectionHeader(
              title: 'Today',
              trailing: todayEntries.isEmpty
                  ? null
                  : Text(
                      '${todayEntries.length} '
                      '${todayEntries.length == 1 ? 'drink' : 'drinks'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
            ),
            if (todayEntries.isEmpty)
              const EmptyState(
                icon: Icons.water_drop_outlined,
                title: 'Nothing logged yet',
                message: 'Tap an amount above to record your first drink of the day.',
              )
            else
              _TodayLog(entries: todayEntries, settings: settings),
          ],
        ),
      ),
    );
  }

  String _vesselPrimary(int ml, WaterSettings settings) {
    if (settings.displayUnit == VolumeUnit.ml) return '$ml';
    return formatVolume(ml, settings, withUnit: false);
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: Theme.of(context).textTheme.titleLarge),
              Text(
                formatDayLabel(DateTime.now()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (streak > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.of(context).aquaWash,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.bolt,
                  size: 16,
                  color: AppColors.of(context).aquaDeep,
                ),
                const SizedBox(width: 4),
                Text(
                  '$streak day${streak == 1 ? '' : 's'} on goal',
                  style: TextStyle(
                    color: AppColors.of(context).aquaDeep,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _NextReminderLine extends StatelessWidget {
  const _NextReminderLine({required this.settings});

  final WaterSettings settings;

  @override
  Widget build(BuildContext context) {
    final next = _nextReminder(settings);

    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const WaterSettingsScreen())),
      child: Row(
        children: [
          Icon(
            settings.remindersEnabled
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            color: settings.remindersEnabled
                ? AppColors.of(context).aqua
                : AppColors.of(context).inkSoft,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              !settings.remindersEnabled
                  ? 'Reminders are off'
                  : next == null
                  ? 'No reminders fit in your active hours'
                  : 'Next reminder at ${next.label(settings.use24hClock)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (settings.remindersEnabled)
            Text(
              'every ${formatInterval(settings.intervalMinutes)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(width: 6),
          Icon(
            Icons.chevron_right,
            size: 20,
            color: AppColors.of(context).inkSoft,
          ),
        ],
      ),
    );
  }

  /// Finds the next scheduled slot after now, wrapping to tomorrow's first slot.
  TimeOfDayLike? _nextReminder(WaterSettings settings) {
    final slots = NotificationService.waterReminderSlots(settings);
    if (slots.isEmpty) return null;
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final upcoming =
        slots.where((slot) => slot.minutesOfDay > nowMinutes).toList()
          ..sort((a, b) => a.minutesOfDay.compareTo(b.minutesOfDay));
    if (upcoming.isNotEmpty) return upcoming.first;
    final sorted = [...slots]
      ..sort((a, b) => a.minutesOfDay.compareTo(b.minutesOfDay));
    return sorted.first;
  }
}

class _QuickAddRow extends StatelessWidget {
  const _QuickAddRow({required this.settings});

  final WaterSettings settings;

  @override
  Widget build(BuildContext context) {
    final amounts = settings.quickAddAmountsMl;

    return Row(
      children: [
        for (var i = 0; i < amounts.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _AmountButton(
              amountMl: amounts[i],
              settings: settings,
              emphasised: amounts[i] == settings.effectiveReminderAmountMl,
            ),
          ),
        ],
      ],
    );
  }
}

class _AmountButton extends StatelessWidget {
  const _AmountButton({
    required this.amountMl,
    required this.settings,
    this.emphasised = false,
  });

  final int amountMl;
  final WaterSettings settings;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emphasised
          ? AppColors.of(context).aqua
          : AppColors.of(context).panel,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await AppScope.read(context).addWater(amountMl);
          if (!context.mounted) return;
          _showLoggedSnack(context, amountMl, settings);
        },
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: emphasised
                  ? AppColors.of(context).aqua
                  : AppColors.of(context).hairline,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add,
                size: 16,
                color: emphasised
                    ? AppColors.of(context).onAccent
                    : AppColors.of(context).aqua,
              ),
              const SizedBox(height: 2),
              Text(
                formatVolumeCompact(amountMl, settings),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  color: emphasised
                      ? AppColors.of(context).onAccent
                      : AppColors.of(context).ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomAmountButton extends StatelessWidget {
  const _CustomAmountButton({required this.settings});

  final WaterSettings settings;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _openCustomAmountSheet(context, settings),
      icon: const Icon(Icons.edit_outlined, size: 18),
      label: const Text('Log a different amount'),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
    );
  }
}

Future<void> _openCustomAmountSheet(
  BuildContext context,
  WaterSettings settings,
) async {
  final state = AppScope.read(context);

  final amount = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.of(context).panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _CustomAmountSheet(settings: settings),
  );

  if (amount == null || amount <= 0) return;
  await state.addWater(amount);
  if (!context.mounted) return;
  _showLoggedSnack(context, amount, settings);
}

/// The sheet is a StatefulWidget purely so it can own its TextEditingController.
/// Creating the controller outside and disposing it as soon as the sheet's
/// future completes is a trap: the sheet is still mounted while it slides away,
/// so the TextField keeps rebuilding against a disposed controller and the
/// resulting throw aborts the subtree's teardown ('_dependents.isEmpty').
class _CustomAmountSheet extends StatefulWidget {
  const _CustomAmountSheet({required this.settings});

  final WaterSettings settings;

  @override
  State<_CustomAmountSheet> createState() => _CustomAmountSheetState();
}

class _CustomAmountSheetState extends State<_CustomAmountSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    Navigator.of(context).pop(_parseToMl(raw, widget.settings));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        22,
        20,
        22 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How much did you drink?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              suffixText: widget.settings.displayUnit.shortLabel,
            ),
            onSubmitted: _submit,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _submit(_controller.text),
            child: const Text('Log it'),
          ),
        ],
      ),
    );
  }
}

int _parseToMl(String raw, WaterSettings settings) {
  final value = double.tryParse(raw.trim().replaceAll(',', '.'));
  if (value == null || value <= 0) return 0;
  return (value * settings.unitSizeMl).round();
}

void _showLoggedSnack(
  BuildContext context,
  int amountMl,
  WaterSettings settings,
) {
  final messenger = ScaffoldMessenger.of(context);
  final state = AppScope.read(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text('Logged ${formatVolume(amountMl, settings)}'),
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
        label: 'Undo',
        // Matches the snack bar's own text colour, which flips with the theme.
        textColor: Theme.of(context).snackBarTheme.contentTextStyle?.color,
        onPressed: state.undoLastEntry,
      ),
    ),
  );
}

class _TodayLog extends StatelessWidget {
  const _TodayLog({required this.entries, required this.settings});

  final List<WaterEntry> entries;
  final WaterSettings settings;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);

    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Dismissible(
              key: ValueKey(entries[i].id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: AppColors.of(context).clay,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: Icon(
                  Icons.delete_outline,
                  color: AppColors.of(context).onAccent,
                ),
              ),
              onDismissed: (_) => state.removeWaterEntry(entries[i].id),
              child: ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.of(context).aquaWash,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    entries[i].fromNotification
                        ? Icons.notifications_outlined
                        : Icons.water_drop,
                    size: 18,
                    color: AppColors.of(context).aquaDeep,
                  ),
                ),
                title: Text(
                  formatVolume(entries[i].amountMl, settings),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Text(
                  formatClock(
                    entries[i].timestamp,
                    use24h: settings.use24hClock,
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
