import 'package:flutter/material.dart';

import '../models/property.dart';
import 'listing_card.dart';
import 'reveal.dart';
import 'routes.dart';

/// Responsive grid of listing cards as a sliver: one column on phones, two
/// or three on tablets and the web. The card height is derived from its
/// width, so the grid never needs a fixed row height.
class SliverListingGrid extends StatelessWidget {
  final List<Property> items;
  final String heroPrefix;
  final void Function(Property) onOpen;
  final void Function(Property) onToggleSave;
  final bool skeleton;
  final int skeletonCount;

  const SliverListingGrid({
    super.key,
    required this.items,
    required this.heroPrefix,
    required this.onOpen,
    required this.onToggleSave,
  })  : skeleton = false,
        skeletonCount = 0;

  const SliverListingGrid.skeleton({super.key, this.skeletonCount = 3})
      : items = const [],
        heroPrefix = '',
        onOpen = _noop,
        onToggleSave = _noop,
        skeleton = true;

  static void _noop(Property p) {}

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final margin = pageMargin(width);
        const gap = 16.0;
        final avail = width - margin * 2;
        final cols = avail >= 1000 ? 3 : (avail >= 640 ? 2 : 1);
        final cardWidth = (avail - gap * (cols - 1)) / cols;
        final cardHeight = ListingCard.heightFor(cardWidth);
        final count = skeleton ? skeletonCount : items.length;

        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: margin),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
              childAspectRatio: cardWidth / cardHeight,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                if (skeleton) return const ListingSkeleton();
                final property = items[i];
                return Reveal(
                  key: ValueKey<String>('$heroPrefix-${property.id}'),
                  index: i,
                  child: ListingCard(
                    property: property,
                    heroPrefix: heroPrefix,
                    onTap: () => onOpen(property),
                    onToggleSave: () => onToggleSave(property),
                  ),
                );
              },
              childCount: count,
            ),
          ),
        );
      },
    );
  }
}
