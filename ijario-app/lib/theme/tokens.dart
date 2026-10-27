import 'package:flutter/material.dart';

/// The five colors of the Ijario palette (from the brand card), plus a few
/// clearly-named tints derived from them. Nothing else is allowed in the UI.
class BColors {
  BColors._();

  // --- The palette -------------------------------------------------------
  static const Color oxblood = Color(0xFF5E1E2B); // brand
  static const Color rawOak = Color(0xFFD2BCA8); // warm accent
  static const Color plaster = Color(0xFFDADCDD); // light neutral
  static const Color concrete = Color(0xFF9C9D9B); // mid neutral
  static const Color obsidian = Color(0xFF202020); // ink / dark ground

  // --- Derived tints (each is one of the above, lightened or darkened) ----
  static const Color oxbloodDeep = Color(0xFF3B121B); // oxblood, darkened
  static const Color oxbloodGlow = Color(0xFF8C3446); // oxblood, lightened (only on dark ground)
  static const Color plasterTint = Color(0xFFECEDED); // plaster, lightened: app background
  static const Color paper = Color(0xFFF8F7F5); // plaster + warmth: card surface
  static const Color inkMuted = Color(0xFF5E5F5D); // concrete, darkened to pass 4.5:1 on plaster
  static const Color obsidianRaised = Color(0xFF2B2A2A); // obsidian, lightened: dark card surface
  static const Color obsidianHigh = Color(0xFF363535); // obsidian, lightened more: dark fills

  // Lifted versions, for the light edge of a gradient (that is what makes a
  // button or card read as a raised, curved surface).
  static const Color oxbloodLift = Color(0xFF7A2B3D); // oxblood, lightened
  static const Color oakLift = Color(0xFFE6D6C6); // raw oak, lightened

  // --- Semantic (only where meaning needs a non-palette hue) ---------------
  static const Color success = Color(0xFF3F6B4F);
  static const Color successOnDark = Color(0xFF8FC1A0);
  static const Color danger = Color(0xFFB3382C);
  static const Color dangerOnDark = Color(0xFFE58C82);
}

/// Everything that changes between light and dark mode. Get it with
/// `context.c`.
class BPalette {
  final bool isDark;
  final Color bg; // scaffold
  final Color surface; // cards
  final Color surfaceAlt; // fills inside cards, inputs
  final Color ink; // primary text
  final Color inkMuted; // secondary text (4.5:1 or better)
  final Color inkFaint; // hints, disabled, decorative icons (NOT for essential text)
  final Color line; // hairlines
  final Color brand; // accent for text / icons / links
  final Color primaryFill; // primary button background
  final Color onPrimary;
  final Color selectedFill; // selected chip background
  final Color onSelected;
  final Color selectedBorder;
  final Color success;
  final Color danger;

  // Depth: card surface gradient (top-left light -> bottom-right), its rim
  // light, the shadows that lift it, and the lit edge of selected controls.
  final Color cardTop;
  final Color cardBottom;
  final Color cardRim;
  final List<BoxShadow> cardShadows;
  final Color selectedTop;

  // Soft colour glows painted behind every tab, so glass has something
  // to be glass over.
  final Color glowWarm;
  final Color glowBrand;

  const BPalette({
    required this.isDark,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.line,
    required this.brand,
    required this.primaryFill,
    required this.onPrimary,
    required this.selectedFill,
    required this.onSelected,
    required this.selectedBorder,
    required this.success,
    required this.danger,
    required this.cardTop,
    required this.cardBottom,
    required this.cardRim,
    required this.cardShadows,
    required this.selectedTop,
    required this.glowWarm,
    required this.glowBrand,
  });

  static const BPalette light = BPalette(
    isDark: false,
    bg: BColors.plasterTint,
    surface: BColors.paper,
    surfaceAlt: BColors.plaster,
    ink: BColors.obsidian,
    inkMuted: BColors.inkMuted,
    inkFaint: BColors.concrete,
    line: Color(0x1F202020),
    brand: BColors.oxblood,
    primaryFill: BColors.oxblood,
    onPrimary: BColors.paper,
    selectedFill: BColors.oxblood,
    onSelected: BColors.paper,
    selectedBorder: BColors.oxblood,
    success: BColors.success,
    danger: BColors.danger,
    cardTop: Color(0xEBFFFFFF),
    cardBottom: Color(0xB8F8F7F5),
    cardRim: Color(0xB3FFFFFF),
    cardShadows: [
      BoxShadow(color: Color(0x1F5E1E2B), blurRadius: 28, offset: Offset(0, 12)),
      BoxShadow(color: Color(0x0F202020), blurRadius: 4, offset: Offset(0, 1)),
    ],
    selectedTop: BColors.oxbloodLift,
    glowWarm: BColors.rawOak,
    glowBrand: BColors.oxblood,
  );

