import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'glass.dart';

/// The ground every tab sits on: the plain background plus a few big, soft
/// colour glows (oxblood and raw oak). It is fixed while content scrolls
/// over it, which is what gives the translucent cards something to float
/// above. Painted once (no animation), so it costs nothing per frame.
class AppBackdrop extends StatelessWidget {
  final Widget? child;

  const AppBackdrop({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return SizedBox.expand(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _BackdropPainter(dark: p.isDark, base: p.bg, warm: p.glowWarm, brand: p.glowBrand),
          child: child,
        ),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  final bool dark;
  final Color base;
  final Color warm;
  final Color brand;

  const _BackdropPainter({required this.dark, required this.base, required this.warm, required this.brand});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = base);

    void glow(Color color, double alpha, Offset at, double radius) {
      final center = Offset(at.dx * size.width, at.dy * size.height);
      final r = radius * size.longestSide;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }

    if (dark) {
      glow(brand, 0.75, const Offset(0.95, 0.12), 0.62);
      glow(BColors.oxbloodDeep, 0.9, const Offset(0.05, 0.55), 0.55);
      glow(warm, 0.13, const Offset(0.1, 1.0), 0.55);
    } else {
      glow(warm, 0.55, const Offset(0.0, 0.95), 0.62);
      glow(brand, 0.13, const Offset(1.0, 0.18), 0.62);
      glow(const Color(0xFFFFFFFF), 0.7, const Offset(0.2, 0.0), 0.5);
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) =>
      old.dark != dark || old.base != base || old.warm != warm || old.brand != brand;
}

/// Screen frame for pushed pages: the glowing backdrop, a glass back button
/// and a title, with [body] filling the rest.
class BackdropScaffold extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget> actions;
  final Widget body;

  const BackdropScaffold({
    super.key,
    this.title,
    this.titleWidget,
    this.actions = const [],
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Scaffold(
      backgroundColor: p.bg,
      body: AppBackdrop(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    GlassIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      semanticLabel: 'Orqaga',
                      iconColor: p.ink,
                      tint: p.isDark ? Colors.white : Colors.white,
                      tintAlpha: p.isDark ? 0.10 : 0.55,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: titleWidget ??
                          Text(
                            title ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BType.headline(p.ink).copyWith(fontSize: 26),
                          ),
                    ),
                    ...actions,
                  ],
                ),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}
