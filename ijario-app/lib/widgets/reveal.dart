import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// One-shot entrance: fades in while rising [dy] pixels (500ms, signature
/// curve). Give siblings consecutive [index] values to stagger them by 70ms;
/// the delay is capped so a long list never makes anyone wait.
/// With "reduce motion" on, the content simply appears.
class Reveal extends StatefulWidget {
  final Widget child;
  final int index;
  final double dy;

  const Reveal({super.key, required this.child, this.index = 0, this.dy = 18});

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: BMotion.enter);
  late final Animation<double> _curve =
      CurvedAnimation(parent: _controller, curve: BMotion.emphasized);
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (BMotion.reduce(context)) {
      _controller.value = 1;
      return;
    }
    final steps = widget.index < 0 ? 0 : (widget.index > 6 ? 6 : widget.index);
    final delay = BMotion.stagger * steps;
    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) {
        final v = _curve.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, (1 - v) * widget.dy), child: child),
        );
      },
    );
  }
}
