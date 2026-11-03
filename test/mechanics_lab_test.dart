import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';

void drawLab(InkSession s, List<V> points, {bool reverse = false}) {
  final p = reverse ? points.reversed.toList() : points;
  expect(s.beginStroke(p.first), isTrue, reason: 'start ${p.first.toJson()}');
  for (var i = 1; i < p.length; i++) {
    for (var j = 1; j <= 20; j++) {
      s.moveStroke(p[i - 1] + (p[i] - p[i - 1]) * (j / 20));
    }
  }
  expect(s.endStroke(), isTrue, reason: s.message);
}

final _planCursor = Expando<int>();
void drawPendingPlan(InkSession s) {
  final lab = s.mechanics!;
  if (lab.spec.family == null) return;
  var next = _planCursor[s] ?? 0;
  while (next < lab.tasks.length && lab.tasks[next].ready(s)) {
    drawLab(s, lab.tasks[next].points);
    _planCursor[s] = ++next;
  }
}

void prepareLab(InkSession s, {int route = 0}) {
  final lab = s.mechanics!;
  if (lab.spec.family != null) {
    drawPendingPlan(s);
    lab.holdDot = false;
    return;
  }
  if (lab.spec.id == 'eraser') s.advance(5.5);
  for (final p in lab.guides[route].take(lab.spec.id == 'landing' ? 1 : 10)) {
    drawLab(s, p);
  }
  lab.holdDot = false;
}

void runLab(InkSession s, {int fps = 120}) {
  for (var i = 0; i < fps * 25 && s.phase == Phase.playing; i++) {
    drawPendingPlan(s);
    s.advance(1 / fps);
    if (s.mechanics!.spec.id == 'landing' &&
        s.collected.contains('landing-ink') &&
        s.lines.length == 1) {
      drawLab(s, s.mechanics!.guides.first[1]);
    }
    expect(s.x.isFinite && s.y.isFinite && s.vy.isFinite, isTrue);
    expect(s.activeLines, lessThanOrEqualTo(2));
    expect(s.ledge, isNull);
  }
}

