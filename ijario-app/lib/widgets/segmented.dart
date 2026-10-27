import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'pressable.dart';

/// Two to four mutually exclusive options in one pill. The selected cell
/// fills with the brand colour.
class Segmented extends StatelessWidget {
  final List<String> options;
  final int index;
  final ValueChanged<int> onChanged;

  const Segmented({super.key, required this.options, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BDeco.card(p, radius: BRadius.pill, raised: false),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: Pressable(
                onTap: () => onChanged(i),
                haptic: true,
                semanticLabel: options[i],
                child: AnimatedContainer(
                  duration: BMotion.state,
                  curve: BMotion.ease,
                  height: 44,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: i == index
                      ? BDeco.primary(p, shadow: false)
                      : BoxDecoration(borderRadius: BRadius.all(BRadius.pill)),
                  child: Text(
                    options[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BType.label(i == index ? p.onPrimary : p.ink).copyWith(fontSize: 14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
