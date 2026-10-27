import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'glass.dart';
import 'pressable.dart';

/// Heart button for placing over photos. When a listing becomes saved the
/// heart pops (1.0 -> 1.15 -> 1.0, 350ms): the "success" feedback from the
/// motion guide, kept to a 15% overshoot.
class SaveButton extends StatefulWidget {
  final bool saved;
  final VoidCallback onTap;
  final double size;

  const SaveButton({super.key, required this.saved, required this.onTap, this.size = 44});

  @override
  State<SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<SaveButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.15), weight: 40),
    TweenSequenceItem(tween: Tween<double>(begin: 1.15, end: 1.0), weight: 60),
  ]).animate(CurvedAnimation(parent: _controller, curve: BMotion.ease));

  @override
  void didUpdateWidget(covariant SaveButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.saved && !oldWidget.saved && !BMotion.reduce(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: widget.onTap,
      haptic: true,
      semanticLabel: widget.saved ? 'Saralanganlardan olib tashlash' : 'Saralanganlarga qo\'shish',
      child: ScaleTransition(
        scale: _scale,
        child: Glass(
          borderRadius: BorderRadius.circular(widget.size / 2),
          blur: 16,
          tint: Colors.black,
          tintAlpha: 0.28,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: AnimatedSwitcher(
              duration: BMotion.state,
              child: Icon(
                widget.saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                key: ValueKey<bool>(widget.saved),
                size: widget.size * 0.5,
                color: widget.saved ? BColors.rawOak : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
