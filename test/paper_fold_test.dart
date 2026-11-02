import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'mechanics_lab_test.dart' show drawLab, prepareLab, runLab;

InkSession pageScene([String id = 'fold']) =>
    InkLabCase.byId(id).createSession()..start();
void pressAndFold(InkSession s, [double seconds = 1]) {
  s.x = FoldPaper.buttonX;
  s.y = 0;
  s.grounded = true;
  s.advance(seconds);
}

void main() {
  test('Waiting or passing above the button cannot fold the page', () {
    final s = pageScene(), p = s.mechanics!.paper!;
    s.advance(5);
    expect(p.pressed, isFalse);
    expect(p.angle, 0);
    s.x = FoldPaper.buttonX;
    s.y = 20;
    s.grounded = false;
    s.advance(1);
    expect(p.pressed, isFalse);
  });

  test(
    'A diagonal corner fold changes the real floor and keeps paid ink immutable',
    () {
      final s = pageScene(), p = s.mechanics!.paper!;
      prepareLab(s);
      final bridge = s.lines.first, inside = s.lines.last;
      final source = inside.points.map((v) => v.toJson()).toList(),
          paid = inside.cost;
      expect(p.surfaces.first.yAt(250), 0);
      runLab(s);
      expect(s.phase, Phase.complete, reason: s.message);
      expect(p.pressed, isTrue);
      expect(p.angle, closeTo(math.pi, 1e-9));
      expect(inside.points.map((v) => v.toJson()).toList(), source);
      expect(inside.cost, paid);
      expect(inside.concealed, isTrue);
      expect(bridge.concealed, isFalse);
      final slope = p.surfaces.firstWhere((e) => e.contains(250));
      expect(slope.yAt(250), closeTo(-30, 1e-7));
      expect(p.surfaces.last.b.distance(const V(340, -60)), lessThan(1e-7));
    },
  );

  test(
    'The final fold is a planar mirror, preserving lengths and crease points',
    () {
      final s = pageScene(), p = s.mechanics!.paper!;
      pressAndFold(s, 1.1);
      expect(
        p.project(const V(340, 0)).distance(const V(304, -108)),
        lessThan(1e-7),
      );
      expect(p.project(p.creaseEnd).distance(p.creaseEnd), lessThan(1e-7));
      expect(
        p.project(p.project(const V(280, -18))).distance(const V(280, -18)),
        lessThan(1e-7),
      );
      for (var i = 1; i < p.flap.length; i++) {
        expect(
          p.project(p.flap[i]).distance(p.project(p.flap[i - 1])),
          closeTo(p.flap[i].distance(p.flap[i - 1]), 1e-7),
        );
      }
    },
  );

  test('Ink follows the flat sheet before it turns face down', () {
    final s = pageScene(), p = s.mechanics!.paper!;
    drawLab(s, s.mechanics!.guides.first.last);
    final line = s.lines.single;
    pressAndFold(s, .25);
    expect(p.frontFacing, isTrue);
    expect(
      line.contours.single.last.distance(p.project(line.points.last)),
      lessThan(1e-7),
    );
    expect(
      line.contours.single.last.distance(line.points.last),
      greaterThan(1),
    );
  });

  test(
    'The button does not insert a bridge or replace a missing player stroke',
    () {
      final s = pageScene();
      s.mechanics!.holdDot = false;
      s.advance(20);
      expect(s.mechanics!.paper!.pressed, isTrue);
      expect(s.lines, isEmpty);
      expect(s.phase, Phase.dead);
    },
  );

  test(
    'Only ink inside the moving corner folds; its fixed half stays still',
    () {
      final s = pageScene();
      drawLab(s, [
        const V(150, 0),
        const V(160, 0),
        const V(200, -2),
        const V(245, -8),
      ]);
      final line = s.lines.single, source = line.points.toList(), ink = s.ink;
      s.level.noRegen.add([-1000, 1000]);
      pressAndFold(s, 1.1);
      expect(line.contours.single.first.distance(source.first), lessThan(1e-7));
      expect(line.contours.single.last.distance(const V(160, 0)), lessThan(.2));
      expect(line.yAt(200), isNull);
      expect(line.points, source);
      expect(s.ink, ink);
    },
  );

  test(
    'Another bank on the crease side remains fixed outside the physical sheet',
    () {
      final s = pageScene();
      drawLab(s, s.mechanics!.guides.first.first);
      final line = s.lines.single,
          source = line.points.map((v) => v.toJson()).toList();
      pressAndFold(s, 1.1);
      expect(line.contours.single.map((v) => v.toJson()).toList(), source);
      expect(line.yAt(400), -60);
    },
  );

  test(
    'Front-side ink disappears behind the turned page and frees its slot',
    () {
      final s = pageScene('fold-cover'), p = s.mechanics!.paper!;
      drawLab(s, s.mechanics!.guides.first.first);
      final line = s.lines.single, paid = line.cost;
      pressAndFold(s, 1.1);
      expect(p.backFacing, isTrue);
      expect(line.contours, isEmpty);
      expect(line.cost, paid);
      expect(line.yAt(200), isNull);
      expect(s.activeLines, 0);
      expect(s.solidLines, isEmpty);
      s.level.terrain.clear();
      s.x = 200;
      s.y = 30;
      s.vy = -10;
      s.grounded = false;
      s.mechanics!.holdDot = false;
      s.advance(.7);
      expect(s.grounded, isFalse);
      expect(s.y, lessThan(0));
    },
  );

  test(
    'A folded-over page clips covered static ink without bridging the hidden gap',
    () {
      final s = pageScene('fold-cover');
      final line = InkLine('covered', [const V(120, -10), const V(285, -10)]);
      s.lines.add(line);
      pressAndFold(s, 1.1);
      expect(line.contours, hasLength(2));
      expect(line.yAt(130), closeTo(-10, 1e-7));
      expect(line.yAt(200), isNull);
      expect(line.yAt(275), closeTo(-10, 1e-7));
    },
  );

  test(
    'Unrelated overhead ink remains fixed, and a settled fold stops rebuilding geometry',
    () {
      final s = pageScene(),
          roof = InkLine('roof', [const V(180, 110), const V(290, 110)]);
      s.lines.add(roof);
      pressAndFold(s, 1.1);
      final contours = roof.contours, revision = roof.geometryRevision;
      final count = s.level.terrain.length;
      s.advance(5);
      expect(roof.contours, same(contours));
      expect(roof.geometryRevision, revision);
      expect(roof.yAt(200), 110);
      expect(s.level.terrain.length, count);
    },
  );

  test(
    'New ink can be drawn on the exposed back without revealing old front ink',
    () {
      final s = pageScene('fold-cover');
      drawLab(s, s.mechanics!.guides.first.first);
      final old = s.lines.single;
      pressAndFold(s, 1.1);
      drawLab(s, [const V(200, 0), const V(220, -16), const V(235, 0)]);
      final fresh = s.lines.last;
      expect(old.concealed, isTrue);
      expect(fresh.concealed, isFalse);
      expect(s.activeLines, 1);
      expect(fresh.yAt(220), lessThan(-10));
    },
  );

  test(
    'Pause freezes a started fold and retry restores the original paper and ink',
    () {
      final s = pageScene(), p = s.mechanics!.paper!;
      drawLab(s, s.mechanics!.guides.first.first);
      pressAndFold(s, .25);
      expect(p.progress, inExclusiveRange(0, 1));
      final angle = p.angle, contour = s.lines.single.contours;
      s.pause();
      s.advance(5);
      expect(p.angle, angle);
      expect(s.lines.single.contours, same(contour));
      s.retry();
      expect(s.mechanics!.paper!.pressed, isFalse);
      expect(s.mechanics!.paper!.angle, 0);
      expect(s.lines, isEmpty);
    },
  );

  test(
    'The page waits for an active pen before deforming a newly drawn contour',
    () {
      final s = pageScene();
      expect(s.beginStroke(const V(340, 0)), isTrue);
      s.moveStroke(const V(310, -8));
      pressAndFold(s, .4);
      expect(s.mechanics!.paper!.pressed, isTrue);
      expect(s.mechanics!.paper!.progress, 0);
      s.moveStroke(const V(280, -18));
      expect(s.endStroke(), isTrue);
      s.advance(1);
      expect(s.mechanics!.paper!.settled, isTrue);
      expect(s.lines.single.concealed, isTrue);
    },
  );

  test(
    'A paper sheet does not create a tall invisible wall under its edge',
    () {
      final s = pageScene();
      s.x = 210;
      s.y = -80;
      s.vy = -10;
      s.grounded = false;
      s.mechanics!.holdDot = false;
      s.advance(.3);
      expect(s.x, greaterThan(225));
      expect(s.mechanics!.paper!.pressed, isFalse);
    },
  );
}
