import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Plays the short swallow effect that confirms a logged drink.
///
/// The audio itself lives in `android/app/src/main/res/raw/water_swallow.mp3`
/// and is played by a SoundPool in MainActivity. Keeping it on the native side
/// avoids an audio package for one 30 KB sound, and SoundPool is built for
/// exactly this: decode once, replay with no latency.
///
/// Every failure is swallowed. A missing channel (a unit test, or a platform
/// that never implements it) must never turn into a failed water log.
class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();

  static const MethodChannel _channel = MethodChannel('drink_water/sound');

  /// Only Android implements the channel. Checked via [defaultTargetPlatform]
  /// rather than dart:io so this stays usable from a widget test.
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Set false by the first failure so a device that cannot play the sound stops
  /// paying for a platform round trip on every tap.
  bool _available = true;

  Future<void> playSwallow() async {
    if (!_available || !isSupported) return;
    try {
      await _channel.invokeMethod<void>('playSwallow');
    } on MissingPluginException {
      _available = false;
    } catch (_) {
      // Anything else (a busy audio focus, a transient decode failure) is
      // per-call and worth retrying next time, so availability is left alone.
    }
  }
}
