import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// The one dimensional, deliberately showy element in the app: a glass carafe
/// that fills as the day goes on, with a live waterline.
///
/// Everything else in the UI is flat and hairline-bordered so this reads as the
/// focal point rather than competing with cards.
class WaterVessel extends StatefulWidget {
  const WaterVessel({
    super.key,
    required this.progress,
    required this.primaryLabel,
    required this.secondaryLabel,
    this.size = const Size(196, 268),
  });

  /// 0.0 to (potentially) above 1.0 when the goal is exceeded.
  final double progress;

  /// Big numeral in the middle, e.g. "1.4 L".
  final String primaryLabel;

  /// Quiet line underneath, e.g. "of 2 L goal".
  final String secondaryLabel;

  final Size size;

  @override
  State<WaterVessel> createState() => _WaterVesselState();
}

class _WaterVesselState extends State<WaterVessel>
    with TickerProviderStateMixin {
  late final AnimationController _waves = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  late Animation<double> _level;
  double _shownProgress = 0;

  @override
  void initState() {
    super.initState();
    _level = AlwaysStoppedAnimation(widget.progress.clamp(0.0, 1.0));
    _shownProgress = widget.progress.clamp(0.0, 1.0);
    _animateTo(widget.progress);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect reduced-motion: the ripple is decorative, the fill is not. This
    // lives here rather than in initState because it needs MediaQuery.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _waves.stop();
    } else if (!_waves.isAnimating) {
      _waves.repeat();
    }
  }

  @override
  void didUpdateWidget(WaterVessel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animateTo(widget.progress);
    }
  }

  void _animateTo(double target) {
    final clamped = target.clamp(0.0, 1.0);
    _level = Tween<double>(
      begin: _shownProgress,
      end: clamped,
    ).animate(CurvedAnimation(parent: _fill, curve: Curves.easeOutCubic));
    _shownProgress = clamped;
    _fill
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _waves.dispose();
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final theme = Theme.of(context);
    final overflowing = widget.progress > 1.0;

    return SizedBox(
      width: widget.size.width,
      height: widget.size.height,
      // The labels are passed as AnimatedBuilder's `child` so this subtree is
      // built once instead of on every frame of the wave animation — and so no
      // semantics node sits on top of the repainting CustomPaint, which is what
      // tripped the framework's '!semantics.parentDataDirty' assertion.
      child: AnimatedBuilder(
        animation: Listenable.merge([_waves, _fill]),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 28),
            child: MergeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.primaryLabel,
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: AppColors.marine,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.secondaryLabel,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.aquaDeep,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        builder: (context, child) {
          return RepaintBoundary(
            child: CustomPaint(
              painter: _VesselPainter(
                level: _level.value,
                phase: reduceMotion ? 0 : _waves.value * 2 * math.pi,
                animateWaves: !reduceMotion,
                overflowing: overflowing,
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

class _VesselPainter extends CustomPainter {
  _VesselPainter({
    required this.level,
    required this.phase,
    required this.animateWaves,
    required this.overflowing,
  });

  final double level;
  final double phase;
  final bool animateWaves;
  final bool overflowing;

  @override
  void paint(Canvas canvas, Size size) {
    final body = _vesselPath(size);

    // Glass
    canvas.drawPath(
      body,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.92),
    );

    canvas.save();
    canvas.clipPath(body);

    final waterTop = size.height * (1 - level);

    if (level > 0.001) {
      final waterRect = Rect.fromLTRB(0, waterTop, size.width, size.height);
      canvas.drawRect(
        waterRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: overflowing
                ? const [Color(0xFF3FBF9B), AppColors.kelp]
                : const [Color(0xFF52C4D3), AppColors.aquaDeep],
          ).createShader(waterRect),
      );

      // Two offset waves give the surface a sense of motion without being loud.
      _drawWave(
        canvas,
        size,
        waterTop,
        amplitude: 6,
        phase: phase,
        color: Colors.white.withValues(alpha: 0.35),
      );
      _drawWave(
        canvas,
        size,
        waterTop,
        amplitude: 4,
        phase: phase + math.pi / 1.6,
        color: Colors.white.withValues(alpha: 0.55),
      );

      // Rising bubbles, only while animating.
      if (animateWaves) {
        final bubblePaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.30);
        for (var i = 0; i < 6; i++) {
          final seed = (i + 1) * 0.137;
          final travel = ((phase / (2 * math.pi)) + seed) % 1.0;
          final y = size.height - travel * (size.height - waterTop);
          final x = size.width * (0.18 + 0.64 * _pseudoRandom(i));
          if (y > waterTop + 8) {
            canvas.drawCircle(Offset(x, y), 2.0 + (i % 3), bubblePaint);
          }
        }
      }
    }

    canvas.restore();

    // Measurement ticks at 25 / 50 / 75 %, so the vessel doubles as a gauge.
    final tickPaint = Paint()
      ..color = AppColors.aquaDeep.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    for (final fraction in const [0.25, 0.5, 0.75]) {
      final y = size.height * (1 - fraction);
      canvas.drawLine(
        Offset(size.width * 0.72, y),
        Offset(size.width * 0.86, y),
        tickPaint,
      );
    }

    // Outline last so it sits above the water.
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = overflowing
            ? AppColors.kelp.withValues(alpha: 0.9)
            : AppColors.aquaDeep.withValues(alpha: 0.65),
    );
  }

  double _pseudoRandom(int index) {
    final value = math.sin(index * 12.9898) * 43758.5453;
    return value - value.floorToDouble();
  }

  void _drawWave(
    Canvas canvas,
    Size size,
    double waterTop, {
    required double amplitude,
    required double phase,
    required Color color,
  }) {
    final path = Path()..moveTo(0, waterTop);
    for (double x = 0; x <= size.width; x += 4) {
      final y =
          waterTop +
          math.sin((x / size.width * 2 * math.pi) + phase) * amplitude;
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  /// A carafe silhouette: narrow neck, sloping shoulder, rounded base.
  Path _vesselPath(Size size) {
    final w = size.width;
    final h = size.height;
    final neckHalf = w * 0.17;
    final bodyHalf = w * 0.48;
    final shoulderY = h * 0.22;
    final radius = w * 0.14;

    return Path()
      ..moveTo(w / 2 - neckHalf, 0)
      ..lineTo(w / 2 + neckHalf, 0)
      ..lineTo(w / 2 + neckHalf, h * 0.09)
      // Shoulder flare
      ..cubicTo(
        w / 2 + neckHalf,
        h * 0.15,
        w / 2 + bodyHalf,
        h * 0.14,
        w / 2 + bodyHalf,
        shoulderY,
      )
      ..lineTo(w / 2 + bodyHalf, h - radius)
      ..quadraticBezierTo(w / 2 + bodyHalf, h, w / 2 + bodyHalf - radius, h)
      ..lineTo(w / 2 - bodyHalf + radius, h)
      ..quadraticBezierTo(w / 2 - bodyHalf, h, w / 2 - bodyHalf, h - radius)
      ..lineTo(w / 2 - bodyHalf, shoulderY)
      ..cubicTo(
        w / 2 - bodyHalf,
        h * 0.14,
        w / 2 - neckHalf,
        h * 0.15,
        w / 2 - neckHalf,
        h * 0.09,
      )
      ..close();
  }

  @override
  bool shouldRepaint(_VesselPainter oldDelegate) =>
      oldDelegate.level != level ||
      oldDelegate.phase != phase ||
      oldDelegate.overflowing != overflowing;
}
