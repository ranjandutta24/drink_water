import 'dart:async';

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
import '../widgets/shell_nav.dart';
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
                message:
                    'Tap an amount above, then tap it again to confirm your '
                    'first drink of the day.',
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

    // This screen has no AppBar — the greeting *is* the header — so the drawer
    // handle gets a row of its own above the text. Putting it beside the
    // greeting instead would indent that one line away from the left margin
    // every other row on the page lines up on.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Transform.translate(
              offset: const Offset(-10, 0),
              child: const NavMenuButton(dense: true),
            ),
            const Spacer(),
            if (streak > 0) _StreakChip(streak: streak),
          ],
        ),
        const SizedBox(height: 4),
        Text(greeting, style: Theme.of(context).textTheme.titleLarge),
        Text(
          formatDayLabel(DateTime.now()),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: palette.aquaWash,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt, size: 16, color: palette.aquaDeep),
          const SizedBox(width: 4),
          Text(
            '$streak day${streak == 1 ? '' : 's'} on goal',
            style: TextStyle(
              color: palette.aquaDeep,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
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

/// Quick-add is deliberately two-tap: the first tap arms one button, the second
/// commits it. A phone in a pocket or a mis-aimed thumb can produce one tap, but
/// almost never two on the same target inside [_armedWindow], so the day's total
/// stays trustworthy without a dialog interrupting every drink.
class _QuickAddRow extends StatefulWidget {
  const _QuickAddRow({required this.settings});

  final WaterSettings settings;

  @override
  State<_QuickAddRow> createState() => _QuickAddRowState();
}

class _QuickAddRowState extends State<_QuickAddRow> {
  /// Long enough to read the hint and tap again, short enough that a forgotten
  /// armed button cannot be committed much later by accident.
  static const Duration _armedWindow = Duration(seconds: 4);

  int? _armedIndex;
  Timer? _disarmTimer;
  ScrollNotificationObserverState? _scrollObserver;

  @override
  void didUpdateWidget(_QuickAddRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // quickAddAmountsMl is derived from the glass and bottle sizes and is a Set,
    // so editing those can both reorder it and shorten it. An armed index left
    // over from the old list would confirm an amount the button never showed,
    // or point past the end of the new one.
    final before = oldWidget.settings.quickAddAmountsMl;
    final now = widget.settings.quickAddAmountsMl;
    final sameList =
        before.length == now.length &&
        List.generate(now.length, (i) => before[i] == now[i]).every((e) => e);
    if (!sameList) _disarm();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Scrolling the page is a strong signal the user has moved on, so it should
    // cancel a pending confirmation. Null-safe because the observer only exists
    // under a Scaffold.
    final observer = ScrollNotificationObserver.maybeOf(context);
    if (observer == _scrollObserver) return;
    _scrollObserver?.removeListener(_onScroll);
    _scrollObserver = observer;
    _scrollObserver?.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollObserver?.removeListener(_onScroll);
    _disarmTimer?.cancel();
    super.dispose();
  }

  void _onScroll(ScrollNotification notification) {
    if (_armedIndex == null) return;
    if (notification is ScrollStartNotification) _disarm();
  }

  void _disarm() {
    _disarmTimer?.cancel();
    _disarmTimer = null;
    if (_armedIndex != null && mounted) setState(() => _armedIndex = null);
  }

  void _handleTap(int index, int amountMl) {
    if (_armedIndex != index) {
      // Arming a different amount replaces the previous one rather than
      // stacking, so only ever one button is live.
      setState(() => _armedIndex = index);
      _disarmTimer?.cancel();
      _disarmTimer = Timer(_armedWindow, _disarm);
      return;
    }
    _disarm();
    _log(amountMl);
  }

  Future<void> _log(int amountMl) async {
    final state = AppScope.read(context);
    await state.addWater(amountMl);
    if (!mounted) return;
    _showLoggedSnack(context, amountMl, widget.settings);
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final amounts = settings.quickAddAmountsMl;
    // Belt and braces alongside didUpdateWidget: never index past the row.
    final index = _armedIndex;
    final armed = (index != null && index < amounts.length) ? index : null;

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < amounts.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _AmountButton(
                  amountMl: amounts[i],
                  settings: settings,
                  emphasised: amounts[i] == settings.effectiveReminderAmountMl,
                  armed: armed == i,
                  onTap: () => _handleTap(i, amounts[i]),
                ),
              ),
            ],
          ],
        ),
        // Reserves no space when idle, so the buttons do not shift the page.
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: armed == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Tap ${formatVolume(amounts[armed], settings)} again '
                    'to log it',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.of(context).kelp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _AmountButton extends StatelessWidget {
  const _AmountButton({
    required this.amountMl,
    required this.settings,
    required this.armed,
    required this.onTap,
    this.emphasised = false,
  });

  final int amountMl;
  final WaterSettings settings;

  /// Waiting for its second tap.
  final bool armed;
  final VoidCallback onTap;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final label = formatVolumeCompact(amountMl, settings);

    // Armed wins over emphasised: green reads as "about to happen" and is the
    // only green on this screen, so it cannot be mistaken for the blue default.
    final Color fill = armed
        ? palette.kelp
        : emphasised
        ? palette.aqua
        : palette.panel;
    final Color border = armed
        ? palette.kelp
        : emphasised
        ? palette.aqua
        : palette.hairline;
    final Color foreground = armed || emphasised
        ? palette.onAccent
        : palette.ink;

    return Semantics(
      button: true,
      label: armed
          ? 'Confirm logging ${formatVolume(amountMl, settings)}'
          : 'Log ${formatVolume(amountMl, settings)}, tap twice to confirm',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(
              height: 66,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    armed ? Icons.check_rounded : Icons.add,
                    size: armed ? 19 : 16,
                    color: armed || emphasised
                        ? palette.onAccent
                        : palette.aqua,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
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