  static const BPalette dark = BPalette(
    isDark: true,
    bg: BColors.obsidian,
    surface: BColors.obsidianRaised,
    surfaceAlt: BColors.obsidianHigh,
    ink: BColors.plaster,
    inkMuted: BColors.concrete,
    inkFaint: Color(0xFF6E6F6D),
    line: Color(0x1FDADCDD),
    brand: BColors.rawOak,
    primaryFill: BColors.rawOak,
    onPrimary: BColors.obsidian,
    selectedFill: BColors.oxblood,
    onSelected: BColors.plaster,
    selectedBorder: Color(0x99D2BCA8),
    success: BColors.successOnDark,
    danger: BColors.dangerOnDark,
    cardTop: Color(0x24DADCDD),
    cardBottom: Color(0x0FDADCDD),
    cardRim: Color(0x2EDADCDD),
    cardShadows: [
      BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 14)),
      BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1)),
    ],
    selectedTop: BColors.oxbloodGlow,
    glowWarm: BColors.rawOak,
    glowBrand: BColors.oxblood,
  );
}

/// Ready-made decorations, so every raised surface in the app is lit the
/// same way (light from the top-left, shadows falling down and to the
/// brand colour in light mode).
class BDeco {
  BDeco._();

  /// A raised, translucent "glass" surface: gradient fill, rim, layered shadow.
  /// No backdrop blur here on purpose: behind cards the app background is a
  /// smooth gradient, so a blur would look identical but cost a lot of
  /// frame time in long lists. Real blur is kept for the nav bar and for
  /// controls over photos.
  static BoxDecoration card(BPalette p, {double radius = BRadius.card, bool raised = true}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [p.cardTop, p.cardBottom],
      ),
      border: Border.all(color: p.cardRim, width: 1),
      boxShadow: raised ? p.cardShadows : null,
    );
  }

  /// Lightens [c] towards white by [amount] (0..1).
  static Color lift(Color c, [double amount = 0.18]) => Color.lerp(c, const Color(0xFFFFFFFF), amount)!;

  /// The primary button: a pill lit from above, with a coloured shadow.
  static BoxDecoration primary(BPalette p, {Color? fill, double radius = BRadius.pill, bool shadow = true}) {
    final base = fill ?? p.primaryFill;
    final top = fill == null && !p.isDark ? BColors.oxbloodLift : lift(base, p.isDark ? 0.28 : 0.2);
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, base],
      ),
      border: Border.all(color: const Color(0x33FFFFFF), width: 1),
      boxShadow: shadow
          ? [
              BoxShadow(color: base.withValues(alpha: p.isDark ? 0.30 : 0.38), blurRadius: 20, offset: const Offset(0, 9)),
              const BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1)),
            ]
          : null,
    );
  }

  /// Selected chip / segment.
  static BoxDecoration selected(BPalette p, {double radius = BRadius.pill, bool shadow = true}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [p.selectedTop, p.selectedFill],
      ),
      border: Border.all(color: p.selectedBorder, width: 1.2),
      boxShadow: shadow
          ? [BoxShadow(color: BColors.oxblood.withValues(alpha: p.isDark ? 0.5 : 0.30), blurRadius: 14, offset: const Offset(0, 6))]
          : null,
    );
  }
}

extension BContext on BuildContext {
  BPalette get c =>
      Theme.of(this).brightness == Brightness.dark ? BPalette.dark : BPalette.light;
}

/// Radii. Different things get different radii: that hierarchy is part of
/// the look (small thumbs < fields < cards < sheets), taken from the
/// generous rounded blocks on the palette card.
class BRadius {
  BRadius._();
  static const double thumb = 14;
  static const double field = 20;
  static const double card = 28;
  static const double sheet = 36;
  static const double pill = 999;

  static BorderRadius all(double r) => BorderRadius.circular(r);
  static BorderRadius top(double r) => BorderRadius.vertical(top: Radius.circular(r));
}

class BSpace {
  BSpace._();
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 48;

  /// Horizontal page margin.
  static const double page = 20;
}

/// Motion system: the "Premium" archetype from the motion-design skill.
/// One signature easing, a small set of durations, no overshoot, entrances
/// longer than exits, stagger kept under ~500ms in total.
class BMotion {
  BMotion._();

  /// Signature curve: used for ~80% of all animation.
  static const Curve ease = Cubic(0.4, 0.0, 0.2, 1.0);

  /// Entrances that should feel like arriving.
  static const Curve emphasized = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Exits accelerate away.
  static const Curve exit = Cubic(0.3, 0.0, 1.0, 1.0);

  static const Duration press = Duration(milliseconds: 120);
  static const Duration state = Duration(milliseconds: 250);
  static const Duration enter = Duration(milliseconds: 500);
  static const Duration page = Duration(milliseconds: 500);
  static const Duration reveal = Duration(milliseconds: 800);
  static const Duration stagger = Duration(milliseconds: 70);

  /// Respect the OS "reduce motion" setting.
  static bool reduce(BuildContext context) => MediaQuery.of(context).disableAnimations;
}
