part of 'ink_model.dart';

/// Temporary, opt-in experiments. Story data never enables these rules.
class InkLabCase {
  const InkLabCase(
    this.id,
    this.tr,
    this.en,
    this.tipTr,
    this.tipEn, {
    this.momentum = false,
    this.family,
  });
  final String id, tr, en, tipTr, tipEn;
  final bool momentum;
  final String? family;
  static const all = [
    InkLabCase(
      'slide',
      'Kaydırak ve hız',
      'Slide and speed',
      'Kesik izi takip ederek dik bir iniş çiz. Dot kısa bir atlayışla kaydırağa yerleşir.',
      'Draw a steep descent along the guide. Dot hops onto it and gathers speed.',
      momentum: true,
    ),
    InkLabCase(
      'ramp',
      'Rampa ve sıçrama',
      'Ramp and launch',
      'İnişi yukarı kıvır. Kazandığın hız çizginin ucunda sıçramaya dönüşür.',
      'Curve the descent upward. Your speed becomes a jump at the tip.',
      momentum: true,
    ),
    InkLabCase(
      'landing',
      'İniş yolunu çiz',
      'Draw the landing',
      'İlk çizgiyle havalan. Kalkışa yakın damlayı alınca ikinci çizgiyi alt kıyıdan geriye doğru çiz.',
      'Collect the drop near takeoff, then draw the second stroke backward from the lower bank.',
      momentum: true,
    ),
    InkLabCase(
      'ceiling',
      'Alçak çıkış',
      'Low launch',
      'Rampayı alçak bitir. Fazla dik çıkış, üstteki mürekkep lekesine çarpar.',
      'Finish with a low launch angle to avoid the overhead ink stain.',
      momentum: true,
    ),
    InkLabCase(
      'eraser',
      'Gezinen silgi',
      'Moving eraser',
      'Silgi yalnız dokunduğu mürekkebi siler; çizgide kalan parçalar korunur. Yükselmesini bekle, sonra köprüyü kur ve yürü.',
      'The eraser removes only the ink it touches, leaving the other pieces intact. Wait until it rises, then draw and walk.',
    ),
    InkLabCase(
      'fold',
      'Katlanan kâğıt',
      'Folding paper',
      'Alt kıyıdan sola bir köprü çiz. Sayfanın içine de çizim yapabilirsin. Dot düğmeye basınca sağ üst köşe kat izinden içeri kapanır; zemin eğime dönüşür, katın içindeki çizim arkada kalır.',
      'Draw a bridge left from the lower bank, and try drawing inside the page. The button folds the top-right corner inward: the floor becomes a slope and ink inside the fold is covered.',
    ),
    InkLabCase(
      'fold-cover',
      'Katın arkasındaki mürekkep',
      'Ink behind the fold',
      'Sağdaki sayfanın içine bir çizgi çiz. Dot düğmeye basınca sayfa sola kapanır: ön yüzdeki çizim gizlenir, kâğıdın arkası yarığı kapatır.',
      'Draw inside the right page. The button folds it left: the front-side ink is hidden and the paper back closes the gap.',
    ),
    InkLabCase(
      'pulley',
      'Makaralı köprü',
      'Pulley bridge',
      'İpli köprünün ucunun yükselip alçalmasını zamanla. Sabit kıyılardan ayrı bir geçiş de çizebilirsin.',
      'Time the rope-driven bridge as its tip rises and falls, or draw a crossing from the fixed banks.',
    ),
    InkLabCase(
      'crumble',
      'Çatlayan platform',
      'Crumbling platform',
      'Platform, Dot basınca çatlar. Üzerinden geçecek kemeri önceden hazırla.',
      'The platform cracks under Dot. Prepare an arch over it before walking.',
    ),
    InkLabCase(
      'weight',
      'Ağırlık ve düğme',
      'Weight and switch',
      'Üst oluğu çiz. Bilye baskı düğmesine oturunca kapı açılır; alttan ilerle.',
      'Draw the upper rail. The ball presses the switch and opens the gate below.',
    ),
    InkLabCase(
      'routes',
      'İki farklı yol',
      'Two routes',
      'Az mürekkepli alçak geçit ya da daha geniş üst yol. Örnek düğmesi iki rotayı sırayla gösterir.',
      'Choose the cheap low passage or the longer upper route. Guide cycles through both.',
    ),
    InkLabCase(
      'repair',
      'Eksik bağlantı',
      'Missing link',
      'Üstteki iki pirinç pimi bir çizgiyle bağla. Mekanizma alttaki kâğıt köprüyü açar.',
      'Join the two brass pins with ink. The mechanism unfolds the paper bridge below.',
    ),
    ..._planLabCases,
    InkLabCase(
      'spikes',
      'Dikenli zemin',
      'Spiked paper',
      'Dikenlerin üzerinden geçen bir kemer çiz. Yalnız kâğıda değmesi yetmez; ayaklarına da açıklık bırak.',
      'Arch over the spikes. Paper contact approves the ink, but leave clearance under Dot’s feet.',
    ),
    InkLabCase(
      'wall-saw',
      'Duvardaki döner bıçak',
      'Retracting wall saw',
      'Bıçak işaret verdikten sonra duvardan çıkar. Yüksek bir yol çiz ya da alçak rampayı bıçak gizliyken geç.',
      'The wall signals before the blade emerges. Draw a high route or time a lower ramp while it is hidden.',
    ),
  ];
  static InkLabCase byId(String id) => all.firstWhere((c) => c.id == id);
  String title(String language) => language == 'tr' ? tr : en;
  String tip(String language) => language == 'tr' ? tipTr : tipEn;
  InkSession createSession() =>
      InkSession([
          {
            'number': 1,
            'title': tr,
            'width': family == null ? (momentum ? 670.0 : 580.0) : 780.0,
            'cells': <Map<String, dynamic>>[],
            'experiment': id,
          },
        ], lab: true)
        ..drawingTutorialDone = true
        ..ledgeTutorialDone = true
        ..firstDrawDone = true;
}

