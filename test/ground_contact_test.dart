import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';

InkSession scene(List<V> points, {bool ink = false, bool reverse = false}) {
  final s = InkSession([
    {'number': 1, 'title': 'Contact regression', 'width': 2000, 'cells': []},
  ])..start();
  s.level.terrain.clear();
  if (ink) {
    s.lines.add(
      InkLine('contour', reverse ? points.reversed.toList() : points),
    );
  } else {
    for (var i = 1; i < points.length; i++) {
      s.level.terrain.add(Surface('ground:$i', points[i - 1], points[i]));
    }
  }
  return s;
}

void main() {
  for (final ink in [false, true]) {
    test('A sharp shallow ditch keeps contact on ${ink ? 'ink' : 'paper'}', () {
      final s = scene([
        const V(0, 0),
        const V(40, 0),
        const V(44, -24),
        const V(48, 0),
        const V(200, 0),
      ], ink: ink)..x = 38;
      for (var i = 0; i < 180; i++) {
        s.advance(1 / 120);
        expect(s.grounded, isTrue, reason: 'Contact lost at (${s.x}, ${s.y})');
        expect(s.phase, Phase.playing);
        expect(s.y, greaterThanOrEqualTo(-24.001));
      }
      expect(s.x, greaterThan(65));
      expect(s.y, closeTo(0, 1e-5));
    });

    test(
      'A falling foot catches a rising ${ink ? 'ink' : 'paper'} surface',
      () {
        final s = scene([const V(90, -10), const V(160, 60)], ink: ink)
          ..x = 100
          ..y = .1
          ..vy = -20
          ..grounded = false;
        s.advance(1 / 120);
        expect(s.grounded, isTrue);
        expect(s.y, closeTo(s.x - 100, 1e-6));
        expect(s.lastEvent, 'land');
      },
    );
  }

  test('A landing between frame endpoints is not skipped', () {
    final s = scene([const V(100.14, 0), const V(100.22, 0)])
      ..x = 100
      ..y = .12
      ..vy = -40
      ..grounded = false;
    final events = <String>[];
    s.onEvent = (name, _) => events.add(name);
    s.advance(1 / 120);
    expect(events, contains('land'));
    expect(s.x, inInclusiveRange(100.14, 100.22));
    expect(s.y, closeTo(0, 1e-6));
  });

  test(
    'Foot samples follow both sides of a ditch and ignore an overhead loop',
    () {
      final s = scene([const V(-100, 60), const V(0, 0), const V(100, 60)])
        ..x = 0;
      final left = s.groundPointAt(-10)!, right = s.groundPointAt(10)!;
      expect(left.y, greaterThan(0));
      expect(right.y, closeTo(left.y, 1e-6));
      expect(left.x, closeTo(-right.x, 1e-6));
      final flat = scene([const V(0, 0), const V(200, 0)])..x = 100;
      flat.lines.add(InkLine('overhead', [const V(90, .5), const V(110, 1)]));
      expect(flat.groundSlope, 0);
      expect(flat.groundPointAt(-10)!.y, 0);
      expect(flat.groundPointAt(10)!.y, 0);
    },
  );

  test('Reversing a drawn contour does not change contact or travel speed', () {
    final points = [
      const V(0, 0),
      const V(40, 0),
      const V(44, -24),
      const V(48, 0),
      const V(200, 0),
    ];
    final a = scene(points, ink: true)..x = 38;
    final b = scene(points, ink: true, reverse: true)..x = 38;
    a.advance(1.5);
    for (var i = 0; i < 90; i++) {
      b.advance(1 / 60);
    }
    expect(a.x, closeTo(b.x, 1e-6));
    expect(a.y, closeTo(b.y, 1e-6));
    expect(a.walked, closeTo(b.walked, 1e-6));
    expect(a.walked, closeTo(a.walkSpeed * 1.5, .5));
  });

  test(
    'Separated free ends remain gaps and ink retired in midair is not solid',
    () {
      final s = scene([const V(0, 0), const V(40, 0)], ink: true)..x = 39;
      expect(s.groundPointAt(5), isNull);
      s.advance(.5);
      expect(s.grounded, isFalse);
      expect(s.y, lessThan(0));
      final falling = scene([const V(90, -10), const V(160, 60)], ink: true)
        ..x = 100
        ..y = .1
        ..vy = -20
        ..grounded = false;
      falling.lines.single.retired = true;
      falling.advance(1 / 120);
      expect(falling.grounded, isFalse);
    },
  );
}
