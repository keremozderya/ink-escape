import 'dart:convert';
import 'dart:collection';
import 'dart:math' as math;

/// Track structural edits so immutable collision geometry can be reused.
class _GeometryList<T> extends ListBase<T> {
  final List<T> _items = [];
  int revision = 0;
  @override
  int get length => _items.length;
  @override
  set length(int value) {
    _items.length = value;
    revision++;
  }

  @override
  T operator [](int index) => _items[index];
  @override
  void operator []=(int index, T value) {
    _items[index] = value;
    revision++;
  }

  @override
  void add(T value) {
    _items.add(value);
    revision++;
  }

  @override
  void addAll(Iterable<T> values) {
    _items.addAll(values);
    revision++;
  }

  @override
  void insert(int index, T value) {
    _items.insert(index, value);
    revision++;
  }

  @override
  void insertAll(int index, Iterable<T> values) {
    _items.insertAll(index, values);
    revision++;
  }

  @override
  void clear() {
    if (_items.isNotEmpty) {
      _items.clear();
      revision++;
    }
  }

  @override
  void removeWhere(bool Function(T) test) {
    final before = length;
    _items.removeWhere(test);
    if (length != before) revision++;
  }
}

class V {
  const V(this.x, this.y);
  final double x, y;
  V operator +(V b) => V(x + b.x, y + b.y);
  V operator -(V b) => V(x - b.x, y - b.y);
  V operator *(double f) => V(x * f, y * f);
  double get length => math.sqrt(x * x + y * y);
  double distance(V b) => (this - b).length;
  List<double> toJson() => [x, y];
  static V from(dynamic a) =>
      V((a[0] as num).toDouble(), (a[1] as num).toDouble());
}

double pathLength(List<V> p) {
  var n = 0.0;
  for (var i = 1; i < p.length; i++) {
    n += p[i].distance(p[i - 1]);
  }
  return n;
}

/// Resample by distance along X, then remove only small hand wobble.
/// Keep dense curve samples rather than reducing a deliberate arch to a triangle.
List<V> smoothStroke(List<V> input, {double tolerance = 1.7}) {
  if (input.length < 3) {
    return List<V>.of(input);
  }
  // X resampling cannot represent verticals, loops or deliberate backtracking.
  // Keep those contours intact instead of flattening or rejecting them.
  for (var i = 1; i < input.length; i++) {
    if (input[i].x <= input[i - 1].x) {
      return List<V>.of(input);
    }
  }
  final first = input.first, last = input.last, dx = last.x - first.x;
  if (dx <= 0) {
    return List<V>.of(input);
  }
  final count = (dx / 3).ceil().clamp(2, 160);
  final sampled = <V>[];
  var segment = 1;
  for (var i = 0; i <= count; i++) {
    final x = first.x + dx * i / count;
    while (segment < input.length - 1 && input[segment].x < x) {
      segment++;
    }
    final a = input[segment - 1], b = input[segment];
    final t = ((x - a.x) / (b.x - a.x)).clamp(0.0, 1.0).toDouble();
    sampled.add(V(x, a.y + (b.y - a.y) * t));
  }
  const weights = [1.0, 4.0, 6.0, 4.0, 1.0];
  final result = <V>[first];
  for (var i = 1; i < count; i++) {
    var y = 0.0;
    for (var k = -2; k <= 2; k++) {
      final index = i + k;
      // Extend the end tangents rather than repeating the endpoint. Repeated
      // padding would turn a straight 55-degree line into a steeper bump.
      final height = index < 0
          ? sampled.first.y + (sampled[1].y - sampled.first.y) * index
          : index > count
          ? sampled.last.y +
                (sampled.last.y - sampled[count - 1].y) * (index - count)
          : sampled[index].y;
      y += height * weights[k + 2] / 16;
    }
    y = sampled[i].y + (y - sampled[i].y).clamp(-tolerance, tolerance);
    result.add(V(sampled[i].x, y));
  }
  result.add(last);
  return result;
}

class Surface {
  Surface(this.id, this.a, this.b, {this.tag = 'ground'});
  final String id, tag;
  final V a, b;
  double get slope => (b.y - a.y) / (b.x - a.x);
  bool contains(double x) => x >= a.x - 0.001 && x <= b.x + 0.001;
  double yAt(double x) => a.y + (x - a.x) * slope;
  V project(V p) {
    final ab = b - a;
    final t =
        (((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) /
                (ab.x * ab.x + ab.y * ab.y))
            .clamp(0.0, 1.0)
            .toDouble();
    var q = a + ab * t;
    if (q.distance(a) <= 16) {
      q = a;
    }
    if (q.distance(b) <= 16) {
      q = b;
    }
    return q;
  }
}

class Anchor {
  Anchor(this.point, this.surface);
  final V point;
  final Surface surface;
}

class Pickup {
  Pickup(this.id, this.p, this.value);
  final String id;
  final V p;
  final double value;
}

class Gate {
  Gate(this.id, this.x, this.conditions);
  final String id;
  final double x;
  final List<String> conditions;
  bool open = false;
}

class Ball {
  Ball(
    this.id,
    this.source,
    this.receiver,
    this.triggerX,
    this.delay,
    this.initialSpeed,
    this.friction,
  );
  final String id;
  final V source, receiver;
  final double triggerX, delay, initialSpeed, friction;
  double? triggeredAt;
  bool released = false, captured = false, missed = false;
  String? railId;
  double distanceOnRail = 0, speed = 0;
  V position = const V(0, 0);
  double vy = 0;
  Map<String, dynamic> toJson() => {
    'id': id,
    'triggeredAt': triggeredAt,
    'released': released,
    'captured': captured,
    'missed': missed,
    'railId': railId,
    'distance': distanceOnRail,
    'speed': speed,
    'position': position.toJson(),
    'vy': vy,
  };
  void restore(Map<String, dynamic> m) {
    triggeredAt = (m['triggeredAt'] as num?)?.toDouble();
    released = m['released'] == true;
    captured = m['captured'] == true;
    missed = m['missed'] == true;
    railId = m['railId'] as String?;
    distanceOnRail = (m['distance'] as num).toDouble();
    speed = (m['speed'] as num).toDouble();
    position = V.from(m['position']);
    vy = (m['vy'] as num).toDouble();
  }
}

class Rain {
  Rain(this.id, this.left, this.right);
  final String id;
  final double left, right;
  double? triggeredAt;
  int emitted = 0;
}

class Crumb {
  Crumb(this.x, this.y, this.vy, this.seed);
  double x, y, vy;
  final int seed;
  List<num> toJson() => [x, y, vy, seed];
}

class InkLine {
  InkLine(this.id, List<V> points, {this.role = 'walk'})
    : points = List<V>.unmodifiable(points);
  final String id, role;
  final List<V> points;
  bool retired = false;
  double retiredAt = 0;
  late final double cost = pathLength(points);
  late final double left = points.map((p) => p.x).reduce(math.min);
  late final double right = points.map((p) => p.x).reduce(math.max);

