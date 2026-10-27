import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'glass.dart';
import 'pressable.dart';

/// Floating navigation: four tabs with an "add listing" button in the
/// middle. It is a dark pane of glass in both themes, so the content that
/// scrolls underneath shows through blurred. The selected tab gets a soft
/// raw-oak pill that slides in (250ms).
class GlassNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final int chatBadge;
  final int profileBadge;

  const GlassNavBar({
    super.key,
    required this.index,
    required this.onSelect,
    required this.onAdd,
    this.chatBadge = 0,
    this.profileBadge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.c.isDark;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                boxShadow: const [
                  BoxShadow(color: Color(0x59000000), blurRadius: 32, offset: Offset(0, 14)),
                  BoxShadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: Glass(
              borderRadius: BorderRadius.circular(36),
              blur: 24,
              tint: dark ? BColors.obsidianRaised : BColors.obsidian,
              tintAlpha: dark ? 0.72 : 0.82,
              child: SizedBox(
                height: 72,
                child: Row(
                  children: [
                    Expanded(child: _Item(icon: Icons.home_rounded, label: 'Bosh sahifa', selected: index == 0, onTap: () => onSelect(0))),
                    Expanded(child: _Item(icon: Icons.favorite_rounded, label: 'Saralangan', selected: index == 1, onTap: () => onSelect(1))),
                    _AddButton(onTap: onAdd),
                    Expanded(child: _Item(icon: Icons.chat_bubble_rounded, label: 'Xabarlar', selected: index == 2, badge: chatBadge, onTap: () => onSelect(2))),
                    Expanded(child: _Item(icon: Icons.person_rounded, label: 'Profil', selected: index == 3, badge: profileBadge, onTap: () => onSelect(3))),
                  ],
                ),
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  const _Item({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? BColors.rawOak : BColors.plaster.withValues(alpha: 0.66);
    return Pressable(
      onTap: onTap,
      haptic: true,
      semanticLabel: label,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: BMotion.state,
                curve: BMotion.ease,
                width: 52,
                height: 30,
                decoration: BoxDecoration(
                  color: selected ? BColors.rawOak.withValues(alpha: 0.18) : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, size: 23, color: color),
              ),
              if (badge > 0)
                Positioned(
                  right: 4,
                  top: -3,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: BColors.rawOak,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badge > 9 ? '9+' : '$badge',
                      style: const TextStyle(
                        fontFamily: BType.sans,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: BColors.obsidian,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, maxLines: 1, style: BType.label(color).copyWith(fontSize: 10.5, letterSpacing: 0)),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Pressable(
        onTap: onTap,
        haptic: true,
        semanticLabel: "E'lon joylash",
        scale: 0.92,
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [BColors.oxbloodLift, BColors.oxblood],
            ),
            border: Border.all(color: BColors.rawOak, width: 1.6),
            boxShadow: [
              BoxShadow(color: BColors.rawOak.withValues(alpha: 0.28), blurRadius: 16, offset: const Offset(0, 4)),
            ],
          ),
          child: const Icon(Icons.add_rounded, size: 28, color: BColors.plaster),
        ),
      ),
    );
  }
}
