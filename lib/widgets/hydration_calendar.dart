import 'package:flutter/material.dart';

import '../models/water_log.dart';
import '../theme.dart';
import '../utils/format.dart';

/// A week strip that expands into a month grid, each day shaded by how much of
/// the goal was met.
///
/// Collapsed it shows the week containing [selected], which can straddle two
/// months — so days are looked up by key out of [totalsByDay] rather than being
/// generated from a single month's report.
class HydrationCalendar extends StatefulWidget {
  const HydrationCalendar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.totalsByDay,
    required this.goalMl,
    this.firstLoggedDay,
  });

  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  final Map<String, int> totalsByDay;
  final int goalMl;

  /// Used to stop the month arrows from walking back through empty years.
  final DateTime? firstLoggedDay;

  @override
  State<HydrationCalendar> createState() => _HydrationCalendarState();
}

class _HydrationCalendarState extends State<HydrationCalendar> {
  bool _expanded = false;

  /// First of the month on show while expanded. Follows [selected] when the
  /// selection moves outside it.
  late DateTime _month = _monthOf(widget.selected);

  static DateTime _monthOf(DateTime date) => DateTime(date.year, date.month);

  static DateTime _dayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  @override
  void didUpdateWidget(HydrationCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final month = _monthOf(widget.selected);
    if (month != _monthOf(oldWidget.selected) && month != _month) {
      _month = month;
    }
  }

  int _totalFor(DateTime day) =>
      widget.totalsByDay[WaterEntry.dayKeyFor(day)] ?? 0;

  /// Monday-first, matching the weekly report.
  List<DateTime> get _weekOfSelected {
    final day = _dayOf(widget.selected);
    final monday = day.subtract(Duration(days: day.weekday - 1));
    return [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];
  }

  /// Six rows of seven, padded out of the neighbouring months so the grid never
  /// changes height as the user pages through.
  List<DateTime?> get _monthGrid {
    final first = _month;
    final leading = first.weekday - 1;
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    return [
      for (var i = 0; i < 42; i++)
        if (i < leading || i >= leading + daysInMonth)
          null
        else
          DateTime(first.year, first.month, i - leading + 1),
    ];
  }

  bool get _canGoBack {
    final first = widget.firstLoggedDay;
    if (first == null) return false;
    return _month.isAfter(_monthOf(first));
  }

  bool get _canGoForward => _month.isBefore(_monthOf(DateTime.now()));

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.hairline),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        children: [
          _header(palette),
          const SizedBox(height: 10),
          _weekdayLabels(palette),
          const SizedBox(height: 6),
          // AnimatedSize keeps the expand from snapping. The two bodies are
          // separate subtrees rather than one grid with a variable row count,
          // because the collapsed week can cross a month boundary.
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded ? _monthBody(palette) : _weekBody(palette),
          ),
          _footer(palette),
        ],
      ),
    );
  }

  Widget _header(AppPalette palette) {
    final label = _expanded
        ? '${monthShort(_month)} ${_month.year}'
        : formatDayLabel(widget.selected);

    return Row(
      children: [
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (_expanded) ...[
          _ArrowButton(
            icon: Icons.chevron_left,
            onPressed: _canGoBack ? () => _shiftMonth(-1) : null,
          ),
          _ArrowButton(
            icon: Icons.chevron_right,
            onPressed: _canGoForward ? () => _shiftMonth(1) : null,
          ),
        ] else
          TextButton(
            onPressed: () => widget.onSelect(_dayOf(DateTime.now())),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: palette.aquaDeep,
            ),
            child: const Text('Today'),
          ),
      ],
    );
  }

  Widget _weekdayLabels(AppPalette palette) {
    // 2024-01-01 was a Monday, so counting up from it gives the names in the
    // same Monday-first order as the grid below.
    final reference = DateTime(2024, 1, 1);

    return Row(
      children: [
        for (var offset = 0; offset < 7; offset++)
          Expanded(
            child: Center(
              child: Text(
                weekdayShort(
                  reference.add(Duration(days: offset)),
                ).substring(0, 1),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: palette.inkSoft,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _weekBody(AppPalette palette) {
    return Row(
      children: [
        for (final day in _weekOfSelected)
          Expanded(child: _cell(day, palette)),
      ],
    );
  }

  Widget _monthBody(AppPalette palette) {
    final grid = _monthGrid;
    return Column(
      children: [
        for (var row = 0; row < 6; row++)
          Row(
            children: [
              for (var column = 0; column < 7; column++)
                Expanded(child: _cell(grid[row * 7 + column], palette)),
            ],
          ),
      ],
    );
  }

  Widget _footer(AppPalette palette) {
    return Align(
      alignment: Alignment.center,
      child: TextButton.icon(
        onPressed: () => setState(() {
          _expanded = !_expanded;
          if (_expanded) _month = _monthOf(widget.selected);
        }),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          foregroundColor: palette.inkSoft,
        ),
        icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18),
        label: Text(
          _expanded ? 'Show one week' : 'Show the month',
          style: const TextStyle(fontSize: 12.5),
        ),
      ),
    );
  }

  Widget _cell(DateTime? day, AppPalette palette) {
    if (day == null) return const SizedBox(height: 44);

    final today = _dayOf(DateTime.now());
    final isFuture = day.isAfter(today);
    final isToday = day == today;
    final isSelected = day == _dayOf(widget.selected);
    final total = _totalFor(day);
    final progress = widget.goalMl <= 0 ? 0.0 : total / widget.goalMl;

    final fill = isFuture ? Colors.transparent : _fillFor(progress, palette);
    // Solid aqua is dark enough that the day number has to flip to read at all.
    final onFill = progress >= 1 && !isFuture ? palette.onAccent : palette.ink;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: SizedBox(
        height: 40,
        child: Material(
          color: fill,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            // Tapping tomorrow would show an empty timeline and no way to log
            // into it, so the future is inert.
            onTap: isFuture ? null : () => widget.onSelect(day),
            borderRadius: BorderRadius.circular(11),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: isSelected
                    ? Border.all(color: palette.aquaDeep, width: 2)
                    : isToday
                    ? Border.all(color: palette.aquaDeep.withValues(alpha: 0.4))
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected || isToday
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: isFuture ? palette.inkSoft : onFill,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Four steps rather than a continuous ramp: a grid of 42 subtly different
  /// blues is unreadable, whereas "nothing / some / most / done" can be taken in
  /// at a glance.
  Color _fillFor(double progress, AppPalette palette) {
    if (progress <= 0) return palette.canvas;
    if (progress < 0.5) return palette.aquaWash;
    if (progress < 1) return palette.aqua.withValues(alpha: 0.45);
    return palette.aqua;
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      color: AppColors.of(context).inkSoft,
    );
  }
}