enum InkLabMotion { walking, entryHop, sliding, airborne, coasting }

/// One connected contour, parameterized by distance instead of screen X.
/// Verticals and small hand wobble are valid; a deliberate loop is not a slide.
class _LabRail {
  _LabRail(List<V> contour) {
    final forward = contour.last.x >= contour.first.x;
    for (final point in forward ? contour : contour.reversed) {
      if (points.isEmpty || point.distance(points.last) > 1e-7) {
        lengths.add(
          points.isEmpty ? 0 : lengths.last + point.distance(points.last),
        );
        points.add(point);
      }
    }
    var furthestX = points.first.x;
    var usable = points.length > 1;
    for (final point in points) {
      if (point.x < furthestX - 2.4) usable = false;
      furthestX = math.max(furthestX, point.x);
    }
    rideable = usable;
  }
  final List<V> points = [];
  final List<double> lengths = [];
  late final bool rideable;

  (V, double) sample(double distance) {
    for (var i = 1; i < points.length; i++) {
      if (distance <= lengths[i] || i == points.length - 1) {
        final d = points[i] - points[i - 1];
        final t = ((distance - lengths[i - 1]) / (lengths[i] - lengths[i - 1]))
            .clamp(0.0, 1.0);
        return (points[i - 1] + d * t, math.atan2(d.y, d.x));
      }
    }
    return (points.last, 0);
  }

  /// Match actual foot contact, including the next fraction of a walking step.
  /// This never reaches down to a distant or floating drawing.
  (double, V)? contact(V feet, {double ahead = .75}) {
    var error = double.infinity;
    (double, V)? best;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], d = points[i] - a;
      final t =
          (((feet.x - a.x) * d.x + (feet.y - a.y) * d.y) /
                  (d.x * d.x + d.y * d.y))
              .clamp(0.0, 1.0);
      final at = a + d * t;
      if (at.x < feet.x - .75 ||
          at.x > feet.x + ahead ||
          (at.y - feet.y).abs() > .75) {
        continue;
      }
      final gap = at.distance(feet);
      if (gap < error) {
        error = gap;
        best = (lengths[i - 1] + d.length * t, at);
      }
    }
    return best;
  }

  bool descendsAt(double distance) {
    final from = sample(distance).$1;
    final to = sample(math.min(lengths.last, distance + 8)).$1;
    final drop = from.y - to.y;
    return drop >= 4 &&
        math.atan2(drop, math.max(0, to.x - from.x)) > math.pi / 3;
  }
}

