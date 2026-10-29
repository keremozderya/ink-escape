import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';

const emptyLevels = [
  {'number': 1, 'title': 'Short bank regression', 'width': 2000, 'cells': []},
];

InkSession lowBridge(double drop, {bool reverse = false, double inset = 2}) {
  final s = InkSession(emptyLevels)..start();
  s.level.terrain
    ..clear()
    ..addAll([
      Surface('left', const V(-100, 0), const V(100, 0)),
      Surface('right', const V(180, 0), const V(500, 0)),
    ]);
  final points = [const V(100, 0), V(180 + inset, -drop)];
  s.lines.add(
    InkLine('low-bridge', reverse ? points.reversed.toList() : points),
  );
  return s..x = 98;
}

void main() {
  test(
    'A low bridge committed through drawing input reaches the opposite bank',
    () {
      final s = lowBridge(16)..lines.clear();
      expect(s.beginStroke(const V(100, 0)), isTrue);
      for (var i = 1; i <= 30; i++) {
        s.moveStroke(V(100 + 82 * i / 30, -16 * i / 30));
      }
      expect(s.endStroke(), isTrue);
      expect(s.lines.single.points.last.y, -16);
      s.advance(3);
      expect(s.x, greaterThan(195));
      expect(s.y, 0);
      expect(s.phase, Phase.playing);
    },
  );

  for (final drop in [2.0, 8.0, 16.0, InkSession.autoJumpHeight]) {
    for (final fps in [30, 60, 120]) {
      for (final reverse in [false, true]) {
        test('Bridge $drop below bank, $fps FPS, reversed=$reverse', () {
          final s = lowBridge(drop, reverse: reverse);
          var jumped = false;
          s.onEvent = (event, _) => jumped |= event == 'jump';
          for (var frame = 0; frame < fps * 3; frame++) {
            s.advance(1 / fps);
            // The body must clear the bank before moving inside its face.
            if (s.x > 168.001) expect(s.y, greaterThanOrEqualTo(-.501));
            expect(s.ledge, isNull);
            expect(s.phase, Phase.playing);
          }
          expect(jumped, isTrue);
          expect(s.x, greaterThan(195));
          expect(s.y, closeTo(0, 1e-6));
          expect(s.grounded, isTrue);
          expect(s.onNatural, isTrue);
        });
      }
    }
  }

  test('Exact 24-unit natural and drawn steps use an airborne arc', () {
    for (final ink in [false, true]) {
      final s = InkSession(emptyLevels)..start();
      s.level.terrain
        ..clear()
        ..add(Surface('base', const V(-100, 0), const V(100, 0)));
      if (ink) {
        s.lines.add(
          InkLine('step', [
            const V(100, 0),
            const V(100, 24),
            const V(400, 24),
          ]),
        );
      } else {
        s.level.terrain.add(Surface('top', const V(100, 24), const V(400, 24)));
      }
      s.x = 85;
      var airborne = false, apex = 0.0, jumps = 0;
      s.onEvent = (event, _) {
        if (event == 'jump') jumps++;
      };
      for (var i = 0; i < 180; i++) {
        s.advance(1 / 120);
        airborne |= !s.grounded && s.vy > 0;
        apex = math.max(apex, s.y);
        expect(s.ledge, isNull);
      }
      expect(airborne, isTrue);
      expect(apex, greaterThan(24));
      expect(apex, lessThanOrEqualTo(28));
      expect(jumps, 1);
      expect(s.x, greaterThan(125));
      expect(s.y, 24);
      expect(s.grounded, isTrue);
    }
  });

  test('A bridge ending below a taller bank cannot enter solid paper', () {
    final s = lowBridge(40, inset: 10);
    var jumps = 0;
    s.onEvent = (event, _) {
      if (event == 'jump') jumps++;
    };
    s.advance(2.9);
    expect(jumps, 0);
    expect(s.x, lessThanOrEqualTo(168));
    expect(s.y, greaterThan(-40));
    expect(s.grounded, isTrue);
    s.advance(3.1);
    expect(s.phase, Phase.dead);
    expect(s.message, contains('3 saniyedir'));
  });

  test('A 24.2-unit vertical stroke cannot be jumped or climbed in stages', () {
    final s = InkSession(emptyLevels)..start();
    s.level.terrain.add(Surface('base', const V(0, 0), const V(300, 0)));
    s.lines.add(InkLine('wall', [const V(100, 0), const V(100, 24.2)]));
    s.x = 85;
    s.advance(4);
    expect(s.phase, Phase.dead);
    expect(s.x, lessThan(100));
    expect(s.y, 0);
  });

  test('A retired bridge and an unconnected gap do not grant a jump', () {
    final retired = lowBridge(8);
    retired.lines.single.retired = true;
    retired.advance(3);
    expect(retired.y, lessThan(-300));
    final gap = lowBridge(8)..lines.clear();
    var jumps = 0;
    gap.onEvent = (event, _) {
      if (event == 'jump') jumps++;
    };
    gap.advance(3);
    expect(jumps, 0);
    expect(gap.phase, Phase.dead);
  });

  test('Pause and a save roundtrip preserve a rising jump', () {
    final s = lowBridge(16);
    for (var i = 0; i < 240 && (s.grounded || s.vy <= 0); i++) {
      s.advance(1 / 120);
    }
    expect(s.vy, greaterThan(0));
    expect(s.grounded, isFalse);
    final snapshot =
        jsonDecode(jsonEncode(s.snapshot())) as Map<String, dynamic>;
    final restored = InkSession.restore(emptyLevels, snapshot);
    // Synthetic terrain is rebuilt just as real authored terrain is on load.
    restored.level.terrain
      ..clear()
      ..addAll(s.level.terrain);
    s.pause();
    final position = V(s.x, s.y), velocity = s.vy;
    s.advance(5);
    expect(V(s.x, s.y).distance(position), 0);
    expect(s.vy, velocity);
    s.start();
    restored.start();
    s.advance(1);
    restored.advance(1);
    expect(restored.x, closeTo(s.x, 1e-6));
    expect(restored.y, closeTo(s.y, 1e-6));
    expect(restored.grounded, s.grounded);
    expect(s.x, greaterThan(180));
  });

  test('A low ceiling stops the head on the rising arc', () {
    final s = lowBridge(16);
    s.lines.add(InkLine('ceiling', [const V(145, 25), const V(180, 25)]));
    var hitCeiling = false;
    for (var i = 0; i < 240; i++) {
      s.advance(1 / 120);
      if (!s.grounded && s.ledge == null && s.vy == 0) {
        hitCeiling = true;
        expect(s.y + InkSession.dotHeight, closeTo(25, 1e-6));
      }
      if (s.ledge == null && s.x >= 145 && s.x <= 180) {
        expect(s.y + InkSession.dotHeight, lessThanOrEqualTo(25.001));
      }
    }
    expect(hitCeiling, isTrue);
    expect(s.x, lessThanOrEqualTo(168));
  });
}
