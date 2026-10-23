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
    double movement = 1,
  }) {
    final weight = walking && grounded ? movement.clamp(0.0, 1.0) : 0.0;
    final phase = (distance / 40) % 1;
    InkFootPose foot(double offset) {
      if (!grounded) {
        return InkFootPose(offset == 0 ? -7 : 7, offset == 0 ? 5 : 8, false);
      }
      if (weight == 0) {
        return InkFootPose(offset == 0 ? -4 : 4, 0, true);
      }
      final p = (phase + offset) % 1;
      final idleX = offset == 0 ? -4.0 : 4.0;
      if (p < .5) {
        return InkFootPose(idleX + (10 - 40 * p - idleX) * weight, 0, true);
      }
      final swing = (p - .5) * 2;
      final ease = swing * swing * (3 - 2 * swing);
      return InkFootPose(
        idleX + (-10 + 20 * ease - idleX) * weight,
        6.2 * math.pow(math.sin(math.pi * swing), 2) * weight,
        false,
      );
    }

    final contact = math.cos(phase * 4 * math.pi);
    final breath = math.sin(time * 1.8);
    double blend(double idle, double moving) => idle + (moving - idle) * weight;
    return InkWalkPose(
      foot(0),
      foot(.5),
      blend(.4 * (1 + breath), 1.45 * (1 - contact)),
      blend(1 - .009 * breath, 1 + .035 * contact),
      blend(1 + .012 * breath, 1 - .036 * contact),
      grounded
          ? blend(.006 * breath, .035 + .025 * math.sin(phase * 2 * math.pi))
          : -.08,
    );
  }
}

class InkFootPlacement {
  const InkFootPlacement(this.x, this.y, this.angle);
  final double x, y, angle;
}

/// Place feet along the supporting contour instead of extending one tangent
/// through a hilltop or ditch. Shorter strides keep steep steps within reach.
class InkGroundPose {
  const InkGroundPose(this.back, this.front, this.bodyLift);
  final InkFootPlacement back, front;
  final double bodyLift;

  static double strideForAngle(double angle) => 1 - .55 * math.sin(angle).abs();

  static InkGroundPose place(
    InkWalkPose pose, {
    required bool grounded,
    required double angle,
    required double stride,
    required (double, double)? Function(double) sampleGround,
  }) {
    InkFootPlacement foot(InkFootPose p, double hip) {
      final along = (p.x + hip * .18) * (grounded ? stride : 1);
      final hit = grounded ? sampleGround(along) : null;
      final x = hit?.$1 ?? along * (grounded ? math.cos(angle) : 1);
      final height = hit?.$2 ?? along * (grounded ? math.sin(angle) : 0);
      final before = grounded ? sampleGround(along - .5) : null;
      final after = grounded ? sampleGround(along + .5) : null;
      final tangent = before != null && after != null
          ? math.atan2(after.$2 - before.$2, after.$1 - before.$1)
          : grounded
          ? angle
          : 0.0;
      return InkFootPlacement(
        x,
        -height - p.lift,
        -tangent.clamp(-math.pi / 3, math.pi / 3),
      );
    }

    final back = foot(pose.back, -5), front = foot(pose.front, 5);
    final lift = grounded
        ? math.max(0.0, math.max(-back.y, -front.y) - 6)
        : 0.0;
    return InkGroundPose(back, front, lift);
  }
}