  Iterable<(double, double)> crossingsAt(double x) sync* {
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      final dx = b.x - a.x;
      // Vertical strokes are walls, never horizontal support or a NaN height.
      if (dx.abs() <= 1e-7) continue;
      if (x >= math.min(a.x, b.x) - .001 && x <= math.max(a.x, b.x) + .001) {
        final slope = (b.y - a.y) / dx;
        yield (a.y + slope * (x - a.x), slope);
      }
    }
  }

  double? yAt(double x) {
    double? top;
    for (final hit in crossingsAt(x)) {
      if (top == null || hit.$1 > top) top = hit.$1;
    }
    return top;
  }

  double slopeAt(double x) {
    (double, double)? top;
    for (final hit in crossingsAt(x)) {
      if (top == null || hit.$1 > top.$1) top = hit;
    }
    return top?.$2 ?? 0;
  }

  (V, double) atDistance(double s) {
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      final length = a.distance(b);
      if (length <= 1e-7) continue;
      if (s <= length || i == points.length - 1) {
        return (
          a + (b - a) * (s / length).clamp(0.0, 1.0).toDouble(),
          (b.y - a.y) / length,
        );
      }
      s -= length;
    }
    return (points.last, 0);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'points': points.map((p) => p.toJson()).toList(),
    'role': role,
    'retired': retired,
    'retiredAt': retiredAt,
  };
  static InkLine from(Map<String, dynamic> m) =>
      InkLine(
          m['id'] as String,
          (m['points'] as List).map(V.from).toList(),
          role: m['role'] as String,
        )
        ..retired = m['retired'] == true
        ..retiredAt = (m['retiredAt'] as num).toDouble();
}

class Draft {
  Draft(this.start, this.points) : rawPoint = points.last;
  final Anchor start;
  final List<V> points;
  V rawPoint;
  bool backwards = false;
  V? get end => points.isEmpty ? null : points.last;
}

/// A nonvertical floor segment, ordered in Dot's direction of travel.
class _GroundSegment {
  _GroundSegment(this.a, this.b, this.natural)
    : slope = (b.y - a.y) / (b.x - a.x);
  final V a, b;
  final bool natural;
  final double slope;
  late final double lengthPerX = math.sqrt(1 + slope * slope);
  double yAt(double xx) => a.y + (xx - a.x) * slope;
  bool contains(double xx) => xx >= a.x - 1e-6 && xx <= b.x + 1e-6;
}

/// One continuous uphill section. Its total rise, rather than each tiny
/// sampled segment, determines whether it is a small step or a tall wall.
class _ClimbRun {
  _ClimbRun(this.points, this.natural) : path = InkLine('climb', points);
  final List<V> points;
  final bool natural;
  final InkLine path;
  double get rise => points.last.y - points.first.y;

  double? distanceAt(V point) {
    var distance = 0.0;
    var closest = .75;
    double? result;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i], ab = b - a;
      final length = ab.length;
      if (length <= 1e-7) continue;
      final t =
          (((point.x - a.x) * ab.x + (point.y - a.y) * ab.y) /
                  (length * length))
              .clamp(0.0, 1.0);
      final error = (a + ab * t).distance(point);
      if (error <= closest) {
        closest = error;
        result = distance + length * t;
      }
      distance += length;
    }
    return result;
  }
}

class Level {
  Level(this.number, this.title, this.width);
  final int number;
  final String title;
  final double width;
  final List<Surface> terrain = _GeometryList<Surface>(), anchors = [];
  final List<Pickup> pickups = [];
  final List<Gate> gates = [];
  final List<Ball> balls = [];
  final List<Rain> rain = [];
  final List<List<double>> hazards = [];
  final List<List<double>> noRegen = [];
  final List<Map<String, dynamic>> reference = [];

  static Level from(Map<String, dynamic> m) {
    final l = Level(
      (m['number'] as num).toInt(),
      m['title'] as String,
      (m['width'] as num).toDouble(),
    );
    // Safe tail behind the origin keeps the camera seamless after a level boundary.
    l.terrain.add(Surface('previous-tail', const V(-512, 0), const V(0, 0)));
    for (final dynamic rawCell in m['cells'] as List) {
      final c = Map<String, dynamic>.from(rawCell as Map);
      final ox = (c['offset_x'] as num).toDouble();
      final ci = c['index'];
      V wp(dynamic a) => V.from(a) + V(ox, 0);
      var index = 0;
      for (final r in c['route'] as List) {
        if (r['kind'] != 'natural') {
          continue;
        }
        final p = (r['points'] as List).map(wp).toList();
        for (var j = 1; j < p.length; j++) {
          if (p[j].x > p[j - 1].x + .001) {
            l.terrain.add(Surface('terrain:$ci:${index++}', p[j - 1], p[j]));
          }
        }
      }
      for (final pad in c['pads'] as List) {
        final p = wp(pad['center']);
        final interval = pad['surface_x_interval'] as List?;
        final left = interval == null
            ? p.x - 16
            : (interval[0] as num).toDouble() + ox;
        final right = interval == null
            ? p.x + 16
            : (interval[1] as num).toDouble() + ox;
        final id = pad['id'] as String;
        final role =
            (c['lines'] as List).firstWhere(
                  (dynamic z) => id.startsWith('${z['id']}-'),
                )['role']
                as String;
        final s = Surface(
          'pad:$ci:$id',
          V(left, p.y),
          V(right, p.y),
          tag: role,
        );
        l.anchors.add(s);
        // Only elevated ledges add separate terrain; floor ledges are part of the exact route.
        if (p.y > 64) {
          l.terrain.add(s);
        }
      }
      for (final p in c['pickups'] as List) {
        l.pickups.add(
          Pickup(
            'pickup:$ci:${l.pickups.length}',
            wp([p['x'], (p['y'] as num) + 16]),
            (p['value'] as num).toDouble(),
          ),
        );
      }
      for (final g in c['gates'] as List) {
        l.gates.add(
          Gate(
            'gate:$ci:${g['id']}',
            ox + (g['x'] as num).toDouble(),
            (g['conditions'] as List).cast<String>(),
          ),
        );
      }
      for (final o in c['objects'] as List) {
        final b = Ball(
          'ball:$ci:${o['id']}',
          wp(o['source']),
          wp(o['receiver']),
          ox + (o['source_trigger_x'] as num).toDouble(),
          (o['source_delay'] as num).toDouble(),
          (o['v0'] as num).toDouble(),
          (o['friction'] as num).toDouble(),
        );
        b.position = b.source;
        l.balls.add(b);
      }
      if (c['rain'] != null) {
        final a = c['rain']['rect'] as List;
        l.rain.add(Rain('rain:$ci', ox + (a[0] as num), ox + (a[2] as num)));
      }
      for (final dynamic h in c['hazards'] as List) {
        if (h['rect'] != null) {
          final a = (h['rect'] as List)
              .map((v) => (v as num).toDouble())
              .toList();
          l.hazards.add([a[0] + ox, a[1], a[2] + ox, a[3]]);
        }
      }
      for (final a in c['absorbent'] as List) {
        l.noRegen.add([
          (a[0] as num).toDouble() + ox,
          (a[1] as num).toDouble() + ox,
        ]);
      }
      for (final dynamic r in c['lines'] as List) {
        l.reference.add({
          'id': '$ci:${r['id']}',
          'points': (r['points'] as List).map(wp).toList(),
          'cue': ox + (r['cue_x'] as num).toDouble(),
          'role': r['role'],
        });
      }
    }
    l.terrain.add(
      Surface('next-tail', V(l.width - .001, 0), V(l.width + 32, 0)),
    );
    return l;
  }
}

