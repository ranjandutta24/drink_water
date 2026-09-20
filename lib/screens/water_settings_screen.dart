import 'package:flutter/material.dart';

import '../models/time_of_day_x.dart';
import '../models/volume_unit.dart';
import '../models/water_settings.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class WaterSettingsScreen extends StatelessWidget {
  const WaterSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final settings = state.settings;

    Future<void> update(WaterSettings next) => state.updateSettings(next);

    return Scaffold(
      appBar: AppBar(title: const Text('Water reminders')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.remindersEnabled,
              onChanged: (value) =>
                  update(settings.copyWith(remindersEnabled: value)),
              title: const Text(
                'Remind me to drink',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                settings.remindersEnabled
                    ? '${settings.remindersPerDay} reminders a day'
                    : 'No notifications will be sent',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 22),
          const SectionHeader(title: 'How often'),
          _IntervalPanel(settings: settings, onChanged: update),
          const SizedBox(height: 22),
          const SectionHeader(title: 'Active hours'),
          _WindowPanel(settings: settings, onChanged: update),
          const SizedBox(height: 22),
          const SectionHeader(title: 'Units and sizes'),
          _UnitsPanel(settings: settings, onChanged: update),
          const SizedBox(height: 22),
          const SectionHeader(title: 'Daily goal'),
          _GoalPanel(settings: settings, onChanged: update),
          const SizedBox(height: 22),
          const SectionHeader(title: 'Amount per reminder'),
          _ReminderAmountPanel(settings: settings, onChanged: update),
          const SizedBox(height: 22),
          const SectionHeader(title: 'Delivery'),
          _DeliveryPanel(settings: settings, onChanged: update),
          const SizedBox(height: 22),
          _SchedulePreview(settings: settings),
        ],
      ),
    );
  }
}

class _IntervalPanel extends StatelessWidget {
  const _IntervalPanel({required this.settings, required this.onChanged});

  final WaterSettings settings;
  final ValueChanged<WaterSettings> onChanged;

  static const _presets = [15, 30, 45, 60, 90, 120, 180];

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatInterval(settings.intervalMinutes),
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'between reminders',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Slider(
            value: settings.intervalMinutes.toDouble(),
            min: 15,
            max: 240,
            divisions: 45,
            activeColor: AppColors.aqua,
            label: formatInterval(settings.intervalMinutes),
            onChanged: (value) {
              // Snap to 5 minute steps — nobody needs a 37 minute interval.
              final snapped = (value / 5).round() * 5;
              onChanged(settings.copyWith(intervalMinutes: snapped));
            },
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final minutes in _presets)
                ChoiceChip(
                  label: Text(formatInterval(minutes)),
                  selected: settings.intervalMinutes == minutes,
                  showCheckmark: false,
                  selectedColor: AppColors.aqua,
                  side: const BorderSide(color: AppColors.hairline),
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: settings.intervalMinutes == minutes
                        ? Colors.white
                        : AppColors.marine,
                  ),
                  onSelected: (_) =>
                      onChanged(settings.copyWith(intervalMinutes: minutes)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WindowPanel extends StatelessWidget {
  const _WindowPanel({required this.settings, required this.onChanged});

  final WaterSettings settings;
  final ValueChanged<WaterSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _TimeRow(
            label: 'First reminder',
            time: settings.startTime,
            use24h: settings.use24hClock,
            onPicked: (time) => onChanged(settings.copyWith(startTime: time)),
          ),
          const Divider(height: 1),
          _TimeRow(
            label: 'Last reminder',
            time: settings.endTime,
            use24h: settings.use24hClock,
            onPicked: (time) => onChanged(settings.copyWith(endTime: time)),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Text(
              'Reminders stay inside this window so you are not woken at night. '
              'If your last reminder is earlier than your first, the window '
              'runs overnight.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.time,
    required this.use24h,
    required this.onPicked,
  });

  final String label;
  final TimeOfDay time;
  final bool use24h;
  final ValueChanged<TimeOfDay> onPicked;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: Text(
        formatTime(time, use24h: use24h),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.aquaDeep,
        ),
      ),
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) onPicked(picked);
      },
    );
  }
}

class _UnitsPanel extends StatelessWidget {
  const _UnitsPanel({required this.settings, required this.onChanged});

  final WaterSettings settings;
  final ValueChanged<WaterSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Show amounts as',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          SegmentedButton<VolumeUnit>(
            segments: [
              for (final unit in VolumeUnit.values)
                ButtonSegment(value: unit, label: Text(unit.shortLabel)),
            ],
            selected: {settings.displayUnit},
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              backgroundColor: Colors.white,
              selectedBackgroundColor: AppColors.aquaWash,
              selectedForegroundColor: AppColors.aquaDeep,
              side: const BorderSide(color: AppColors.hairline),
            ),
            onSelectionChanged: (selection) =>
                onChanged(settings.copyWith(displayUnit: selection.first)),
          ),
          const SizedBox(height: 18),
          _SizeField(
            label: 'One glass holds',
            valueMl: settings.glassSizeMl,
            onChanged: (value) => onChanged(settings.copyWith(glassSizeMl: value)),
          ),
          const SizedBox(height: 12),
          _SizeField(
            label: 'One bottle holds',
            valueMl: settings.bottleSizeMl,
            onChanged: (value) =>
                onChanged(settings.copyWith(bottleSizeMl: value)),
          ),
          const SizedBox(height: 12),
          Text(
            'Everything is stored in millilitres, so you can switch units any '
            'time without changing your history.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SizeField extends StatefulWidget {
  const _SizeField({
    required this.label,
    required this.valueMl,
    required this.onChanged,
  });

  final String label;
  final int valueMl;
  final ValueChanged<int> onChanged;

  @override
  State<_SizeField> createState() => _SizeFieldState();
}

