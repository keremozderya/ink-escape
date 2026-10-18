import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'package:ink_escape/core/save_journal.dart';

final raw =
    jsonDecode(File('assets/data/prototype_levels.json').readAsStringSync())
        as Map<String, dynamic>;
List<Map<String, dynamic>> data([String? lab]) =>
    (lab == null ? raw['story'] : [raw['labs'][lab]])
        .map<Map<String, dynamic>>((dynamic x) => Map<String, dynamic>.from(x))
        .toList();
InkSession game([String? lab]) =>
    InkSession(data(lab), lab: lab != null)..start();
bool draw(InkSession s, List<V> points, {double seconds = 0}) {
  if (!s.beginStroke(points.first)) {
    return false;
  }
  final len = pathLength(points), steps = (len / 3).ceil();
  final line = InkLine('test', points);
  for (var j = 1; j <= steps; j++) {
    s.moveStroke(line.atDistance(len * j / steps).$1);
    if (seconds > 0) {
      s.advance(seconds / steps);
    }
  }
  return s.endStroke();
}

void solve(InkSession s, {String? skip, void Function(InkSession)? inspect}) {
  final done = <String>{};
  var n = 0;
  while (s.phase == Phase.playing && n++ < 120000) {
    for (final ref in s.level.reference) {
      final id = '${s.levelIndex}:${ref['id']}';
      if (!done.contains(id) && s.x >= (ref['cue'] as double)) {
        done.add(id);
        if (ref['role'] == skip) {
          continue;
        }
        expect(
          draw(s, (ref['points'] as List<V>), seconds: 1),
          isTrue,
          reason: '${s.level.title} $id: ${s.message}',
        );
      }
    }
    inspect?.call(s);
    s.advance(1 / 60);
  }
  expect(n, lessThan(120000));
}