enum Phase { ready, playing, paused, resumeStroke, dead, complete }

class LedgeGrip {
  LedgeGrip(this.corner, this.landing);
  static const requiredPulls = 5;
  final V corner, landing;
  int pulls = 0;
  double progress = 0;
  double get targetProgress => pulls / requiredPulls;
  Map<String, dynamic> toJson() => {
    'corner': corner.toJson(),
    'landing': landing.toJson(),
    'pulls': pulls,
    'progress': progress,
  };
}

class SlowBudget {
  final List<(double, double)> slices = [];
  double used(double now) {
    final cut = now - 6;
    slices.removeWhere((s) => s.$2 <= cut);
    if (slices.isNotEmpty && slices.first.$1 < cut) {
      slices[0] = (cut, slices.first.$2);
    }
    return slices.fold(0.0, (sum, s) => sum + s.$2 - s.$1);
  }

  double consume(double now, double dt, bool drawing) {
    final remaining = math.max(0.0, 2.0 - used(now));
    final slow = drawing ? math.min(dt, remaining) : 0.0;
    if (slow > 1e-9) {
      if (slices.isNotEmpty && (slices.last.$2 - now).abs() < 1e-6) {
        slices[slices.length - 1] = (slices.last.$1, now + slow);
      } else {
        slices.add((now, now + slow));
      }
    }
    return slow;
  }
}

class InkSession {
  InkSession(this.levelData, {this.lab = false}) {
    _loadLevel();
  }
  final List<Map<String, dynamic>> levelData;
  final bool lab;
  late Level level;
  int levelIndex = 0, strokeSerial = 0, resetEpoch = 0;
  Phase phase = Phase.ready;
  double ink = 180, entryInk = 180;
  double x = 0, y = 0, vy = 0, gameTime = 0, realTime = 0, activeTotal = 0;
  double walked = 0, entryWalked = 0, origin = 0;
  // A fixed paper-world scale, independent of screen size and device density.
  static const unitsPerCentimeter = 32.0;
  double get distanceCm => walked / unitsPerCentimeter;
  double get levelProgress => (x / level.width).clamp(0.0, 1.0).toDouble();
  static const maxClimbDegrees = 55.0, stuckLimit = 3.0, dotHeight = 32.0;
  static final maxClimbSlope = math.tan(maxClimbDegrees * math.pi / 180);
  double _stuckElapsed = 0;
  V? _progressPoint;
  bool grounded = true, onNatural = true, strokePointerActive = false;
  final List<InkLine> lines = _GeometryList<InkLine>();
  LedgeGrip? ledge;
  Level? _geometryLevel;
  int _terrainRevision = -1, _lineRevision = -1;
  List<bool> _retiredStates = [];
  List<_GroundSegment> _segments = [], _nearSegments = [];
  List<_ClimbRun> _climbs = [];
  double _nearLeft = double.infinity, _nearRight = double.negativeInfinity;
  final Set<String> collected = {};
  final List<Crumb> crumbs = [];
  final SlowBudget budget = SlowBudget();
  Draft? draft;
  String message = '', lastEvent = '';
  double messageUntil = 0;
  bool firstDrawDone = false;
  bool migratedLayout = false;
  double get walkSpeed => lab ? 32 : 56;
  void Function(String, V)? onEvent;
  void Function(bool)? onSaveRequested;
  double saveElapsed = 0;
  int get activeLines => lines.where((l) => !l.retired).length;
  int? get stuckCountdown {
    // Ordinary walking briefly stays within the one-unit progress radius.
    // Wait long enough to avoid a warning flashing on every normal footstep.
    if (phase != Phase.playing || ledge != null || _stuckElapsed < .15) {
      return null;
    }
    return (stuckLimit - _stuckElapsed).ceil().clamp(1, 3);
  }

  Iterable<InkLine> get solidLines => lines.where((l) => !l.retired);
  void _loadLevel() {
    level = Level.from(levelData[levelIndex]);
  }

  void emit(String name, [V? at]) {
    lastEvent = name;
    onEvent?.call(name, at ?? V(x, y));
  }

  void hint(String s) {
    message = s;
    messageUntil = realTime + 2;
    emit('invalid');
  }

  Anchor? anchorAt(V p) {
    Anchor? best;
    var distance = 20.0;
    for (final s in [...level.terrain, ...level.anchors]) {
      if (s.id == 'previous-tail') {
        continue;
      }
      final q = s.project(p), d = q.distance(p);
      if (d < distance) {
        distance = d;
        best = Anchor(q, s);
      }
    }
    return best;
  }

  bool beginStroke(V p) {
    if (ledge != null) return false;
    if (phase == Phase.resumeStroke) {
      if (draft?.end != null && p.distance(draft!.end!) <= 26) {
        phase = Phase.playing;
        strokePointerActive = true;
        return true;
      }
      return false;
    }
    if (phase != Phase.playing || draft != null) {
      return false;
    }
    if (activeLines >= 2) {
      hint('İki çizgi hâlâ görevde.');
      return false;
    }
    final a = anchorAt(p);
    if (a == null) {
      hint('Sabit bir kâğıt kenarından başla.');
      return false;
    }
    draft = Draft(a, [a.point]);
    strokePointerActive = true;
    emit('penStart', a.point);
    return true;
  }

  void moveStroke(V p) {
    if (phase != Phase.playing || !strokePointerActive || draft == null) {
      return;
    }
    final d = draft!;
    final last = d.points.last;
    if (p.distance(d.rawPoint) < .8) {
      return;
    }
    // Sub-pixel hand wobble is removed; intentional contours remain intact.
    if (p.x < d.rawPoint.x - 2.4) {
      d.backwards = true;
    }
    d.rawPoint = p;
    final alpha = ((p - last).length / 7).clamp(.42, .96).toDouble();
    final filtered = last + (p - last) * alpha;
    d.points.add(filtered);
    emit('penMove', filtered);
  }