void main() {
  for (final spec in InkLabCase.all) {
    for (final fps in [30, 60, 120]) {
      test(
        '${spec.id}: real drawing input completes the course at $fps FPS',
        () {
          final s = spec.createSession()..start();
          prepareLab(s);
          runLab(s, fps: fps);
          expect(
            s.phase,
            Phase.complete,
            reason: '${s.x}, ${s.y}: ${s.message}',
          );
        },
      );
    }
  }
  test(
    'The upper alternative is a complete second solution with normal ink cost',
    () {
      final s = InkLabCase.byId('routes').createSession()..start();
      prepareLab(s, route: 1);
      runLab(s);
      expect(s.phase, Phase.complete);
      expect(s.collected, contains('upper-ink'));
    },
  );
  test(
    'The entry hop rises first; descent accelerates and the ramp trades speed for height',
    () {
      final s = InkLabCase.byId('ramp').createSession()..start();
      prepareLab(s);
      final events = <String>[];
      s.onEvent = (name, _) => events.add(name);
      var peakSpeed = 0.0, hopApex = 0.0, uphillSpeed = double.infinity;
      while (s.phase == Phase.playing &&
          s.mechanics!.motion != InkLabMotion.airborne) {
        s.advance(1 / 120);
        final m = s.mechanics!;
        if (m.motion == InkLabMotion.entryHop) hopApex = math.max(hopApex, s.y);
        if (m.sliding) {
          peakSpeed = math.max(peakSpeed, m.speed);
          if (m.railAngle > .3) uphillSpeed = m.speed;
        }
      }
      expect(hopApex, greaterThan(3));
      expect(peakSpeed, greaterThan(150));
      expect(uphillSpeed, lessThan(peakSpeed));
      expect(s.vy, greaterThan(50));
      expect(events.where((e) => e == 'slideHop').length, 1);
      expect(events.where((e) => e == 'slideStart').length, 1);
      expect(events, contains('jump'));
      runLab(s);
      expect(s.phase, Phase.complete);
    },
  );
  test(
    'Reverse drawing is physically equivalent; gravity and friction bound energy',
    () {
      final a = InkLabCase.byId('ramp').createSession()..start();
      final b = InkLabCase.byId('ramp').createSession()..start();
      drawLab(a, a.mechanics!.guides.first.first);
      // Add a tiny natural endpoint for the reverse-drawn free tip.
      // The contour itself is identical; this isolates drawing direction.
      b.level.anchors.add(
        Surface('tip', const V(266, -42), const V(266.001, -42)),
      );
      drawLab(b, b.mechanics!.guides.first.first, reverse: true);
      a.mechanics!.holdDot = b.mechanics!.holdDot = false;
      for (var i = 0; i < 500; i++) {
        a.advance(1 / 120);
        b.advance(1 / 120);
        expect(a.x, closeTo(b.x, .8));
        expect(a.y, closeTo(b.y, .8));
        expect(
          a.mechanics!.speed,
          lessThanOrEqualTo(math.sqrt(56 * 56 + 2 * 160 * 90) + 1),
        );
      }
    },
  );
  test(
    'A shallow descent cannot enter the slide; pause freezes hop, coast and scenery',
    () {
      final shallow = InkLabCase.byId('slide').createSession()..start();
      drawLab(shallow, [const V(130, 0), const V(220, -50)]);
      shallow.mechanics!.holdDot = false;
      shallow.advance(3);
      expect(shallow.mechanics!.motion, InkLabMotion.walking);
      for (final id in ['ramp', 'pulley', 'eraser']) {
        final s = InkLabCase.byId(id).createSession()..start();
        if (id == 'ramp') {
          prepareLab(s);
          s.advance(2.4);
        } else {
          s.advance(.5);
        }
        final p = V(s.x, s.y),
            time = s.gameTime,
            angle = s.mechanics!.pulleyAngle,
            speed = s.mechanics!.speed;
        s.pause();
        s.advance(10);
        expect(V(s.x, s.y).distance(p), 0);
        expect(s.gameTime, time);
        expect(s.mechanics!.pulleyAngle, angle);
        expect(s.mechanics!.speed, speed);
      }
    },
  );
  test(
    'An erased rail releases Dot and retry resets all experimental state',
    () {
      final s = InkLabCase.byId('ramp').createSession()..start();
      prepareLab(s);
      s.advance(3);
      expect(s.mechanics!.sliding, isTrue);
      s.lines.single.retired = true;
      s.advance(.02);
      expect(s.mechanics!.motion, InkLabMotion.airborne);
      s.retry();
      expect(s.x, 0);
      expect(s.mechanics!.holdDot, isTrue);
      expect(s.mechanics!.motion, InkLabMotion.walking);
      expect(s.lines, isEmpty);
      expect(s.ink, 240);
    },
  );
  test(
    'Without a landing stroke, pressure rail, repair link or stable bridge the course fails',
    () {
      for (final id in ['landing', 'weight', 'repair', 'crumble']) {
        final s = InkLabCase.byId(id).createSession()..start();
        if (id == 'landing') drawLab(s, s.mechanics!.guides.first.first);
        s.mechanics!.holdDot = false;
        s.advance(20);
        expect(s.phase, Phase.dead, reason: id);
      }
    },
  );
  test('The eraser really removes ink and failure is avoidable by timing', () {
    final s = InkLabCase.byId('eraser').createSession()..start();
    drawLab(s, s.mechanics!.guides.first.first);
    s.advance(5);
    expect(s.activeLines, 1);
    expect(s.lines.single.contours, hasLength(2));
    expect(s.lines.single.travelLength, lessThan(s.lines.single.cost));
    expect(s.lines.single.yAt(160), 0);
    expect(s.lines.single.yAt(330), 0);
    expect(s.x, 0);
    final safe = InkLabCase.byId('eraser').createSession()..start();
    prepareLab(safe);
    runLab(safe);
    expect(safe.phase, Phase.complete);
  });
  test(
    'The pulley bridge carries a supported foot and does not accumulate surfaces',
    () {
      final s = InkLabCase.byId('pulley').createSession()..start();
      final lab = s.mechanics!, deck = s.mechanics!.pulleyDeck!;
      s.x = deck.a.x + 20 * math.cos(lab.pulleyAngle);
      s.y = 20 * math.sin(lab.pulleyAngle);
      final before = V(s.x, s.y), count = s.level.terrain.length;
      s.advance(1);
      expect(V(s.x, s.y).distance(before), greaterThan(1));
      expect(s.level.terrain.length, count);
      expect(s.y, closeTo(s.mechanics!.pulleyDeck!.yAt(s.x), .001));
    },
  );
  test(
    'Ink may touch a moving pulley deck instead of starting on fixed paper',
    () {
      final s = InkLabCase.byId('pulley').createSession()..start();
      final edge = s.mechanics!.pulleyDeck!.b;
      expect(s.beginStroke(edge + const V(30, 30)), isTrue);
      s.moveStroke(edge);
      expect(s.endStroke(), isTrue, reason: s.message);
    },
  );
  test(
    'A failed case lookup is explicit and existing story sessions use normal rules',
    () {
      expect(() => InkLabCase.byId('missing'), throwsStateError);
      final s = InkSession([
        {'number': 1, 'title': 'Story', 'width': 2000, 'cells': []},
      ]);
      expect(s.mechanics, isNull);
      expect(s.walkSpeed, 56);
    },
  );
}
