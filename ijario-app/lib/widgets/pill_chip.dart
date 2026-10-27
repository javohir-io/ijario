import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'pressable.dart';

/// A selectable pill (filters, options). Selected = filled with the brand
/// "selected" colour; unselected = quiet outline. At least 44px tall.
class PillChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final fg = selected ? p.onSelected : p.ink;
    return Pressable(
      onTap: onTap,
      haptic: true,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: BMotion.state,
        curve: BMotion.ease,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: selected
            ? BDeco.selected(p)
            : BDeco.card(p, radius: BRadius.pill, raised: false),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
            ],
            Text(label, style: BType.label(fg).copyWith(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