  (List<V>?, String) validatedDraft() {
    final d = draft;
    if (d == null || d.points.length < 2) {
      return (null, 'Sabit bir kenardan başlayıp yolunu çiz.');
    }
    final raw = List<V>.of(d.points)..[0] = d.start.point;
    // Release may happen in open space. Nearby paper still offers a gentle snap.
    final end = anchorAt(d.rawPoint);
    raw[raw.length - 1] = end != null && end.point.distance(d.rawPoint) <= 6
        ? end.point
        : d.rawPoint;
    final p = smoothStroke(raw);
    final cost = pathLength(p);
    if (cost < 12) {
      return (null, 'Biraz daha uzun bir çizgi çiz.');
    }
    if (cost > 220) {
      return (null, 'Çizgi 220 birimi aşmasın.');
    }
    if (cost > ink + 1e-7) {
      return (null, 'Bu şekil için mürekkep yetmiyor.');
    }
    if (activeLines >= 2) {
      return (null, 'İki çizgi hâlâ görevde.');
    }
    return (p, '');
  }

  bool endStroke() {
    if (phase != Phase.playing || draft == null || !strokePointerActive) {
      return false;
    }
    strokePointerActive = false;
    emit('penStop');
    final (p, error) = validatedDraft();
    if (p == null) {
      draft = null;
      hint(error);
      return false;
    }
    var role = 'walk';
    final a = draft!.start.surface;
    if (a.tag != 'ground') {
      role = a.tag;
    }
    final line = InkLine('ink:${strokeSerial++}', p, role: role);
    ink -= line.cost;
    lines.add(line);
    draft = null;
    firstDrawDone = true;
    emit('commit', p.last);
    return true;
  }

  void cancelDraft() {
    draft = null;
    strokePointerActive = false;
    emit('penStop');
  }

  void start() {
    if (phase != Phase.ready && phase != Phase.paused) {
      return;
    }
    phase = draft == null ? Phase.playing : Phase.resumeStroke;
    strokePointerActive = false;
    emit('start');
  }

  void pause() {
    if (phase != Phase.playing && phase != Phase.resumeStroke) {
      return;
    }
    phase = Phase.paused;
    strokePointerActive = false;
    emit('pause');
    onSaveRequested?.call(true);
  }

  void losePointer() {
    if (draft != null && phase == Phase.playing) {
      pause();
    }
  }

  void retry() {
    final total = activeTotal, originalOrigin = origin;
    resetEpoch++;
    _loadLevel();
    phase = Phase.ready;
    ink = entryInk;
    x = 0;
    y = 0;
    vy = 0;
    gameTime = 0;
    realTime = 0;
    grounded = true;
    onNatural = true;
    walked = entryWalked;
    ledge = null;
    _stuckElapsed = 0;
    _progressPoint = null;
    lines.clear();
    collected.clear();
    crumbs.clear();
    budget.slices.clear();
    draft = null;
    strokePointerActive = false;
    message = '';
    messageUntil = 0;
    activeTotal = total;
    origin = originalOrigin;
    onSaveRequested?.call(true);
  }

  void die(String reason) {
    if (phase != Phase.playing) {
      return;
    }
    phase = Phase.dead;
    ledge = null;
    resetEpoch++;
    strokePointerActive = false;
    message = reason;
    emit('death');
    onSaveRequested?.call(true);
  }

  void advance(double dt) {
    if (phase != Phase.playing) {
      return;
    }
    // Caller uses bounded fixed steps; tests can supply arbitrarily long durations safely.
    var remaining = dt;
    while (remaining > 1e-9 && phase == Phase.playing) {
      final h = math.min(remaining, 1 / 120);
      remaining -= h;
      final slow = budget.consume(
        realTime,
        h,
        draft != null && strokePointerActive,
      );
      realTime += h;
      activeTotal += h;
      saveElapsed += h;
      final worldDt = h - .6 * slow;
      gameTime += worldDt;
      _walk(worldDt);
      _trackProgress(h);
      _balls(worldDt);
      _rain(worldDt);
      _collect();
      _gates();
      _retire();
      if (grounded &&
          onNatural &&
          !level.noRegen.any((z) => x >= z[0] && x <= z[1])) {
        ink = math.min(240.0, ink + 10 * worldDt);
      }
      for (final r in level.hazards) {
        if (x + 12 > r[0] &&
            x - 12 < r[2] &&
            y + dotHeight > r[1] &&
            y < r[3]) {
          die('Gövden için biraz daha açıklık bırak.');
        }
      }
      if (y < -300) {
        die('Köprü hazır olmadan kenarı geçtin.');
      }
      if (phase == Phase.playing && x >= level.width) {
        _nextLevel();
      }
      if (saveElapsed >= 5 && phase == Phase.playing) {
        saveElapsed = 0;
        onSaveRequested?.call(false);
      }
    }
  }

  void _ensureGeometry() {
    final terrainRevision = (level.terrain as _GeometryList<Surface>).revision;
    final lineRevision = (lines as _GeometryList<InkLine>).revision;
    var unchanged =
        identical(level, _geometryLevel) &&
        terrainRevision == _terrainRevision &&
        lineRevision == _lineRevision &&
        _retiredStates.length == lines.length;
    if (unchanged) {
      for (var i = 0; i < lines.length; i++) {
        if (_retiredStates[i] != lines[i].retired) {
          unchanged = false;
          break;
        }
      }
    }
    if (unchanged) return;
    _geometryLevel = level;
    _terrainRevision = terrainRevision;
    _lineRevision = lineRevision;
    _retiredStates = lines.map((line) => line.retired).toList();
    _segments = _buildGroundSegments()..sort((a, b) => a.a.x.compareTo(b.a.x));
    _climbs = _buildClimbRuns().toList();
    _nearLeft = double.infinity;
    _nearRight = double.negativeInfinity;
  }

  List<_GroundSegment> get _groundSegments {
    _ensureGeometry();
    return _segments;
  }

  List<_GroundSegment> get _nearGround {
    _ensureGeometry();
    if (x - 24 >= _nearLeft && x + 24 <= _nearRight) return _nearSegments;
    _nearLeft = (x / 64).floor() * 64.0 - 32;
    _nearRight = _nearLeft + 128;
    _nearSegments = [];
    for (final segment in _segments) {
      if (segment.a.x > _nearRight) break;
      if (segment.b.x >= _nearLeft) _nearSegments.add(segment);
    }
    return _nearSegments;
  }

  List<_GroundSegment> _buildGroundSegments() {
    final segments = <_GroundSegment>[];
    for (final s in level.terrain) {
      if (s.b.x - s.a.x > 1e-7) {
        segments.add(_GroundSegment(s.a, s.b, true));
      }
    }
    for (final line in solidLines) {
      for (var i = 1; i < line.points.length; i++) {
        var a = line.points[i - 1], b = line.points[i];
        if ((b.x - a.x).abs() <= 1e-7) continue;
        if (a.x > b.x) {
          final swap = a;
          a = b;
          b = swap;
        }
        segments.add(_GroundSegment(a, b, false));
      }
    }
    return segments;
  }

