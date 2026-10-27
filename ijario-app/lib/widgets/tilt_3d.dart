import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Lets a card turn towards the pointer in real perspective, with a soft
/// glare that follows the light (like holding a glossy card under a lamp).
///
/// Mouse: follows the cursor while hovering. Touch: tilts towards the
/// finger while pressed, then settles back. It never takes part in gesture
/// handling, so scrolling and taps are unaffected. Off when the OS asks for
/// reduced motion.
class Tilt3D extends StatefulWidget {
  final Widget child;
  final double radius;

  /// Maximum rotation in radians (0.07 is about 4 degrees).
  final double maxAngle;

  const Tilt3D({super.key, required this.child, this.radius = BRadius.card, this.maxAngle = 0.07});

  @override
  State<Tilt3D> createState() => _Tilt3DState();
}

class _Tilt3DState extends State<Tilt3D> {
  Offset _tilt = Offset.zero; // -1..1 on each axis, 0 = centred
  bool _active = false;

  void _set(Offset localPosition) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size.isEmpty) return;
    final dx = (localPosition.dx / box.size.width * 2 - 1).clamp(-1.0, 1.0).toDouble();
    final dy = (localPosition.dy / box.size.height * 2 - 1).clamp(-1.0, 1.0).toDouble();
    setState(() {
      _tilt = Offset(dx, dy);
      _active = true;
    });
  }

  void _reset() {
    if (!_active && _tilt == Offset.zero) return;
    setState(() {
      _tilt = Offset.zero;
      _active = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (BMotion.reduce(context)) return widget.child;

    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.0011)
      ..rotateX(-_tilt.dy * widget.maxAngle)
      ..rotateY(_tilt.dx * widget.maxAngle);

    return MouseRegion(
      onHover: (event) => _set(event.localPosition),
      onExit: (_) => _reset(),
      child: Listener(
        onPointerDown: (event) => _set(event.localPosition),
        onPointerMove: (event) {
          // Touch: stay tilted towards where the press started, so that
          // scrolling with a finger doesn't make the card wobble.
          if (event.kind == PointerDeviceKind.mouse) _set(event.localPosition);
        },
        onPointerUp: (_) => _reset(),
        onPointerCancel: (_) => _reset(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: BMotion.ease,
          transformAlignment: Alignment.center,
          transform: matrix,
          // Clip.none: the card's shadow is painted outside its box.
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              widget.child,
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _active ? 1 : 0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(widget.radius),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment(-_tilt.dx, -_tilt.dy),
                            radius: 0.95,
                            colors: [
                              const Color(0xFFFFFFFF).withValues(alpha: 0.20),
                              const Color(0x00FFFFFF),
                            ],
                          ),
                        ),
                      ),
                    ),
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