class _LabRailCache {
  _LabRailCache(InkLine line)
    : revision = line.geometryRevision,
      paths = [for (final contour in line.contours) _LabRail(contour)];
  final int revision;
  final List<_LabRail> paths;
}

/// The real departure impulse, sampled at a physics step, for presentation.
class InkSlideExit {
  const InkSlideExit(this.position, this.velocity, this.time);
  final V position, velocity;
  final double time;
  double get angle => math.atan2(velocity.y, velocity.x);
}

class MechanicsLab {
  MechanicsLab(this.session, this.spec);
  final InkSession session;
  final InkLabCase spec;
  bool holdDot = true;
  bool showGuide = false;
  int guideRoute = 0;
  final List<List<List<V>>> guides = [];
  final List<InkLabTask> tasks = [];
  InkLabMotion motion = InkLabMotion.walking;
  InkLine? _rail;
  final Expando<_LabRailCache> _railPaths = Expando<_LabRailCache>();
  _LabRail? _path;
  int _railRevision = -1;
  (V, double, double)? _slideBefore;
  InkSlideExit? lastSlideExit;
  double _dustTravel = 0;
  List<V> _points = [];
  List<double> _lengths = [];
  double _distance = 0, speed = 0, vx = 0, _hopAge = 0;
  V _hopStart = const V(0, 0), _hopTarget = const V(0, 0);
  V? _strokePress;
  final Set<String> _entered = {};
  double _nextEraseEffect = 0;
  double? crackAt;
  double crackContactX = 160;
  static const crackDuration = .9, crackDepth = 26.0;
  static const crackBreaks = [160.0, 177.0, 196.0, 212.0, 233.0, 251.0, 275.0];
  bool collapsed = false, repaired = false;
  double repairProgress = 0;
  FoldPaper? paper;
  Surface? pulleyDeck;
  double get pulleyAngle => .46 + .46 * math.sin(session.gameTime * 1.15);
  V get eraser => V(
    245 + 24 * math.sin(session.gameTime * 1.1),
    38 + 38 * math.cos(session.gameTime * .75),
  );
  double get crackProgress => crackAt == null
      ? 0
      : ((session.gameTime - crackAt!) / crackDuration).clamp(0.0, 1.0);
  bool get sliding => motion == InkLabMotion.sliding;
  double get speedRatio {
    if (holdDot) return 0;
    if (motion == InkLabMotion.walking) return 1;
    final actual =
        motion == InkLabMotion.airborne || motion == InkLabMotion.entryHop
        ? math.sqrt(vx * vx + session.vy * session.vy)
        : speed;
    return actual / session.walkSpeed;
  }

  double get railAngle => _points.length < 2 ? 0 : _sample(_distance).$2;

  /// A board spans multiple pen segments. Averaging over its footprint avoids
  /// reacting to every small kink; physics keeps the exact rail tangent.
  double get surfAngle {
    if (_points.length < 2) return 0;
    final a = _sample(math.max(0, _distance - 10)).$1;
    final b = _sample(math.min(_lengths.last, _distance + 10)).$1;
    return a.distance(b) < 1e-7 ? railAngle : math.atan2(b.y - a.y, b.x - a.x);
  }

  void cycleGuide() {
    if (!showGuide) {
      showGuide = true;
      guideRoute = 0;
    } else if (guideRoute + 1 < guides.length) {
      guideRoute++;
    } else {
      showGuide = false;
    }
  }

  /// Snapping a press just inside the paper rim must not add a backwards hook
  /// before the user's actual stroke. Preview and collision use this same path.
  void beginStroke(V press) => _strokePress = press;

  List<V> normalizeStroke(List<V> raw) {
    if (!spec.momentum || raw.length < 3 || _strokePress == null) return raw;
    final anchor = raw.first;
    final direction = raw.last.x >= anchor.x ? 1 : -1;
    if ((_strokePress!.x - anchor.x) * direction >= -.75) return raw;
    var i = 1;
    while (i < raw.length - 1 && (raw[i].x - anchor.x) * direction < -1e-7) {
      if (raw[i].distance(anchor) > 20) return raw;
      i++;
    }
    return i > 1 ? [anchor, ...raw.skip(i)] : raw;
  }

  List<_LabRail> _pathsFor(InkLine line) {
    var cache = _railPaths[line];
    if (cache == null || cache.revision != line.geometryRevision) {
      cache = _LabRailCache(line);
      _railPaths[line] = cache;
    }
    return cache.paths;
  }

