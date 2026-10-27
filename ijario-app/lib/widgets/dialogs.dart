import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Yes / no question. Returns true only if the person confirmed.
/// Destructive confirmations use the danger colour for the action.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Bekor qilish',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final p = ctx.c;
      return AlertDialog(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BRadius.all(BRadius.card)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        title: Text(title, style: BType.headline(p.ink)),
        content: Text(message, style: BType.body(p.inkMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(cancelLabel, style: BType.label(p.inkMuted).copyWith(fontSize: 14.5)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(
              confirmLabel,
              style: BType.label(destructive ? p.danger : p.brand).copyWith(fontSize: 14.5),
            ),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
