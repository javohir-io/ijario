import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Opens a modal bottom sheet in the app's style: large top corners, a
/// grabber, keyboard-aware, and no wider than a phone on big screens.
Future<T?> showIjarioSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool fullHeight = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (ctx) {
      final p = ctx.c;
      final insets = MediaQuery.of(ctx).viewInsets.bottom;
      final content = Container(
        decoration: BoxDecoration(
          color: p.bg,
          borderRadius: BRadius.top(BRadius.sheet),
        ),
        child: Column(
          mainAxisSize: fullHeight ? MainAxisSize.max : MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: p.inkFaint.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 6),
            Flexible(child: builder(ctx)),
          ],
        ),
      );
      return Padding(
        padding: EdgeInsets.only(bottom: insets),
        child: fullHeight ? SizedBox(height: double.infinity, child: content) : content,
      );
    },
  );
}
