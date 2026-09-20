import 'package:flutter/material.dart';

import 'screens/shell_screen.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DrinkWaterApp());
}

class DrinkWaterApp extends StatefulWidget {
  const DrinkWaterApp({super.key});

  @override
  State<DrinkWaterApp> createState() => _DrinkWaterAppState();
}

class _DrinkWaterAppState extends State<DrinkWaterApp> {
  late final Future<AppState> _bootstrap = _start();
  AppState? _state;

  Future<AppState> _start() async {
    final state = await AppState.create();
    _state = state;
    // Ask for notification permission on first run, after the UI exists so the
    // system dialog does not appear over a blank screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.requestPermissions();
    });
    return state;
  }

  @override
  void dispose() {
    _state?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppState>(
      future: _bootstrap,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _Frame(child: _StartupError(error: snapshot.error!));
        }
        final state = snapshot.data;
        if (state == null) return const _Frame(child: _Splash());

        // AppScope sits *above* MaterialApp so the Navigator — and therefore
        // every pushed route — is a descendant of it.
        return AppScope(
          state: state,
          child: const _Frame(child: ShellScreen()),
        );
      },
    );
  }
}

/// The MaterialApp itself. Split out so it can be reused for every startup
/// state without duplicating the theme.
class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drink Water',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: child,
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.aqua,
          ),
        ),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 34, color: AppColors.clay),
              const SizedBox(height: 14),
              Text(
                'The app could not load your data',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
