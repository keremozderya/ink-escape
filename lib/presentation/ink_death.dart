import 'dart:math' as math;

double _ease(double start, double end, double time) {
  final t = ((time - start) / (end - start)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// A short ink breakup. All positions are sampled from age, so frame rate and
/// paused frames cannot change the shape or leave particles behind on retry.
class InkDeathPose {
  InkDeathPose(double age) : age = age.clamp(0.0, duration).toDouble();
  static const duration = .85;
  final double age;
  double get bodyOpacity => 1 - _ease(.06, .28, age);
  double get bodyLift => 3 * _ease(0, .22, age);
  double get rippleRadius => 7 + 27 * _ease(.03, .38, age);
  double get rippleOpacity =>
      .3 * _ease(0, .05, age) * (1 - _ease(.08, .38, age));
  double get stainOpacity =>
      .2 * _ease(.06, .25, age) * (1 - _ease(.42, duration, age));

  Iterable<InkDeathDrop> get drops sync* {
    for (var i = 0; i < 22; i++) {
      final start = .04 + (i % 5) * .018;
      final lifetime = .44 + (i % 4) * .045;
      final elapsed = age - start;
      if (elapsed <= 0 || elapsed >= lifetime) continue;
      final t = elapsed / lifetime;
      final angle = i * 2.399963;
      final vx = math.cos(angle) * (32 + i % 5 * 9);
      final vy = -35.0 - i % 6 * 10;
      final x = math.cos(angle) * 8 + vx * elapsed;
      final y =
          -24 + math.sin(angle) * 11 + vy * elapsed + 100 * elapsed * elapsed;
      yield InkDeathDrop(
        x,
        y,
        (1.8 + i % 4 * .55) * (1 - .55 * t),
        _ease(0, .06, elapsed) * math.pow(1 - t, 1.35),
        math.atan2(vy + 200 * elapsed, vx),
        1.2 + .65 * (1 - t),
      );
    }
  }
}

class InkDeathDrop {
  const InkDeathDrop(
    this.x,
    this.y,
    this.radius,
    this.opacity,
    this.angle,
    this.stretch,
  );
  final double x, y, radius, opacity, angle, stretch;
}