void main() {
  test(
    'Without a stroke Dot walks off the edge and falls; retry is level start',
    () {
      final s = game();
      s.advance(15);
      expect(s.phase, Phase.dead);
      expect(s.x, greaterThan(320));
      expect(s.y, lessThan(-300));
      s.retry();
      expect(s.x, 0);
      expect(s.ink, 180);
      expect(s.phase, Phase.ready);
    },
  );
  test(
    'Release commits only valid anchored geometry and charges actual length',
    () {
      final s = game();
      expect(s.beginStroke(const V(320, 0)), isTrue);
      s.moveStroke(const V(356, 3));
      expect(s.ink, 180);
      s.moveStroke(const V(392, 0));
      expect(s.endStroke(), isTrue);
      expect(s.lines.length, 1);
      expect(s.ink, closeTo(180 - s.lines.first.cost, 1e-6));
      final bad = game();
      expect(
        draw(bad, [const V(320, 0), const V(360, 70), const V(392, 0)]),
        isFalse,
      );
      expect(bad.ink, 180);
      expect(draw(bad, [const V(320, 0), const V(340, 0)]), isFalse);
      expect(bad.ink, 180);
      bad.ink = 10;
      expect(draw(bad, [const V(320, 0), const V(392, 0)]), isFalse);
      expect(bad.ink, 10);
    },
  );
  test('Tiny jitter is removed while a deliberate arch remains', () {
    final s = game();
    s.beginStroke(const V(320, 0));
    for (var i = 1; i <= 24; i++) {
      final x = 320 + i * 3.0;
      final t = i / 24;
      final y = 9 * 4 * t * (1 - t) + (i.isOdd ? .08 : -.08);
      s.moveStroke(V(x, y));
      s.moveStroke(V(x - .2, y + .2));
    }
    expect(s.endStroke(), isTrue);
    expect(
      s.lines.first.points.map((p) => p.y).reduce((a, b) => a > b ? a : b),
      greaterThan(8),
    );
    expect(s.lines.first.points.length, lessThan(35));
  });
  test(
    'Small hand wobble in a shallow curve does not reject the whole stroke',
    () {
      final s = game();
      s.beginStroke(const V(320, 0));
      for (var i = 1; i <= 30; i++) {
        final t = i / 30;
        final wobble = i == 30 ? 0.0 : (i.isOdd ? 1.5 : -1.5);
        s.moveStroke(V(320 + 72 * t, 5 * 4 * t * (1 - t) + wobble));
      }
      expect(s.endStroke(), isTrue, reason: s.message);
      expect(
        s.lines.single.points.map((p) => p.y).reduce((a, b) => a > b ? a : b),
        greaterThan(3),
      );
    },
  );
  test('Backward, overlong and vertical strokes are rejected without cost', () {
    final s = game();
    s.beginStroke(const V(320, 0));
    s.moveStroke(const V(350, 0));
    s.moveStroke(const V(340, 0));
    s.moveStroke(const V(392, 0));
    expect(s.endStroke(), isFalse);
    expect(s.ink, 180);
    expect(draw(s, [const V(0, 0), const V(280, 0)]), isFalse);
    expect(s.ink, 180);
    expect(draw(s, [const V(100, 0), const V(100, 80)]), isFalse);
    expect(s.ink, 180);
  });
  test('Brief finger backtracking is tolerated without erasing a bridge', () {
    final s = game();
    s.beginStroke(const V(320, 0));
    s.moveStroke(const V(350, 0));
    s.moveStroke(const V(346, .5));
    s.moveStroke(const V(370, 1));
    s.moveStroke(const V(392, 0));
    expect(s.endStroke(), isTrue, reason: s.message);
    expect(s.lines.single.points.last.toJson(), [392.0, 0.0]);
    s.x = 318;
    s.advance(2.5);
    expect(s.grounded, isTrue);
    expect(s.onNatural, isTrue);
    expect(s.x, greaterThan(392));
  });
  test(
    'Two slots never evict the bridge under Dot; retirement waits for full body',
    () {
      final s = game('two');
      s.ink = 240;
      expect(draw(s, [const V(240, 0), const V(352, 0)]), isTrue);
      s.ink = 240;
      expect(draw(s, [const V(576, 0), const V(688, 0)]), isTrue);
      s.x = 290;
      expect(s.beginStroke(const V(20, 0)), isFalse);
      expect(s.activeLines, 2);
      expect(s.lines.first.retired, isFalse);
      s.advance(1);
      expect(s.grounded, isTrue);
      expect(s.onNatural, isFalse);
      expect(s.lines.first.retired, isFalse);
      s.x = 363;
      s.y = 0;
      s.grounded = true;
      s.onNatural = true;
      s.advance(.001);
      expect(s.lines.first.retired, isFalse);
      s.x = 365;
      s.advance(.001);
      expect(s.lines.first.retired, isTrue);
    },
  );
  test(
    'Ink regrows on safe paper only, never in air, on ink or while paused',
    () {
      final s = game();
      s.ink = 100;
      s.advance(1);
      expect(s.ink, closeTo(110, .01));
      expect(draw(s, [const V(320, 0), const V(392, 0)]), isTrue);
      s.x = 330;
      s.ink = 50;
      s.advance(1);
      expect(s.ink, 50);
      s.pause();
      final t = s.realTime;
      s.advance(20);
      expect(s.ink, 50);
      expect(s.realTime, t);
      s.start();
      s.x = 600;
      s.grounded = false;
      s.onNatural = false;
      s.y = -20;
      s.advance(.3);
      expect(s.ink, 50);
    },
  );
  test(
    'Slow budget is a trailing active-real window; tapping does not refill it',
    () {
      final b = SlowBudget();
      expect(b.consume(0, 2, true), 2);
      expect(b.consume(2, .5, true), 0);
      expect(b.consume(3, 1, false), 0);
      expect(b.consume(4, 1, true), 0);
      expect(b.consume(7, 1, true), 1);
      expect(b.used(8), closeTo(1, 1e-8));
      final s = game();
      s.beginStroke(const V(100, 0));
      s.advance(2);
      expect(s.gameTime, closeTo(.8, .0001));
      s.cancelDraft();
      s.beginStroke(const V(120, 0));
      s.advance(1);
      expect(s.gameTime, closeTo(1.8, .0001));
    },
  );
  test(
    'Both authored first levels pass with one-second real gestures and no injected bridges',
    () {
      final s = game();
      double? boundaryTime;
      double? entry;
      var previous = 0;
      solve(
        s,
        inspect: (q) {
          if (q.levelIndex != previous) {
            boundaryTime = q.activeTotal;
            entry = q.entryInk;
            previous = q.levelIndex;
          }
        },
      );
      expect(s.phase, Phase.complete);
      expect(boundaryTime, closeTo(300, 20));
      expect(s.activeTotal, closeTo(600, 30));
      expect(s.ink, lessThanOrEqualTo(240));
      expect(entry, isNotNull);
      s.phase = Phase.playing;
      s.die('test');
      s.retry();
      expect(s.levelIndex, 1);
      expect(s.x, 0);
      expect(s.ink, entry);
    },
  );
  test(
    'Starting with zero Ink is recoverable before the first authored gap',
    () {
      final s = game();
      s.ink = 0;
      solve(s);
      expect(s.phase, Phase.complete);
    },
  );
  test('Roof lab blocks eraser rain; a path without a roof fails', () {
    final a = game('roof');
    solve(a);
    expect(a.phase, Phase.complete);
    final b = game('roof');
    solve(b, skip: 'roof');
    expect(b.phase, Phase.dead);
    expect(b.message, contains('çatı'));
  });
  test(
    'Drawn rail carries the marble into its receiver and opens the gate',
    () {
      final s = game('ball');
      solve(s);
      expect(s.phase, Phase.complete);
      expect(s.level.balls.single.captured, isTrue);
      expect(s.level.gates.single.open, isTrue);
      final bad = game('ball');
      solve(bad, skip: 'object');
      expect(bad.phase, Phase.dead);
      expect(bad.level.gates.single.open, isFalse);
    },
  );
  test(
    'Save roundtrip preserves live state and partial stroke, but waits before moving',
    () {
      final s = game('roof');
      draw(s, [const V(244, 96), const V(324, 96)]);
      s.advance(3);
      s.beginStroke(const V(240, 0));
      s.moveStroke(const V(280, 4));
      s.advance(.5);
      final map = cloneJson(s.snapshot());
      final r = InkSession.restore(data('roof'), map);
      expect(r.phase, Phase.ready);
      expect(r.x, s.x);
      expect(r.ink, s.ink);
      expect(r.crumbs.length, s.crumbs.length);
      expect(r.budget.slices, s.budget.slices);
      expect(r.draft!.rawPoint.toJson(), s.draft!.rawPoint.toJson());
      expect(r.saveElapsed, s.saveElapsed);
      expect(r.draft!.points.last.x, s.draft!.points.last.x);
      r.advance(10);
      expect(r.x, s.x);
      r.start();
      expect(r.phase, Phase.resumeStroke);
      r.advance(10);
      expect(r.x, s.x);
      expect(r.beginStroke(const V(0, 200)), isFalse);
      expect(r.beginStroke(r.draft!.points.last), isTrue);
      r.moveStroke(const V(328, 0));
      expect(r.endStroke(), isTrue);
    },
  );
  test('Paused input cannot create or complete a stroke', () {
    final s = game();
    s.beginStroke(const V(320, 0));
    s.moveStroke(const V(350, 0));
    s.pause();
    final points = s.draft!.points.length;
    s.moveStroke(const V(392, 0));
    expect(s.endStroke(), isFalse);
    expect(s.draft!.points.length, points);
    expect(s.ink, 180);
  });
  test('A late old save can never defeat the death/reset fence', () async {
    final store = DelayedStore();
    final j = SaveJournal(store, 'x');
    final old = j.save({'alive': true}, resetEpoch: 0);
    await store.entered.future;
    final fence = j.fence(1, {'alive': false, 'x': 0});
    await Future<void>.delayed(Duration.zero);
    store.release.complete();
    await old;
    await fence;
    final next = SaveJournal(store, 'x');
    expect(await next.load(), {'alive': false, 'x': 0});
    store.values['x.a'] = 'corrupt';
    store.values['x.b'] = 'corrupt';
    expect(await SaveJournal(store, 'x').load(), {'alive': false, 'x': 0});
  });
  test(
    'Corrupt newest journal falls back to previous intact revision',
    () async {
      final store = TestStore();
      final j = SaveJournal(store, 'x');
      await j.save({'n': 1}, resetEpoch: 0);
      await j.save({'n': 2}, resetEpoch: 0);
      store.values['x.a'] = 'torn write';
      expect(await SaveJournal(store, 'x').load(), {'n': 1});
    },
  );
}

class TestStore extends StringStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class DelayedStore extends TestStore {
  final entered = Completer<void>(), release = Completer<void>();
  bool first = true;
  @override
  Future<void> write(String key, String value) async {
    if (first) {
      first = false;
      entered.complete();
      await release.future;
    }
    values[key] = value;
  }
}
