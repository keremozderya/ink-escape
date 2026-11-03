part of 'ink_model.dart';

/// An ink-toothed strip fixed to a paper surface. These same triangles are
/// painted and used for continuous body contact, including the front shoe.
class InkSpikeBed {
  InkSpikeBed(
    this.id,
    this.left,
    this.right, {
    this.y = 0,
    this.height = 10,
    this.pitch = 10,
  }) {
    if (![left, right, y, height, pitch].every((v) => v.isFinite) ||
        right <= left ||
        height <= 0 ||
        pitch <= 0) {
      throw ArgumentError(
        'A spike bed needs a finite positive span, height and pitch',
      );
    }
  }
  final String id;
  final double left, right, y, height, pitch;
  late final List<List<V>> teeth = List.unmodifiable(_teeth());

  Iterable<List<V>> _teeth() sync* {
    final count = ((right - left) / pitch).ceil(),
        width = (right - left) / count;
    final seed = id.codeUnits.fold(0, (sum, n) => sum + n);
    for (var i = 0; i < count; i++) {
      final x = left + width * i;
      final h = height * (.82 + ((seed + i * 7) % 5) * .045);
      yield List.unmodifiable([
        V(x, y),
        V(x + width, y),
        V(x + width * (.42 + (i % 3) * .07), y + h),
      ]);
    }
  }

  bool hitsBody(V from, V to) {
    if (math.max(from.x, to.x) + InkSession._bodyHalfWidth < left ||
        math.min(from.x, to.x) - InkSession._bodyHalfWidth > right ||
        math.min(from.y, to.y) > y + height ||
        math.max(from.y, to.y) + InkSession.dotHeight < y) {
      return false;
    }
    return teeth.any((triangle) => _sweptBodyPolygon(from, to, triangle));
  }
}

enum InkSawPhase { hidden, warning, extending, exposed, retracting }

/// A rotating cutter in a real paper wall. Its clock is gameTime, so pause,
/// retry and an ordinary saved session need no independent animation timer.
class InkWallSaw {
  InkWallSaw(
    this.id,
    this.mount, {
    this.direction = -1,
    this.radius = 16,
    this.reach = 34,
    this.period = 5.6,
    this.offset = 0,
  }) {
    if ((direction != -1 && direction != 1) ||
        ![
          mount.x,
          mount.y,
          radius,
          reach,
          period,
          offset,
        ].every((v) => v.isFinite) ||
        radius <= 0 ||
        reach <= 0 ||
        period < .5) {
      throw ArgumentError(
        'A wall saw needs finite dimensions, direction ±1 and a period of at least .5 seconds',
      );
    }
  }
  final String id;
  final V mount;
  final int direction;
  final double radius, reach, period, offset;
  double _cycle(double time) => ((time + offset) % period) / period;
  InkSawPhase phaseAt(double time) {
    final p = _cycle(time);
    if (p < .40) return InkSawPhase.hidden;
    if (p < .48) return InkSawPhase.warning;
    if (p < .62) return InkSawPhase.extending;
    if (p < .83) return InkSawPhase.exposed;
    return InkSawPhase.retracting;
  }

  double amountAt(double time) {
    final p = _cycle(time);
    double ease(double t) => t * t * (3 - 2 * t);
    if (p < .48) return 0;
    if (p < .62) return ease((p - .48) / .14);
    if (p < .83) return 1;
    return 1 - ease((p - .83) / .17);
  }

  V centerAt(double time) =>
      mount +
      V(direction * (-(radius + 4) + (radius + 4 + reach) * amountAt(time)), 0);
  double angleAt(double time) => time * math.pi * 1.4 * direction;
  bool exposedAt(double time) =>
      direction * (centerAt(time).x - mount.x) + radius > 1e-7;

