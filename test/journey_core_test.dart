import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';

List<Map<String, dynamic>> journeyLevels() => [
  for (final (index, width) in [(1, 128.0), (2, 256.0)])
    {
      'number': index,
      'title': 'Journey $index',
      'width': width,
      'cells': [
        {
          'index': 1,
          'offset_x': 0,
          'route': [
            {
              'kind': 'natural',
              'points': [
                [0, 0],
                [width, 0],
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

void main() {
  test('Centimeters use walked distance and a fixed world scale', () {
    final s = InkSession(journeyLevels())..start();
    expect(s.distanceCm, 0);
    s.advance(1);
    expect(s.distanceCm, closeTo(s.walkSpeed / 32, 1e-7));
    expect(s.levelProgress, closeTo(s.x / 128, 1e-7));
  });

  test(
    'Distance follows slope length while progress tracks chapter position',
    () {
      final s = InkSession(journeyLevels())..start();
      s.level.terrain
        ..clear()
        ..add(Surface('slope', const V(0, 0), const V(100, 100)));
      s.advance(1);
      expect(s.walked, closeTo(56, 1e-6));
      expect(s.x, closeTo(56 / 1.4142135623730951, 1e-6));
      expect(s.distanceCm, greaterThan(s.x / 32));
      expect(s.levelProgress, closeTo(s.x / 128, 1e-7));
    },
  );

  test('Neither counter advances during a pause or while blocked', () {
    final s = InkSession(journeyLevels())..start();
    s.advance(.5);
    s.pause();
    final distance = s.distanceCm, progress = s.levelProgress;
    s.advance(10);
    expect(s.distanceCm, distance);
    expect(s.levelProgress, progress);
    s.start();
    s.lines.add(InkLine('wall', [V(s.x + 10, 0), V(s.x + 10, 80)]));
    s.advance(1);
    expect(s.stuckCountdown, isNotNull);
    expect(s.distanceCm, distance);
    expect(s.levelProgress, progress);
  });

  test('Boundary resets the bar without stopping or jumping the distance', () {
    final s = InkSession(journeyLevels())..start();
    s.x = 127.9;
    s.walked = 127.9;
    final before = s.origin + s.x, distance = s.walked;
    final events = <String>[];
    s.onEvent = (name, _) => events.add(name);
    s.advance(1 / 120);
    expect(s.level.number, 2);
    expect(s.phase, Phase.playing);
    expect(s.levelProgress, inInclusiveRange(0, .002));
    expect(s.origin + s.x - before, closeTo(s.walkSpeed / 120, 1e-6));
    expect(s.walked - distance, closeTo(s.walkSpeed / 120, 1e-6));
    expect(s.y, 0);
    expect(s.grounded, isTrue);
    expect(events, contains('boundary'));
    expect(events, isNot(contains('complete')));
    expect(events, isNot(contains('pause')));
    final atEntry = s.distanceCm;
    s.advance(.5);
    expect(s.distanceCm, greaterThan(atEntry));
    expect(s.levelProgress, closeTo(s.x / 256, 1e-7));
  });

  test(
    'Retry and death checkpoint retain distance from completed chapters',
    () {
      final levels = journeyLevels();
      final s = InkSession(levels)..start();
      s.advance(3);
      final entry = s.entryWalked;
      expect(entry, greaterThanOrEqualTo(128));
      expect(s.walked, greaterThan(entry));
      s.die('test');
      final fromDeath = InkSession.restore(levels, cloneJson(s.snapshot()));
      expect(fromDeath.distanceCm, entry / 32);
      expect(fromDeath.levelIndex, 1);
      expect(fromDeath.levelProgress, 0);
      s.retry();
      expect(s.walked, entry);
      expect(s.levelProgress, 0);
      s.start();
      s.advance(.5);
      expect(s.distanceCm, closeTo((entry + 28) / 32, 1e-6));
    },
  );

  test('Save restore preserves both the live and entry distance', () {
    final levels = journeyLevels();
    final s = InkSession(levels)..start();
    s.advance(3);
    final r = InkSession.restore(levels, cloneJson(s.snapshot()));
    expect(r.distanceCm, s.distanceCm);
    expect(r.levelProgress, s.levelProgress);
    expect(r.entryWalked, s.entryWalked);
    r.retry();
    expect(r.distanceCm, s.entryWalked / 32);
  });

  test(
    'A previous-version save remains readable without an entry distance',
    () {
      final levels = journeyLevels();
      final s = InkSession(levels)..start();
      s.advance(3);
      final saved = cloneJson(s.snapshot())..remove('entryWalked');
      final r = InkSession.restore(levels, saved);
      expect(r.distanceCm, s.distanceCm);
      r.retry();
      expect(r.distanceCm, closeTo(128 / 32, .02));
    },
  );

  test('Progress is bounded and reaches full at the authored ending', () {
    final s = InkSession(journeyLevels())..start();
    s.x = -10;
    expect(s.levelProgress, 0);
    s.x = 0;
    s.advance(10);
    expect(s.phase, Phase.complete);
    expect(s.levelProgress, 1);
    final distance = s.distanceCm;
    s.advance(5);
    expect(s.distanceCm, distance);
  });
}