  bool _syncRail({V? contactAt}) {
    final rail = _rail;
    if (rail == null || rail.retired || rail.concealed) return false;
    if (_railRevision == rail.geometryRevision) return true;
    final at = contactAt ?? V(session.x, session.y);
    for (final path in _pathsFor(rail)) {
      if (!path.rideable) continue;
      final contact = path.contact(at, ahead: .01);
      if (contact != null && contact.$2.distance(at) < .75) {
        _attach(rail, path, contact.$1);
        return true;
      }
    }
    return false;
  }

  void _floor(String id, double ax, double ay, double bx, double by) =>
      session.level.terrain.add(Surface(id, V(ax, ay), V(bx, by)));
  void _pin(String id, double x, double y) =>
      session.level.anchors.add(Surface(id, V(x, y), V(x + .001, y)));
  void prepare() {
    final s = session;
    s.level.terrain.clear();
    s.ink = s.entryInk = 240;
    if (spec.family != null) {
      _preparePlan();
      return;
    }
    if (spec.id == 'spikes') {
      _floor('lab-ground', -160, 0, 730, 0);
      s.level.spikes.addAll([
        InkSpikeBed('lab-spikes-a', 175, 215),
        InkSpikeBed('lab-spikes-b', 245, 285),
      ]);
      guides.add([
        [const V(140, 0), const V(166, 32), const V(292, 32), const V(320, 0)],
      ]);
      return;
    }
    if (spec.id == 'wall-saw') {
      _floor('lab-start', -160, 0, 160, 0);
      _floor('lab-wall', 300, 60, 730, 60);
      s.level.wallSaws.add(InkWallSaw('lab-saw', const V(300, 32)));
      guides.add([
        [const V(160, 0), const V(210, 50), const V(255, 66), const V(300, 60)],
      ]);
      return;
    }
    if (spec.id == 'fold' || spec.id == 'fold-cover') {
      paper = FoldPaper(s, cover: spec.id == 'fold-cover');
      _floor('lab-start', -160, 0, 160, 0);
      if (spec.id == 'fold-cover') {
        s.level.terrain.clear();
        _floor('lab-start', -160, 0, 150, 0);
        _floor('lab-finish', 260, 0, 650, 0);
        guides.add([
          [
            const V(280, 0),
            const V(295, -18),
            const V(318, -32),
            const V(340, -18),
          ],
        ]);
      } else {
        _floor('lab-finish', 425, -60, 650, -60);
        guides.add([
          [const V(425, -60), const V(340, -60)],
          [const V(340, 0), const V(310, -8), const V(280, -18)],
        ]);
      }
      paper!.prepare();
      return;
    }
    _floor('lab-start', -160, 0, 130, 0);
    if (spec.momentum) {
      // Each player stroke stays below the normal 220-unit ink limit.
      final bowl = <V>[
        const V(130, 0),
        const V(145, -36),
        const V(161, -68),
        const V(180, -83),
        const V(203, -88),
        const V(225, -83),
        const V(246, -67),
        const V(266, -42),
      ];
      if (spec.id == 'slide') {
        guides.add([
          [
            const V(130, 0),
            const V(147, -43),
            const V(167, -78),
            const V(200, -96),
            const V(260, -96),
          ],
        ]);
        _floor('lab-finish', 260, -96, 730, -96);
      } else if (spec.id == 'landing') {
        guides.add([
          bowl,
          [
            const V(390, -50),
            const V(370, -65),
            const V(350, -65),
            const V(330, -50),
            const V(310, -20),
          ],
        ]);
        _floor('lab-finish', 390, -50, 730, -50);
        _pin('landing-anchor', 390, -50);
        s.level.pickups.add(Pickup('landing-ink', const V(245, -51), 90));
      } else if (spec.id == 'ceiling') {
        guides.add([
          [...bowl.take(6), const V(253, -72), const V(280, -64)],
        ]);
        _floor('lab-finish', 375, -105, 730, -105);
        s.level.hazards.add([280, 5, 385, 45]);
      } else {
        guides.add([bowl]);
        _floor('lab-finish', 330, -60, 730, -60);
      }
      return;
    }
    s.level.terrain.removeWhere((f) => f.id == 'lab-start');
    _floor('lab-start', -160, 0, 160, 0);
    if (spec.id == 'routes') {
      _floor('lab-finish', 335, 0, 650, 0);
      _floor('lab-upper', 232, 95, 265, 95);
      _pin('upper-a', 232, 95);
      _pin('upper-b', 265, 95);
      s.level.hazards.add([225, 39, 270, 65]);
      guides.add([
        [const V(160, 0), const V(335, 0)],
      ]);
      guides.add([
        [const V(160, 0), const V(232, 95)],
        [const V(265, 95), const V(335, 0)],
      ]);
      s.level.pickups.add(Pickup('upper-ink', const V(245, 111), 45));
    } else if (spec.id == 'weight') {
      _floor('lab-finish', 160, 0, 650, 0);
      _pin('ball-source', 175, 100);
      _pin('ball-target', 280, 65);
      final ball = Ball(
        'lab-ball',
        const V(175, 108),
        const V(280, 73),
        0,
        2.5,
        20,
        1,
      )..position = const V(175, 108);
      s.level.balls.add(ball);
      s.level.gates.add(Gate('lab-gate', 340, ['lab-ball']));
      guides.add([
        [const V(175, 100), const V(230, 84), const V(280, 65)],
      ]);
    } else if (spec.id == 'repair') {
      _floor('lab-finish', 380, 0, 650, 0);
      _pin('pin-a', 190, 90);
      _pin('pin-b', 290, 90);
      guides.add([
        [const V(190, 90), const V(290, 90)],
      ]);
    } else {
      _floor('lab-finish', 330, 0, 650, 0);
      if (spec.id == 'pulley') {
        _setPulley();
        guides.add([
          [const V(160, 0), const V(330, 0)],
        ]);
      } else if (spec.id == 'crumble') {
        _floor('lab-crack', 160, 0, 275, 0);
        guides.add([
          [
            const V(160, 0),
            const V(205, 32),
            const V(275, 32),
            const V(330, 0),
          ],
        ]);
      } else {
        guides.add([
          [const V(160, 0), const V(330, 0)],
        ]);
      }
    }
  }

