import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'buttons.dart';
import 'ijario_mark.dart';

/// What to show when a list is empty: say what's missing and offer the one
/// next step. (An empty screen is an invitation, not an apology.)
class EmptyState extends StatelessWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const IjarioMark(size: 72, colors: MarkTone.quiet, animate: false),
              const SizedBox(height: 20),
              Text(title, textAlign: TextAlign.center, style: BType.headline(p.ink)),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center, style: BType.body(p.inkMuted)),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 24),
                PrimaryButton(label: actionLabel!, onPressed: onAction, expand: false),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
