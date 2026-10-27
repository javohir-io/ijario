import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/aurora_background.dart';
import '../../widgets/buttons.dart';
import '../../widgets/glass.dart';
import '../../widgets/ijario_mark.dart';
import '../../widgets/reveal.dart';
import '../../widgets/routes.dart';
import '../main_shell.dart';
import 'auth_screen.dart';

/// For people who aren't signed in. One promise, three ways forward.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: BColors.oxbloodDeep,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const AuroraBackground(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Glass(
                              borderRadius: BorderRadius.circular(BRadius.sheet),
                              blur: 22,
                              tint: Colors.white,
                              tintAlpha: 0.10,
                              padding: const EdgeInsets.fromLTRB(26, 30, 26, 22),
                              child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 24),
                                const Reveal(child: IjarioMark(size: 56)),
                                const SizedBox(height: 40),
                                Reveal(
                                  index: 1,
                                  child: Text('Sizga mos uy shu yerda.', style: BType.hero(BColors.plaster)),
                                ),
                                const SizedBox(height: 18),
                                Reveal(
                                  index: 2,
                                  child: Text(
                                    "Narxlarni solishtiring, egasi bilan to'g'ridan-to'g'ri yozishing va ko'rishga yoziling.",
                                    style: BType.body(BColors.plaster.withValues(alpha: 0.82)).copyWith(fontSize: 16.5),
                                  ),
                                ),
                                const SizedBox(height: 56),
                                Reveal(
                                  index: 3,
                                  child: PrimaryButton(
                                    label: 'Kirish',
                                    fill: BColors.rawOak,
                                    foreground: BColors.obsidian,
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Reveal(
                                  index: 4,
                                  child: SecondaryButton(
                                    label: "Ro'yxatdan o'tish",
                                    foreground: BColors.plaster,
                                    borderColor: BColors.plaster.withValues(alpha: 0.45),
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const AuthScreen(initialMode: AuthMode.register),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Reveal(
                                  index: 5,
                                  child: Center(
                                    child: TextAction(
                                      label: "Mehmon sifatida ko'rish",
                                      color: BColors.rawOak,
                                      onTap: () => Navigator.of(context).pushReplacement(
                                        fadeRoute<void>(const MainShell()),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