  _GroundSegment? _support(
    List<_GroundSegment> segments,
    V at, {
    double direction = 1,
  }) {
    _GroundSegment? best;
    var error = .75;
    for (final segment in segments) {
      if (!segment.contains(at.x)) continue;
      final delta = (segment.yAt(at.x) - at.y).abs();
      if (delta > error + 1e-7) continue;
      final continues = direction > 0
          ? segment.b.x > at.x + 1e-7
          : segment.a.x < at.x - 1e-7;
      final bestContinues =
          best != null &&
          (direction > 0 ? best.b.x > at.x + 1e-7 : best.a.x < at.x - 1e-7);
      if (best == null ||
          delta < error - 1e-7 ||
          (delta <= error + 1e-7 &&
              (continues && !bestContinues ||
                  continues == bestContinues &&
                      segment.slope * direction > best.slope * direction))) {
        best = segment;
        error = delta;
      }
    }
    return best;
  }

  double _junctionX(
    List<_GroundSegment> segments,
    _GroundSegment floor,
    double fromX,
    double direction,
  ) {
    var end = direction > 0 ? floor.b.x : floor.a.x;
    for (final other in segments) {
      final difference = other.slope - floor.slope;
      if (difference.abs() < 1e-9) continue;
      final cross =
          (floor.a.y -
              floor.slope * floor.a.x -
              other.a.y +
              other.slope * other.a.x) /
          difference;
      if ((cross - fromX) * direction > 1e-7 &&
          (end - cross) * direction > 1e-7 &&
          other.contains(cross)) {
        end = cross;
      }
    }
    return end;
  }

  /// Sample the same connected contour that supports Dot, including corners.
  /// Nearby overhead lines and unconnected platforms cannot move his feet.
  V? groundPointAt(double distance) => groundSampler()(distance);

  (_ClimbRun, double)? _stepUnderFoot() {
    _ensureGeometry();
    for (final run in _climbs) {
      if (!_smallEnough(run, y)) continue;
      final distance = run.distanceAt(V(x, y));
      if (distance != null) return (run, distance);
    }
    return null;
  }

  /// Reuse one geometry snapshot for all foot samples in a rendered frame.
  V? Function(double) groundSampler() {
    if (!grounded) return (_) => null;
    final all = _groundSegments, nearby = _nearGround;
    final origin = V(x, y);
    final step = _support(nearby, origin) == null ? _stepUnderFoot() : null;
    return (distance) {
      final segments = distance.abs() <= 24 ? nearby : all;
      final direction = distance < 0 ? -1.0 : 1.0;
      var point = origin, remaining = distance.abs();
      if (step != null) {
        final along = step.$2 + distance;
        if (along >= 0 && along <= step.$1.path.cost) {
          return step.$1.path.atDistance(along).$1;
        }
        point = along < 0 ? step.$1.points.first : step.$1.points.last;
        remaining = along < 0 ? -along : along - step.$1.path.cost;
      }
      for (var i = 0; i < segments.length * 2 + 2; i++) {
        final floor = _support(segments, point, direction: direction);
        if (floor == null) return null;
        final end = _junctionX(segments, floor, point.x, direction);
        final available = (end - point.x).abs() * floor.lengthPerX;
        if (remaining <= available + 1e-7) {
          final xx = point.x + direction * remaining / floor.lengthPerX;
          return V(xx, floor.yAt(xx));
        }
        if (available <= 1e-7) return null;
        point = V(end, floor.yAt(end));
        remaining -= available;
      }
      return null;
    };
  }

  double get groundSlope {
    if (!grounded) return 0;
    final floor = _support(_nearGround, V(x, y));
    if (floor != null) return floor.slope;
    final step = _stepUnderFoot();
    if (step == null) return 0;
    final a = step.$1.path.atDistance(math.max(0, step.$2 - .1)).$1;
    final b = step.$1.path
        .atDistance(math.min(step.$1.path.cost, step.$2 + .1))
        .$1;
    return b.x - a.x > 1e-7 ? (b.y - a.y) / (b.x - a.x) : double.infinity;
  }

  void _walk(double dt) {
    if (ledge != null && _advanceGrip(dt)) return;
    _ensureGeometry();
    final climbs = _climbs;
    final segments = _nearGround;
    var remaining = dt;
    // Consume distance up to each real corner before choosing the next floor.
    // Comparing the next height with the old height loses steep downslopes.
    for (
      var i = 0;
      grounded && remaining > 1e-9 && i < segments.length * 2 + 2;
      i++
    ) {
      if (_climbSmallStep(walkSpeed * remaining, climbs)) return;
      final floor = _support(segments, V(x, y));
      if (floor != null) {
        if (floor.slope > maxClimbSlope + 1e-6) return;
        final end = _junctionX(segments, floor, x, 1);
        final dx = math.min(
          walkSpeed * remaining / floor.lengthPerX,
          math.max(0.0, end - x),
        );
        if (_blockedAhead(x + dx, y, climbs)) return;
        if (dx > 1e-7) {
          final target = V(x + dx, floor.yAt(x + dx));
          final duration = target.distance(V(x, y)) / walkSpeed;
          _walkTo(target, floor.natural);
          remaining = math.max(0.0, remaining - duration);
          continue;
        }
      }
      grounded = false;
      onNatural = false;
      vy = 0;
    }
    if (grounded || remaining <= 1e-9) return;
    final previous = V(x, y);
    final nextX = x + walkSpeed * remaining;
    vy -= 160 * remaining;
    final next = V(
      _blockedAhead(nextX, y, climbs) ? x : nextX,
      y + vy * remaining,
    );
    _GroundSegment? landing;
    var firstHit = double.infinity;
    for (final floor in segments) {
      // Intersect the entire moving foot path with the floor, rather than
      // testing only its final X. Rising banks and thin ledges need this sweep.
      final before = previous.y - floor.yAt(previous.x);
      final after = next.y - floor.yAt(next.x);
      if (before < -1e-7 || after > 1e-7 || before - after <= 1e-9) continue;
      final t = (before / (before - after)).clamp(0.0, 1.0);
      final xx = previous.x + (next.x - previous.x) * t;
      if (!floor.contains(xx)) continue;
      // Leaving a free endpoint is a real fall, not another landing at t=0.
      if (t <= 1e-7 && next.x > previous.x && floor.b.x <= previous.x + 1e-7) {
        continue;
      }
      if (t < firstHit) {
        firstHit = t;
        landing = floor;
      }
    }
    if (landing != null) {
      x = previous.x + (next.x - previous.x) * firstHit;
      y = landing.yAt(x);
      vy = 0;
      grounded = true;
      onNatural = landing.natural;
      emit('land');
    } else {
      x = next.x;
      y = next.y;
      _tryGrip(previous, next, segments);
    }
  }

