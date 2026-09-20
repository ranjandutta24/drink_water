import 'package:flutter/material.dart';

import '../models/medicine.dart';
import '../models/time_of_day_x.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Add or edit a single medicine: name, dosage, which weekdays, and any number
/// of times per day.
class MedicineEditorScreen extends StatefulWidget {
  const MedicineEditorScreen({super.key, this.existing});

  final Medicine? existing;

  @override
  State<MedicineEditorScreen> createState() => _MedicineEditorScreenState();
}

class _MedicineEditorScreenState extends State<MedicineEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _dosage;
  late final TextEditingController _notes;

  late Set<int> _weekdays;
  late List<TimeOfDay> _times;
  late MealRelation _mealRelation;
  late int _colorIndex;

  late MedicineSchedule _schedule;
  late int _intervalHours;
  late TimeOfDay _intervalStart;
  late TimeOfDay _intervalEnd;

  bool get _isNew => widget.existing == null;

  /// What will actually be saved: the hand-picked list, or the times the
  /// interval rule works out to.
  List<TimeOfDay> get _resolvedTimes => _schedule == MedicineSchedule.interval
      ? Medicine.buildIntervalTimes(
          intervalHours: _intervalHours,
          start: _intervalStart,
          end: _intervalEnd,
        )
      : _times;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _dosage = TextEditingController(text: existing?.dosage ?? '');
    _notes = TextEditingController(text: existing?.notes ?? '');
    _weekdays = {...?existing?.weekdays};
    if (_weekdays.isEmpty) _weekdays = {1, 2, 3, 4, 5, 6, 7};
    _times = [...?existing?.times];
    if (_times.isEmpty) _times = [const TimeOfDay(hour: 9, minute: 0)];
    _mealRelation = existing?.mealRelation ?? MealRelation.none;
    _colorIndex = existing?.colorIndex ?? 0;
    _schedule = existing?.schedule ?? MedicineSchedule.times;
    _intervalHours = existing?.intervalHours ?? Medicine.kDefaultIntervalHours;
    _intervalStart =
        existing?.intervalStart ?? const TimeOfDay(hour: 8, minute: 0);
    _intervalEnd =
        existing?.intervalEnd ?? const TimeOfDay(hour: 22, minute: 0);
  }

  @override
  void dispose() {
    _name.dispose();
    _dosage.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final use24h = AppScope.of(context).settings.use24hClock;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Add medicine' : 'Edit medicine'),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
          children: [
            Panel(
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Medicine name',
                      hintText: 'Metformin',
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Give the medicine a name'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _dosage,
                    decoration: const InputDecoration(
                      labelText: 'Dosage (optional)',
                      hintText: '1 tablet, 500 mg',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionHeader(title: 'Times of day'),
            _ScheduleModePicker(
              selected: _schedule,
              onSelected: (schedule) => setState(() => _schedule = schedule),
            ),
            const SizedBox(height: 12),
            if (_schedule == MedicineSchedule.times)
              _TimesPanel(
                times: _times,
                use24h: use24h,
                onAdd: _addTime,
                onEdit: _editTime,
                onRemove: (index) => setState(() => _times.removeAt(index)),
              )
            else
              _IntervalPanel(
                intervalHours: _intervalHours,
                start: _intervalStart,
                end: _intervalEnd,
                generated: _resolvedTimes,
                use24h: use24h,
                onIntervalChanged: (hours) =>
                    setState(() => _intervalHours = hours),
                onPickStart: () => _pickWindowEdge(isStart: true),
                onPickEnd: () => _pickWindowEdge(isStart: false),
              ),
            const SizedBox(height: 22),
            const SectionHeader(title: 'Days'),
            _WeekdayPanel(
              selected: _weekdays,
              onToggle: (day) => setState(() {
                if (_weekdays.contains(day)) {
                  _weekdays.remove(day);
                } else {
                  _weekdays.add(day);
                }
              }),
              onPreset: (days) => setState(() => _weekdays = {...days}),
            ),
            const SizedBox(height: 22),
            const SectionHeader(title: 'Extras'),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Food', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final relation in MealRelation.values)
                        ChoiceChip(
                          label: Text(relation.label),
                          selected: _mealRelation == relation,
                          showCheckmark: false,
                          backgroundColor: AppColors.of(context).panel,
                          selectedColor: AppColors.of(context).irisWash,
                          side: BorderSide(
                            color: AppColors.of(context).hairline,
                          ),
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _mealRelation == relation
                                ? AppColors.of(context).iris
                                : AppColors.of(context).ink,
                          ),
                          onSelected: (_) =>
                              setState(() => _mealRelation = relation),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _notes,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Note shown in the reminder (optional)',
                      hintText: 'Take with a full glass of water',
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Colour', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (
                        var i = 0;
                        i < AppColors.of(context).medicinePalette.length;
                        i++
                      ) ...[
                        if (i > 0) const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => setState(() => _colorIndex = i),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.of(context).medicinePalette[i],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _colorIndex == i
                                    ? AppColors.of(context).ink
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _SummaryLine(times: _resolvedTimes.length, days: _weekdays.length),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
          child: FilledButton(
            onPressed: _save,
            child: Text(_isNew ? 'Add medicine' : 'Save changes'),
          ),
        ),
      ),
    );
  }

  Future<void> _addTime() async {
    // The notification id scheme allots two digits per time slot, so the
    // hand-picked list needs the same ceiling the generated one has.
    if (_times.length >= Medicine.maxIntervalTimes) {
      _snack('That is as many times a day as a reminder can hold');
      return;
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null || !mounted) return;
    if (_times.any((time) => time.minutesOfDay == picked.minutesOfDay)) {
      _snack('That time is already on the list');
      return;
    }
    setState(() => _times.add(picked));
  }

  Future<void> _pickWindowEdge({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _intervalStart : _intervalEnd,
      helpText: isStart ? 'First reminder of the day' : 'Stop reminding after',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _intervalStart = picked;
      } else {
        _intervalEnd = picked;
      }
    });
  }

  Future<void> _editTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _times[index],
    );
    if (picked == null || !mounted) return;
    setState(() => _times[index] = picked);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final times = _resolvedTimes;
    if (times.isEmpty) {
      _snack(
        _schedule == MedicineSchedule.interval
            ? 'That window is too short for this interval'
            : 'Add at least one time of day',
      );
      return;
    }
    if (_weekdays.isEmpty) {
      _snack('Pick at least one day');
      return;
    }

    final medicine = Medicine(
      id: widget.existing?.id ?? 'm${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim(),
      dosage: _dosage.text.trim(),
      notes: _notes.text.trim(),
      mealRelation: _mealRelation,
      weekdays: _weekdays,
      // Stored materialised either way, so scheduling and history never have to
      // know which mode produced them.
      times: times,
      enabled: widget.existing?.enabled ?? true,
      colorIndex: _colorIndex,
      schedule: _schedule,
      intervalHours: _intervalHours,
      intervalStart: _intervalStart,
      intervalEnd: _intervalEnd,
    );

    final navigator = Navigator.of(context);
    await AppScope.read(context).upsertMedicine(medicine);
    if (!mounted) return;
    navigator.pop();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${widget.existing?.name}?'),
        content: const Text(
          'Its reminders will be cancelled. Past doses stay in your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.of(context).clay,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final navigator = Navigator.of(context);
    await AppScope.read(context).deleteMedicine(widget.existing!.id);
    if (!mounted) return;
    navigator.pop();
  }
}

