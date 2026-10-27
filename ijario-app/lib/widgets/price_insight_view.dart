import 'package:flutter/material.dart';

import '../models/property.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../utils/formatters.dart';

/// "Is this a fair price?": where this listing sits against the median of
/// similar active listings. Only shown when the server had enough data.
class PriceInsightView extends StatelessWidget {
  final Property property;
  final PriceInsight insight;

  const PriceInsightView({super.key, required this.property, required this.insight});

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final Color verdictColor = insight.verdict == 'arzon'
        ? p.success
        : (insight.verdict == 'qimmat' ? p.danger : p.ink);

    // Map -40%..+40% onto the track; beyond that the marker sits at the end.
    final position = ((insight.diffPercent / 40.0 + 1) / 2).clamp(0.04, 0.96).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BDeco.card(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            insight.verdict == 'bozor_narxida'
                ? 'Bozor narxida'
                : '${insight.headline} ${insight.scopeLabel}',
            style: BType.headline(verdictColor).copyWith(fontSize: 25),
          ),
          const SizedBox(height: 6),
          Text(
            'O\'xshash ${insight.sampleSize} ta e\'lon asosida. '
            "O'rtacha narx: ${formatMoneyShort(insight.median, insight.currency)} / oy.",
            style: BType.small(p.inkMuted),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 22,
            child: CustomPaint(
              size: const Size(double.infinity, 22),
              painter: _TrackPainter(
                position: position,
                cheap: p.success,
                fair: p.inkFaint,
                dear: p.danger,
                marker: p.ink,
                halo: p.surface,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(flex: 40, child: Text('Arzon', style: BType.small(p.inkMuted))),
              Expanded(
                flex: 20,
                child: Text('Bozor narxi', textAlign: TextAlign.center, style: BType.small(p.inkMuted)),
              ),
              Expanded(
                flex: 40,
                child: Text('Qimmat', textAlign: TextAlign.right, style: BType.small(p.inkMuted)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  final double position;
  final Color cheap;
  final Color fair;
  final Color dear;
  final Color marker;
  final Color halo;

  _TrackPainter({
    required this.position,
    required this.cheap,
    required this.fair,
    required this.dear,
    required this.marker,
    required this.halo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    const trackH = 8.0;
    final w = size.width;

    RRect seg(double a, double b) => RRect.fromRectAndRadius(
          Rect.fromLTRB(w * a, cy - trackH / 2, w * b, cy + trackH / 2),
          const Radius.circular(trackH / 2),
        );

    // 40% cheap | 20% fair | 40% expensive, with a hair of space between.
    canvas.drawRRect(seg(0.0, 0.395), Paint()..color = cheap.withValues(alpha: 0.45));
    canvas.drawRRect(seg(0.405, 0.595), Paint()..color = fair.withValues(alpha: 0.55));
    canvas.drawRRect(seg(0.605, 1.0), Paint()..color = dear.withValues(alpha: 0.45));

    final center = Offset(w * position, cy);
    canvas.drawCircle(center, 11, Paint()..color = halo);
    canvas.drawCircle(center, 7.5, Paint()..color = marker);
  }

  @override
  bool shouldRepaint(covariant _TrackPainter oldDelegate) =>
      oldDelegate.position != position ||
      oldDelegate.cheap != cheap ||
      oldDelegate.fair != fair ||
      oldDelegate.dear != dear ||
      oldDelegate.marker != marker ||
      oldDelegate.halo != halo;
}