  void _tryGrip(V previous, V next, List<_GroundSegment> segments) {
    if (vy >= 0 || next.y > previous.y + 1e-7) return;
    _GroundSegment? chosen;
    var nearest = double.infinity;
    for (final floor in segments) {
      final corner = floor.a;
      if (floor.slope > maxClimbSlope || floor.b.x - corner.x < .01) continue;
      // Only the approaching, exposed corner can be caught. Never re-grab the
      // platform Dot just walked off or a vertex inside a continuous contour.
      final reach = corner.x - next.x;
      if (reach < -2 || reach > 12 || corner.x + 2 < previous.x) continue;
      final rise = corner.y - next.y;
      if (rise < -2 || rise > dotHeight * .75) continue;
      final blocked = segments.any(
        (other) =>
            !identical(other, floor) &&
            other.a.x < corner.x - .01 &&
            other.contains(corner.x - .01) &&
            (other.yAt(corner.x) - corner.y).abs() < .75,
      );
      if (blocked || reach >= nearest) continue;
      nearest = reach;
      chosen = floor;
    }
    if (chosen == null) return;
    final targetX = math.min(chosen.a.x + 8, chosen.b.x);
    ledge = LedgeGrip(chosen.a, V(targetX, chosen.yAt(targetX)));
    grounded = false;
    onNatural = false;
    vy = 0;
    _stuckElapsed = 0;
    draft = null;
    strokePointerActive = false;
    emit('penStop');
    emit('ledgeGrab', chosen.a);
    onSaveRequested?.call(true);
  }

  bool pullLedge() {
    final grip = ledge;
    if (phase != Phase.playing ||
        grip == null ||
        grip.pulls >= LedgeGrip.requiredPulls) {
      return false;
    }
    grip.pulls++;
    emit('ledgePull', grip.corner);
    return true;
  }

  bool _gripHasSupport(LedgeGrip grip) => _nearGround.any(
    (floor) =>
        floor.contains(grip.landing.x) &&
        (floor.yAt(grip.landing.x) - grip.landing.y).abs() <= .75,
  );

  bool _advanceGrip(double dt) {
    final grip = ledge!;
    if (!_gripHasSupport(grip)) {
      ledge = null;
      vy = 0;
      return false;
    }
    grip.progress = math.min(grip.targetProgress, grip.progress + dt * 1.6);
    final t = grip.progress * grip.progress * (3 - 2 * grip.progress);
    final hang = grip.corner + const V(-18, -24);
    final desired = hang + (grip.landing - hang) * t;
    final before = V(x, y);
    final next = before + (desired - before) * (1 - math.exp(-20 * dt));
    x = next.x;
    y = next.y;
    vy = 0;
    if (grip.pulls > 0) walked += before.distance(next);
    if (grip.progress >= 1 && next.distance(grip.landing) < .2) {
      x = grip.landing.x;
      y = grip.landing.y;
      final floor = _support(_nearGround, grip.landing);
      grounded = true;
      onNatural = floor?.natural ?? false;
      ledge = null;
      emit('land');
      onSaveRequested?.call(true);
    }
    return true;
  }

  void _walkTo(V target, bool natural) {
    final oldWalk = walked;
    walked += target.distance(V(x, y));
    x = target.x;
    y = target.y;
    vy = 0;
    grounded = true;
    onNatural = natural;
    if ((walked / 20).floor() > (oldWalk / 20).floor()) emit('step');
  }

  Iterable<_ClimbRun> _groupClimbs(
    Iterable<(V, V)> segments,
    bool natural,
  ) sync* {
    List<V>? run;
    for (final segment in segments) {
      var a = segment.$1, b = segment.$2;
      if (a.x > b.x || ((a.x - b.x).abs() <= 1e-7 && a.y > b.y)) {
        final swap = a;
        a = b;
        b = swap;
      }
      final dx = b.x - a.x;
      final steep =
          b.y > a.y + 1e-7 &&
          (dx.abs() <= 1e-7 || (b.y - a.y) / dx > maxClimbSlope + 1e-6);
      if (!steep) {
        if (run != null) yield _ClimbRun(run, natural);
        run = null;
      } else if (run != null && run.last.distance(a) < .001) {
        run.add(b);
      } else if (run != null && b.distance(run.first) < .001) {
        run.insert(0, a);
      } else {
        if (run != null) yield _ClimbRun(run, natural);
        run = [a, b];
      }
    }
    if (run != null) yield _ClimbRun(run, natural);
  }

  Iterable<_ClimbRun> _buildClimbRuns() sync* {
    final terrain = level.terrain.where((s) => s.tag == 'ground').toList()
      ..sort((a, b) => a.a.x.compareTo(b.a.x));
    yield* _groupClimbs(terrain.map((s) => (s.a, s.b)), true);
    for (final line in solidLines) {
      yield* _groupClimbs([
        for (var i = 1; i < line.points.length; i++)
          (line.points[i - 1], line.points[i]),
      ], false);
    }
  }

  bool _smallEnough(_ClimbRun run, double feetY) =>
      run.rise <= dotHeight + 1e-6 &&
      run.points.last.y - feetY <= dotHeight + 1e-6;

  bool _climbSmallStep(double travel, List<_ClimbRun> climbs) {
    for (final run in climbs) {
      if (!_smallEnough(run, y)) continue;
      double? distance;
      var available = travel;
      if (x < run.points.first.x - .001) {
        final approach = run.points.first.x - x;
        if (approach > travel || (y - run.points.first.y).abs() > .75) continue;
        available -= approach;
        distance = 0;
      } else {
        distance = run.distanceAt(V(x, y));
      }
      if (distance == null || distance >= run.path.cost - 1e-6) continue;
      final nextDistance = math.min(run.path.cost, distance + available);
      var target = run.path.atDistance(nextDistance).$1;
      if (nextDistance >= run.path.cost - 1e-6) {
        // Leave the shared vertex so the finished steep leg cannot trap Dot
        // instead of allowing him onto the next surface (or off the free end).
        target = target + const V(.002, 0);
      }
      _walkTo(target, run.natural);
      return true;
    }
    return false;
  }

  bool _blockedAhead(double nextX, double feetY, List<_ClimbRun> climbs) {
    // Sweep Dot's body against walls and slopes he cannot climb. Overhead
    // roofs stay clear, and vertical strokes never become infinite slopes.
    for (final run in climbs) {
      if (_smallEnough(run, feetY)) continue;
      for (var i = 1; i < run.points.length; i++) {
        final a = run.points[i - 1], b = run.points[i];
        final dx = b.x - a.x;
        final vertical = dx.abs() <= 1e-7;
        if (!vertical && (b.y - a.y) / dx <= maxClimbSlope + 1e-6) {
          continue;
        }
        final left = math.max(x - 12, math.min(a.x, b.x));
        final right = math.min(nextX + 12, math.max(a.x, b.x));
        if (left > right) continue;
        final low = vertical
            ? math.min(a.y, b.y)
            : a.y + (b.y - a.y) * (left - a.x) / dx;
        final high = vertical
            ? math.max(a.y, b.y)
            : a.y + (b.y - a.y) * (right - a.x) / dx;
        if (high > feetY + .5 && low < feetY + dotHeight) return true;
      }
    }
    return false;
  }