/// Chooses between hand-picked times and a repeating interval. Two rows rather
/// than a segmented control so each option can carry its one-line explanation.
class _ScheduleModePicker extends StatelessWidget {
  const _ScheduleModePicker({required this.selected, required this.onSelected});

  final MedicineSchedule selected;
  final ValueChanged<MedicineSchedule> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final schedule in MedicineSchedule.values) ...[
            if (schedule != MedicineSchedule.values.first)
              Divider(height: 1, color: palette.hairline),
            Semantics(
              button: true,
              selected: selected == schedule,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () => onSelected(schedule),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          schedule == MedicineSchedule.times
                              ? Icons.schedule_outlined
                              : Icons.repeat_rounded,
                          size: 20,
                          color: selected == schedule
                              ? palette.aquaDeep
                              : palette.inkSoft,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                schedule.label,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: selected == schedule
                                      ? palette.aquaDeep
                                      : palette.ink,
                                ),
                              ),
                              Text(
                                schedule.note,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          selected == schedule
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: selected == schedule
                              ? palette.aqua
                              : palette.inkSoft,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The interval editor: how often, between which hours, and what that works out
/// to. The generated list is shown because "every 4 hours" alone hides whether
/// the last dose lands at a sensible hour.
class _IntervalPanel extends StatelessWidget {
  const _IntervalPanel({
    required this.intervalHours,
    required this.start,
    required this.end,
    required this.generated,
    required this.use24h,
    required this.onIntervalChanged,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final int intervalHours;
  final TimeOfDay start;
  final TimeOfDay end;
  final List<TimeOfDay> generated;
  final bool use24h;
  final ValueChanged<int> onIntervalChanged;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Remind me', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final hours in Medicine.intervalChoices)
                ChoiceChip(
                  label: Text(hours == 1 ? 'Hourly' : 'Every $hours h'),
                  selected: intervalHours == hours,
                  showCheckmark: false,
                  backgroundColor: palette.panel,
                  selectedColor: palette.aquaWash,
                  side: BorderSide(
                    color: intervalHours == hours
                        ? palette.aqua
                        : palette.hairline,
                  ),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: intervalHours == hours
                        ? palette.aquaDeep
                        : palette.ink,
                  ),
                  onSelected: (_) => onIntervalChanged(hours),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _WindowEdge(
                  label: 'From',
                  time: start,
                  use24h: use24h,
                  onTap: onPickStart,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WindowEdge(
                  label: 'Until',
                  time: end,
                  use24h: use24h,
                  onTap: onPickEnd,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            generated.isEmpty
                ? 'No reminders fit — widen the window or pick a shorter '
                      'interval.'
                : 'That works out to ${generated.length} '
                      'reminder${generated.length == 1 ? '' : 's'} a day:',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (generated.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final time in generated)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: palette.aquaWash,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      formatTime(time, use24h: use24h),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: palette.aquaDeep,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WindowEdge extends StatelessWidget {
  const _WindowEdge({
    required this.label,
    required this.time,
    required this.use24h,
    required this.onTap,
  });

  final String label;
  final TimeOfDay time;
  final bool use24h;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return Semantics(
      button: true,
      label: '$label ${formatTime(time, use24h: use24h)}',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  formatTime(time, use24h: use24h),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: palette.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimesPanel extends StatelessWidget {
  const _TimesPanel({
    required this.times,
    required this.use24h,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
  });

  final List<TimeOfDay> times;
  final bool use24h;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final indexed = List.generate(times.length, (index) => index)
      ..sort((a, b) => times[a].minutesOfDay.compareTo(times[b].minutesOfDay));

    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final index in indexed) ...[
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(
                formatTime(times[index], use24h: use24h),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () => onEdit(index),
              trailing: times.length == 1
                  ? null
                  : IconButton(
                      tooltip: 'Remove time',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => onRemove(index),
                    ),
            ),
            const Divider(height: 1),
          ],
          ListTile(
            leading: Icon(Icons.add, color: AppColors.of(context).aquaDeep),
            title: Text(
              'Add a time',
              style: TextStyle(
                color: AppColors.of(context).aquaDeep,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: onAdd,
          ),
        ],
      ),
    );
  }
}

class _WeekdayPanel extends StatelessWidget {
  const _WeekdayPanel({
    required this.selected,
    required this.onToggle,
    required this.onPreset,
  });

  final Set<int> selected;
  final ValueChanged<int> onToggle;
  final ValueChanged<Set<int>> onPreset;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _names = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var day = 1; day <= 7; day++)
                Semantics(
                  label: _names[day - 1],
                  selected: selected.contains(day),
                  child: GestureDetector(
                    onTap: () => onToggle(day),
                    child: Container(
                      width: 40,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected.contains(day)
                            ? AppColors.of(context).aqua
                            : AppColors.of(context).panel,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected.contains(day)
                              ? AppColors.of(context).aqua
                              : AppColors.of(context).hairline,
                        ),
                      ),
                      child: Text(
                        _labels[day - 1],
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: selected.contains(day)
                              ? AppColors.of(context).onAccent
                              : AppColors.of(context).inkSoft,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => onPreset({1, 2, 3, 4, 5, 6, 7}),
                child: const Text('Every day'),
              ),
              TextButton(
                onPressed: () => onPreset({1, 2, 3, 4, 5}),
                child: const Text('Weekdays'),
              ),
              TextButton(
                onPressed: () => onPreset({6, 7}),
                child: const Text('Weekends'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.times, required this.days});

  final int times;
  final int days;

  @override
  Widget build(BuildContext context) {
    final total = times * days;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.of(context).irisWash,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.of(context).iris),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              total == 0
                  ? 'Pick at least one day and one time.'
                  : 'That is $total reminder${total == 1 ? '' : 's'} a week.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.of(context).ink),
            ),
          ),
        ],
      ),
    );
  }
}
