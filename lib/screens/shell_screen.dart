import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../widgets/app_drawer.dart';
import '../widgets/shell_nav.dart';
import 'dashboard_screen.dart';
import 'home_screen.dart';
import 'medicines_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

/// Five destinations reached from the side drawer, each a full screen. All of
/// them stay alive so the reports keep their selected period — and the dashboard
/// its selected day — while the user checks something else.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  ShellDestination _current = ShellDestination.dashboard;
  ShellDestination _leaving = ShellDestination.dashboard;
  bool _drawerOpen = false;

  /// Drives the destination change. Starts at 1 — completed — so the first frame
  /// shows the dashboard fully settled rather than fading in.
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

  /// Index order matches [ShellDestination.values], which is what makes
  /// `destination.index` a valid slot number.
  static const List<Widget> _pages = [
    DashboardScreen(),
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
          _leaving != _current &&
          mounted) {
        setState(() => _leaving = _current);
      }
    });
  }

  @override
  void dispose() {
    _transition.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _go(ShellDestination value) {
    if (value == _current) return;
    setState(() {
      _leaving = _current;
      _current = value;
    });
    _transition.forward(from: 0);
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  /// Android back. With no bottom bar there is nothing on screen that says "you
  /// are one step away from home", so back returns to the dashboard first and
  /// only leaves the app from there.
  void _handleBack(bool didPop, Object? result) {
    if (didPop) return;

    // An open drawer registers a pop handler of its own, so a back press can
    // reach both it and this one. Either flag being set means the press belongs
    // to the drawer, not to navigation — checking both makes the outcome
    // independent of which handler the framework runs first. closeDrawer is
    // idempotent, so it is safe even if the drawer already acted.
    final state = _scaffoldKey.currentState;
    if (_drawerOpen || (state?.isDrawerOpen ?? false)) {
      state?.closeDrawer();
      return;
    }

    _go(ShellDestination.dashboard);
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
    final isCurrent = i == _current.index;
    final isLeaving = i == _leaving.index && _leaving != _current;

    // TickerMode stops off-screen pages from driving animations (and from
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
    return PopScope(
      canPop: _current == ShellDestination.dashboard && !_drawerOpen,
      onPopInvokedWithResult: _handleBack,
      // Above the Scaffold so the drawer itself can read the current
      // destination and highlight the right row.
      child: ShellNav(
        current: _current,
        go: _go,
        openDrawer: _openDrawer,
        child: Scaffold(
          key: _scaffoldKey,
          drawer: const AppDrawer(),
          // Tracked only so back can close the drawer instead of leaving the app.
          onDrawerChanged: (isOpen) {
            if (isOpen != _drawerOpen) setState(() => _drawerOpen = isOpen);
          },
          // A Stack rather than an IndexedStack so two pages can be on screen
          // together mid-transition. Every page still gets laid out on every
          // frame, exactly as IndexedStack did, which is what keeps scroll
          // offsets and form state intact; the hidden ones are simply never
          // painted.
          body: Stack(
            fit: StackFit.expand,
            children: [for (var i = 0; i < _pages.length; i++) _slot(i)],
          ),
        ),
      ),
    );
  }
}
