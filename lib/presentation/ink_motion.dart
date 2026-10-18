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
    double verticalSpeed = 0,
    double landing = 0,
  }) {
    final phase = (distance / 28) % 1;
    InkFootPose foot(double offset) {
      if (!grounded) {
        return InkFootPose(offset == 0 ? -4 : 5, offset == 0 ? 5 : 3, false);
      }
      if (!walking) {
        return InkFootPose(offset == 0 ? -4 : 4, 0, true);
      }
      final p = (phase + offset) % 1;
      if (p < .5) {
        return InkFootPose(7 - 28 * p, 0, true);
      }
      final swing = (p - .5) * 2;
      // Hermite return with -1 ground-relative velocity at both contacts.
      // A planted foot travels -distance, so it stays fixed on the paper.
      final swingX =
          -7 - 14 * swing + 84 * swing * swing - 56 * swing * swing * swing;
      return InkFootPose(
        swingX,
        5.2 * math.pow(math.sin(math.pi * swing), 2),
        false,
      );
    }

    final contact = math.cos(phase * 4 * math.pi);
    final breath = math.sin(time * 1.8);
    return InkWalkPose(
      foot(0),
      foot(.5),
      grounded
          ? (walking ? 1.1 * (1 - contact) : .25 * (1 + breath)) - 1.4 * landing
          : .5,
      grounded
          ? (walking ? 1 + .035 * contact : 1 - .007 * breath) + .09 * landing
          : .94,
      grounded
          ? (walking ? 1 - .032 * contact : 1 + .009 * breath) - .08 * landing
          : 1.06,
      grounded
          ? (walking
                ? .035 + .012 * math.sin(phase * 2 * math.pi)
                : .005 * breath)
          : (verticalSpeed / 1000).clamp(-.12, .06).toDouble(),
    );
  }
}