  void _setPulley() {
    final old = pulleyDeck;
    final angle = pulleyAngle;
    final next = Surface(
      'lab-pulley',
      const V(160, 0),
      V(160 + 130 * math.cos(angle), 130 * math.sin(angle)),
    );
    if (old != null) {
      if (session.grounded &&
          old.contains(session.x) &&
          (old.yAt(session.x) - session.y).abs() < .1) {
        final distance = (V(session.x, session.y) - old.a).length;
        session.x = 160 + distance * math.cos(angle);
        session.y = distance * math.sin(angle);
      }
      session.level.terrain.remove(old);
    }
    pulleyDeck = next;
    session.level.terrain.add(next);
  }

  void beforeStep(double dt) {
    _slideBefore = sliding ? (V(session.x, session.y), railAngle, speed) : null;
    if (holdDot && session.level.balls.isNotEmpty) {
      for (final ball in session.level.balls) {
        if (!ball.released) ball.triggeredAt = session.gameTime;
      }
    }
    if (spec.id == 'pulley') _setPulley();
    paper?.beforeStep(dt);
    if (spec.id == 'repair') {
      if (!repaired) {
        repaired = session.solidLines.any(
          (l) =>
              l.points.any((p) => p.distance(const V(190, 90)) < 9) &&
              l.points.any((p) => p.distance(const V(290, 90)) < 9),
        );
      }
      if (repaired && repairProgress < 1) {
        repairProgress = math.min(1, repairProgress + dt / .45);
        if (repairProgress >= 1) {
          _floor('lab-repair-bridge', 160, 0, 380, 0);
          session.emit('gate');
        }
      }
    }
  }

