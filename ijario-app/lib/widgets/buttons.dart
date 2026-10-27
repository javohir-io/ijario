import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'pressable.dart';

/// The one loud button on a screen. A pill, 56px tall, filled with the
/// brand colour (oxblood in light mode, raw oak in dark mode).
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool expand;
  final Color? fill;
  final Color? foreground;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.expand = true,
    this.fill,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final enabled = onPressed != null && !loading;
    final fg = enabled ? (foreground ?? p.onPrimary) : p.inkMuted;

    final content = loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BType.button(fg),
                ),
              ),
            ],
          );

    return Pressable(
      onTap: enabled ? onPressed : null,
      haptic: true,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: BMotion.state,
        curve: BMotion.ease,
        height: 56,
        width: expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        alignment: Alignment.center,
        decoration: enabled
            ? BDeco.primary(p, fill: fill)
            : BoxDecoration(color: p.surfaceAlt, borderRadius: BRadius.all(BRadius.pill)),
        child: content,
      ),
    );
  }
}

/// A quieter pill with an outline, for the second action beside a
/// [PrimaryButton].
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final Color? foreground;
  final Color? borderColor;

  /// Smaller (46px) for use inside cards.
  final bool compact;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.foreground,
    this.borderColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final fg = foreground ?? p.ink;
    return Pressable(
      onTap: onPressed,
      haptic: true,
      semanticLabel: label,
      child: Container(
        height: compact ? 46 : 56,
        width: expand ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BRadius.all(BRadius.pill),
          color: p.ink.withValues(alpha: 0.04),
          border: Border.all(color: borderColor ?? p.ink.withValues(alpha: 0.26), width: 1.3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BType.button(fg).copyWith(fontSize: compact ? 14 : 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plain text action (e.g. "Parolni unutdingizmi?"). The hit area is at
/// least 44px tall.
class TextAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const TextAction({super.key, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Center(
          widthFactor: 1,
          child: Text(label, style: BType.label(color ?? p.brand).copyWith(fontSize: 14)),
        ),
      ),
    );
  }
}