  void _trackProgress(double dt) {
    if (ledge != null) {
      _stuckElapsed = 0;
      _progressPoint = V(x, y);
      return;
    }
    final position = V(x, y);
    final previous = _progressPoint;
    if (previous == null || position.distance(previous) >= 1) {
      _progressPoint = position;
      _stuckElapsed = 0;
      return;
    }
    _stuckElapsed += dt;
    if (_stuckElapsed >= stuckLimit - 1e-9) {
      die(
        'Dot 3 saniyedir ilerleyemiyor. Daha rahat çıkabileceği bir yol çiz.',
      );
    }
  }

  void _collect() {
    for (final p in level.pickups) {
      if (!collected.contains(p.id) &&
          (x - p.p.x).abs() <= 16 &&
          (y + 16 - p.p.y).abs() <= 23) {
        collected.add(p.id);
        ink = math.min(240, ink + p.value);
        emit('pickup', p.p);
      }
    }
  }

  void _balls(double dt) {
    for (final b in level.balls) {
      if (b.captured) {
        continue;
      }
      if (b.triggeredAt == null && x >= b.triggerX) {
        b.triggeredAt = gameTime;
      }
      if (!b.released &&
          b.triggeredAt != null &&
          gameTime >= b.triggeredAt! + b.delay) {
        b.released = true;
        b.speed = b.initialSpeed;
        b.position = b.source;
        for (final l in solidLines) {
          if (l.points.first.distance(b.source - const V(0, 8)) <= 22) {
            b.railId = l.id;
            break;
          }
        }
        emit('ballRelease', b.position);
      }
      if (!b.released) {
        continue;
      }
      final rail = lines
          .where((l) => l.id == b.railId && !l.retired)
          .firstOrNull;
      if (rail != null && !b.missed) {
        final (_, tangentY) = rail.atDistance(b.distanceOnRail);
        final acceleration = -160 * tangentY - b.friction;
        final nextSpeed = math.max(0.0, b.speed + acceleration * dt);
        b.distanceOnRail += (b.speed + nextSpeed) * .5 * dt;
        b.speed = nextSpeed;
        b.position = rail.atDistance(b.distanceOnRail).$1 + const V(0, 8);
        if (b.distanceOnRail >= rail.cost) {
          if (b.position.distance(b.receiver) <= 22) {
            b.captured = true;
            b.position = b.receiver;
            emit('capture', b.position);
          } else {
            b.missed = true;
            b.vy = 0;
          }
        }
      } else {
        b.missed = true;
        b.position = b.position + V(b.speed * dt, b.vy * dt);
        b.vy -= 160 * dt;
      }
    }
  }

  void _rain(double dt) {
    for (final r in level.rain) {
      if (r.triggeredAt == null && x >= r.left - 260) {
        r.triggeredAt = gameTime;
      }
      if (r.triggeredAt == null || x > r.right + 480) {
        continue;
      }
      while (gameTime - r.triggeredAt! >= r.emitted * .24) {
        final xx = r.left + (r.emitted % 3) / 2 * (r.right - r.left);
        crumbs.add(Crumb(xx, 224, 0, r.emitted++));
      }
    }
    final remove = <Crumb>[];
    for (final c in crumbs) {
      final before = c.y;
      c.vy -= 160 * dt;
      c.y += c.vy * dt;
      var firstHit = -1000.0;
      bool hitsDot = false;
      for (final l in solidLines) {
        for (final hit in l.crossingsAt(c.x)) {
          final yy = hit.$1;
          if (yy <= before + 3 && yy >= c.y - 3 && yy > firstHit) {
            firstHit = yy;
          }
        }
      }
      if ((c.x - x).abs() < 15 &&
          y + dotHeight <= before + 3 &&
          y + dotHeight >= c.y - 3 &&
          y + dotHeight > firstHit) {
        firstHit = y + dotHeight;
        hitsDot = true;
      }
      if (firstHit > -900) {
        remove.add(c);
        if (hitsDot) {
          die('Silgi kırıntıları için üstte bir çatı gerekiyor.');
        } else {
          emit('crumb', V(c.x, firstHit));
        }
      } else if (c.y < -120) {
        remove.add(c);
      }
    }
    crumbs.removeWhere(remove.contains);
  }

  void _gates() {
    for (final g in level.gates) {
      // This vertical slice implements the object gate; other families stay outside its scope.
      if (!g.open &&
          level.balls.isNotEmpty &&
          level.balls.every((b) => b.captured)) {
        g.open = true;
        emit('gate', V(g.x, 30));
      }
      if (!g.open && x + 12 >= g.x && x - 12 < g.x + 12) {
        die('Önce bilyeyi çiçekli yuvaya ulaştır.');
      }
    }
  }

  void _retire() {
    for (final l in solidLines.toList()) {
      final dependent = level.balls
          .where((b) => b.railId == l.id && !b.captured && !b.missed)
          .isNotEmpty;
      final objectFinished = level.balls.any(
        (b) => b.railId == l.id && b.captured,
      );
      final past = grounded && onNatural && x - 12 > l.right;
      if (!dependent && (objectFinished || past)) {
        l.retired = true;
        l.retiredAt = gameTime;
        emit('dissolve', l.points.last);
      }
    }
    lines.removeWhere((l) => l.retired && gameTime - l.retiredAt > 1);
  }

  void _nextLevel() {
    if (levelIndex + 1 >= levelData.length) {
      phase = Phase.complete;
      emit('complete');
      onSaveRequested?.call(true);
      return;
    }
    final width = level.width;
    x -= width;
    origin += width;
    levelIndex++;
    ledge = null;
    entryInk = ink;
    entryWalked = walked;
    _loadLevel();
    lines.clear();
    crumbs.clear();
    collected.clear();
    draft = null;
    strokePointerActive = false;
    gameTime = 0;
    _stuckElapsed = 0;
    _progressPoint = null;
    emit('boundary');
    onSaveRequested?.call(true);
  }

  Map<String, dynamic> checkpointSnapshot() {
    final checkpoint = InkSession(levelData, lab: lab);
    checkpoint.levelIndex = levelIndex;
    checkpoint._loadLevel();
    checkpoint.entryInk = entryInk;
    checkpoint.ink = entryInk;
    checkpoint.entryWalked = entryWalked;
    checkpoint.walked = entryWalked;
    checkpoint.activeTotal = activeTotal;
    checkpoint.origin = origin;
    checkpoint.resetEpoch = resetEpoch;
    checkpoint.firstDrawDone = firstDrawDone;
    return checkpoint.snapshot();
  }

