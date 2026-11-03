import 'dart:math' as math;

import '../core/ink_model.dart';

/// Small presentation records sampled against game time. Pausing therefore
/// freezes a board in flight and its trail without separate timers or physics.
class InkSurfAnimation {
  double? _started;
  int _seed = 0;
  double rideAngle = 0;
  final List<InkSurfFlight> flights = [];
  final List<InkSurfDust> dust = [];
  static const maxDust = 32, maxFlights = 3;

  void begin(double time, {double angle = 0}) {
    _started = time;
    rideAngle = angle;
  }

  /// Board and feet share one frame-rate independent, shortest-turn rotation.
  void follow(double target, double dt) {
    final delta = math.atan2(
      math.sin(target - rideAngle),
      math.cos(target - rideAngle),
    );
    rideAngle += delta * (1 - math.exp(-18 * math.max(0, dt)));
  }

  double drawProgress(double time) =>
      _started == null ? 1 : ((time - _started!) / .14).clamp(0.0, 1.0);

  void release(InkSlideExit exit) {
    flights.add(InkSurfFlight(exit));
    if (flights.length > maxFlights) flights.removeAt(0);
    _started = null;
  }

  void friction(V contact, double angle, double time) {
    final direction = V(math.cos(angle), math.sin(angle)),
        normal = V(-math.sin(angle), math.cos(angle));
    for (var i = 0; i < 2; i++) {
      final seed = _seed++;
      dust.add(
        InkSurfDust(
          contact - direction * (11.0 + seed % 4) + normal * .7,
          direction * (-9.0 - seed % 6) + normal * (6.0 + seed % 8),
          time,
          .32 + seed % 4 * .035,
          .6 + seed % 3 * .2,
          seed.isEven,
        ),
      );
    }
    if (dust.length > maxDust) dust.removeRange(0, dust.length - maxDust);
  }

  void prune(double time) {
    flights.removeWhere((p) => time - p.started >= InkSurfFlight.duration);
    dust.removeWhere((p) => time - p.started >= p.life);
  }

  void reset() {
    _started = null;
    _seed = 0;
    rideAngle = 0;
    flights.clear();
    dust.clear();
  }
}

class InkSurfFlight {
  InkSurfFlight(InkSlideExit exit)
    : origin = exit.position,
      started = exit.time,
      angle = exit.angle + separationAngle,
      velocity =
          V(
            math.cos(exit.angle + separationAngle),
            math.sin(exit.angle + separationAngle),
          ) *
          math.max(25, exit.velocity.length * .78);
  final V origin, velocity;
  final double started, angle;
  static const duration = .95, separationAngle = 8 * math.pi / 180;
  V position(double time) {
    final age = (time - started).clamp(0.0, duration);
    return origin + velocity * age + V(0, -60 * age * age);
  }

  double rotation(double time) =>
      angle - .16 * (time - started).clamp(0.0, duration);
  double opacity(double time) => math
      .pow((1 - (time - started) / duration).clamp(0.0, 1.0), 1.4)
      .toDouble();
}

class InkSurfDust {
  const InkSurfDust(
    this.origin,
    this.velocity,
    this.started,
    this.life,
    this.size,
    this.fleck,
  );
  final V origin, velocity;
  final double started, life, size;
  final bool fleck;
  V position(double time) {
    final age = (time - started).clamp(0.0, life);
    return origin + velocity * age + V(0, -16 * age * age);
  }

  double opacity(double time) =>
      (1 - (time - started) / life).clamp(0.0, 1.0) * .6;
}
