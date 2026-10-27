import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Colours for the mark's liquid-metal fill.
class MarkTone {
  MarkTone._();

  /// For dark / oxblood backgrounds.
  static const List<Color> warm = [BColors.plaster, BColors.rawOak, BColors.paper, BColors.rawOak];

  /// For light backgrounds.
  static const List<Color> brand = [BColors.oxbloodDeep, BColors.oxblood, BColors.oxbloodGlow, BColors.oxblood];

  /// Quiet, for empty states.
  static const List<Color> quiet = [BColors.concrete, BColors.plaster, BColors.concrete, BColors.plaster];
}

/// The Ijario mark: an arched doorway inside an arch, the shape of the
/// window in the brand photo. Its fill is a slowly turning metallic
/// gradient, and a band of light sweeps across it every nine seconds (the
/// liquid-logo idea, done with a plain gradient).
class IjarioMark extends StatefulWidget {
  final double size;
  final List<Color> colors;
  final bool animate;

  const IjarioMark({
    super.key,
    this.size = 64,
    this.colors = MarkTone.warm,
    this.animate = true,
  });

  @override
  State<IjarioMark> createState() => _IjarioMarkState();
}

class _IjarioMarkState extends State<IjarioMark> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 9));
  bool _initialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    if (widget.animate && !BMotion.reduce(context)) {
      _controller.repeat();
    } else {
      _controller.value = 0.4;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Ijario',
      image: true,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _MarkPainter(_controller, widget.colors, widget.animate),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  final Animation<double> animation;
  final List<Color> colors;
  final bool animated;

  _MarkPainter(this.animation, this.colors, this.animated) : super(repaint: animation);

  /// Shared with the app-icon generator: keep the proportions in sync.
  static Path shapeFor(Size size) {
    final s = size.shortestSide;
    final w = s * 0.62;
    final h = s * 0.84;
    final left = (size.width - w) / 2;
    final top = (size.height - h) / 2;

    final outer = Path()
      ..addRRect(RRect.fromRectAndCorners(
        Rect.fromLTWH(left, top, w, h),
        topLeft: Radius.circular(w / 2),
        topRight: Radius.circular(w / 2),
        bottomLeft: Radius.circular(w * 0.10),
        bottomRight: Radius.circular(w * 0.10),
      ));

    final iw = w * 0.40;
    final ih = h * 0.52;
    final inner = Path()
      ..addRRect(RRect.fromRectAndCorners(
        Rect.fromLTWH(left + (w - iw) / 2, top + h - ih - h * 0.09, iw, ih),
        topLeft: Radius.circular(iw / 2),
        topRight: Radius.circular(iw / 2),
        bottomLeft: Radius.circular(iw * 0.06),
        bottomRight: Radius.circular(iw * 0.06),
      ));

    return Path.combine(PathOperation.difference, outer, inner);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = animation.value;
    final shape = shapeFor(size);
    final bounds = shape.getBounds();

    final fill = Paint()
      ..shader = LinearGradient(
        colors: colors,
        stops: const [0.0, 0.40, 0.70, 1.0],
        transform: GradientRotation(2 * math.pi * t),
      ).createShader(bounds);
    canvas.drawPath(shape, fill);

    // A band of light crosses the mark during the first fifth of each loop.
    if (animated && t < 0.2) {
      final s = (t / 0.2) * 1.5 - 0.25; // -0.25 .. 1.25
      double clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
      final shine = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.65),
            Colors.white.withValues(alpha: 0),
          ],
          stops: [clamp01(s - 0.16), clamp01(s), clamp01(s + 0.16)],
        ).createShader(bounds);
      canvas.save();
      canvas.clipPath(shape);
      canvas.drawRect(bounds, shine);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) =>
      oldDelegate.colors != colors || oldDelegate.animated != animated;
}

/// "Ijario" set in the display serif.
class IjarioWordmark extends StatelessWidget {
  final Color color;
  final double size;

  const IjarioWordmark({super.key, required this.color, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Ijario',
      style: BType.display(color).copyWith(fontSize: size, height: 1.0),
    );
  }
}