  Map<String, dynamic> snapshot() => {
    'schema': 1,
    'layoutRevision': levelData.first['layoutRevision'] ?? 1,
    'lab': lab,
    'levelIndex': levelIndex,
    'phase': phase.name,
    'ink': ink,
    'entryInk': entryInk,
    'x': x,
    'y': y,
    'vy': vy,
    'gameTime': gameTime,
    'realTime': realTime,
    'activeTotal': activeTotal,
    'walked': walked,
    'ledge': ledge?.toJson(),
    'entryWalked': entryWalked,
    'stuckElapsed': _stuckElapsed,
    'progressPoint': _progressPoint?.toJson(),
    'origin': origin,
    'grounded': grounded,
    'onNatural': onNatural,
    'saveElapsed': saveElapsed,
    'strokeSerial': strokeSerial,
    'resetEpoch': resetEpoch,
    'firstDrawDone': firstDrawDone,
    'lines': lines.map((l) => l.toJson()).toList(),
    'collected': collected.toList(),
    'balls': level.balls.map((b) => b.toJson()).toList(),
    'gates': {for (final g in level.gates) g.id: g.open},
    'rain': {
      for (final r in level.rain) r.id: [r.triggeredAt, r.emitted],
    },
    'crumbs': crumbs.map((c) => c.toJson()).toList(),
    'budget': budget.slices.map((s) => [s.$1, s.$2]).toList(),
    'draft': draft == null
        ? null
        : {
            'surface': draft!.start.surface.id,
            'start': draft!.start.point.toJson(),
            'points': draft!.points.map((p) => p.toJson()).toList(),
            'backwards': draft!.backwards,
            'rawPoint': draft!.rawPoint.toJson(),
          },
  };
  static InkSession restore(
    List<Map<String, dynamic>> data,
    Map<String, dynamic> m,
  ) {
    if (m['schema'] != 1) {
      throw const FormatException('Unsupported save schema');
    }
    final s = InkSession(data, lab: m['lab'] == true);
    s.levelIndex = (m['levelIndex'] as num).toInt().clamp(0, data.length - 1);
    s._loadLevel();
    double d(String k) => (m[k] as num).toDouble();
    if ((m['layoutRevision'] ?? 1) != (data.first['layoutRevision'] ?? 1)) {
      // Shortened routes invalidate old local line/terrain coordinates. Preserve
      // completed chapters and restart only the current death checkpoint.
      s.entryInk = d('entryInk');
      s.ink = s.entryInk;
      s.origin = data
          .take(s.levelIndex)
          .fold<double>(
            0,
            (sum, level) => sum + (level['width'] as num).toDouble(),
          );
      s.entryWalked = s.origin;
      s.walked = s.entryWalked;
      s.activeTotal = d('activeTotal');
      s.resetEpoch = (m['resetEpoch'] as num).toInt() + 1;
      s.firstDrawDone = m['firstDrawDone'] == true;
      s.migratedLayout = true;
      return s;
    }
    s.ink = d('ink');
    s.entryInk = d('entryInk');
    s.x = d('x');
    s.y = d('y');
    s.vy = d('vy');
    s.gameTime = d('gameTime');
    s.realTime = d('realTime');
    s.activeTotal = d('activeTotal');
    s.saveElapsed = (m['saveElapsed'] as num?)?.toDouble() ?? 0;
    s.walked = d('walked');
    // Older saves did not retain the chapter-entry walking distance. Estimate
    // only that checkpoint; the live counter keeps its exact saved distance.
    s.entryWalked =
        (m['entryWalked'] as num?)?.toDouble() ??
        math.max(0.0, s.walked - math.max(0.0, s.x));
    s._stuckElapsed = (m['stuckElapsed'] as num?)?.toDouble() ?? 0;
    s._progressPoint = m['progressPoint'] == null
        ? null
        : V.from(m['progressPoint']);
    s.origin = d('origin');
    s.grounded = m['grounded'] == true;
    s.onNatural = m['onNatural'] == true;
    s.strokeSerial = (m['strokeSerial'] as num).toInt();
    s.resetEpoch = (m['resetEpoch'] as num).toInt();
    s.firstDrawDone = m['firstDrawDone'] == true;
    s.lines.addAll(
      (m['lines'] as List).map(
        (a) => InkLine.from(Map<String, dynamic>.from(a)),
      ),
    );
    s.collected.addAll((m['collected'] as List).cast<String>());
    for (final dynamic b in m['balls'] as List) {
      s.level.balls
          .where((o) => o.id == b['id'])
          .firstOrNull
          ?.restore(Map<String, dynamic>.from(b));
    }
    for (final g in s.level.gates) {
      g.open = m['gates'][g.id] == true;
    }
    for (final r in s.level.rain) {
      final a = m['rain'][r.id] as List;
      r.triggeredAt = (a[0] as num?)?.toDouble();
      r.emitted = (a[1] as num).toInt();
    }
    for (final dynamic a in m['crumbs'] as List) {
      s.crumbs.add(
        Crumb(
          (a[0] as num).toDouble(),
          (a[1] as num).toDouble(),
          (a[2] as num).toDouble(),
          (a[3] as num).toInt(),
        ),
      );
    }
    for (final dynamic a in m['budget'] as List) {
      s.budget.slices.add(((a[0] as num).toDouble(), (a[1] as num).toDouble()));
    }
    if (m['ledge'] case final Map raw) {
      final grip = LedgeGrip(V.from(raw['corner']), V.from(raw['landing']));
      grip.pulls = (raw['pulls'] as num).toInt().clamp(
        0,
        LedgeGrip.requiredPulls,
      );
      grip.progress = (raw['progress'] as num).toDouble().clamp(
        0.0,
        grip.targetProgress,
      );
      if (s._gripHasSupport(grip)) {
        s.ledge = grip;
        s.grounded = false;
        s.vy = 0;
      }
    }
    if (m['draft'] != null) {
      final a = m['draft'];
      final surface = [
        ...s.level.terrain,
        ...s.level.anchors,
      ].where((z) => z.id == a['surface']).firstOrNull;
      if (surface != null) {
        s.draft =
            Draft(
                Anchor(V.from(a['start']), surface),
                (a['points'] as List).map(V.from).toList(),
              )
              ..backwards = a['backwards'] == true
              ..rawPoint = a['rawPoint'] == null
                  ? V.from((a['points'] as List).last)
                  : V.from(a['rawPoint']);
      }
    }
    if (m['phase'] == Phase.dead.name) {
      // A persisted death can never restore the live pre-death world.
      final cp = s.checkpointSnapshot();
      cp['phase'] = Phase.ready.name;
      return InkSession.restore(data, cp);
    }
    s.phase = Phase.ready;
    s.strokePointerActive = false;
    if (m['phase'] == Phase.complete.name) {
      s.phase = Phase.complete;
    }
    return s;
  }
}

/// Deep clone is used at the persistence boundary, never a shared live map.
Map<String, dynamic> cloneJson(Map<String, dynamic> a) =>
    jsonDecode(jsonEncode(a)) as Map<String, dynamic>;
