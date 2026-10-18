import 'dart:convert';
import 'dart:math' as math;

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
      y += sampled[(i + k).clamp(0, count)].y * weights[k + 2] / 16;
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
  InkLine(this.id, this.points, {this.role = 'walk'});
  final String id, role;
  final List<V> points;
  bool retired = false;
  double retiredAt = 0;
  double get cost => pathLength(points);
  double get left => points.first.x;
  double get right => points.last.x;
  double? yAt(double x) {
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      if (x >= a.x - .001 && x <= b.x + .001) {
        return a.y + (b.y - a.y) * (x - a.x) / (b.x - a.x);
      }
    }
    return null;
  }

  double slopeAt(double x) {
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      if (x >= a.x - .001 && x <= b.x + .001) {
        return (b.y - a.y) / (b.x - a.x);
      }
    }
    return 0;
  }

  (V, double) atDistance(double s) {
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      final length = a.distance(b);
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

class Level {
  Level(this.number, this.title, this.width);
  final int number;
  final String title;
  final double width;
  final List<Surface> terrain = [], anchors = [];
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
  double walked = 0, origin = 0;
  bool grounded = true, onNatural = true, strokePointerActive = false;
  final List<InkLine> lines = [];
  final Set<String> collected = {};
  final List<Crumb> crumbs = [];
  final SlowBudget budget = SlowBudget();
  Draft? draft;
  String message = '', lastEvent = '';
  double messageUntil = 0;
  bool firstDrawDone = false;
  void Function(String, V)? onEvent;
  void Function(bool)? onSaveRequested;
  double saveElapsed = 0;
  int get activeLines => lines.where((l) => !l.retired).length;
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
    if (p.x <= last.x + .4) {
      return;
    }
    final alpha = ((p - last).length / 7).clamp(.42, .96).toDouble();
    final filtered = last + (p - last) * alpha;
    d.points.add(filtered);
    emit('penMove', filtered);
  }

  (List<V>?, String) validatedDraft() {
    final d = draft;
    if (d == null || d.points.length < 2) {
      return (null, 'İki sabit yüzeyi birleştir.');
    }
    final end = anchorAt(d.points.last);
    if (end == null) {
      return (null, 'Diğer ucu da sabit kâğıda bırak.');
    }
    if (d.backwards) {
      return (null, 'Çizgi soldan sağa ilerlemeli.');
    }
    final raw = List<V>.of(d.points)..[0] = d.start.point;
    raw[raw.length - 1] = end.point;
    final p = smoothStroke(raw);
    if (end.point.x - p.first.x < 12) {
      return (null, 'İki ayrı kenarı birleştir.');
    }
    for (var i = 1; i < p.length; i++) {
      final dx = p[i].x - p[i - 1].x;
      if (dx <= .01) {
        return (null, 'Çizgi kendi üzerine dönmesin.');
      }
      if (((p[i].y - p[i - 1].y) / dx).abs() > .70 + 1e-6) {
        return (null, 'Bu kısım Dot için fazla dik.');
      }
    }
    final cost = pathLength(p);
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
    final b = anchorAt(p.last)!.surface;
    if (a.tag == b.tag && a.tag != 'ground') {
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
    walked = 0;
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
        if (x + 12 > r[0] && x - 12 < r[2] && y + 32 > r[1] && y < r[3]) {
          die('Gövden için biraz daha açıklık bırak.');
        }
      }
      if (y < -300) {
        die('Köprü hazır olmadan kenarı geçtin.');
      }
      if (phase == Phase.playing && x - 12 >= level.width) {
        _nextLevel();
      }
      if (saveElapsed >= 5 && phase == Phase.playing) {
        saveElapsed = 0;
        onSaveRequested?.call(false);
      }
    }
  }

  (double, bool, double)? _support(
    double xx,
    double expected,
    double tolerance,
  ) {
    (double, bool, double)? best;
    void consider(double yy, bool natural, double slope) {
      if ((yy - expected).abs() <= tolerance &&
          (best == null || yy > best!.$1 + .001)) {
        best = (yy, natural, slope);
      }
    }

    for (final s in level.terrain) {
      if (s.contains(xx)) {
        consider(s.yAt(xx), true, s.slope);
      }
    }
    for (final l in solidLines) {
      final yy = l.yAt(xx);
      if (yy != null) {
        consider(yy, false, l.slopeAt(xx));
      }
    }
    return best;
  }

  void _walk(double dt) {
    if (grounded) {
      final old = _support(x, y, 1.2);
      final slope = old?.$3 ?? 0;
      final dx = 32 * dt / math.sqrt(1 + slope * slope);
      final next = _support(x + dx, y, 1.2);
      if (next != null) {
        final oldWalk = walked;
        walked += math.sqrt(dx * dx + math.pow(next.$1 - y, 2));
        x += dx;
        y = next.$1;
        onNatural = next.$2;
        if ((walked / 14).floor() > (oldWalk / 14).floor()) {
          emit('step');
        }
        return;
      }
      grounded = false;
      onNatural = false;
      vy = 0;
    }
    final previousY = y;
    x += 32 * dt;
    vy -= 160 * dt;
    y += vy * dt;
    double? landing;
    bool natural = true;
    void check(double yy, bool isNatural) {
      if (previousY >= yy - .001 &&
          y <= yy &&
          (landing == null || yy > landing!)) {
        landing = yy;
        natural = isNatural;
      }
    }

    for (final s in level.terrain) {
      if (s.contains(x)) {
        check(s.yAt(x), true);
      }
    }
    for (final l in solidLines) {
      final yy = l.yAt(x);
      if (yy != null) {
        check(yy, false);
      }
    }
    if (landing != null) {
      y = landing!;
      vy = 0;
      grounded = true;
      onNatural = natural;
      emit('land');
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
        final yy = l.yAt(c.x);
        if (yy != null && yy <= before + 3 && yy >= c.y - 3 && yy > firstHit) {
          firstHit = yy;
        }
      }
      if ((c.x - x).abs() < 15 &&
          y + 32 <= before + 3 &&
          y + 32 >= c.y - 3 &&
          y + 32 > firstHit) {
        firstHit = y + 32;
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
    entryInk = ink;
    _loadLevel();
    lines.clear();
    crumbs.clear();
    collected.clear();
    draft = null;
    strokePointerActive = false;
    gameTime = 0;
    emit('boundary');
    onSaveRequested?.call(true);
  }

  Map<String, dynamic> checkpointSnapshot() {
    final checkpoint = InkSession(levelData, lab: lab);
    checkpoint.levelIndex = levelIndex;
    checkpoint._loadLevel();
    checkpoint.entryInk = entryInk;
    checkpoint.ink = entryInk;
    checkpoint.activeTotal = activeTotal;
    checkpoint.origin = origin;
    checkpoint.resetEpoch = resetEpoch;
    checkpoint.firstDrawDone = firstDrawDone;
    return checkpoint.snapshot();
  }

  Map<String, dynamic> snapshot() => {
    'schema': 1,
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
