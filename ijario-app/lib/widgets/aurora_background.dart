import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Slowly drifting colour field in the brand palette: oxblood depths with
/// warm raw-oak light. It is the one ambient motion in the app (a 28s loop,
/// far under "attention-grabbing"), inspired by the flowing gradient planes
/// of ShaderGradient but drawn with plain radial gradients so it runs on
/// every platform without shader compilation.
///
/// The loop is seamless (every blob moves with an integer number of cycles)
/// and pauses entirely when "reduce motion" is on.
class AuroraBackground extends StatefulWidget {
  final Widget? child;
  final bool animate;

  const AuroraBackground({super.key, this.child, this.animate = true});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 28));
  bool _initialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    if (widget.animate && !BMotion.reduce(context)) {
      _controller.repeat();
    } else {
      _controller.value = 0.18;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _AuroraPainter(_controller),
        child: widget.child,
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final Animation<double> animation;

  _AuroraPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = animation.value;
    final rect = Offset.zero & size;
    final maxSide = math.max(size.width, size.height);

    canvas.drawRect(rect, Paint()..color = BColors.oxbloodDeep);

    void blob({
      required Color color,
      required double alpha,
      required double radius,
      required double cx,
      required double cy,
      required double ax,
      required double ay,
      required int fx,
      required int fy,
      required double phase,
    }) {
      final x = cx + ax * math.sin(2 * math.pi * (t * fx + phase));
      final y = cy + ay * math.cos(2 * math.pi * (t * fy + phase * 1.7));
      final center = Offset(x * size.width, y * size.height);
      final r = radius * maxSide;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.drawRect(rect, paint);
    }

    blob(color: BColors.oxblood, alpha: 1.0, radius: 0.95, cx: 0.25, cy: 0.20, ax: 0.18, ay: 0.12, fx: 1, fy: 1, phase: 0.0);
    blob(color: BColors.oxbloodGlow, alpha: 0.60, radius: 0.62, cx: 0.85, cy: 0.38, ax: 0.14, ay: 0.16, fx: 1, fy: 2, phase: 0.31);
    blob(color: BColors.rawOak, alpha: 0.50, radius: 0.55, cx: 0.55, cy: 1.02, ax: 0.22, ay: 0.10, fx: 2, fy: 1, phase: 0.62);
    blob(color: BColors.plaster, alpha: 0.16, radius: 0.38, cx: 0.92, cy: 0.04, ax: 0.10, ay: 0.08, fx: 1, fy: 1, phase: 0.8);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) => oldDelegate.animation != animation;
}
