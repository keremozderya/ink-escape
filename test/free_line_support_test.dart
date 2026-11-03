import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'mechanics_lab_test.dart' show drawLab;

const screenshotStroke = [
  V(33, 33),
  V(45, 22),
  V(78, 0),
  V(120, -26),
  V(170, -49),
  V(201, -61),
];

InkSession screenshotScene({bool reverse = false}) {
  final s = InkLabCase.byId('ramp').createSession()..start();
  drawLab(s, screenshotStroke, reverse: reverse);
  s.mechanics!.holdDot = false;
  return s;
}

void main() {
  for (final fps in [30, 60, 120]) {
    for (final reverse in [false, true]) {
      test(
        'Free descending tip is used above paper at $fps FPS (reverse=$reverse)',
        () {
          final s = screenshotScene(reverse: reverse);
          final events = <String>[];
          s.onEvent = (event, _) => events.add(event);
          var touchedInk = false;
          for (var i = 0; i < fps * 3 && s.phase == Phase.playing; i++) {
            s.advance(1 / fps);
            for (final (height, _) in s.lines.single.crossingsAt(s.x)) {
              expect(
                height > s.y + .75 && height < s.y + InkSession.dotHeight,
                isFalse,
                reason:
                    'The body must not walk through the descending contour at x=${s.x}, y=${s.y}, ink=$height',
              );
            }
            if (s.x < 75 && s.grounded && !s.onNatural && s.y > .75) {
              touchedInk = true;
            }
          }
          expect(events, contains('jump'));
          expect(
            touchedInk,
            isTrue,
            reason:
                'Dot must get onto the exposed tip before crossing the paper contact',
          );
          expect(s.x, greaterThan(100));
        },
      );
    }
  }
  test('A stroke completed across the already walking body remains usable', () {
    final s = screenshotScene()..x = 65;
    var rose = false;
    for (var i = 0; i < 360 && s.phase == Phase.playing; i++) {
      s.advance(1 / 120);
      rose |= s.y > 5;
      if (i > 30) {
        for (final (height, _) in s.lines.single.crossingsAt(s.x)) {
          expect(
            height > s.y + .75 && height < s.y + InkSession.dotHeight,
            isFalse,
          );
        }
      }
    }
    expect(rose, isTrue);
    expect(s.x, greaterThan(100));
    expect(s.phase, Phase.playing);
  });

  test(
    'A connected but unreachable free tip blocks instead of pulling Dot upward',
    () {
      final s = InkLabCase.byId('ramp').createSession()..start();
      drawLab(s, [const V(25, 60), const V(100, 0), const V(160, -40)]);
      final events = <String>[];
      s.onEvent = (event, _) => events.add(event);
      s.mechanics!.holdDot = false;
      s.advance(5);
      expect(events, isNot(contains('jump')));
      expect(s.y, closeTo(0, 1e-7));
      expect(s.x, lessThan(100));
      expect(s.phase, Phase.dead);
      expect(s.message, contains('3 saniyedir'));
    },
  );
  test(
    'Erasing the paper contact removes the old free-entry hop and barrier',
    () {
      final s = screenshotScene();
      s.advance(
        .05,
      ); // Populate the collision cache before the eraser changes it.
      expect(InkEraser(const V(78, 0)).erase(s.lines.single), isTrue);
      final events = <String>[];
      s.onEvent = (event, _) => events.add(event);
      s.advance(2);
      expect(events, isNot(contains('jump')));
      expect(s.x, greaterThan(100));
      expect(s.phase, Phase.playing);
    },
  );
  test(
    'An interrupted free-entry hop resumes with the same position and velocity',
    () {
      final raw = jsonDecode(
        File('assets/data/prototype_levels.json').readAsStringSync(),
      );
      final data = (raw['story'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final s = InkSession(data)..start();
      s.ink = 240;
      s.x = 190;
      drawLab(s, screenshotStroke.map((p) => p + const V(190, 0)).toList());
      while (s.grounded && s.x < 225) {
        s.advance(1 / 120);
      }
      expect(s.grounded, isFalse);
      expect(s.vy, greaterThan(0));
      s.advance(.12);
      s.pause();
      final r = InkSession.restore(data, s.snapshot());
      s.start();
      r.start();
      for (var i = 0; i < 240; i++) {
        s.advance(1 / 120);
        r.advance(1 / 120);
        expect(r.x, closeTo(s.x, 1e-7));
        expect(r.y, closeTo(s.y, 1e-7));
        expect(r.vy, closeTo(s.vy, 1e-7));
        expect(r.phase, s.phase);
      }
    },
  );
}
