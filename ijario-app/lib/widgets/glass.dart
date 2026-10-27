import 'dart:ui';

import 'package:flutter/material.dart';

import 'pressable.dart';

/// Frosted glass: a backdrop blur, a faint tint gradient and a thin "rim
/// light" stroke that is bright at the top-left and bottom-right and dark in
/// between. The rim is the idea borrowed from liquid-glass-js (light
/// bunching at the edges where glass bends it); it is what makes the panel
/// read as a thick pane instead of a translucent rectangle.
///
/// Used sparingly, on purpose: only on controls that float above moving or
/// photographic content (the navigation bar, buttons over photos).
class Glass extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double blur;
  final Color tint;
  final double tintAlpha;
  final EdgeInsetsGeometry? padding;

  const Glass({
    super.key,
    required this.child,
    required this.borderRadius,
    this.blur = 20,
    this.tint = Colors.white,
    this.tintAlpha = 0.20,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: CustomPaint(
          foregroundPainter: _RimPainter(borderRadius),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tint.withValues(alpha: tintAlpha),
                  tint.withValues(alpha: tintAlpha * 0.55),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _RimPainter extends CustomPainter {
  final BorderRadius radius;

  _RimPainter(this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect).deflate(0.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.06),
          Colors.white.withValues(alpha: 0.04),
          Colors.white.withValues(alpha: 0.32),
        ],
        stops: const [0.0, 0.38, 0.62, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _RimPainter oldDelegate) => oldDelegate.radius != radius;
}

/// A round glass button for placing over photos (back, share, save...).
/// 44px: the minimum comfortable touch target.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String semanticLabel;
  final double size;
  final Color iconColor;
  final Color tint;
  final double tintAlpha;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.size = 44,
    this.iconColor = Colors.white,
    this.tint = Colors.black,
    this.tintAlpha = 0.28,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      semanticLabel: semanticLabel,
      child: Glass(
        borderRadius: BorderRadius.circular(size / 2),
        blur: 16,
        tint: tint,
        tintAlpha: tintAlpha,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.5, color: iconColor),
        ),
      ),
    );
  }
}
