import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/water_settings.dart';
import '../services/file_share_service.dart';
import '../services/timeline_service.dart';
import '../theme.dart';
import '../widgets/hydration_card.dart';

/// Preview of the shareable card, with the two things you can do with it.
///
/// The card on screen *is* the thing that gets captured — there is no second,
/// off-screen copy to keep in sync — so what the user approves is exactly what
/// leaves the phone.
class ShareCardScreen extends StatefulWidget {
  const ShareCardScreen({
    super.key,
    required this.timeline,
    required this.settings,
    this.streak = 0,
  });

  final DayTimeline timeline;
  final WaterSettings settings;
  final int streak;

  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  final GlobalKey _cardKey = GlobalKey();
  bool _busy = false;

  /// 3x a 360pt card is a 1080px PNG — the width every social app expects, and
  /// small enough that the encode stays well under a frame budget.
  static const double _captureScale = 3;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Share your day')),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: RepaintBoundary(
                  key: _cardKey,
                  child: HydrationCard(
                    timeline: widget.timeline,
                    settings: widget.settings,
                    streak: widget.streak,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: Text(
              'Only what you see here is shared.',
              style: TextStyle(fontSize: 12, color: palette.inkSoft),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _run(_save),
                      icon: const Icon(Icons.save_alt, size: 19),
                      label: const Text('Save'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _run(_share),
                      icon: const Icon(Icons.share_outlined, size: 19),
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _run(Future<void> Function(Uint8List bytes) action) async {
    setState(() => _busy = true);
    try {
      final bytes = await _capture();
      if (bytes == null) {
        if (mounted) _snack('Could not render the card.');
        return;
      }
      await action(bytes);
    } catch (error) {
      if (mounted) _snack('Something went wrong. ($error)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Uint8List?> _capture() async {
    final object = _cardKey.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) return null;

    // Wait out the frame in flight before capturing: the button that got us here
    // just rebuilt into its disabled state, and a boundary mid-repaint has
    // nothing useful to hand over. Not guarded by debugNeedsPaint — that getter
    // only assigns its result inside an assert, so reading it in a release build
    // throws.
    await WidgetsBinding.instance.endOfFrame;

    final image = await object.toImage(pixelRatio: _captureScale);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      // The raw image holds native memory that the garbage collector does not
      // account for, so it has to be let go explicitly.
      image.dispose();
    }
  }

  String get _fileName {
    final date = widget.timeline.date;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return 'hydration-${date.year}-$month-$day.png';
  }

  Future<void> _share(Uint8List bytes) =>
      FileShareService.share(bytes, _fileName);

  Future<void> _save(Uint8List bytes) async {
    final outcome = await FileShareService.save(
      bytes,
      _fileName,
      dialogTitle: 'Save your card',
    );
    if (!mounted) return;
    switch (outcome.status) {
      case SaveStatus.saved:
        _snack('Card saved as $_fileName');
      case SaveStatus.savedToAppFolder:
        _snack('Saved inside the app folder: ${outcome.path}');
      case SaveStatus.cancelled:
        break;
      case SaveStatus.failed:
        _snack('Could not save the card. (${outcome.error})');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