  void afterStep(double dt) {
    final s = session;
    paper?.afterStep();
    if (spec.id == 'crumble' && !collapsed) {
      if (s.grounded && s.x >= 159 && s.x <= 275 && s.y.abs() < .1) {
        if (crackAt == null) {
          crackAt = s.gameTime;
          crackContactX = s.x.clamp(160.0, 275.0);
        }
      }
      if (crackProgress >= 1) {
        collapsed = true;
        s.level.terrain.removeWhere((f) => f.id == 'lab-crack');
        s.emit('crumb', const V(215, 0));
      }
    }
    if (spec.id == 'eraser') {
      final at = eraser;
      final brush = InkEraser(at);
      var erased = false;
      for (final line in s.solidLines.toList()) {
        if (!brush.erase(line)) continue;
        erased = true;
        if (line.concealed) {
          line.retired = true;
          line.retiredAt = s.gameTime;
        }
      }
      if (erased && s.gameTime >= _nextEraseEffect) {
        _nextEraseEffect = s.gameTime + .08;
        s.emit('erase', at);
      }
      if (at.x > s.x - 20 &&
          at.x < s.x + 20 &&
          at.y > s.y - 9 &&
          at.y < s.y + 36) {
        s.die('Silginin geçişini bekleyip yeniden dene.');
      }
    }
    final previous = _slideBefore;
    if (previous != null && !sliding) {
      final velocity = V(vx, s.vy);
      lastSlideExit = InkSlideExit(
        V(s.x, s.y),
        velocity.length > 1
            ? velocity
            : V(math.cos(previous.$2), math.sin(previous.$2)) * previous.$3,
        s.gameTime,
      );
      s.emit('surfRelease', lastSlideExit!.position);
    }
  }

  /// A small authored entry hop, followed by energy-based surface motion.
  /// Hopping is once per line, never a repeatable source of kinetic energy.
  bool move(double dt) {
    final s = session;
    if (!spec.momentum) return false;
    if (motion == InkLabMotion.walking) {
      if (!s.grounded) return false;
      for (final line in s.solidLines) {
        if (_entered.contains(line.id)) continue;
        for (final path in _pathsFor(line)) {
          if (!path.rideable) continue;
          final contact = path.contact(
            V(s.x, s.y),
            ahead: s.walkSpeed * dt + .75,
          );
          if (contact == null || !path.descendsAt(contact.$1)) continue;
          // A downhill stroke drawn across the top of solid paper cannot pull
          // Dot through that paper. Wait until his supporting bank really ends.
          final below = path
              .sample(math.min(path.lengths.last, contact.$1 + 8))
              .$1;
          if (s.level.terrain.any(
            (floor) =>
                floor.tag == 'ground' &&
                floor.contains(below.x) &&
                floor.b.x > below.x + 1e-6 &&
                floor.yAt(below.x) > below.y + .75,
          )) {
            continue;
          }
          _attach(line, path, contact.$1);
          _entered.add(line.id);
          _hopStart = V(s.x, s.y);
          _distance += math.min(12, (_lengths.last - _distance) * .15);
          _hopTarget = _sample(_distance).$1;
          _hopAge = 0;
          speed = s.walkSpeed;
          motion = InkLabMotion.entryHop;
          s.grounded = false;
          s.onNatural = false;
          s.emit('slideHop');
          return _hop(dt);
        }
      }
      return false;
    }
    if (motion == InkLabMotion.entryHop) return _hop(dt);
    if (motion == InkLabMotion.sliding) return _slide(dt);
    if (motion == InkLabMotion.airborne) return _air(dt);
    return _coast(dt);
  }

  void _attach(InkLine rail, _LabRail path, double distance) {
    _rail = rail;
    _path = path;
    _railRevision = rail.geometryRevision;
    _points = path.points;
    _lengths = path.lengths;
    _distance = distance;
  }

  (V, double) _sample(double distance) => _path!.sample(distance);

  void _position(V p) {
    session.walked += p.distance(V(session.x, session.y));
    session.x = p.x;
    session.y = p.y;
  }

  bool _hop(double dt) {
    final s = session;
    if (!_syncRail(contactAt: _hopTarget)) {
      motion = InkLabMotion.airborne;
      return _air(dt);
    }
    _hopAge = math.min(.36, _hopAge + dt);
    final t = _hopAge / .36;
    _position(
      _hopStart +
          (_hopTarget - _hopStart) * t +
          V(0, 12 * math.sin(math.pi * t)),
    );
    vx = (_hopTarget.x - _hopStart.x) / .36;
    s.vy =
        (_hopTarget.y - _hopStart.y) / .36 +
        12 * math.pi / .36 * math.cos(math.pi * t);
    if (t >= 1) {
      speed = math.sqrt(
        s.walkSpeed * s.walkSpeed +
            2 * InkSession._gravity * math.max(0, _hopStart.y - _hopTarget.y),
      );
      motion = InkLabMotion.sliding;
      s.grounded = true;
      s.vy = 0;
      s.emit('slideStart');
    }
    return true;
  }

