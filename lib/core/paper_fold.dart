part of 'ink_model.dart';

/// A flat sheet with a fixed crease. The moving region closes onto the same
/// drawing plane by reflection; there is no perspective, lift or hinged ramp.
/// Both collision and ink visibility come from the resulting paper silhouette.
class FoldPaper {
  FoldPaper(this.session, {this.cover = false})
    : crease = V(cover ? 260 : 160, 0),
      normal = cover ? const V(1, 0) : V(1 / math.sqrt(10), 3 / math.sqrt(10));
  final InkSession session;
  final bool cover;
  final V crease, normal;
  static const depth = 110.0, duration = .95, buttonX = 90.0;
  final Map<InkLine, _PaperInk> _ink = {};
  final List<Surface> surfaces = [];
  bool pressed = false;
  double progress = 0;
  double get angle => math.pi * (progress * progress * (3 - 2 * progress));
  bool get frontFacing => math.cos(angle) > 1e-6;
  bool get backFacing => math.cos(angle) < -1e-6;
  bool get settled => progress >= 1;
  double _side(V p) =>
      (p.x - crease.x) * normal.x + (p.y - crease.y) * normal.y;
  List<V> get source => cover
      ? [
          const V(260, 0),
          const V(370, 0),
          const V(370, -depth),
          const V(260, -depth),
        ]
      : [
          const V(160, 0),
          const V(340, 0),
          const V(340, -depth),
          const V(160, -depth),
        ];
  List<V> get flap => _half(source, true);
  List<V> get fixed => _half(source, false);
  List<V> get polygon => flap.map(project).toList();
  V get creaseEnd => cover ? const V(260, -depth) : const V(340, -60);

  V project(V p) => p - normal * (_side(p) * (1 - math.cos(angle)));
  V _unproject(V p) => p + normal * (_side(p) * (1 / math.cos(angle) - 1));

  List<V> _half(List<V> poly, bool moving) {
    final result = <V>[];
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i], b = poly[(i + 1) % poly.length];
      final da = _side(a) * (moving ? 1 : -1),
          db = _side(b) * (moving ? 1 : -1);
      if (da >= -1e-7) result.add(a);
      if ((da > 1e-7 && db < -1e-7) || (da < -1e-7 && db > 1e-7)) {
        result.add(a + (b - a) * (da / (da - db)));
      }
    }
    return result;
  }

  void prepare() => _surface();

  /// Only the upper outline supports feet. Lower polygon edges must never
  /// become invisible floors, and an edge-on flap cannot create a tall wall.
  void _surface() {
    session.level.terrain.removeWhere((s) => surfaces.contains(s));
    surfaces.clear();
    final polys = [
      if (fixed.length >= 3) fixed,
      if (math.cos(angle).abs() > 1e-6) polygon,
    ];
    final xs = polys.expand((p) => p.map((v) => v.x)).toSet().toList()..sort();
    for (var i = 1; i < xs.length; i++) {
      final left = xs[i - 1], right = xs[i];
      if (right - left < 1e-6) {
        continue;
      }
      final mid = (left + right) / 2;
      (V, V)? upper;
      double? height;
      for (final poly in polys) {
        for (var j = 0; j < poly.length; j++) {
          final a = poly[j], b = poly[(j + 1) % poly.length];
          if ((b.x - a.x).abs() < 1e-8 ||
              mid < math.min(a.x, b.x) ||
              mid > math.max(a.x, b.x)) {
            continue;
          }
          final y = a.y + (b.y - a.y) * (mid - a.x) / (b.x - a.x);
          if (height == null || y > height) {
            height = y;
            upper = (a, b);
          }
        }
      }
      if (upper == null) continue;
      final (a, b) = upper;
      double y(double x) => a.y + (b.y - a.y) * (x - a.x) / (b.x - a.x);
      final next = Surface(
        'lab-paper-sheet:${surfaces.length}',
        V(left, y(left)),
        V(right, y(right)),
      );
      surfaces.add(next);
    }
    session.level.terrain.addAll(surfaces);
  }

  Anchor? anchorAt(V p) {
    Anchor? nearest;
    var distance = 20.0;
    for (final edge in surfaces) {
      final q = edge.project(p), d = q.distance(p);
      if (d < distance) {
        nearest = Anchor(q, edge);
        distance = d;
      }
    }
    return nearest;
  }

  void bind(InkLine line, Surface anchor) {
    // Split at the actual flap outline, not an infinite half-plane: drawings
    // on another bank remain fixed even if they lie on the same crease side.
    if (math.cos(angle).abs() >= .08) {
      _ink[line] = _PaperInk([
        for (final piece in _split(line.points, polygon))
          (piece.$2 ? piece.$1.map(_unproject).toList() : piece.$1, piece.$2),
      ], frontFacing);
    }
    _apply(line);
  }

  List<(List<V>, bool)> _split(List<V> points, List<V> poly) {
    final result = <(List<V>, bool)>[];
    void add(V a, V b, bool moving) {
      if (a.distance(b) < 1e-7) return;
      if (result.isNotEmpty &&
          result.last.$2 == moving &&
          result.last.$1.last.distance(a) < 1e-6) {
        result.last.$1.add(b);
      } else {
        result.add(([a, b], moving));
      }
    }

    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i], delta = b - a;
      final interval = _paperInterval(a, b, poly);
      if (interval == null) {
        add(a, b, false);
        {
          continue;
        }
      }
      final (lo, hi) = interval;
      add(a, a + delta * lo, false);
      add(a + delta * lo, a + delta * hi, true);
      add(a + delta * hi, b, false);
    }
    return result;
  }

  List<List<V>> _view(_PaperInk ink) {
    final paths = <List<V>>[];
    for (final piece in ink.pieces) {
      if (piece.$2 &&
          (ink.front != frontFacing || math.cos(angle).abs() < 1e-5)) {
        continue;
      }
      final path = piece.$2 ? piece.$1.map(project).toList() : piece.$1;
      final visible = !piece.$2 && backFacing
          ? _outsidePaper(path, polygon)
          : [path];
      for (final part in visible) {
        if (paths.isNotEmpty && paths.last.last.distance(part.first) < 1e-6) {
          paths.last.addAll(part.skip(1));
        } else {
          paths.add(List.of(part));
        }
      }
    }
    return paths;
  }

  List<List<V>> guidePaths(List<List<V>> guides) => [
    for (final path in guides) ..._view(_PaperInk(_split(path, flap), true)),
  ];

  void _apply(InkLine line) {
    final binding = _ink[line];
    if (binding != null) {
      line.setContours(_view(binding));
    } else if (backFacing) {
      line.setContours(_outsidePaper(line.points, polygon));
    }
    if (settled && line.concealed && !line.retired) {
      line.retired = true;
      line.retiredAt = session.gameTime;
      session.emit('dissolve', crease);
    }
  }

  void beforeStep(double dt) {
    if (!pressed || settled || session.draft != null) return;
    final at = V(session.x, session.y), oldFront = frontFacing;
    final onPaper =
        session.grounded &&
        surfaces.any(
          (edge) => edge.contains(at.x) && (edge.yAt(at.x) - at.y).abs() < .75,
        );
    final onInk =
        session.grounded &&
        _ink.keys.any(
          (line) =>
              !line.retired &&
              !line.concealed &&
              line.yAt(at.x) != null &&
              (line.yAt(at.x)! - at.y).abs() < .75,
        );
    final moving = _paperInterval(at, at, polygon) != null;
    final material =
        (onPaper || onInk) && moving && math.cos(angle).abs() >= .08
        ? _unproject(at)
        : null;
    progress = math.min(1, progress + dt / duration);
    _surface();
    for (final line in session.lines) {
      _apply(line);
    }
    _ink.removeWhere((line, _) => !session.lines.contains(line));
    if (material != null && oldFront && frontFacing) {
      final next = project(material);
      session.x = next.x;
      session.y = next.y;
    } else if (material != null && oldFront && !frontFacing) {
      session.grounded = false;
      session.onNatural = false;
      session.vy = 0;
    }
  }

  void afterStep() {
    if (!pressed &&
        session.grounded &&
        session.x + 8 >= buttonX &&
        session.x - 8 <= buttonX &&
        session.y.abs() < .75) {
      pressed = true;
      session.emit('gate', const V(buttonX, 0));
    }
  }
}

