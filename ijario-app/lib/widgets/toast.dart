import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A short message that floats above the content. Say what happened, in
/// the same words as the button that caused it ("Saqlandi", not "Muvaffaqiyatli!").
void showToast(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final dark = Theme.of(context).brightness == Brightness.dark;

  // The snack bar is obsidian in light mode and plaster in dark mode, so the
  // status icon uses the tone that stays readable on that.
  final Color iconColor = error
      ? (dark ? BColors.danger : BColors.dangerOnDark)
      : (dark ? BColors.success : BColors.successOnDark);

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              size: 20,
              color: iconColor,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
