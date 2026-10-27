import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

class Stat {
  final String value;
  final String label;

  const Stat(this.value, this.label);
}

/// A row of key numbers separated by hairlines: rooms, area, floor... The
/// hairlines mark real boundaries between separate facts.
class StatRow extends StatelessWidget {
  final List<Stat> stats;

  const StatRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final children = <Widget>[];
    for (var i = 0; i < stats.length; i++) {
      if (i > 0) {
        children.add(Container(width: 1, height: 34, color: p.line));
      }
      children.add(
        Expanded(
          child: Column(
            children: [
              Text(stats[i].value, style: BType.title(p.ink).copyWith(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(stats[i].label, style: BType.small(p.inkMuted)),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BDeco.card(p),
      child: Row(children: children),
    );
  }
}
