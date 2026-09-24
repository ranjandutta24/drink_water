import 'package:flutter/material.dart';

import '../models/water_settings.dart';
import '../services/timeline_service.dart';
import '../theme.dart';
import '../utils/format.dart';

/// The square card that gets captured to a PNG and shared.
///
/// Laid out at a fixed [width] rather than filling its parent: the capture has to
/// be reproducible, so the design must not reflow between a phone preview and
/// whatever the render pixel ratio ends up being.
class HydrationCard extends StatelessWidget {
  const HydrationCard({
    super.key,
    required this.timeline,
    required this.settings,
    this.streak = 0,
    this.width = 360,
  });

  final DayTimeline timeline;
  final WaterSettings settings;
  final int streak;
  final double width;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final progress = timeline.progress.clamp(0.0, 1.0).toDouble();
    final scale = width / 360;

    return Container(
      width: width,
      height: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28 * scale),
        // Deliberately the accent gradient in both themes: the card leaves the
        // app, so it should look like itself rather than like the reader's
        // brightness setting.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.aqua, palette.aquaDeep],
        ),
      ),
      padding: EdgeInsets.all(26 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.water_drop,
                size: 18 * scale,
                color: palette.onAccent,
              ),
              SizedBox(width: 7 * scale),
              Text(
                'Drink Water',
                style: TextStyle(
                  fontSize: 13 * scale,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: palette.onAccent,
                ),
              ),
              const Spacer(),
              Text(
                formatDayLabel(timeline.date),
                style: TextStyle(
                  fontSize: 12 * scale,
                  color: palette.onAccent.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: SizedBox(
              width: 132 * scale,
              height: 132 * scale,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 11 * scale,
                    strokeCap: StrokeCap.round,
                    backgroundColor: palette.onAccent.withValues(alpha: 0.22),
                    valueColor: AlwaysStoppedAnimation<Color>(palette.onAccent),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeline.goalMl <= 0
                              ? '—'
                              : '${(timeline.progress * 100).round()}%',
                          style: TextStyle(
                            fontSize: 30 * scale,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                            color: palette.onAccent,
                          ),
                        ),
                        Text(
                          'of goal',
                          style: TextStyle(
                            fontSize: 11 * scale,
                            color: palette.onAccent.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 18 * scale),
          Center(
            child: Text(
              timeline.goalMl <= 0
                  ? formatVolume(timeline.waterTotalMl, settings)
                  : '${formatVolume(timeline.waterTotalMl, settings, withUnit: false)}'
                        ' of ${formatVolume(timeline.goalMl, settings)}',
              style: TextStyle(
                fontSize: 19 * scale,
                fontWeight: FontWeight.w700,
                color: palette.onAccent,
              ),
            ),
          ),
          const Spacer(),
          // Wrap, not Row: three pills with long labels would overflow a narrow
          // card, and overflow stripes would be baked into the shared PNG.
          Wrap(
            runSpacing: 6 * scale,
            children: [
              _Pill(
                icon: Icons.local_drink_outlined,
                label:
                    '${timeline.drinkCount} '
                    '${timeline.drinkCount == 1 ? 'drink' : 'drinks'}',
                scale: scale,
              ),
              if (timeline.dosesScheduled > 0)
                _Pill(
                  icon: Icons.medication_outlined,
                  label:
                      '${timeline.dosesTaken}/${timeline.dosesScheduled} doses',
                  scale: scale,
                ),
              if (streak > 0)
                _Pill(
                  icon: Icons.bolt,
                  label: '$streak day${streak == 1 ? '' : 's'}',
                  scale: scale,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.scale});

  final IconData icon;
  final String label;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final onAccent = AppColors.of(context).onAccent;
    return Padding(
      padding: EdgeInsets.only(right: 8 * scale),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 10 * scale,
          vertical: 6 * scale,
        ),
        decoration: BoxDecoration(
          color: onAccent.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13 * scale, color: onAccent),
            SizedBox(width: 5 * scale),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5 * scale,
                fontWeight: FontWeight.w600,
                color: onAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