class _PaperInk {
  _PaperInk(this.pieces, this.front);
  final List<(List<V>, bool)> pieces;
  final bool front;
}

/// Segment interval inside a convex sheet, shared by binding and occlusion.
(double, double)? _paperInterval(V a, V b, List<V> poly) {
  if (poly.length < 3) return null;
  var area = 0.0;
  for (var i = 0; i < poly.length; i++) {
    final p = poly[i], q = poly[(i + 1) % poly.length];
    area += p.x * q.y - p.y * q.x;
  }
  if (area.abs() < 1e-7) return null;
  final sign = area >= 0 ? 1.0 : -1.0, delta = b - a;
  var lo = 0.0, hi = 1.0;
  for (var i = 0; i < poly.length; i++) {
    final p = poly[i], edge = poly[(i + 1) % poly.length] - p;
    final c = sign * (edge.x * (a.y - p.y) - edge.y * (a.x - p.x));
    final d = sign * (edge.x * delta.y - edge.y * delta.x);
    if (d.abs() < 1e-9) {
      if (c < -1e-7) return null;
    } else if (d > 0) {
      lo = math.max(lo, -c / d);
    } else {
      hi = math.min(hi, -c / d);
    }
    if (lo > hi + 1e-9) return null;
  }
  if (hi < 0 || lo > 1) return null;
  return (lo.clamp(0.0, 1.0), hi.clamp(0.0, 1.0));
}

/// Hidden runs are removed from both visuals and collision without joining
/// their exposed ends into an invisible bridge.
List<List<V>> _outsidePaper(List<V> points, List<V> polygon) {
  final result = <List<V>>[];
  void add(V a, V b) {
    if (a.distance(b) < 1e-7) return;
    if (result.isNotEmpty && result.last.last.distance(a) < 1e-6) {
      result.last.add(b);
    } else {
      result.add([a, b]);
    }
  }

  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1], b = points[i], delta = b - a;
    final interval = _paperInterval(a, b, polygon);
    if (interval == null) {
      add(a, b);
    } else {
      add(a, a + delta * interval.$1);
      add(a + delta * interval.$2, b);
    }
  }
  return result;
}
