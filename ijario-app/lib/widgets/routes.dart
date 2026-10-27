import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A cross-fade between screens (600ms), used for the big context switches:
/// splash -> welcome -> app. Everything else uses the standard slide.
Route<T> fadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 600),
    reverseTransitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: BMotion.ease),
        child: child,
      );
    },
  );
}

/// Horizontal page margin that keeps content to a readable column on very
/// wide screens (the web build), while phones keep the normal margin.
double pageMargin(double width, {double maxContent = 1180}) {
  final extra = (width - maxContent) / 2;
  return extra > BSpace.page ? extra : BSpace.page;
}