  bool hitsBody(V from, V to, double start, double end) {
    // Behind the wall the cutter is harmless, even while it keeps rotating.
    if ((from.x - mount.x) * direction + InkSession._bodyHalfWidth < 0 &&
        (to.x - mount.x) * direction + InkSession._bodyHalfWidth < 0) {
      return false;
    }
    // Subdivide the clock, then sweep relative motion rather than checking only
    // final positions. A fast rider and a blade moving toward a waiting Dot
    // cannot tunnel through each other.
    final steps = math.max(1, ((end - start).abs() * 240).ceil());
    for (var i = 0; i < steps; i++) {
      final a = i / steps, b = (i + 1) / steps;
      final t0 = start + (end - start) * a, t1 = start + (end - start) * b;
      if (!exposedAt(t0) && !exposedAt(t1)) continue;
      final p =
          centerAt(t0) -
          (from + (to - from) * a + const V(0, InkSession.dotHeight / 2));
      final q =
          centerAt(t1) -
          (from + (to - from) * b + const V(0, InkSession.dotHeight / 2));
      if (_segmentBoxDistance(
            p,
            q,
            InkSession._bodyHalfWidth,
            InkSession.dotHeight / 2,
          ) <=
          radius) {
        return true;
      }
    }
    return false;
  }
}

bool _sweptBodyPolygon(V from, V to, List<V> polygon) {
  var enter = 0.0, leave = 1.0;
  final axes = <V>[const V(1, 0), const V(0, 1)];
  for (var i = 0; i < polygon.length; i++) {
    final d = polygon[(i + 1) % polygon.length] - polygon[i];
    axes.add(V(-d.y, d.x));
  }
  for (final axis in axes) {
    if (axis.length < 1e-9) continue;
    double dot(V p) => p.x * axis.x + p.y * axis.y;
    final values = polygon.map(dot);
    final half =
        axis.x.abs() * InkSession._bodyHalfWidth +
        axis.y.abs() * InkSession.dotHeight / 2;
    final low = values.reduce(math.min) - half,
        high = values.reduce(math.max) + half;
    final origin = dot(from + const V(0, InkSession.dotHeight / 2)),
        velocity = dot(to - from);
    if (velocity.abs() < 1e-10) {
      if (origin < low || origin > high) return false;
    } else {
      final a = (low - origin) / velocity, b = (high - origin) / velocity;
      enter = math.max(enter, math.min(a, b));
      leave = math.min(leave, math.max(a, b));
      if (enter > leave) return false;
    }
  }
  return enter <= leave;
}

double _segmentBoxDistance(V a, V b, double halfWidth, double halfHeight) {
  final delta = b - a;
  var enter = 0.0, leave = 1.0;
  for (final (origin, speed, half) in [
    (a.x, delta.x, halfWidth),
    (a.y, delta.y, halfHeight),
  ]) {
    if (speed.abs() < 1e-10) {
      if (origin.abs() > half) {
        enter = 2;
        break;
      }
    } else {
      final p = (-half - origin) / speed, q = (half - origin) / speed;
      enter = math.max(enter, math.min(p, q));
      leave = math.min(leave, math.max(p, q));
    }
  }
  if (enter <= leave) return 0;
  double pointBox(V p) => V(
    math.max(0, p.x.abs() - halfWidth),
    math.max(0, p.y.abs() - halfHeight),
  ).length;
  var closest = math.min(pointBox(a), pointBox(b));
  final length2 = delta.x * delta.x + delta.y * delta.y;
  for (final corner in [
    V(-halfWidth, -halfHeight),
    V(halfWidth, -halfHeight),
    V(halfWidth, halfHeight),
    V(-halfWidth, halfHeight),
  ]) {
    final d = corner - a;
    final t = length2 < 1e-10
        ? 0.0
        : ((d.x * delta.x + d.y * delta.y) / length2).clamp(0.0, 1.0);
    closest = math.min(closest, corner.distance(a + delta * t));
  }
  return closest;
}

extension _ObstacleContacts on InkSession {
  bool _checkObstacles(V before, double beforeTime) {
    final after = V(x, y);
    for (final bed in level.spikes) {
      if (bed.hitsBody(before, after)) {
        die('Dikenlerin üstüne basmadan bir yol çiz.');
        return true;
      }
    }
    for (final saw in level.wallSaws) {
      if (saw.hitsBody(before, after, beforeTime, gameTime)) {
        die('Bıçak geri çekilene kadar bekle ya da üstünden geç.');
        return true;
      }
    }
    return false;
  }
}
