import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'core/ink_model.dart';
import 'presentation/ink_death.dart';
import 'presentation/ink_motion.dart';
import 'presentation/paper_world.dart';
import 'l10n/ink_strings.dart';

class InkGame extends FlameGame {
  InkGame(
    this.session, {
    this.onFrame,
    this.onEffect,
    this.initialCamera,
    this.holdForLesson,
  });
  final InkSession session;
  final VoidCallback? onFrame;
  final void Function(String)? onEffect;
  final double? initialCamera;
  final bool Function()? holdForLesson;
  InkStrings strings = const InkStrings('en');
  late ui.Image dot, props, garden, openingArt;
  late PaperWorld paperWorld;
  bool sceneReady = false;
  bool _removed = false;
  double cameraX = -96, visualTime = 0, deadAge = 0, _uiTime = 0;
  double _lessonSaveElapsed = 0;
  double _origin = 0;
  double _landAt = -10;
  double _lastWalked = 0, _gaitDistance = 0, _movement = 0, _groundAngle = 0;
  final _animation = InkAnimationBlend();
  V? _lastCorner;
  V _frameStart = const V(0, 0), _catchOffset = const V(0, 0);
  double? _gateAt;
  final Map<String, double> _lineBorn = {};
  final List<InkPickupFlight> _flights = [];
  final List<InkParticle> particles = [];
  Level? _nextLevel;
  List<Surface> _nextTerrain = [];
  final Map<Surface, ui.Picture> _terrainPictures = {};
  Object? _lastUiState;
  int _shownIndex = -1;
  static const double worldWidth = 480,
      worldHeight = 400,
      groundInset = 40,
      baseline = worldHeight - groundInset;
  // Crop the unused sky while keeping enough route visible for a full stroke.
  double get scale => math.min(size.y / worldHeight, size.x / worldWidth);
  double get visibleWidth => size.x / scale;
  double get visibleHeight => size.y / scale;
  double get groundY => visibleHeight - groundInset;
  bool get deathEffectComplete => deadAge >= InkDeathPose.duration;
  V worldPoint(Offset local) =>
      V(local.dx / scale + cameraX, groundY - local.dy / scale);
  Offset point(V p) => Offset(p.x - cameraX, groundY - p.y);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    dot = await images.load('dot_walk.png');
    props = await images.load('props.png');
    garden = await images.load('paper_garden.png');
    final ruins = await images.load('paper_ruins.png');
    openingArt = await images.load('storyboard_opening.png');
    final memories = <PaperMemory>[];
    var levelOrigin = 0.0;
    for (final level in session.levelData) {
      for (final memory in (level['memories'] as List? ?? const [])) {
        memories.add(
          PaperMemory(
            levelOrigin + (memory['x'] as num).toDouble(),
            memory['kind'] == 'letter',
          ),
        );
      }
      levelOrigin += (level['width'] as num).toDouble();
    }
    paperWorld = PaperWorld(garden, ruins, memories);
    await paperWorld.prepare();
    if (_removed) {
      paperWorld.dispose();
      return;
    }
    cameraX = session.ledge != null
        ? session.x - 96
        : initialCamera ?? session.x - 96;
    _origin = session.origin;
    _cacheNext();
    if (session.level.gates.any((g) => g.open)) {
      _gateAt = -1;
    }
    sceneReady = true;
    _resetGait();
    session.onEvent = effect;
    onFrame?.call();
  }

  void resetView() {
    cameraX = session.x - 96;
    _origin = session.origin;
    _shownIndex = -1;
    _gateAt = null;
    _lineBorn.clear();
    _flights.clear();
    visualTime = 0;
    deadAge = 0;
    _resetGait();
    _landAt = -10;
    particles.clear();
    _cacheNext();
  }

  void _resetGait() {
    _lastWalked = session.walked;
    _gaitDistance = session.walked;
    _movement = 0;
    _groundAngle = math.atan(session.groundSlope);
    _animation.reset(
      grounded: session.grounded,
      gripping: session.ledge != null || session.cornerSupport != null,
    );
    _lastCorner = session.ledge?.corner ?? session.cornerSupport;
    _frameStart = V(session.x, session.y);
    _catchOffset = const V(0, 0);
  }

  void _cacheNext() {
    if (_shownIndex == session.levelIndex) {
      return;
    }
    _clearTerrainPictures();
    _shownIndex = session.levelIndex;
    _nextLevel = _shownIndex + 1 < session.levelData.length
        ? Level.from(session.levelData[_shownIndex + 1])
        : null;
    final offset = V(session.level.width, 0);
    _nextTerrain = [
      for (final surface in _nextLevel?.terrain ?? <Surface>[])
        if (surface.id != 'previous-tail' && surface.id != 'next-tail')
          Surface(surface.id, surface.a + offset, surface.b + offset),
    ];
  }

  void _clearTerrainPictures() {
    for (final picture in _terrainPictures.values) {
      picture.dispose();
    }
    _terrainPictures.clear();
  }

  @override
  void onRemove() {
    _removed = true;
    _clearTerrainPictures();
    if (sceneReady) paperWorld.dispose();
    super.onRemove();
  }

  void effect(String name, V at) {
    onEffect?.call(name);
    if (name == 'land') _landAt = visualTime;
    if (name == 'ledgeGrab') {
      _catchOffset = _frameStart + _catchOffset - V(session.x, session.y);
    }
    if (name == 'death') {
      deadAge = 0;
      particles.clear();
      _flights.clear();
    }
    if (name == 'commit' && session.lines.isNotEmpty) {
      _lineBorn[session.lines.last.id] = visualTime;
    }
    if (name == 'pickup') {
      _flights.add(InkPickupFlight(point(at), visualTime));
    }
    if (name == 'gate') {
      _gateAt = visualTime;
    }
    if (name == 'boundary') {
      cameraX -= session.origin - _origin;
      _origin = session.origin;
      _cacheNext();
    }
    if (name == 'pickup' ||
        name == 'commit' ||
        name == 'capture' ||
        name == 'crumb') {
      for (var i = 0; i < 8; i++) {
        final a = i * 2.399;
        particles.add(
          InkParticle(
            at,
            V(math.cos(a) * 16, 18 + math.sin(a) * 12),
            0,
            name == 'pickup',
          ),
        );
      }
    }
    if (name == 'step') {
      particles.add(
        InkParticle(V(session.x - 4, session.y + 1), const V(-3, 0), .7, false),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!sceneReady) {
      return;
    }
    final step = math.max(0.0, dt);
    if (session.phase == Phase.playing) {
      _frameStart = V(session.x, session.y);
      if (holdForLesson?.call() ?? false) {
        // The first lesson holds physics, not the five-second save guarantee.
        _lessonSaveElapsed += step;
        if (_lessonSaveElapsed >= 5) {
          _lessonSaveElapsed = 0;
          session.onSaveRequested?.call(false);
        }
      } else {
        _lessonSaveElapsed = 0;
        session.advance(step);
      }
      final moved = math.max(0.0, session.walked - _lastWalked);
      _lastWalked = session.walked;
      final blend = 1 - math.exp(-14 * step);
      final targetAngle = session.grounded
          ? math.atan(session.groundSlope)
          : 0.0;
      _groundAngle += (targetAngle - _groundAngle) * blend;
      final stride = InkGroundPose.strideForAngle(_groundAngle);
      _gaitDistance += moved / stride;
      final moving = moved > 1e-7 && session.grounded ? 1.0 : 0.0;
      _movement += (moving - _movement) * blend;
      final corner = session.ledge?.corner ?? session.cornerSupport;
      if (corner != null) _lastCorner = corner;
      _animation.advance(
        step,
        grounded: session.grounded,
        gripping: corner != null,
        vy: session.vy,
      );
      _catchOffset = _catchOffset * math.exp(-20 * step);
      visualTime += step;
      cameraX += (session.x - 96 - cameraX) * (1 - math.exp(-10 * step));
      for (final p in particles) {
        p.age += step;
        p.p = p.p + p.velocity * step;
      }
      particles.removeWhere((p) => p.age > 1.2);
      _flights.removeWhere((p) => visualTime - p.started > .7);
    } else if (session.phase == Phase.ready) {
      visualTime += step;
    } else if (session.phase == Phase.dead) {
      deadAge += step;
    }
    _uiTime += step;
    if (_uiTime >= .05) {
      _uiTime = 0;
      final uiState = (
        session.phase,
        session.ink.floor(),
        session.distanceCm.toStringAsFixed(1),
        session.levelProgress,
        session.activeLines,
        session.stuckCountdown,
        session.ledge?.pulls,
        session.firstDrawDone,
        session.x > 60,
        session.realTime < session.messageUntil,
        session.message,
        deathEffectComplete,
      );
      if (uiState != _lastUiState) {
        _lastUiState = uiState;
        onFrame?.call();
      }
    }
  }

  @override
  Color backgroundColor() => const Color(0xfff4efdf);

  @override
  void render(Canvas canvas) {
    if (!sceneReady) {
      return;
    }
    canvas.save();
    canvas.scale(scale);
    canvas.clipRect(Rect.fromLTWH(0, 0, visibleWidth, visibleHeight));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, visibleWidth, visibleHeight),
      Paint()..color = const Color(0xfff5f0e4),
    );
    paperWorld.background(
      canvas,
      cameraX + session.origin,
      width: visibleWidth,
      groundY: groundY,
    );
    _cacheNext();
    // Distant pencil stems; they never act as collision surfaces.
    for (final s in session.level.terrain) {
      if (s.id == 'next-tail') {
        continue;
      }
      if (s.b.x < cameraX - 40 || s.a.x > cameraX + visibleWidth + 40) {
        continue;
      }
      _terrain(canvas, s);
    }
    final next = _nextLevel;
    if (next != null) {
      for (final surface in _nextTerrain) {
        if (surface.a.x > cameraX + visibleWidth + 40) continue;
        if (surface.b.x >= cameraX - 40) _terrain(canvas, surface);
      }
      for (final p in next.pickups) {
        _prop(
          canvas,
          0,
          point(p.p + V(session.level.width, 0)),
          25,
          29,
          bottom: .55,
        );
      }
    }
    for (final s in session.level.anchors) {
      if (s.a.y < 64) {
        continue;
      }
      final a = point(s.a), b = point(s.b);
      canvas.drawLine(
        a + const Offset(0, 3),
        b + const Offset(0, 3),
        Paint()
          ..color = const Color(0xffb4a891)
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = const Color(0xfff0e3c9)
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        a - const Offset(0, 1),
        b - const Offset(0, 1),
        Paint()
          ..color = const Color(0xff5c5549)
          ..strokeWidth = 1,
      );
      canvas.drawLine(
        b,
        b + const Offset(-7, 9),
        Paint()
          ..color = const Color(0xff938774)
          ..strokeWidth = 1,
      );
    }
    for (final b in session.level.balls) {
      _prop(
        canvas,
        2,
        point(b.receiver) + const Offset(0, 8),
        42,
        34,
        bottom: .7,
      );
      final p = b.released ? b.position : b.source;
      _prop(
        canvas,
        1,
        point(p),
        23,
        23,
        bottom: .5,
        rotation: b.distanceOnRail / 8,
      );
      // A short sketched cradle makes the release point legible.
      final q = point(b.source - const V(0, 10));
      canvas.drawArc(
        Rect.fromCenter(center: q - const Offset(0, 2), width: 25, height: 13),
        0,
        math.pi,
        false,
        Paint()
          ..color = const Color(0xff8b7a61)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
    for (final g in session.level.gates) {
      final t = g.open
          ? Curves.easeInOutCubic.transform(
              ((visualTime - (_gateAt ?? visualTime)) / .6)
                  .clamp(0.0, 1.0)
                  .toDouble(),
            )
          : 0.0;
      if (t < 1) {
        _groundProp(canvas, 4, point(V(g.x, 0)), 90, 112, alpha: 1 - t);
      }
      if (t > 0) {
        _groundProp(canvas, 5, point(V(g.x, 0)), 90, 112, alpha: t);
      }
    }
    for (final p in session.level.pickups) {
      if (session.collected.contains(p.id) ||
          (p.p.x - cameraX < -120 || p.p.x - cameraX > visibleWidth + 120)) {
        continue;
      }
      _prop(
        canvas,
        0,
        point(p.p) + Offset(0, -2 * math.sin(visualTime * 2 + p.p.x)),
        25,
        29,
        bottom: .55,
      );
    }
    for (final l in session.lines) {
      final alpha = l.retired
          ? 1 -
                Curves.easeInOutCubic.transform(
                  (session.gameTime - l.retiredAt).clamp(0.0, 1.0).toDouble(),
                )
          : 1.0;
      _line(
        canvas,
        l.points,
        const Color(0xff302c29).withValues(alpha: alpha),
        4.2 *
            (.38 +
                .62 *
                    Curves.easeOutCubic.transform(
                      ((visualTime - (_lineBorn[l.id] ?? -1)) / .18)
                          .clamp(0.0, 1.0)
                          .toDouble(),
                    )),
      );
      _line(
        canvas,
        l.points.map((p) => p + const V(0, .7)).toList(),
        const Color(0xff9c8774).withValues(alpha: alpha * .35),
        .7,
      );
    }
    final draft = session.draft;
    if (draft != null) {
      final (valid, _) = session.validatedDraft();
      final color = valid != null
          ? const Color(0xff544e45)
          : const Color(0xffa67f5b);
      _line(
        canvas,
        valid ?? smoothStroke(draft.points),
        color.withValues(alpha: .6),
        3.0,
      );
      final p = point(draft.points.last);
      canvas.drawCircle(p, 5, Paint()..color = color.withValues(alpha: .14));
      canvas.drawCircle(
        p,
        3,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      _text(
        canvas,
        '${pathLength(valid ?? smoothStroke(draft.points)).ceil()} ${strings.t('Ink')}',
        p + const Offset(8, -28),
        size: 13,
        color: color,
      );
      for (final a in [...session.level.terrain, ...session.level.anchors]) {
        if (a.id == 'previous-tail') {
          continue;
        }
        for (final v in [a.a, a.b]) {
          if (v.x <= draft.start.point.x + 10 ||
              v.x - draft.start.point.x > 220) {
            continue;
          }
          canvas.drawCircle(
            point(v),
            4,
            Paint()
              ..color = const Color(0xff86765a).withValues(alpha: .7)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
      }
    }
    for (final c in session.crumbs) {
      _prop(
        canvas,
        3,
        point(V(c.x, c.y)),
        13,
        13,
        bottom: .5,
        rotation: c.seed + visualTime,
      );
    }
    for (final p in particles) {
      canvas.drawCircle(
        point(p.p),
        p.gold ? 2 : 1.2,
        Paint()
          ..color = (p.gold ? const Color(0xffac8a45) : const Color(0xff4c4235))
              .withValues(
                alpha: (1 - p.age / 1.2).clamp(0.0, 1.0).toDouble() * .6,
              ),
      );
    }
    for (final flight in _flights) {
      final t = ((visualTime - flight.started) / .7).clamp(0.0, 1.0).toDouble();
      final k = Curves.easeInOutCubic.transform(t),
          a = flight.screen,
          b = const Offset(40, 48);
      final center = Offset(
        a.dx + (b.dx - a.dx) * k,
        a.dy + (b.dy - a.dy) * k - 45 * math.sin(math.pi * k),
      );
      _prop(
        canvas,
        0,
        center,
        23 - 11 * k,
        27 - 13 * k,
        bottom: .5,
        alpha: 1 - t * .6,
      );
    }
    _firstDrawHint(canvas);
    _dot(canvas);
    paperWorld.foreground(
      canvas,
      cameraX + session.origin,
      width: visibleWidth,
      groundY: groundY,
    );
    if (session.phase == Phase.resumeStroke && draft != null) {
      final q = point(draft.points.last);
      canvas.drawCircle(
        q,
        16,
        Paint()
          ..color = const Color(0xff89754f)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
    canvas.restore();
    super.render(canvas);
  }

  void _terrain(Canvas c, Surface s) {
    if (s.a.y > 64) return;
    final picture = _terrainPictures.putIfAbsent(s, () {
      final recorder = ui.PictureRecorder();
      _recordTerrain(Canvas(recorder), s);
      return recorder.endRecording();
    });
    c.save();
    c.translate(-cameraX, groundY);
    c.drawPicture(picture);
    c.restore();
    // Deterministic botanical details sit on the same natural surface.
    if (s.b.x - s.a.x > 100) {
      final base = s.a.x + 65;
      for (var xx = base; xx < s.b.x - 32; xx += 237) {
        if (xx - cameraX < -80 || xx - cameraX > visibleWidth + 80) {
          continue;
        }
        _groundProp(c, 6, point(V(xx, s.yAt(xx))), 65, 63);
      }
    }
  }

  void _recordTerrain(Canvas c, Surface s) {
    final a = Offset(s.a.x, -s.a.y), b = Offset(s.b.x, -s.b.y);
    final elevated = s.a.y > 64;
    if (elevated) {
      return;
    }
    final p = Path()..moveTo(a.dx, a.dy);
    final count = math.max(2, ((b.dx - a.dx) / 7).ceil());
    for (var i = 0; i <= count; i++) {
      final t = i / count, x = a.dx + (b.dx - a.dx) * t;
      final noise = math.sin(x * 1.7) * .6 + math.sin(x * .41) * .55;
      p.lineTo(x, a.dy + (b.dy - a.dy) * t + noise);
    }
    // A torn vertical edge and a folded underside, rather than rectangular blocks.
    p.lineTo(b.dx + 1, b.dy + 22);
    p.lineTo(b.dx - 3, b.dy + 45);
    p.lineTo(b.dx + 2, groundInset + 24);
    p.lineTo(a.dx - 2, groundInset + 24);
    p.lineTo(a.dx + 2, a.dy + 36);
    p.close();
    c.drawPath(
      p.shift(const Offset(2, 4)),
      Paint()
        ..color = const Color(0x153c3020)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    c.drawPath(p, Paint()..color = const Color(0xffe6dbc4));
    c.save();
    c.clipPath(p);
    c.drawRect(
      Rect.fromLTRB(a.dx - 2, math.min(a.dy, b.dy), b.dx + 2, groundInset + 24),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, math.min(a.dy, b.dy)),
          Offset(0, math.min(a.dy, b.dy) + 170),
          [const Color(0xfff6eddc), const Color(0xffe9dfca)],
        ),
    );
    for (var i = (s.a.x / 13).floor(); i < s.b.x / 13; i++) {
      final xx = i * 13.0, yy = -s.yAt(i * 13.0);
      c.drawLine(
        Offset(xx, yy + 5),
        Offset(xx - 3, yy + 11 + i % 7),
        Paint()
          ..color = const Color(0x2283775e)
          ..strokeWidth = .6,
      );
    }
    c.restore();
    final edge = Path()..moveTo(a.dx, a.dy);
    for (var i = 1; i <= count; i++) {
      final t = i / count, xx = a.dx + (b.dx - a.dx) * t;
      edge.lineTo(xx, a.dy + (b.dy - a.dy) * t + math.sin(xx * 1.7) * .6);
    }
    c.drawPath(
      edge,
      Paint()
        ..color = const Color(0xff696052)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25,
    );
  }

  void _line(Canvas c, List<V> points, Color color, double width) {
    if (points.length < 2) {
      return;
    }
    final path = Path()..moveTo(point(points.first).dx, point(points.first).dy);
    for (final v in points.skip(1)) {
      final q = point(v);
      path.lineTo(q.dx, q.dy);
    }
    c.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _firstDrawHint(Canvas c) {
    if (session.firstDrawDone ||
        session.phase != Phase.playing ||
        session.draft != null) {
      return;
    }
    final terrain =
        session.level.terrain
            .where((s) => s.a.y.abs() < .01 && s.b.y.abs() < .01)
            .toList()
          ..sort((a, b) => a.a.x.compareTo(b.a.x));
    for (var i = 1; i < terrain.length; i++) {
      final left = terrain[i - 1].b, right = terrain[i].a;
      if (right.x - left.x < 20 || left.x < session.x - 12) {
        continue;
      }
      final a = point(left), b = point(right);
      final radius = 7 + 1.1 * math.sin(visualTime * 2.5);
      for (final q in [a, b]) {
        c.drawCircle(
          q,
          radius,
          Paint()
            ..color = const Color(0xaa85704e)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        c.drawCircle(q, 2.3, Paint()..color = const Color(0xff6e5c40));
      }
      if (a.dx > 12 && a.dx < 470) {
        _text(c, 'buradan çiz', a + const Offset(-29, -34), size: 11);
      }
      if (b.dx > 12 && b.dx < 458) {
        _text(c, 'burada bırak', b + const Offset(-25, 18), size: 11);
      }
      break;
    }
  }

  // The front arm is taken from the existing atlas, including its ink texture.
  // The diagonal cut follows the body's outline, leaving the face untouched.
  static final Path _frontArmMask = (() {
    Offset p(double x, double y) =>
        Offset(-27 + x * 54 / 443.5, -47.52 + y * 54 / 443.5);
    final points = [
      p(324, 282),
      p(338, 274),
      p(365, 274),
      p(365, 320),
      p(313, 320),
      p(307, 308),
    ];
    return Path()..addPolygon(points, true);
  })();

  void _dot(Canvas c) {
    final dead = session.phase == Phase.dead;
    final position = point(V(session.x, session.y) + _catchOffset);
    // Falling deaths finish below the viewport. Keep the last ink splash at
    // its edge so that the effect remains visible before the retry menu.
    final q = dead
        ? Offset(
            position.dx.clamp(32, visibleWidth - 32).toDouble(),
            position.dy.clamp(65, visibleHeight - 24).toDouble(),
          )
        : position;
    final death = InkDeathPose(deadAge);
    if (dead && death.bodyOpacity == 0) {
      _deathInk(c, q, death);
      return;
    }
    final walking =
        (session.phase == Phase.playing || dead) && session.grounded;
    final grip = session.ledge;
    final corner =
        grip?.corner ??
        session.cornerSupport ??
        (_animation.grip > .001 ? _lastCorner : null);
    final edging = session.cornerSupport != null;
    final rise = grip == null
        ? 1.0
        : (1 + (session.y - grip.corner.y) / LedgeGrip.hangDepth).clamp(
            0.0,
            1.0,
          );
    var pose = InkWalkPose.sample(
      _gaitDistance,
      grounded: session.grounded,
      walking: walking,
      time: visualTime,
      movement: _movement,
    );
    final sampleGround = session.groundSampler();
    var feet = InkGroundPose.place(
      pose,
      grounded: session.grounded,
      angle: _groundAngle,
      stride: InkGroundPose.strideForAngle(_groundAngle),
      sampleGround: (distance) {
        final at = sampleGround(distance);
        return at == null ? null : (at.x - session.x, at.y - session.y);
      },
    );
    final airPose = InkWalkPose.sample(
      _gaitDistance,
      grounded: false,
      walking: false,
    );
    final airFeet = InkGroundPose.place(
      airPose,
      grounded: false,
      angle: 0,
      stride: 1,
      sampleGround: (_) => null,
    );
    if (session.grounded) {
      pose = InkWalkPose.mix(airPose, pose, _animation.support);
      feet = InkGroundPose.mix(airFeet, feet, _animation.support);
    } else {
      final standing = InkWalkPose.sample(
        _gaitDistance,
        grounded: true,
        walking: false,
        time: visualTime,
      );
      final standingFeet = InkGroundPose.place(
        standing,
        grounded: false,
        angle: 0,
        stride: 1,
        sampleGround: (_) => null,
      );
      pose = InkWalkPose.mix(airPose, standing, _animation.support);
      feet = InkGroundPose.mix(airFeet, standingFeet, _animation.support);
    }
    if (corner != null) {
      final plant = edging ? 1.0 : ((rise - .25) / .35).clamp(0.0, 1.0);
      final climbingPose = InkWalkPose(
        const InkFootPose(-4, 2, false),
        InkFootPose(6, 1, plant >= 1),
        0,
        1,
        1,
        0,
      );
      final climbingFeet = InkGroundPose(
        const InkFootPlacement(-4, -2, 0),
        InkFootPlacement(
          6 + (corner.x - session.x + 2 - 6) * plant,
          -1 + (session.y - corner.y + 1) * plant,
          0,
        ),
        0,
      );
      pose = InkWalkPose.mix(pose, climbingPose, _animation.grip);
      feet = InkGroundPose.mix(feet, climbingFeet, _animation.grip);
    }
    final sw = dot.width / 4, sh = dot.height / 2;
    final src = Rect.fromLTWH(0, 0, sw, sh);
    if (dead) {
      c.saveLayer(
        Rect.fromCenter(
          center: q - const Offset(0, 25),
          width: 90,
          height: 100,
        ),
        Paint()..color = Color.fromRGBO(255, 255, 255, death.bodyOpacity),
      );
      c.translate(0, -death.bodyLift);
    }
    if (corner == null) {
      c.drawOval(
        Rect.fromCenter(
          center: q + const Offset(0, 2),
          width: 26 - pose.rise,
          height: 4.2,
        ),
        Paint()
          ..color = const Color(0x28352d23)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    c.save();
    c.translate(q.dx, q.dy);
    final landing = ((visualTime - _landAt) / .28).clamp(0.0, 1.0);
    final impact = math.sin(landing * math.pi) * .035;
    final falling = _animation.fall;
    final free = 1 - _animation.grip;
    final rig = InkBodyRig(
      pose.rise + feet.bodyLift,
      (pose.lean + _groundAngle * .12 * _animation.support) * free,
      pose.width + (impact - falling * .025) * free,
      pose.height + (-impact + falling * .045) * free,
    );
    {
      final swing =
          math.sin(_gaitDistance / 40 * 2 * math.pi) *
          1.2 *
          _movement *
          _animation.support;
      var hand = Offset(
        InkLedgeArmPose.palmX + swing,
        InkLedgeArmPose.palmY - falling * 3,
      );
      if (corner != null) {
        final actual = point(corner) - q;
        final local = rig.inverse(actual.dx, actual.dy);
        final destination = InkLedgeArmPose(local.$1, local.$2, rise);
        final palm = destination.transform(
          InkLedgeArmPose.palmX,
          InkLedgeArmPose.palmY,
        );
        hand = Offset.lerp(hand, Offset(palm.$1, palm.$2), _animation.grip)!;
      }
      final arm = InkLedgeArmPose(hand.dx, hand.dy, 0);
      c.save();
      c.translate(0, -rig.raise);
      c.rotate(rig.angle);
      c.scale(rig.scaleX, rig.scaleY);
      c.translate(InkLedgeArmPose.shoulderX, InkLedgeArmPose.shoulderY);
      c.rotate(arm.angle);
      c.scale(arm.lengthScale, 1);
      c.rotate(-InkLedgeArmPose.baseAngle);
      c.translate(-InkLedgeArmPose.shoulderX, -InkLedgeArmPose.shoulderY);
      c.clipPath(_frontArmMask);
      c.drawImageRect(
        dot,
        src,
        const Rect.fromLTWH(-27, -47.52, 54, 54),
        Paint()..filterQuality = FilterQuality.medium,
      );
      c.restore();
    }
    void foot(
      InkFootPose p,
      InkFootPlacement placement,
      double hip,
      bool front,
    ) {
      final x = placement.x, y = placement.y;
      final joint = rig.point(hip, -9);
      final curve = InkLegCurve(joint, (x, y - 1.2));
      final path = Path()..moveTo(joint.$1, joint.$2);
      if (corner != null && front && placement.x > 10) {
        // Tuck the knee below the hip while the existing front foot steps onto
        // the rim; a straight diagonal would look like another drawn line.
        path.quadraticBezierTo(
          joint.$1 + 2,
          math.max(joint.$2 + 6, curve.ankle.$2 + 3),
          curve.ankle.$1,
          curve.ankle.$2,
        );
      } else {
        path.cubicTo(
          curve.first.$1,
          curve.first.$2,
          curve.second.$1,
          curve.second.$2,
          curve.ankle.$1,
          curve.ankle.$2,
        );
      }
      c.drawPath(
        path,
        Paint()
          ..color = front ? const Color(0xff25221f) : const Color(0xff363029)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.7 - .9 * _animation.grip
          ..strokeCap = StrokeCap.round,
      );
      c.save();
      c.translate(x, y);
      c.rotate(placement.angle);
      c.drawOval(
        Rect.fromCenter(
          center: const Offset(1.6, -1),
          width:
              (p.planted ? 8.5 : 7.2) -
              (p.planted ? 1.3 : .8) * _animation.grip,
          height: 3.1 - .5 * _animation.grip,
        ),
        Paint()..color = const Color(0xff27231f),
      );
      c.drawLine(
        const Offset(-1, -2),
        const Offset(2.3, -2.1),
        Paint()
          ..color = const Color(0x886b6256)
          ..strokeWidth = .55
          ..strokeCap = StrokeCap.round,
      );
      c.restore();
    }

    foot(pose.back, feet.back, -5, false);
    foot(pose.front, feet.front, 5, true);
    c.save();
    c.translate(0, -rig.raise);
    c.rotate(rig.angle);
    c.scale(rig.scaleX, rig.scaleY);
    // Keep one detailed body identity and animate the feet separately; no pose popping.
    c.clipRect(const Rect.fromLTRB(-35, -60, 35, -7));
    {
      final bodyMask = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(const Rect.fromLTRB(-35, -60, 35, -7))
        ..addPath(_frontArmMask, Offset.zero);
      c.clipPath(bodyMask);
    }
    c.drawImageRect(
      dot,
      src,
      const Rect.fromLTWH(-27, -47.52, 54, 54),
      Paint()..filterQuality = FilterQuality.medium,
    );
    // Eyelids close briefly on a deterministic, pause-safe rhythm.
    final blinkTime = visualTime % 4.7;
    final blink = blinkTime < .16 ? math.sin(blinkTime / .16 * math.pi) : 0.0;
    if (blink > .05) {
      for (final eye in [
        const Rect.fromLTWH(-.9, -24.6, 6.9, 10.6),
        const Rect.fromLTWH(9.1, -25.0, 4.5, 9.3),
      ]) {
        c.drawOval(
          Rect.fromLTWH(eye.left, eye.top, eye.width, eye.height * blink),
          Paint()..color = const Color(0xff292723),
        );
      }
    }
    c.restore();
    c.restore();
    if (dead) {
      c.restore();
      _deathInk(c, q, death);
    }
  }

  void _deathInk(Canvas c, Offset at, InkDeathPose pose) {
    if (deadAge >= InkDeathPose.duration) return;
    c.save();
    c.translate(at.dx, at.dy);
    if (session.grounded) {
      final stain = Path()
        ..moveTo(-17, 1)
        ..cubicTo(-15, -2, -5, -3, 1, -1)
        ..cubicTo(10, -3, 21, 0, 17, 3)
        ..cubicTo(12, 6, -6, 4, -17, 1)
        ..close();
      c.drawPath(
        stain,
        Paint()
          ..color = const Color(
            0xff38312a,
          ).withValues(alpha: pose.stainOpacity),
      );
    }
    c.drawOval(
      Rect.fromCenter(
        center: const Offset(0, -22),
        width: pose.rippleRadius * 2,
        height: pose.rippleRadius * 1.5,
      ),
      Paint()
        ..color = const Color(0xff827563).withValues(alpha: pose.rippleOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
    for (final drop in pose.drops) {
      c.save();
      c.translate(drop.x, drop.y);
      c.rotate(drop.angle);
      final shape = Rect.fromCenter(
        center: Offset.zero,
        width: drop.radius * drop.stretch * 2,
        height: drop.radius * 1.5,
      );
      c.drawOval(
        shape,
        Paint()
          ..color = const Color(0xff302b26).withValues(alpha: drop.opacity),
      );
      c.drawOval(
        Rect.fromLTWH(
          shape.left + drop.radius * .4,
          shape.top + .3,
          drop.radius,
          drop.radius * .35,
        ),
        Paint()
          ..color = const Color(
            0xffa9987b,
          ).withValues(alpha: drop.opacity * .28),
      );
      c.restore();
    }
    c.restore();
  }

  void _groundProp(
    Canvas c,
    int index,
    Offset ground,
    double w,
    double h, {
    double alpha = 1,
  }) {
    // Visible feet within each atlas cell, excluding transparent bottom padding.
    final foot = switch (index) {
      4 => 372.5,
      5 => 374.5,
      6 => 373.5,
      _ => throw ArgumentError.value(index, 'index', 'Not a grounded prop'),
    };
    _prop(
      c,
      index,
      ground + const Offset(0, 1),
      w,
      h,
      bottom: foot / (props.height / 2),
      alpha: alpha,
    );
  }

  void _prop(
    Canvas c,
    int index,
    Offset p,
    double w,
    double h, {
    double bottom = .9,
    double rotation = 0,
    double alpha = 1,
  }) {
    if (p.dx < -120 || p.dx > visibleWidth + 120) {
      return;
    }
    final sw = props.width / 4, sh = props.height / 2;
    final src = Rect.fromLTWH((index % 4) * sw, (index ~/ 4) * sh, sw, sh);
    c.save();
    c.translate(p.dx, p.dy);
    if (rotation != 0) {
      c.rotate(rotation);
    }
    c.drawImageRect(
      props,
      src,
      Rect.fromLTWH(-w / 2, -h * bottom, w, h),
      Paint()
        ..color = Color.fromRGBO(255, 255, 255, alpha)
        ..filterQuality = FilterQuality.medium,
    );
    c.restore();
  }

  void _text(
    Canvas c,
    String value,
    Offset p, {
    double size = 14,
    Color color = const Color(0xff5d5143),
  }) {
    final text = TextPainter(
      text: TextSpan(
        text: strings.t(value),
        style: TextStyle(
          fontFamily: 'Nunito',
          fontFamilyFallback: strings.fonts,
          fontSize: size,
          color: color,
        ),
      ),
      textDirection: strings.code == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
    )..layout();
    text.paint(c, p);
    text.dispose();
  }
}

class InkParticle {
  InkParticle(this.p, this.velocity, this.age, this.gold);
  V p;
  final V velocity;
  double age;
  final bool gold;
}

class InkPickupFlight {
  InkPickupFlight(this.screen, this.started);
  final Offset screen;
  final double started;
}