  bool _slide(double dt) {
    final s = session;
    if (!_syncRail()) {
      final angle = _sample(_distance).$2;
      vx = speed * math.cos(angle);
      s.vy = speed * math.sin(angle);
      motion = InkLabMotion.airborne;
      return _air(dt);
    }
    final before = _sample(_distance), direction = before.$2;
    final acceleration = -InkSession._gravity * math.sin(direction) - 9;
    final nextSpeed = math.max(0.0, speed + acceleration * dt);
    final travel = (speed + nextSpeed) * .5 * dt;
    final nextDistance = math.min(_lengths.last, _distance + travel);
    final after = _sample(nextDistance);
    final wallX = s._paperSideLimit(after.$1.x, after.$1.y);
    if (wallX < after.$1.x - 1e-6) {
      final corner = s._cornerLanding(
        s._nearGround,
        after.$1,
        math.min(0.0, speed * math.sin(after.$2)),
      );
      if (corner != null) {
        vx = speed * math.cos(after.$2);
        s.vy = speed * math.sin(after.$2);
        _landOnCorner(after.$1, corner);
        return true;
      }
      _position(V(wallX, after.$1.y));
      vx = 0;
      s.vy = math.min(0, speed * math.sin(after.$2));
      s.grounded = false;
      motion = InkLabMotion.airborne;
      return true;
    }
    // Work-energy integration preserves speed across polyline corners and
    // cannot manufacture energy from a hand-drawn sawtooth.
    final energy =
        speed * speed -
        2 * InkSession._gravity * (after.$1.y - before.$1.y) -
        18 * (nextDistance - _distance);
    speed = math.sqrt(math.max(0, energy)).clamp(0.0, 240.0);
    final travelled = nextDistance - _distance;
    _dustTravel += travelled;
    while (_dustTravel >= 7) {
      _dustTravel -= 7;
      s.emit('slideDust', _sample(nextDistance - _dustTravel).$1);
    }
    _distance = nextDistance;
    _position(after.$1);
    s.vy = 0;
    s.grounded = true;
    s.onNatural = false;
    if (speed < 2) {
      if (after.$2 <= math.atan(InkSession.maxClimbSlope)) {
        motion = InkLabMotion.walking;
      } else {
        motion = InkLabMotion.airborne;
        vx = 0;
        s.vy = -8;
        s.grounded = false;
      }
    } else if (_distance >= _lengths.last - 1e-6) {
      vx = speed * math.cos(after.$2);
      s.vy = speed * math.sin(after.$2);
      final floor = s._support(s._nearGround, V(s.x + .002, s.y));
      if (floor != null &&
          floor.natural &&
          floor.slope.abs() < .05 &&
          after.$2.abs() < .05) {
        motion = InkLabMotion.coasting;
        s.vy = 0;
      } else {
        motion = InkLabMotion.airborne;
        s.grounded = false;
        s.onNatural = false;
        s.emit('jump');
      }
    }
    return true;
  }

