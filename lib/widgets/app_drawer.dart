import 'package:flutter/material.dart';

import '../services/report_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'shell_nav.dart';

/// The side drawer that replaced the bottom navigation bar.
///
/// The header doubles as a glance at today so opening the drawer from a deep
/// screen still answers "am I behind on water?" without navigating anywhere.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final nav = ShellNav.of(context);

    // Background, width and shape come from drawerTheme in theme.dart.
    return Drawer(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _DrawerHeader(),
            Divider(height: 1, color: palette.hairline),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                children: [
                  for (final destination in ShellDestination.values) ...[
                    // Settings is housekeeping rather than a place you go to
                    // read something, so it sits below a break.
                    if (destination == ShellDestination.settings)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                        child: Divider(height: 1, color: palette.hairline),
                      ),
                    _DrawerTile(
                      destination: destination,
                      selected: destination == nav.current,
                      onTap: () {
                        // Close first: the page transition then plays out behind
                        // a drawer that is already on its way out, instead of
                        // both animations fighting for the same frames.
                        Navigator.of(context).pop();
                        nav.go(destination);
                      },
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 14, color: palette.inkSoft),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Everything stays on this phone',
                      style: TextStyle(fontSize: 11.5, color: palette.inkSoft),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final state = AppScope.of(context);
    final settings = state.settings;
    final reports = ReportService(
      entries: state.waterLog,
      goalMl: settings.dailyGoalMl,
    );
    final todayMl = reports.todayTotalMl;
    final goalMl = settings.dailyGoalMl;
    final progress = goalMl <= 0 ? 0.0 : (todayMl / goalMl).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: palette.aquaWash,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.water_drop,
                  size: 19,
                  color: palette.aquaDeep,
                ),
              ),
              const SizedBox(width: 11),
              Text(
                'Drink Water',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            goalMl <= 0
                ? formatVolume(todayMl, settings)
                : '${formatVolume(todayMl, settings, withUnit: false)} of '
                      '${formatVolume(goalMl, settings)} today',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 6,
              color: palette.aquaWash,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: palette.aqua),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final radius = BorderRadius.circular(14);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? palette.aquaWash : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 21,
                  color: selected ? palette.aquaDeep : palette.inkSoft,
                ),
                const SizedBox(width: 15),
                Text(
                  destination.label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? palette.aquaDeep : palette.ink,
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
