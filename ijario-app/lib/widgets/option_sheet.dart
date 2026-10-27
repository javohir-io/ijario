import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'pressable.dart';
import 'sheet.dart';

class OptionItem<T> {
  final String label;
  final T value;
  final IconData? icon;
  final bool destructive;

  const OptionItem(this.label, this.value, {this.icon, this.destructive = false});
}

/// Wraps the chosen value so that "chose null" (e.g. "all cities") can be
/// told apart from "dismissed the sheet" (which returns null).
class Choice<T> {
  final T value;

  const Choice(this.value);
}

/// A list of options in a bottom sheet. Returns the chosen [Choice], or null
/// if the sheet was dismissed.
Future<Choice<T>?> showOptionSheet<T>(
  BuildContext context, {
  required String title,
  required List<OptionItem<T>> options,
  T? selected,
  bool hasSelection = false,
}) {
  return showIjarioSheet<Choice<T>>(
    context,
    builder: (ctx) {
      final p = ctx.c;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(BSpace.page, 12, BSpace.page, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: BType.headline(p.ink)),
            const SizedBox(height: 8),
            for (final option in options)
              Pressable(
                onTap: () => Navigator.of(ctx).pop(Choice<T>(option.value)),
                semanticLabel: option.label,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      if (option.icon != null) ...[
                        Icon(option.icon, size: 22, color: option.destructive ? p.danger : p.inkMuted),
                        const SizedBox(width: 14),
                      ],
                      Expanded(
                        child: Text(
                          option.label,
                          style: BType.body(option.destructive ? p.danger : p.ink).copyWith(
                            fontWeight: (hasSelection && option.value == selected)
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (hasSelection && option.value == selected)
                        Icon(Icons.check_rounded, size: 22, color: p.brand),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