  bool _air(double dt) {
    final s = session, previous = V(session.x, session.y);
    s.grounded = false;
    s.onNatural = false;
    s.vy -= InkSession._gravity * dt;
    final segments = s._nearGround;
    final intended = V(s.x + vx * dt, s.y + s.vy * dt);
    final corner = vx > 0 ? s._cornerLanding(segments, intended, s.vy) : null;
    if (corner != null) {
      _landOnCorner(intended, corner);
      return true;
    }
    var next = V(s._paperSideLimit(intended.x, s.y), intended.y);
    if (next.x < intended.x - 1e-6) vx = 0;
    _GroundSegment? hit;
    var time = double.infinity;
    for (final floor in segments) {
      if (s.vy > 0) {
        final a = previous.y + InkSession.dotHeight - floor.yAt(previous.x);
        final b = next.y + InkSession.dotHeight - floor.yAt(next.x);
        if (a < 0 && b >= 0 && b > a) {
          final xx = previous.x + (next.x - previous.x) * a / (a - b);
          if (floor.contains(xx)) {
            next = V(xx, floor.yAt(xx) - InkSession.dotHeight);
            s.vy = 0;
          }
        }
      }
      final a = previous.y - floor.yAt(previous.x),
          b = next.y - floor.yAt(next.x);
      if (a < -1e-7 || b > 1e-7 || a - b <= 1e-9) continue;
      final t = (a / (a - b)).clamp(0.0, 1.0),
          xx = previous.x + (next.x - previous.x) * (a / (a - b));
      if (!floor.contains(xx) || t < 1e-7 && floor.b.x <= previous.x + 1e-6) {
        continue;
      }
      if (t < time) {
        time = t;
        hit = floor;
      }
    }
    if (hit == null) {
      _position(next);
      return true;
    }
    final xx = previous.x + (next.x - previous.x) * time;
    _position(V(xx, hit.yAt(xx)));
    s.grounded = true;
    s.onNatural = hit.natural;
    final angle = math.atan(hit.slope);
    speed = math.max(0, vx * math.cos(angle) + s.vy * math.sin(angle));
    s.vy = 0;
    s.emit('land');
    for (final line in s.solidLines) {
      if (hit.natural) break;
      for (final path in _pathsFor(line)) {
        if (!path.rideable) continue;
        final contact = path.contact(V(s.x, s.y), ahead: .01);
        if (contact != null &&
            // Reattaching to the line just left would repeat a zero-time landing
            // at its tip until all speed was lost. Choose the continuing rail.
            contact.$1 < path.lengths.last - .001 &&
            contact.$2.distance(V(s.x, s.y)) < .1) {
          _attach(line, path, contact.$1);
          _entered.add(line.id);
          motion = InkLabMotion.sliding;
          s.emit('slideStart');
          return true;
        }
      }
    }
    vx = speed * math.cos(angle);
    motion = InkLabMotion.coasting;
    return true;
  }

  void _landOnCorner(V at, _GroundSegment floor) {
    final s = session, angle = math.atan(floor.slope);
    final projection = math.max(
      0.0,
      vx * math.cos(angle) + s.vy * math.sin(angle),
    );
    final height = floor.yAt(at.x.clamp(floor.a.x, floor.b.x));
    speed = math.sqrt(
      math.max(
        0,
        projection * projection -
            2 * InkSession._gravity * math.max(0, height - at.y),
      ),
    );
    _position(V(at.x, height));
    s.grounded = true;
    s.onNatural = true;
    s.vy = 0;
    vx = speed * math.cos(angle);
    motion = InkLabMotion.coasting;
    s.emit('land', floor.a);
  }

  bool _coast(double dt) {
    final s = session;
    if (speed <= s.walkSpeed) {
      motion = InkLabMotion.walking;
      return false;
    }
    final segments = s._nearGround, at = V(s.x, s.y);
    final centre = s._support(segments, at);
    final foot = centre == null || centre.b.x <= s.x + 1e-7
        ? s._footSupport(segments, at)
        : null;
    final floor = foot?.$1 ?? centre;
    if (floor == null) {
      motion = InkLabMotion.airborne;
      s.grounded = false;
      s.vy = 0;
      return _air(dt);
    }
    final direction = math.atan(floor.slope);
    final travel = math.max(
      0,
      math.min(
        speed * dt / (foot == null ? floor.lengthPerX : 1),
        floor.b.x + (foot == null ? 0 : InkSession._bodyHalfWidth) - s.x,
      ),
    );
    if (travel < 1e-7) {
      motion = InkLabMotion.airborne;
      s.grounded = false;
      s.vy = 0;
      return _air(dt);
    }
    final next = V(
      s.x + travel,
      floor.yAt((s.x + travel).clamp(floor.a.x, floor.b.x)),
    );
    final side = s._paperSideLimit(next.x, s.y);
    if (side < next.x - 1e-7) {
      final corner = s._cornerLanding(segments, next, 0);
      if (corner != null) {
        _landOnCorner(next, corner);
      } else {
        _position(V(side, s.y));
        vx = 0;
        s.vy = 0;
        s.grounded = false;
        motion = InkLabMotion.airborne;
      }
      return true;
    }
    _position(next);
    speed = math.max(
      s.walkSpeed,
      speed + (-InkSession._gravity * math.sin(direction) - 18) * dt,
    );
    vx = speed * math.cos(direction);
    return true;
  }
}
