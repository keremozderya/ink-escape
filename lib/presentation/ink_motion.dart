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
        4.8 * math.pow(math.sin(math.pi * swing), 2) * weight,
        false,
      );
    }

    final contact = math.cos(phase * 4 * math.pi);
    final breath = math.sin(time * 1.8);
    double blend(double idle, double moving) => idle + (moving - idle) * weight;
    return InkWalkPose(
      foot(0),
      foot(.5),
      blend(.4 * (1 + breath), .9 * (1 - contact)),
      blend(1 - .004 * breath, 1 + .012 * contact),
      blend(1 + .005 * breath, 1 - .014 * contact),
      grounded
          ? blend(.006 * breath, .035 + .025 * math.sin(phase * 2 * math.pi))
          : -.08,
    );
  }

  static InkWalkPose mix(InkWalkPose a, InkWalkPose b, double t) {
    double v(double x, double y) => x + (y - x) * t;
    InkFootPose foot(InkFootPose x, InkFootPose y) => InkFootPose(
      v(x.x, y.x),
      v(x.lift, y.lift),
      t < .5 ? x.planted : y.planted,
    );
    return InkWalkPose(
      foot(a.back, b.back),
      foot(a.front, b.front),
      v(a.rise, b.rise),
      v(a.width, b.width),
      v(a.height, b.height),
      v(a.lean, b.lean),
    );
  }
}

/// Frame-rate independent presentation weights. Physics and saved state never
/// depend on these values; pausing freezes them along with the animation clock.
class InkAnimationBlend {
  double support = 1, grip = 0, fall = 0;
  void reset({required bool grounded, required bool gripping}) {
    support = grounded ? 1 : 0;
    grip = gripping ? 1 : 0;
    fall = 0;
  }

  void advance(
    double dt, {
    required bool grounded,
    required bool gripping,
    required double vy,
  }) {
    final blend = 1 - math.exp(-18 * math.max(0, dt));
    support += ((grounded ? 1.0 : 0.0) - support) * blend;
    grip += ((gripping ? 1.0 : 0.0) - grip) * blend;
    final target = grounded || gripping ? 0.0 : (-vy / 250).clamp(0.0, 1.0);
    fall += (target - fall) * blend;
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

  static InkGroundPose mix(InkGroundPose a, InkGroundPose b, double t) {
    double v(double x, double y) => x + (y - x) * t;
    InkFootPlacement foot(InkFootPlacement x, InkFootPlacement y) =>
        InkFootPlacement(v(x.x, y.x), v(x.y, y.y), v(x.angle, y.angle));
    return InkGroundPose(
      foot(a.back, b.back),
      foot(a.front, b.front),
      v(a.bodyLift, b.bodyLift),
    );
  }

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
    // Shoes rotate with the surface. Reserve room for their full upper edge,
    // rather than letting the lifted front shoe overlap the body's hem.
    final shoeTilt = math.max(
      math.sin(back.angle).abs(),
      math.sin(front.angle).abs(),
    );
    final clearance = grounded ? 6 + 4 * shoeTilt : 3.0;
    final lift = math.max(
      0.0,
      math.max(-back.y, -front.y) + clearance - 9 - pose.rise,
    );
    return InkGroundPose(back, front, lift);
  }
}

/// The exact body transform is shared by the sprite and both hip attachments.
class InkBodyRig {
  const InkBodyRig(this.raise, this.angle, this.scaleX, this.scaleY);
  final double raise, angle, scaleX, scaleY;
  (double, double) point(double x, double y) {
    final xx = x * scaleX, yy = y * scaleY;
    return (
      xx * math.cos(angle) - yy * math.sin(angle),
      xx * math.sin(angle) + yy * math.cos(angle) - raise,
    );
  }

  (double, double) inverse(double x, double y) {
    final yy = y + raise;
    return (
      (x * math.cos(angle) + yy * math.sin(angle)) / scaleX,
      (-x * math.sin(angle) + yy * math.cos(angle)) / scaleY,
    );
  }
}

/// Monotone control points avoid a short leg curling back through the body.
class InkLegCurve {
  InkLegCurve(this.hip, this.ankle) {
    final dx = ankle.$1 - hip.$1, dy = ankle.$2 - hip.$2;
    final bend = math.min(1.5, math.max(0.0, dy) * .15);
    first = (hip.$1 + dx / 3 - bend, hip.$2 + dy / 3);
    second = (hip.$1 + dx * 2 / 3 - bend, hip.$2 + dy * 2 / 3);
  }
  final (double, double) hip, ankle;
  late final (double, double) first, second;
}

/// Animate the atlas's own front arm. Its palm stays on the rim until the
/// front foot takes over; the shoulder always remains attached to the body.
class InkLedgeArmPose {
  InkLedgeArmPose(double targetX, double targetY, double rise) {
    final release = ((rise - .55) / .2).clamp(0.0, 1.0);
    final ease = release * release * (3 - 2 * release);
    final endX = targetX + (palmX - targetX) * ease;
    final endY = targetY + (palmY - targetY) * ease;
    final dx = endX - shoulderX, dy = endY - shoulderY;
    angle = math.atan2(dy, dx);
    lengthScale = math.sqrt(dx * dx + dy * dy) / armLength;
  }
  static const shoulderX = -27 + 312 * 54 / 443.5;
  static const shoulderY = -47.52 + 300 * 54 / 443.5;
  static const palmX = -27 + 347 * 54 / 443.5;
  static const palmY = -47.52 + 285 * 54 / 443.5;
  static final baseAngle = math.atan2(palmY - shoulderY, palmX - shoulderX);
  static final armLength = math.sqrt(
    math.pow(palmX - shoulderX, 2) + math.pow(palmY - shoulderY, 2),
  );
  late final double angle, lengthScale;

  (double, double) transform(double x, double y) {
    final dx = x - shoulderX, dy = y - shoulderY;
    final along =
        (dx * math.cos(baseAngle) + dy * math.sin(baseAngle)) * lengthScale;
    final across = -dx * math.sin(baseAngle) + dy * math.cos(baseAngle);
    return (
      shoulderX + along * math.cos(angle) - across * math.sin(angle),
      shoulderY + along * math.sin(angle) + across * math.cos(angle),
    );
  }
}
