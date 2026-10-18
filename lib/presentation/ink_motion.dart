import 'dart:math' as math;
import 'package:flutter/animation.dart';

/// Presentation only: these poses never change Dot's collider or physics.
class InkFootPose {
  const InkFootPose(this.x, this.lift, this.planted);
  final double x, lift;
  final bool planted;
}

class InkWalkPose {
  const InkWalkPose(
    this.back,
    this.front,
    this.rise,
    this.width,
    this.height,
    this.lean,
  );
  final InkFootPose back, front;
  final double rise, width, height, lean;
  static InkWalkPose sample(
    double distance, {
    required bool grounded,
    required bool walking,
    double time = 0,
  }) {
    final phase = (distance / 28) % 1;
    InkFootPose foot(double offset) {
      if (!grounded) {
        return const InkFootPose(-2, 4, false);
      }
      if (!walking) {
        return InkFootPose(offset == 0 ? -4 : 4, 0, true);
      }
      final p = (phase + offset) % 1;
      if (p < .5) {
        return InkFootPose(7 - 28 * p, 0, true);
      }
      final swing = (p - .5) * 2;
      final ease = Curves.easeInOutCubic.transform(swing);
      return InkFootPose(
        -7 + 14 * ease,
        4.5 * math.sin(math.pi * swing),
        false,
      );
    }

    final contact = math.cos(phase * 4 * math.pi);
    final breath = math.sin(time * 1.8);
    return InkWalkPose(
      foot(0),
      foot(.5),
      walking && grounded ? .9 * (1 - contact) : .35 * (1 + breath),
      walking && grounded ? 1 + .023 * contact : 1 - .007 * breath,
      walking && grounded ? 1 - .024 * contact : 1 + .009 * breath,
      grounded
          ? (walking ? .018 * math.sin(phase * 2 * math.pi) : .005 * breath)
          : .07,
    );
  }
}
