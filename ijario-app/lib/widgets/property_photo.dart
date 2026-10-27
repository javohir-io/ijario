import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A listing photo that fades in over a branded placeholder, so a slow
/// connection shows soft colour (never a blank box or a spinner), and a
/// listing with no photos still looks intentional.
class PropertyPhoto extends StatelessWidget {
  final String? url;
  final int seed;
  final BoxFit fit;

  const PropertyPhoto({super.key, required this.url, required this.seed, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final art = PlaceholderArt(seed: seed);
    if (url == null) return art;
    return Stack(
      fit: StackFit.expand,
      children: [
        art,
        Image.network(
          url!,
          fit: fit,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: BMotion.enter,
              curve: BMotion.ease,
              child: child,
            );
          },
        ),
      ],
    );
  }
}

/// Palette-only gradient with a large faint arch (the brand shape).
class PlaceholderArt extends StatelessWidget {
  final int seed;

  const PlaceholderArt({super.key, required this.seed});

  static const List<List<Color>> _gradients = [
    [BColors.oxbloodDeep, BColors.oxblood],
    [BColors.obsidian, BColors.oxblood],
    [BColors.oxblood, Color(0xFF8A6B5C)],
    [Color(0xFF4A4A49), BColors.oxbloodDeep],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _gradients[seed.abs() % _gradients.length];
    // ClipRect matters: the faint arch is taller than the canvas, and a
    // CustomPaint does not clip what it draws, so without this the arch
    // showed up below the photo, behind the listing title.
    return ClipRect(
      child: CustomPaint(
        painter: _ArtPainter(colors, seed.abs() % 2 == 0),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  final List<Color> colors;
  final bool archOnRight;

  _ArtPainter(this.colors, this.archOnRight);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    canvas.clipRect(rect);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(rect),
    );

    final w = size.shortestSide * 0.62;
    final h = w * 1.35;
    final left = archOnRight ? size.width * 0.62 - w / 2 : size.width * 0.38 - w / 2;
    final top = size.height - h * 0.78;
    final arch = RRect.fromRectAndCorners(
      Rect.fromLTWH(left, top, w, h),
      topLeft: Radius.circular(w / 2),
      topRight: Radius.circular(w / 2),
    );
    canvas.drawRRect(arch, Paint()..color = BColors.rawOak.withValues(alpha: 0.12));
    canvas.drawRRect(
      arch.deflate(w * 0.22),
      Paint()..color = BColors.oxbloodDeep.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant _ArtPainter oldDelegate) =>
      oldDelegate.colors != colors || oldDelegate.archOnRight != archOnRight;
}
