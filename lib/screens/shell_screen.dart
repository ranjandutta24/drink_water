import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'home_screen.dart';
import 'medicines_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

/// Four destinations, each a full screen. Kept alive so the reports keep their
/// selected period while the user checks something else.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int _index = 0;
  int _leaving = 0;

  /// Drives the tab change. Starts at 1 — completed — so the first frame shows
  /// the water screen fully settled rather than fading in.
  late final AnimationController _transition = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );

  /// Material's "fade through": the outgoing page clears out first, then the
  /// incoming one fades up and settles from slightly small. Deliberately not a
  /// cross-fade — two opaque screens overlapping at 50% looks like a glitch.
  late final Animation<double> _outgoingFade = _transition.drive(
    CurveTween(curve: const Interval(0.0, 0.30, curve: Curves.easeIn)),
  );
  late final Animation<double> _incomingFade = _transition.drive(
    CurveTween(curve: const Interval(0.28, 1.0, curve: Curves.easeOut)),
  );
  late final Animation<double> _incomingScale = _transition.drive(
    Tween<double>(begin: 0.97, end: 1.0).chain(
      CurveTween(curve: const Interval(0.28, 1.0, curve: Curves.easeOutCubic)),
    ),
  );

  static const List<Widget> _pages = [
    HomeScreen(),
    MedicinesScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Once the fade is over the old page is fully transparent, so let it go back
    // to being a hidden, ticker-less slot instead of animating out of sight.
    _transition.addStatusListener((status) {
      if (status == AnimationStatus.completed &&
          _leaving != _index &&
          mounted) {
        setState(() => _leaving = _index);
      }
    });
  }

  @override
  void dispose() {
    _transition.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _select(int value) {
    if (value == _index) return;
    setState(() {
      _leaving = _index;
      _index = value;
    });
    _transition.forward(from: 0);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Pick up anything logged from a notification while the app was closed.
      AppScope.read(context).consumePendingBackgroundWrites();
    }
  }

  /// One page of the stack, wrapped in whatever it needs to be shown, hidden, or
  /// animated in or out.
  Widget _slot(int i) {
    final isCurrent = i == _index;
    final isLeaving = i == _leaving && _leaving != _index;

    // TickerMode stops off-screen tabs from driving animations (and from
    // repainting). Without it the carafe would keep sloshing in the background
    // forever. The leaving page keeps its ticker until the fade is over so it
    // does not visibly freeze on the way out.
    final page = TickerMode(enabled: isCurrent || isLeaving, child: _pages[i]);

    if (!isCurrent && !isLeaving) {
      // Opacity 0 skips painting the subtree entirely, and IgnorePointer stops
      // a hidden page from swallowing taps meant for the one on top.
      return IgnorePointer(child: Opacity(opacity: 0, child: page));
    }

    return AnimatedBuilder(
      animation: _transition,
      child: page,
      builder: (context, child) {
        if (isLeaving) {
          return IgnorePointer(
            child: Opacity(opacity: 1 - _outgoingFade.value, child: child),
          );
        }
        return Opacity(
          opacity: _incomingFade.value,
          child: Transform.scale(scale: _incomingScale.value, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // A Stack rather than an IndexedStack so two pages can be on screen
      // together mid-transition. Every page still gets laid out on every frame,
      // exactly as IndexedStack did, which is what keeps scroll offsets and
      // form state intact; the hidden ones are simply never painted.
      body: Stack(
        fit: StackFit.expand,
        children: [for (var i = 0; i < _pages.length; i++) _slot(i)],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.water_drop_outlined),
            selectedIcon: Icon(Icons.water_drop),
            label: 'Water',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(Icons.medication),
            label: 'Medicines',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
