import 'package:flutter/material.dart';

import '../models/property.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../utils/formatters.dart';
import 'glass.dart';
import 'pressable.dart';
import 'property_photo.dart';
import 'save_button.dart';
import 'tilt_3d.dart';
import 'shimmer.dart';

/// One listing in a list or grid: a big photo with the price on it, then
/// title, place and the three numbers renters compare first.
class ListingCard extends StatelessWidget {
  /// Height of the text area under the photo (fixed, so a grid can compute
  /// the card's total height from its width).
  static const double infoHeight = 112;
  static const double imageAspect = 4 / 3;

  /// Total card height for a given card width.
  /// (+2 for the 1px border on each side, which insets the content.)
  static double heightFor(double width) => width / imageAspect + infoHeight + 2;

  final Property property;

  /// Distinguishes the shared-element (Hero) tag between screens that can
  /// show the same listing at once (home, saved, my listings).
  final String heroPrefix;
  final VoidCallback onTap;
  final VoidCallback onToggleSave;

  const ListingCard({
    super.key,
    required this.property,
    required this.heroPrefix,
    required this.onTap,
    required this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final pr = property;

    return Pressable(
      onTap: onTap,
      scale: 0.98,
      semanticLabel: pr.title,
      child: Tilt3D(
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BDeco.card(p),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: imageAspect,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: '$heroPrefix-photo-${pr.id}',
                    child: PropertyPhoto(url: pr.coverUrl, seed: pr.id),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.62)],
                          stops: const [0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 76,
                    bottom: 14,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: formatMoneyShort(pr.price, pr.currency),
                            style: BType.price(Colors.white).copyWith(fontSize: 21),
                          ),
                          TextSpan(
                            text: '  / ${unitLabel(pr.priceUnit)}',
                            style: BType.small(Colors.white.withValues(alpha: 0.85))
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _Badges(property: pr),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: SaveButton(saved: pr.isSaved, onTap: onToggleSave),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: infoHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      pr.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BType.title(p.ink).copyWith(fontSize: 16.5),
                    ),
                    Text(
                      pr.hasMetro ? '${pr.placeLabel}, ${pr.metro}' : pr.placeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BType.small(p.inkMuted),
                    ),
                    _SpecLine(property: pr),
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _Badges extends StatelessWidget {
  final Property property;

  const _Badges({required this.property});

  @override
  Widget build(BuildContext context) {
    final label = property.isRented
        ? 'Band'
        : (property.isPostedByOwner ? 'Egasidan' : null);
    if (label == null) return const SizedBox.shrink();
    return Glass(
      borderRadius: BorderRadius.circular(BRadius.pill),
      blur: 14,
      tint: property.isRented ? BColors.rawOak : Colors.black,
      tintAlpha: property.isRented ? 0.85 : 0.32,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Text(
        label,
        style: BType.label(property.isRented ? BColors.obsidian : Colors.white),
      ),
    );
  }
}

class _SpecLine extends StatelessWidget {
  final Property property;

  const _SpecLine({required this.property});

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final specs = <String>[
      '${property.bedrooms} xona',
      if (property.area > 0) '${property.area.round()} m²',
      '${property.floor}-qavat',
    ];
    final style = BType.label(p.ink).copyWith(fontSize: 13.5, fontWeight: FontWeight.w700);

    final children = <Widget>[];
    for (var i = 0; i < specs.length; i++) {
      if (i > 0) {
        children.add(Container(
          width: 1,
          height: 14,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          color: p.line,
        ));
      }
      children.add(Text(specs[i], style: style));
    }

    // Scales down on very narrow cards instead of overflowing.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// Placeholder with the same footprint as [ListingCard], shown while the
/// first page of listings loads.
class ListingSkeleton extends StatelessWidget {
  const ListingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BDeco.card(p),
      child: const Shimmer(
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: ListingCard.imageAspect,
              child: SkeletonBox(height: double.infinity, radius: 0),
            ),
            SizedBox(
              height: ListingCard.infoHeight,
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 190, height: 16),
                    SizedBox(height: 12),
                    SkeletonBox(width: 130, height: 12),
                    Spacer(),
                    SkeletonBox(width: 170, height: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
