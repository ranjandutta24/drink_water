import 'package:flutter/material.dart';

import '../models/water_settings.dart';
import '../services/timeline_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'common.dart';

/// The day's drinks and doses on one rail, in clock order.
class DayTimelineView extends StatelessWidget {
  const DayTimelineView({
    super.key,
    required this.timeline,
    required this.settings,
    this.onMarkTaken,
  });

  final DayTimeline timeline;
  final WaterSettings settings;

  /// Offered only for today: `AppState.recordMedicineTaken` stamps the intake
  /// with `DateTime.now()`, so there is no honest way to tick off a dose that
  /// was due last Tuesday.
  final void Function(DoseEvent dose)? onMarkTaken;

  @override
  Widget build(BuildContext context) {
    if (timeline.isEmpty) {
      return const EmptyState(
        icon: Icons.timeline_outlined,
        title: 'Nothing on this day',
        message: 'No drinks logged and no medicines scheduled.',
      );
    }

    final events = timeline.events;
    return Column(
      children: [
        for (var i = 0; i < events.length; i++)
          _TimelineRow(
            event: events[i],
            settings: settings,
            isLast: i == events.length - 1,
            onMarkTaken: onMarkTaken,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.event,
    required this.settings,
    required this.isLast,
    required this.onMarkTaken,
  });

  final TimelineEvent event;
  final WaterSettings settings;
  final bool isLast;
  final void Function(DoseEvent dose)? onMarkTaken;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final style = _styleFor(event, palette);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 48,
            child: Padding(
              padding: const EdgeInsets.only(top: 1, right: 8),
              child: Text(
                formatClock(event.at, use24h: settings.use24hClock),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: style.muted ? palette.inkSoft : palette.ink,
                ),
              ),
            ),
          ),
          _Rail(style: style, isLast: isLast, palette: palette),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 12, bottom: isLast ? 0 : 16),
              child: _content(context, palette, style),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, AppPalette palette, _RowStyle style) {
    final titleStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: style.muted ? palette.inkSoft : palette.ink,
    );
    final noteStyle = TextStyle(fontSize: 11.5, color: palette.inkSoft);

    // Exhaustive because TimelineEvent is sealed — a new event type breaks the
    // build here rather than silently rendering nothing.
    switch (event) {
      case WaterEvent(:final amountMl, :final runningTotalMl, :final entry):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(formatVolume(amountMl, settings), style: titleStyle),
                if (entry.fromNotification) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.notifications_active_outlined,
                    size: 13,
                    color: palette.inkSoft,
                  ),
                ],
              ],
            ),
            Text(
              '${formatVolume(runningTotalMl, settings)} so far',
              style: noteStyle,
            ),
          ],
        );

      case DoseEvent dose:
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dose.medicine.name, style: titleStyle),
                  Text(_doseNote(dose), style: noteStyle),
                ],
              ),
            ),
            if (onMarkTaken != null &&
                (dose.status == DoseStatus.upcoming ||
                    dose.status == DoseStatus.missed))
              TextButton(
                onPressed: () => onMarkTaken!(dose),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: palette.aquaDeep,
                ),
                child: const Text('Taken'),
              ),
          ],
        );
    }
  }

  String _doseNote(DoseEvent dose) {
    final dosage = dose.medicine.dosage.trim();
    final prefix = dosage.isEmpty ? '' : '$dosage · ';
    final drift = dose.driftMinutes;

    return switch (dose.status) {
      DoseStatus.taken =>
        '$prefix${_driftLabel(drift)}',
      DoseStatus.skipped => '${prefix}Skipped',
      DoseStatus.missed => '${prefix}Not logged',
      DoseStatus.upcoming => '${prefix}Due',
      DoseStatus.extra => '${prefix}Extra dose',
    };
  }

  static String _driftLabel(int? drift) {
    if (drift == null) return 'Taken';
    // Inside a quarter of an hour either way is "on time" as far as anyone
    // cares; past that, say which way and by how much.
    if (drift.abs() < 15) return 'Taken on time';
    final magnitude = drift.abs();
    final amount = magnitude >= 60
        ? '${(magnitude / 60).toStringAsFixed(magnitude % 60 == 0 ? 0 : 1)} h'
        : '$magnitude min';
    return drift > 0 ? 'Taken $amount late' : 'Taken $amount early';
  }

  _RowStyle _styleFor(TimelineEvent event, AppPalette palette) {
    switch (event) {
      case WaterEvent():
        return _RowStyle(colour: palette.aqua, hollow: false, muted: false);
      case DoseEvent(:final status, :final medicine):
        final own = palette
            .medicinePalette[medicine.colorIndex %
                palette.medicinePalette.length];
        return switch (status) {
          DoseStatus.taken => _RowStyle(
            colour: palette.kelp,
            hollow: false,
            muted: false,
          ),
          DoseStatus.skipped => _RowStyle(
            colour: palette.clay,
            hollow: true,
            muted: true,
          ),
          DoseStatus.missed => _RowStyle(
            colour: palette.clay,
            hollow: false,
            muted: false,
          ),
          DoseStatus.upcoming => _RowStyle(
            colour: own,
            hollow: true,
            muted: true,
          ),
          DoseStatus.extra => _RowStyle(
            colour: own,
            hollow: false,
            muted: false,
          ),
        };
    }
  }
}

class _RowStyle {
  const _RowStyle({
    required this.colour,
    required this.hollow,
    required this.muted,
  });

  final Color colour;

  /// An outline instead of a solid dot: nothing has actually happened yet.
  final bool hollow;

  /// Softer text, for rows that are a plan rather than a record.
  final bool muted;
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.style,
    required this.isLast,
    required this.palette,
  });

  final _RowStyle style;
  final bool isLast;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 13,
      child: Column(
        children: [
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: style.hollow ? palette.panel : style.colour,
              border: Border.all(color: style.colour, width: 2),
            ),
          ),
          if (!isLast)
            Expanded(
              child: Container(width: 2, color: palette.hairline),
            ),
        ],
      ),
    );
  }
}
