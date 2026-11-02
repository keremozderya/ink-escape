import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'mechanics_lab_test.dart' show drawLab;

InkSession cornerScene({
  double drop = 3,
  double vy = -20,
  bool momentum = false,
}) {
  final s = InkLabCase.byId(momentum ? 'slide' : 'plan-L').createSession()
    ..start();
  s.level.terrain
    ..clear()
    ..add(Surface('bank', const V(100, 0), const V(900, 0)));
  s.x = 87.8;
  s.y = -drop;
  s.vy = vy;
  s.grounded = false;
  s.onNatural = false;
  s.mechanics!.holdDot = false;
  if (momentum) {
    s.mechanics!.motion = InkLabMotion.airborne;
    s.mechanics!.vx = 90;
    s.mechanics!.speed = 90;
  }
  return s;
}

void main() {
  for (final fps in [30, 73, 144]) {
    for (final drop in [.2, 1.0, 2.0, 3.5]) {
      test('A foot $drop below the rim steps onto it at $fps FPS', () {
        final s = cornerScene(drop: drop);
        for (var i = 0; i < fps; i++) {
          s.advance(1 / fps);
          expect(s.ledge, isNull);
          expect(s.cornerSupport, isNull);
        }
        expect(s.x, greaterThan(125));
        expect(s.y, closeTo(0, 1e-6));
        expect(s.grounded, isTrue);
        expect(s.phase, Phase.playing);
      });
    }
  }

  test(
    'A momentum landing uses the same corner correction and keeps speed',
    () {
      final s = cornerScene(momentum: true);
      s.advance(.5);
      expect(s.x, greaterThan(125));
      expect(s.y, closeTo(0, 1e-6));
      expect(s.grounded, isTrue);
      expect(s.mechanics!.speed, greaterThan(70));
      expect(s.ledge, isNull);
    },
  );

  test('A sliding foot also clears a slightly raised paper lip', () {
    final s = InkLabCase.byId('slide').createSession()..start();
    s.level.terrain.removeWhere((f) => f.id == 'lab-finish');
    s.level.terrain.add(
      Surface('raised-end', const V(235, -58), const V(900, -58)),
    );
    drawLab(s, [
      const V(130, 0),
      const V(145, -40),
      const V(170, -60),
      const V(233, -60),
    ]);
    s.mechanics!.holdDot = false;
    for (var i = 0; i < 120 * 7 && s.x < 260 && s.phase == Phase.playing; i++) {
      s.advance(1 / 120);
    }
    expect(s.x, greaterThanOrEqualTo(260));
    expect(s.y, closeTo(-58, 1e-6));
    expect(s.mechanics!.speed, greaterThan(110));
    expect(s.ledge, isNull);
  });

  test('A trailing foot keeps support only until it leaves the paper', () {
    final s = cornerScene();
    s.level.terrain
      ..clear()
      ..add(Surface('bank', const V(-100, 0), const V(100, 0)));
    s.x = 99;
    s.y = 0;
    s.vy = 0;
    s.grounded = true;
    s.advance(.15);
    expect(s.x, greaterThan(106));
    expect(s.grounded, isTrue);
    expect(s.y, 0);
    expect(s.groundPointAt(-8), isNotNull);
    s.advance(.25);
    expect(s.grounded, isFalse);
    expect(s.y, lessThan(0));
  });

  test('A narrow crack can be stepped over while a foot has real support', () {
    final s = cornerScene();
    s.level.terrain.insert(
      0,
      Surface('left', const V(-100, 0), const V(80, 0)),
    );
    s.x = 79;
    s.y = 0;
    s.vy = 0;
    s.grounded = true;
    for (var i = 0; i < 120; i++) {
      s.advance(1 / 120);
      expect(s.grounded, isTrue);
    }
    expect(s.x, greaterThan(125));
    expect(s.y, 0);
  });

  for (final drop in [5.0, 13.0, 32.0]) {
    test('A foot $drop below the rim still hits the face and falls', () {
      final s = cornerScene(drop: drop);
      s.advance(3);
      expect(s.x, lessThanOrEqualTo(88.001));
      expect(s.phase, Phase.dead);
      expect(s.y, lessThan(-300));
      expect(s.ledge, isNull);
    });
  }

  test('A fast fall cannot be rescued by a near-rim correction', () {
    final s = cornerScene(drop: 1, vy: -180);
    s.advance(2);
    expect(s.x, lessThanOrEqualTo(88.001));
    expect(s.grounded, isFalse);
    expect(s.ledge, isNull);
  });

  test('Corner correction cannot lift the head through a low roof', () {
    final s = cornerScene();
    s.lines.add(InkLine('roof', [const V(75, 29), const V(140, 29)]));
    s.advance(.5);
    expect(s.grounded, isFalse);
    expect(s.y + InkSession.dotHeight, lessThanOrEqualTo(29.001));
    expect(s.x, lessThanOrEqualTo(88.001));
  });

  test('A retired surface cannot support a foot across a real gap', () {
    final s = cornerScene();
    s.level.terrain.clear();
    s.lines.add(
      InkLine('gone', [const V(100, 0), const V(400, 0)])..retired = true,
    );
    s.advance(2);
    expect(s.grounded, isFalse);
    expect(s.y, lessThan(-300));
  });
}
