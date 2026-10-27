import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import 'screens/splash_gate.dart';
import 'services/settings_store.dart';
import 'theme/app_theme.dart';

/// Lets a mouse drag scrollables and carousels too (the web build is used
/// with a mouse, not just touch).
class _AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}

class IjarioApp extends StatelessWidget {
  const IjarioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsStore.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Ijario',
          debugShowCheckedModeBanner: false,
          theme: BTheme.light(),
          darkTheme: BTheme.dark(),
          themeMode: SettingsStore.instance.themeMode,
          scrollBehavior: _AppScrollBehavior(),
          // Cards and the nav bar have fixed heights, so very large system
          // fonts are capped at 1.25x instead of breaking the layout.
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(textScaler: media.textScaler.clamp(maxScaleFactor: 1.25)),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const SplashGate(),
        );
      },
    );
  }
}