class _SizeFieldState extends State<_SizeField> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.valueMl}',
  );

  @override
  void didUpdateWidget(_SizeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.valueMl != oldWidget.valueMl &&
        '${widget.valueMl}' != _controller.text) {
      _controller.text = '${widget.valueMl}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(widget.label)),
        SizedBox(
          width: 118,
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.end,
            decoration: const InputDecoration(
              suffixText: 'ml',
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            onSubmitted: _commit,
            onTapOutside: (_) {
              FocusScope.of(context).unfocus();
              _commit(_controller.text);
            },
          ),
        ),
      ],
    );
  }

  void _commit(String raw) {
    final value = int.tryParse(raw.trim());
    if (value != null && value > 0) {
      widget.onChanged(value);
    } else {
      _controller.text = '${widget.valueMl}';
    }
  }
}

class _GoalPanel extends StatelessWidget {
  const _GoalPanel({required this.settings, required this.onChanged});

  final WaterSettings settings;
  final ValueChanged<WaterSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final step = settings.displayUnit == VolumeUnit.ml ? 100 : 250;

    return Panel(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatVolume(settings.dailyGoalMl, settings),
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'a day',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          _StepperButton(
            icon: Icons.remove,
            onPressed: settings.dailyGoalMl - step >= 200
                ? () => onChanged(
                    settings.copyWith(dailyGoalMl: settings.dailyGoalMl - step),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          _StepperButton(
            icon: Icons.add,
            onPressed: settings.dailyGoalMl + step <= 20000
                ? () => onChanged(
                    settings.copyWith(dailyGoalMl: settings.dailyGoalMl + step),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(46, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}

class _ReminderAmountPanel extends StatelessWidget {
  const _ReminderAmountPanel({
    required this.settings,
    required this.onChanged,
  });

  final WaterSettings settings;
  final ValueChanged<WaterSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final custom = settings.amountPerReminderMl != null;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Optional. When set, each reminder suggests this amount and the '
            '"Drank it" button logs exactly this much.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  custom
                      ? formatVolume(settings.amountPerReminderMl!, settings)
                      : 'Using one glass '
                            '(${settings.glassSizeMl} ml)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (custom)
                TextButton(
                  onPressed: () =>
                      onChanged(settings.copyWith(clearAmountPerReminder: true)),
                  child: const Text('Clear'),
                ),
              TextButton(
                onPressed: () => _pickAmount(context),
                child: Text(custom ? 'Change' : 'Set amount'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickAmount(BuildContext context) async {
    final controller = TextEditingController(
      text: '${settings.amountPerReminderMl ?? settings.glassSizeMl}',
    );
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Amount per reminder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'ml'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(int.tryParse(controller.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result > 0) {
      onChanged(settings.copyWith(amountPerReminderMl: result));
    }
  }
}

class _DeliveryPanel extends StatefulWidget {
  const _DeliveryPanel({required this.settings, required this.onChanged});

  final WaterSettings settings;
  final ValueChanged<WaterSettings> onChanged;

  @override
  State<_DeliveryPanel> createState() => _DeliveryPanelState();
}

class _DeliveryPanelState extends State<_DeliveryPanel> {
  bool? _exactAllowed;
  bool? _notificationsAllowed;

  @override
  void initState() {
    super.initState();
    _refreshPermissions();
  }

  Future<void> _refreshPermissions() async {
    final service = NotificationService.instance;
    final exact = await service.canScheduleExactAlarms();
    final enabled = await service.areNotificationsEnabled();
    if (!mounted) return;
    setState(() {
      _exactAllowed = exact;
      _notificationsAllowed = enabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;

    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SwitchListTile(
            value: settings.vibrate,
            onChanged: (value) =>
                widget.onChanged(settings.copyWith(vibrate: value)),
            title: const Text('Vibrate'),
          ),
          const Divider(height: 1),
          SwitchListTile(
            value: settings.use24hClock,
            onChanged: (value) =>
                widget.onChanged(settings.copyWith(use24hClock: value)),
            title: const Text('24-hour clock'),
          ),
          const Divider(height: 1),
          if (_notificationsAllowed == false)
            _PermissionRow(
              message: 'Notifications are blocked for this app. '
                  'Turn them on to receive reminders.',
              actionLabel: 'Allow notifications',
              onPressed: () async {
                await NotificationService.instance.requestPermissions();
                await _refreshPermissions();
              },
            ),
          if (_exactAllowed == false)
            _PermissionRow(
              message: 'Exact alarms are off, so reminders may arrive a few '
                  'minutes late while the phone is asleep.',
              actionLabel: 'Allow exact alarms',
              onPressed: () async {
                await NotificationService.instance.requestPermissions();
                await _refreshPermissions();
              },
            ),
          ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: const Text('Send a test reminder'),
            subtitle: Text(
              'Check how it looks and sounds',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onTap: () async {
              await NotificationService.instance.showTestNotification();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Test reminder sent')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFDF4E7),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline,
                size: 18,
                color: Color(0xFFB5892B),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: onPressed, child: Text(actionLabel)),
          ),
        ],
      ),
    );
  }
}

class _SchedulePreview extends StatelessWidget {
  const _SchedulePreview({required this.settings});

  final WaterSettings settings;

  @override
  Widget build(BuildContext context) {
    if (!settings.remindersEnabled) return const SizedBox.shrink();
    final slots = NotificationService.waterReminderSlots(settings);
    if (slots.isEmpty) return const SizedBox.shrink();

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's reminders",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final slot in slots)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.aquaWash,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    slot.label(settings.use24hClock),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.aquaDeep,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
