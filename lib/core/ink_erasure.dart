part of 'ink_model.dart';

/// The same rotated, rounded footprint used to draw the wandering eraser.
/// Cuts visible world contours in place; source geometry and paid ink stay
/// immutable, and separated fragments still occupy just one drawing slot.
class InkEraser {
  const InkEraser(this.center);
  final V center;
  static const halfWidth = 14.0, halfHeight = 10.0, corner = 3.0, angle = .12;
  static const _epsilon = 1e-8;

  V _local(V p) {
    final d = p - center, c = math.cos(angle), s = math.sin(angle);
    return V(d.x * c + d.y * s, -d.x * s + d.y * c);
  }

  (double, double)? _rect(V a, V d, double hx, double hy) {
    var lo = 0.0, hi = 1.0;
    for (final axis in [(a.x, d.x, hx), (a.y, d.y, hy)]) {
      if (axis.$2.abs() < _epsilon) {
        if (axis.$1.abs() > axis.$3) return null;
      } else {
        final x = (-axis.$3 - axis.$1) / axis.$2,
            y = (axis.$3 - axis.$1) / axis.$2;
        lo = math.max(lo, math.min(x, y));
        hi = math.min(hi, math.max(x, y));
        if (lo >= hi - _epsilon) return null;
      }
    }
    return (lo, hi);
  }

  (double, double)? _circle(V a, V d, V at) {
    final p = a - at, aa = d.x * d.x + d.y * d.y;
    if (aa < _epsilon) return null;
    final b = p.x * d.x + p.y * d.y,
        c = p.x * p.x + p.y * p.y - corner * corner,
        discriminant = b * b - aa * c;
    if (discriminant <= _epsilon) return null;
    final root = math.sqrt(discriminant),
        lo = math.max(0.0, (-b - root) / aa),
        hi = math.min(1.0, (-b + root) / aa);
    return lo < hi - _epsilon ? (lo, hi) : null;
  }

  (double, double)? _inside(V from, V to) {
    final a = _local(from), d = _local(to) - a;
    final intervals = [
      _rect(a, d, halfWidth - corner, halfHeight),
      _rect(a, d, halfWidth, halfHeight - corner),
      for (final x in [-halfWidth + corner, halfWidth - corner])
        for (final y in [-halfHeight + corner, halfHeight - corner])
          _circle(a, d, V(x, y)),
    ].whereType<(double, double)>().toList();
    if (intervals.isEmpty) return null;
    // A rounded rectangle is convex: all component intersections form one run.
    return (
      intervals.map((r) => r.$1).reduce(math.min),
      intervals.map((r) => r.$2).reduce(math.max),
    );
  }

  bool erase(InkLine line) {
    if (line.retired ||
        line.concealed ||
        line.right < center.x - 18 ||
        line.left > center.x + 18) {
      return false;
    }
    final remaining = <List<V>>[];
    var changed = false;
    for (final path in line.contours) {
      var run = <V>[];
      void flush() {
        if (run.length > 1) remaining.add(run);
        run = [];
      }

      void keep(V a, V b) {
        if (a.distance(b) < _epsilon) return;
        if (run.isEmpty) {
          run.add(a);
        } else if (run.last.distance(a) > _epsilon) {
          flush();
          run.add(a);
        }
        run.add(b);
      }

      for (var i = 1; i < path.length; i++) {
        final a = path[i - 1], b = path[i], delta = b - a;
        final cut = _inside(a, b);
        if (cut == null) {
          keep(a, b);
          continue;
        }
        changed = true;
        keep(a, a + delta * cut.$1);
        flush();
        keep(a + delta * cut.$2, b);
      }
      flush();
    }
    if (changed) line.setContours(remaining);
    return changed;
  }
}
