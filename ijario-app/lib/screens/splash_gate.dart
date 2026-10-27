import 'package:flutter/material.dart';

import '../services/auth_store.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/aurora_background.dart';
import '../widgets/ijario_mark.dart';
import '../widgets/reveal.dart';
import '../widgets/routes.dart';
import 'auth/welcome_screen.dart';
import 'main_shell.dart';

/// First thing on screen: the aurora, the mark and the name arrive while the
/// saved session is restored in the background. Signed-in people go straight
/// to the app; everyone else sees the welcome screen.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // Restoring the session is quick (it reads the device); the minimum
    // lets the logo moment land instead of flashing past.
    await Future.wait<void>([
      AuthStore.instance.restore(),
      Future<void>.delayed(const Duration(milliseconds: 1500)),
    ]);
    if (!mounted) return;
    final Widget next = AuthStore.instance.isLoggedIn ? const MainShell() : const WelcomeScreen();
    Navigator.of(context).pushReplacement(fadeRoute<void>(next));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BColors.oxbloodDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AuroraBackground(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Reveal(dy: 8, child: IjarioMark(size: 96)),
                const SizedBox(height: 18),
                Reveal(
                  index: 2,
                  dy: 12,
                  child: Text('Ijario', style: BType.hero(BColors.plaster)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
