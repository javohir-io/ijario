import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../utils/formatters.dart';

/// Round profile picture; falls back to initials on a raw-oak disc.
class Avatar extends StatelessWidget {
  final String name;
  final String? url;
  final double size;

  const Avatar({super.key, required this.name, this.url, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: BColors.rawOak,
      child: Text(
        initials(name),
        style: BType.title(BColors.oxblood).copyWith(fontSize: size * 0.36, fontWeight: FontWeight.w800),
      ),
    );

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url == null
            ? fallback
            : Image.network(
                url!,
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorBuilder: (_, __, ___) => fallback,
                loadingBuilder: (context, child, progress) => progress == null ? child : fallback,
              ),
      ),
    );
  }
}
