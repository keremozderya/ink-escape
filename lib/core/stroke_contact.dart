part of 'ink_model.dart';

class _StrokeContact {
  const _StrokeContact(this.anchor, this.segment, this.fraction, this.gap);
  final Anchor anchor;
  final int segment;
  final double fraction, gap;
}

/// Test continuous pen segments, not only pointer samples. The visible ink rim
/// may touch paper; pin that touch before smoothing and charging the stroke.
extension _StrokeContactRules on InkSession {
  static const contactRadius = 2.1;

  Iterable<Surface> get _drawingSurfaces sync* {
    for (final surface in [...level.terrain, ...level.anchors]) {
      if (surface.id != 'previous-tail') yield surface;
    }
  }

  (V, double) _projectOn(V p, V a, V b) {
    final d = b - a, length2 = d.x * d.x + d.y * d.y;
    final t = length2 < 1e-12
        ? 0.0
        : (((p - a).x * d.x + (p - a).y * d.y) / length2).clamp(0.0, 1.0);
    return (a + d * t, t);
  }

  Anchor? _pointContact(V point) {
    Anchor? best;
    var gap = contactRadius + 1e-7;
    for (final surface in _drawingSurfaces) {
      final q = _projectOn(point, surface.a, surface.b).$1;
      final distance = q.distance(point);
      if (distance < gap) {
        gap = distance;
        best = Anchor(q, surface);
      }
    }
    return best;
  }

  _StrokeContact _closestContact(V a, V b, Surface surface, int segment) {
    final c = surface.a, d = surface.b, ab = b - a, cd = d - c;
    final cross = ab.x * cd.y - ab.y * cd.x;
    if (cross.abs() > 1e-10) {
      final ca = c - a;
      final t = (ca.x * cd.y - ca.y * cd.x) / cross;
      final u = (ca.x * ab.y - ca.y * ab.x) / cross;
      if (t >= 0 && t <= 1 && u >= 0 && u <= 1) {
        return _StrokeContact(Anchor(c + cd * u, surface), segment, t, 0);
      }
    }
    final pa = _projectOn(a, c, d).$1, pb = _projectOn(b, c, d).$1;
    final pc = _projectOn(c, a, b), pd = _projectOn(d, a, b);
    return [
      _StrokeContact(Anchor(pa, surface), segment, 0, pa.distance(a)),
      _StrokeContact(Anchor(pb, surface), segment, 1, pb.distance(b)),
      _StrokeContact(Anchor(c, surface), segment, pc.$2, c.distance(pc.$1)),
      _StrokeContact(Anchor(d, surface), segment, pd.$2, d.distance(pd.$1)),
    ].reduce(
      (x, y) =>
          y.gap < x.gap - 1e-8 ||
              (y.gap - x.gap).abs() < 1e-8 && y.fraction < x.fraction
          ? y
          : x,
    );
  }

  _StrokeContact? _drawingContact(List<V> points) {
    _StrokeContact? near;
    final surfaces = _drawingSurfaces.toList();
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      _StrokeContact? exact;
      for (final surface in surfaces) {
        if (math.max(a.x, b.x) + contactRadius <
                math.min(surface.a.x, surface.b.x) ||
            math.min(a.x, b.x) - contactRadius >
                math.max(surface.a.x, surface.b.x) ||
            math.max(a.y, b.y) + contactRadius <
                math.min(surface.a.y, surface.b.y) ||
            math.min(a.y, b.y) - contactRadius >
                math.max(surface.a.y, surface.b.y)) {
          continue;
        }
        final hit = _closestContact(a, b, surface, i - 1);
        if (hit.gap < 1e-7) {
          if (exact == null || hit.fraction < exact.fraction) exact = hit;
        } else if (hit.gap <= contactRadius &&
            (near == null || hit.gap < near.gap)) {
          near = hit;
        }
      }
      if (exact != null) return exact;
    }
    return near;
  }

  List<V> _smoothContact(List<V> raw, _StrokeContact contact) {
    final index = contact.segment + (contact.fraction < 1e-7 ? 0 : 1);
    if (contact.fraction < 1e-7 || contact.fraction > 1 - 1e-7) {
      raw[index] = contact.anchor.point;
    } else {
      raw.insert(index, contact.anchor.point);
    }
    // Preserve an interior touch even when resampling a sharp V would round it
    // away from paper. The final preview, collision and paid path are identical.
    return [
      ...smoothStroke(raw.take(index + 1).toList()),
      ...smoothStroke(raw.skip(index).toList()).skip(1),
    ];
  }
}
