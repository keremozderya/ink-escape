import 'dart:math' as math;

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
    final phase = (distance / 40) % 1;
    InkFootPose foot(double offset) {
      if (!grounded) {
        return InkFootPose(offset == 0 ? -7 : 7, offset == 0 ? 5 : 8, false);
      }
      if (!walking) {
        return InkFootPose(offset == 0 ? -4 : 4, 0, true);
      }
      final p = (phase + offset) % 1;
      if (p < .5) {
        return InkFootPose(10 - 40 * p, 0, true);
      }
      final swing = (p - .5) * 2;
      final ease = swing * swing * (3 - 2 * swing);
      return InkFootPose(
        -10 + 20 * ease,
        6.2 * math.pow(math.sin(math.pi * swing), 2),
        false,
      );
    }

    final contact = math.cos(phase * 4 * math.pi);
    final breath = math.sin(time * 1.8);
    return InkWalkPose(
      foot(0),
      foot(.5),
      walking && grounded ? 1.45 * (1 - contact) : .4 * (1 + breath),
      walking && grounded ? 1 + .035 * contact : 1 - .009 * breath,
      walking && grounded ? 1 - .036 * contact : 1 + .012 * breath,
      grounded
          ? (walking
                ? .035 + .025 * math.sin(phase * 2 * math.pi)
                : .006 * breath)
          : -.08,
    );
  }
}
