import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';

InkSession bridge(double height, {bool reverse = false}) {
  final session = InkSession([
    {'number': 1, 'title': 'Raised bridge', 'width': 2000, 'cells': []},
  ])..start();
  session.level.terrain
    ..clear()
    ..add(Surface('paper', const V(-100, 0), const V(100, 0)));
  final points = [V(100, height), V(180, height)];
  session.lines.add(
    InkLine('bridge', reverse ? points.reversed.toList() : points),
  );
  return session..x = 98;
}

void main() {
  for (final height in [2.0, 6.0, InkSession.inkStepHeight]) {
    for (final fps in [30, 60, 120]) {
      test('$height-unit raised bridge stays solid at $fps FPS', () {
        final s = bridge(height);
        for (var frame = 0; frame < fps ~/ 2; frame++) {
          s.advance(1 / fps);
          expect(s.grounded, isTrue);
          expect(s.ledge, isNull);
          expect(s.phase, Phase.playing);
        }
        expect(s.x, greaterThan(110));
        expect(s.y, height);
        expect(s.groundPointAt(3)!.y, height);
      });
    }
  }
  test('Bridge finished just after Dot passes its start catches his feet', () {
    final s = bridge(7)..lines.clear();
    s.advance(.08);
    expect(s.x, greaterThan(100));
    expect(s.grounded, isFalse);
    s.lines.add(InkLine('late', [const V(100, 7), const V(180, 7)]));
    s.advance(1 / 120);
    expect(s.grounded, isTrue);
    expect(s.y, 7);
    expect(s.ledge, isNull);
  });
  test('A line starting inside the paper can rise just above the open lip', () {
    final s = bridge(6)..lines.clear();
    s.lines.add(
      InkLine('ramp', [const V(92, 0), const V(108, 12), const V(180, 12)]),
    );
    s.advance(.8);
    expect(s.x, greaterThan(120));
    expect(s.y, 12);
    expect(s.grounded, isTrue);
  });
  test('Reversed drawing has the same support', () {
    final a = bridge(7), b = bridge(7, reverse: true);
    a.advance(.6);
    b.advance(.6);
    expect(a.x, closeTo(b.x, 1e-6));
    expect(a.y, b.y);
  });
  test('Overhead lines above continuing paper are not stepped onto', () {
    final s = bridge(8);
    s.level.terrain.add(
      Surface('continuing', const V(100, 0), const V(200, 0)),
    );
    s.advance(1);
    expect(s.y, 0);
    expect(s.onNatural, isTrue);
  });
  test(
    'High roofs, retired ink and distant floating ink remain unsupported',
    () {
      final high = bridge(30)..advance(.4);
      expect(high.y, lessThan(0));
      expect(high.grounded, isFalse);
      final retired = bridge(6);
      retired.lines.single.retired = true;
      retired.advance(.4);
      expect(retired.grounded, isFalse);
      final far = bridge(6)
        ..x = 130
        ..y = -1
        ..grounded = false;
      far.advance(.05);
      expect(far.grounded, isFalse);
    },
  );
}
