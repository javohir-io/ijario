import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'tokens.dart';

/// Type system. Display = Cormorant Garamond Italic (the serif on the brand
/// card). Everything functional = Manrope. Sentence case throughout.
class BType {
  BType._();

  static const String serif = 'Cormorant';
  static const String sans = 'Manrope';

  // --- Display (serif italic) ---
  static TextStyle hero(Color c) => TextStyle(
      fontFamily: serif, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600,
      fontSize: 52, height: 0.98, letterSpacing: -0.8, color: c);
  static TextStyle display(Color c) => TextStyle(
      fontFamily: serif, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600,
      fontSize: 38, height: 1.02, letterSpacing: -0.4, color: c);
  static TextStyle headline(Color c) => TextStyle(
      fontFamily: serif, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600,
      fontSize: 28, height: 1.1, letterSpacing: -0.2, color: c);
  static TextStyle subhead(Color c) => TextStyle(
      fontFamily: serif, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500,
      fontSize: 22, height: 1.15, color: c);

  // --- Functional (sans) ---
  static TextStyle price(Color c) => TextStyle(
      fontFamily: sans, fontWeight: FontWeight.w800, fontSize: 22, height: 1.1,
      letterSpacing: -0.4, color: c);
  static TextStyle title(Color c) => TextStyle(
      fontFamily: sans, fontWeight: FontWeight.w700, fontSize: 17, height: 1.3,
      letterSpacing: -0.1, color: c);
  static TextStyle body(Color c) => TextStyle(
      fontFamily: sans, fontWeight: FontWeight.w500, fontSize: 15, height: 1.5, color: c);
  static TextStyle small(Color c) => TextStyle(
      fontFamily: sans, fontWeight: FontWeight.w500, fontSize: 13, height: 1.45, color: c);
  static TextStyle label(Color c) => TextStyle(
      fontFamily: sans, fontWeight: FontWeight.w700, fontSize: 12.5, height: 1.2,
      letterSpacing: 0.1, color: c);
  static TextStyle button(Color c) => TextStyle(
      fontFamily: sans, fontWeight: FontWeight.w700, fontSize: 16, height: 1.2,
      letterSpacing: 0.1, color: c);
}

class BTheme {
  BTheme._();

  static ThemeData light() => _build(BPalette.light, Brightness.light);
  static ThemeData dark() => _build(BPalette.dark, Brightness.dark);

  static ThemeData _build(BPalette p, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.primaryFill,
      onPrimary: p.onPrimary,
      secondary: BColors.rawOak,
      onSecondary: BColors.obsidian,
      error: p.danger,
      onError: BColors.paper,
      surface: p.surface,
      onSurface: p.ink,
    );

    // The same slide-from-the-side transition everywhere, with swipe-back.
    const transitions = PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
      },
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      fontFamily: BType.sans,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      dividerColor: p.line,
      pageTransitionsTheme: transitions,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.brand,
        selectionColor: p.brand.withValues(alpha: 0.25),
        selectionHandleColor: p.brand,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.isDark ? BColors.plaster : BColors.obsidian,
        contentTextStyle: BType.small(p.isDark ? BColors.obsidian : BColors.paper)
            .copyWith(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BRadius.all(BRadius.field)),
      ),
    );
  }
}
