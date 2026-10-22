import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'core/ink_model.dart';
import 'presentation/ink_death.dart';
import 'presentation/ink_motion.dart';
import 'presentation/paper_world.dart';

class InkGame extends FlameGame {
  InkGame(this.session, {this.onFrame, this.onEffect, this.initialCamera});
  final InkSession session;
  final VoidCallback? onFrame;
  final void Function(String)? onEffect;
  final double? initialCamera;
  late ui.Image dot, props, garden, openingArt;
  late PaperWorld paperWorld;
  bool sceneReady = false;
  double cameraX = -96, visualTime = 0, deadAge = 0, _uiTime = 0;
  double _origin = 0;
  double _landAt = -10;
  double? _gateAt;
  final Map<String, double> _lineBorn = {};
  final List<InkPickupFlight> _flights = [];
  final List<InkParticle> particles = [];
  Level? _nextLevel;
  int _shownIndex = -1;
  static const double worldWidth = 480, worldHeight = 853.333, baseline = 588;
  double get scale => size.y / worldHeight;
  double get visibleWidth => size.x / scale;
  bool get deathEffectComplete => deadAge >= InkDeathPose.duration;
  V worldPoint(Offset local) =>
      V(local.dx / scale + cameraX, baseline - local.dy / scale);
  Offset point(V p) => Offset(p.x - cameraX, baseline - p.y);

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
    cameraX = initialCamera ?? session.x - 96;
    _origin = session.origin;
    _cacheNext();
    if (session.level.gates.any((g) => g.open)) {
      _gateAt = -1;
    }
    sceneReady = true;
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
    _landAt = -10;
    particles.clear();
    _cacheNext();
  }

  void _cacheNext() {
    if (_shownIndex == session.levelIndex) {
      return;
    }
    _shownIndex = session.levelIndex;
    _nextLevel = _shownIndex + 1 < session.levelData.length
        ? Level.from(session.levelData[_shownIndex + 1])
        : null;
  }

  void effect(String name, V at) {
    onEffect?.call(name);
    if (name == 'land') _landAt = visualTime;
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
      session.advance(step);
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
      onFrame?.call();
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
    canvas.clipRect(Rect.fromLTWH(0, 0, visibleWidth, worldHeight));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, visibleWidth, worldHeight),
      Paint()..color = const Color(0xfff5f0e4),
    );
    paperWorld.background(canvas, cameraX + session.origin, width: visibleWidth, groundY: baseline);
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
      for (final t in next.terrain) {
        if (t.id == 'previous-tail' || t.id == 'next-tail') {
          continue;
        }
        final offset = V(session.level.width, 0);
        if (t.a.x + offset.x > cameraX + visibleWidth + 40) {
          break;
        }
        if (t.b.x + offset.x >= cameraX) {
          _terrain(canvas, Surface(t.id, t.a + offset, t.b + offset));
        }
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
        _prop(canvas, 4, point(V(g.x, 0)), 90, 112, bottom: .94, alpha: 1 - t);
      }
      if (t > 0) {
        _prop(canvas, 5, point(V(g.x, 0)), 90, 112, bottom: .94, alpha: t);
      }
    }
    for (final p in session.level.pickups) {
      if (session.collected.contains(p.id) || (p.p.x - cameraX < -120 || p.p.x - cameraX > visibleWidth + 120)) {
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
        '${pathLength(valid ?? smoothStroke(draft.points)).ceil()} Ink',
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
    paperWorld.foreground(canvas, cameraX + session.origin, width: visibleWidth);
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
    final a = point(s.a), b = point(s.b);
    final elevated = s.a.y > 64;
    if (elevated) {
      return;
    }
    final p = Path()..moveTo(a.dx, a.dy);
    final count = math.max(2, ((b.dx - a.dx) / 7).ceil());
    for (var i = 0; i <= count; i++) {
      final t = i / count, x = a.dx + (b.dx - a.dx) * t;
      final noise =
          math.sin((x + cameraX) * 1.7) * .6 +
          math.sin((x + cameraX) * .41) * .55;
      p.lineTo(x, a.dy + (b.dy - a.dy) * t + noise);
    }
    // A torn vertical edge and a folded underside, rather than rectangular blocks.
    p.lineTo(b.dx + 1, b.dy + 22);
    p.lineTo(b.dx - 3, b.dy + 45);
    p.lineTo(b.dx + 2, 880);
    p.lineTo(a.dx - 2, 880);
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
      Rect.fromLTRB(a.dx - 2, math.min(a.dy, b.dy), b.dx + 2, 880),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, math.min(a.dy, b.dy)),
          Offset(0, math.min(a.dy, b.dy) + 170),
          [const Color(0xfff6eddc), const Color(0xffe9dfca)],
        ),
    );
    for (var i = (s.a.x / 13).floor(); i < s.b.x / 13; i++) {
      final xx = i * 13.0 - cameraX, yy = baseline - s.yAt(i * 13.0);
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
      edge.lineTo(
        xx,
        a.dy + (b.dy - a.dy) * t + math.sin((xx + cameraX) * 1.7) * .6,
      );
    }
    c.drawPath(
      edge,
      Paint()
        ..color = const Color(0xff696052)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25,
    );
    // Deterministic botanical details sit on the same natural surface.
    if (s.b.x - s.a.x > 100) {
      final base = s.a.x + 65;
      for (var xx = base; xx < s.b.x - 32; xx += 237) {
        if (xx - cameraX < -80 || xx - cameraX > visibleWidth + 80) {
          continue;
        }
        _prop(c, 6, point(V(xx, s.yAt(xx))), 65, 63, bottom: .94);
      }
    }
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

  void _dot(Canvas c) {
    final dead = session.phase == Phase.dead;
    final position = point(V(session.x, session.y));
    // Falling deaths finish below the viewport. Keep the last ink splash at
    // its edge so that the effect remains visible before the retry menu.
    final q = dead
        ? Offset(
            position.dx.clamp(32, visibleWidth - 32).toDouble(),
            position.dy.clamp(65, worldHeight - 24).toDouble(),
          )
        : position;
    final death = InkDeathPose(deadAge);
    if (dead && death.bodyOpacity == 0) {
      _deathInk(c, q, death);
      return;
    }
    final walking =
        (session.phase == Phase.playing || dead) && session.grounded;
    var floorSlope = 0.0;
    if (session.grounded) {
      for (final surface in session.level.terrain) {
        if (surface.contains(session.x) &&
            (surface.yAt(session.x) - session.y).abs() < 1.5) {
          floorSlope = surface.slope;
        }
      }
      for (final line in session.solidLines) {
        final y = line.yAt(session.x);
        if (y != null && (y - session.y).abs() < 1.5) {
          floorSlope = line.slopeAt(session.x);
        }
      }
    }
    // A tiny near-vertical step is climbable, but its tangent must not stretch
    // the walking legs across the screen while Dot steps up it.
    floorSlope = floorSlope
        .clamp(-InkSession.maxClimbSlope, InkSession.maxClimbSlope)
        .toDouble();
    final pose = InkWalkPose.sample(
      session.walked,
      grounded: session.grounded,
      walking: walking,
      time: visualTime,
    );
    final sw = dot.width / 4, sh = dot.height / 2;
    final src = Rect.fromLTWH(0, 0, sw, sh);
    if (dead) {
      c.saveLayer(
        Rect.fromCenter(center: q - const Offset(0, 25), width: 90, height: 100),
        Paint()..color = Color.fromRGBO(255, 255, 255, death.bodyOpacity),
      );
      c.translate(0, -death.bodyLift);
    }
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
    c.save();
    c.translate(q.dx, q.dy);
    void foot(InkFootPose p, double hip, bool front) {
      final x = p.x + hip * .18;
      final y = -p.lift - x * floorSlope;
      final path = Path()
        ..moveTo(hip, -9 - pose.rise * .45)
        ..cubicTo(hip - 1, -4.8, x - 2, y - 4, x, y - 1.2);
      c.drawPath(
        path,
        Paint()
          ..color = front ? const Color(0xff25221f) : const Color(0xff363029)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.7
          ..strokeCap = StrokeCap.round,
      );
      c.drawOval(
        Rect.fromCenter(
          center: Offset(x + 1.6, y - 1),
          width: p.planted ? 8.5 : 7.2,
          height: 3.1,
        ),
        Paint()..color = const Color(0xff27231f),
      );
      c.drawLine(
        Offset(x - 1, y - 2),
        Offset(x + 2.3, y - 2.1),
        Paint()
          ..color = const Color(0x886b6256)
          ..strokeWidth = .55
          ..strokeCap = StrokeCap.round,
      );
    }

    foot(pose.back, -5, false);
    c.save();
    c.translate(0, -pose.rise);
    c.rotate(pose.lean);
    final landing = ((visualTime - _landAt) / .28).clamp(0.0, 1.0);
    final impact = math.sin(landing * math.pi) * .10;
    final falling = session.grounded
        ? 0.0
        : (-session.vy / 250).clamp(0.0, 1.0);
    c.scale(
      pose.width + impact - falling * .05,
      pose.height - impact + falling * .10,
    );
    // Keep one detailed body identity and animate the feet separately; no pose popping.
    c.clipRect(const Rect.fromLTRB(-35, -60, 35, -7));
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
    foot(pose.front, 5, true);
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
        Paint()..color = const Color(0xff38312a).withValues(alpha: pose.stainOpacity),
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
        Paint()..color = const Color(0xff302b26).withValues(alpha: drop.opacity),
      );
      c.drawOval(
        Rect.fromLTWH(shape.left + drop.radius * .4, shape.top + .3,
            drop.radius, drop.radius * .35),
        Paint()..color = const Color(0xffa9987b).withValues(alpha: drop.opacity * .28),
      );
      c.restore();
    }
    c.restore();
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
        text: value,
        style: TextStyle(fontFamily: 'Nunito', fontSize: size, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(c, p);
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
