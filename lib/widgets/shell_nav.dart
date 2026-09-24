import 'package:flutter/material.dart';

/// The five top-level places the drawer can take you.
///
/// Order is the order they appear in the drawer, and the index is the slot in the
/// shell's page stack, so the two can never drift apart.
enum ShellDestination {
  dashboard('Dashboard', Icons.dashboard_outlined, Icons.dashboard),
  water('Water', Icons.water_drop_outlined, Icons.water_drop),
  medicines('Medicines', Icons.medication_outlined, Icons.medication),
  reports('Reports', Icons.bar_chart_outlined, Icons.bar_chart),
  settings('Settings', Icons.settings_outlined, Icons.settings);

  const ShellDestination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Lets a page switch destination or open the drawer without knowing anything
/// about the shell that hosts it.
///
/// This exists because every page builds its own [Scaffold], so
/// `Scaffold.of(context).openDrawer()` from inside a page body would find that
/// page's Scaffold — which has no drawer — instead of the shell's.
class ShellNav extends InheritedWidget {
  const ShellNav({
    super.key,
    required this.current,
    required this.go,
    required this.openDrawer,
    required super.child,
  });

  final ShellDestination current;
  final ValueChanged<ShellDestination> go;
  final VoidCallback openDrawer;

  /// Null on any screen pushed as its own route (the medicine editor, water
  /// settings) and in a widget test that pumps one page on its own, since those
  /// sit beside the shell rather than under it.
  static ShellNav? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellNav>();

  static ShellNav of(BuildContext context) {
    final nav = maybeOf(context);
    assert(nav != null, 'No ShellNav above this widget.');
    return nav!;
  }

  @override
  bool updateShouldNotify(ShellNav oldWidget) =>
      oldWidget.current != current;
}

/// The hamburger. Degrades to empty space when there is no shell above it, so a
/// page stays usable on its own.
class NavMenuButton extends StatelessWidget {
  const NavMenuButton({super.key, this.color, this.dense = false});

  final Color? color;

  /// Drops the stock 48px touch slop to 40px for use outside an AppBar, where
  /// the default padding pushes the glyph well off the page's own margin.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final nav = ShellNav.maybeOf(context);
    if (nav == null) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.menu),
      tooltip: 'Open menu',
      color: color,
      onPressed: nav.openDrawer,
      padding: dense ? EdgeInsets.zero : null,
      visualDensity: dense ? VisualDensity.compact : null,
      constraints: dense
          ? const BoxConstraints.tightFor(width: 40, height: 40)
          : null,
    );
  }
}
