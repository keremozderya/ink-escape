import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';

InkSession ledgeScene({
  bool ink = false,
  double x = 90,
  double y = .1,
  double vy = -40,
}) {
  final s = InkSession([
    {'number': 1, 'title': 'Ledge', 'width': 2000, 'cells': []},
  ])..start();
  s.level.terrain.clear();
  if (ink) {
    s.lines.add(InkLine('ledge', [const V(100, 0), const V(180, 0)]));
  } else {
    s.level.terrain.add(Surface('ledge', const V(100, 0), const V(180, 0)));
  }
  return s
    ..x = x
    ..y = y
    ..vy = vy
    ..grounded = false;
}

void main() {
  for (final ink in [false, true]) {
    test(
      'Touching a ${ink ? 'drawn' : 'paper'} corner hangs; five pulls climb onto it',
      () {
        final s = ledgeScene(ink: ink);
        s.advance(1 / 120);
        expect(s.ledge, isNotNull);
        expect(s.grounded, isFalse);
        expect(s.ledge!.pulls, 0);
        expect(s.beginStroke(const V(100, 0)), isFalse);
        s.advance(5);
        expect(s.phase, Phase.playing);
        expect(s.stuckCountdown, isNull);
        expect(s.ledge, isNotNull);
        expect(s.x, lessThan(100));
        for (var i = 0; i < 4; i++) {
          expect(s.pullLedge(), isTrue);
          s.advance(.2);
        }
        expect(s.ledge, isNotNull);
        expect(s.ledge!.pulls, 4);
        s.pullLedge();
        s.advance(1);
        expect(s.ledge, isNull);
        expect(s.grounded, isTrue);
        expect(s.y, 0);
        expect(s.x, greaterThanOrEqualTo(108));
        expect(s.phase, Phase.playing);
      },
    );
  }

  test(
    'The hand must actually reach an approaching corner while descending',
    () {
      for (final config in [
        (80.0, .1, -40.0),
        (90.0, -25.0, -40.0),
        (90.0, -1.0, 50.0),
        (114.0, -1.0, -40.0),
        (90.0, 5.0, -40.0),
      ]) {
        final s = ledgeScene(x: config.$1, y: config.$2, vy: config.$3);
        s.advance(1 / 120);
        expect(
          s.ledge,
          isNull,
          reason: '$config is outside the hand contact zone',
        );
      }
      final grazing = ledgeScene(y: -1, vy: -10)..advance(1 / 120);
      expect(grazing.ledge, isNotNull);
    },
  );

  test(
    'Walking off the previous edge and internal contour vertices do not grab',
    () {
      final s = ledgeScene(x: 139.9, y: 0, vy: 0)..grounded = true;
      s.level.terrain
        ..clear()
        ..add(Surface('left', const V(0, 0), const V(100, 0)))
        ..add(Surface('right', const V(100, 0), const V(140, 0)));
      s.advance(.5);
      expect(s.ledge, isNull);
      expect(s.grounded, isFalse);
    },
  );

  test('Pausing and restoring preserve the grip and completed pulls', () {
    final s = ledgeScene()..advance(1 / 120);
    s.pullLedge();
    s.advance(.15);
    s.pullLedge();
    s.advance(.15);
    s.pause();
    final before = V(s.x, s.y), progress = s.ledge!.progress;
    s.advance(30);
    expect(s.pullLedge(), isFalse);
    expect(V(s.x, s.y).distance(before), 0);
    expect(s.ledge!.progress, progress);
    final saved = cloneJson(s.snapshot());
    final realData = [
      {
        'number': 1,
        'title': 'Saved ledge',
        'width': 2000,
        'cells': [
          {
            'index': 1,
            'offset_x': 0,
            'route': [
              {
                'kind': 'natural',
                'points': [
                  [100, 0],
                  [180, 0],
                ],
              },
            ],
            'pads': [],
            'pickups': [],
            'gates': [],
            'objects': [],
            'hazards': [],
            'absorbent': [],
            'lines': [],
          },
        ],
      },
    ];
    final restored = InkSession.restore(realData, saved);
    expect(restored.ledge?.pulls, 2);
    expect(restored.ledge?.progress, progress);
    expect(restored.phase, Phase.ready);
    restored.start();
    for (var i = 0; i < 3; i++) {
      restored.pullLedge();
    }
    restored.advance(1.5);
    expect(restored.ledge, isNull);
    expect(restored.grounded, isTrue);
    s.retry();
    expect(s.ledge, isNull);
  });

  test(
    'Retiring the supporting ink releases the grip instead of holding thin air',
    () {
      final s = ledgeScene(ink: true)..advance(1 / 120);
      expect(s.ledge, isNotNull);
      s.lines.single.retired = true;
      s.advance(.1);
      expect(s.ledge, isNull);
      expect(s.grounded, isFalse);
      expect(s.vy, lessThan(0));
    },
  );

  test(
    'Replacing terrain at the same list index invalidates support safely',
    () {
      final s = ledgeScene(x: 120, y: 0, vy: 0)..grounded = true;
      s.advance(.01);
      expect(s.grounded, isTrue);
      s.level.terrain[0] = Surface(
        'raised',
        const V(100, 100),
        const V(180, 100),
      );
      s.advance(.1);
      expect(s.grounded, isFalse);
      expect(s.y, lessThan(0));
    },
  );
}
