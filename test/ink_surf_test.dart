import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'package:ink_escape/presentation/ink_surf.dart';
import 'mechanics_lab_test.dart' show prepareLab, runLab;

InkSession slidingRamp() {
  final s = InkLabCase.byId('ramp').createSession()..start();
  prepareLab(s);
  s.advance(3);
  expect(s.mechanics!.sliding, isTrue);
  return s;
}

void main() {
  test(
    'The departing sketch travels eight degrees away from Dot and fades completely',
    () {
      for (final angle in [-1.0, 0.0, .7]) {
        final exit = InkSlideExit(
              const V(100, 40),
              V(math.cos(angle), math.sin(angle)) * 140,
              10,
            ),
            board = InkSurfFlight(exit);
        expect(
          math.atan2(board.velocity.y, board.velocity.x) - angle,
          inInclusiveRange(5 * math.pi / 180, 10 * math.pi / 180),
        );
        expect(board.position(10).distance(exit.position), 0);
        expect(board.position(10.3).distance(exit.position), greaterThan(20));
        expect(board.opacity(10.4), inExclusiveRange(0, 1));
        expect(board.opacity(10 + InkSurfFlight.duration), closeTo(0, 1e-9));
      }
    },
  );

  test(
    'A real rail departure emits one board impulse while the original ramp still completes',
    () {
      final s = slidingRamp(), releases = <InkSlideExit>[];
      s.onEvent = (event, _) {
        if (event == 'surfRelease') releases.add(s.mechanics!.lastSlideExit!);
      };
      runLab(s);
      expect(s.phase, Phase.complete);
      expect(releases, hasLength(1));
      expect(releases.single.velocity.x, greaterThan(50));
      expect(releases.single.velocity.y, greaterThan(20));
      expect(releases.single.angle, inExclusiveRange(0, math.pi / 2));
    },
  );

  test(
    'Removing the contacted ink releases both Dot and the board without teleporting',
    () {
      final s = slidingRamp(),
          lab = s.mechanics!,
          before = V(s.x, s.y),
          paid = s.lines.single.cost;
      var releases = 0;
      s.onEvent = (event, _) {
        if (event == 'surfRelease') releases++;
      };
      expect(InkEraser(before).erase(s.lines.single), isTrue);
      s.advance(1 / 120);
      expect(lab.motion, InkLabMotion.airborne);
      expect(s.grounded, isFalse);
      expect(V(s.x, s.y).distance(before), lessThan(3));
      expect(releases, 1);
      expect(s.lines.single.cost, paid);
      expect(s.lines.single.contours, hasLength(2));
    },
  );

  test(
    'A cut ahead ends the current connected rail rather than sliding across the gap',
    () {
      final s = slidingRamp(), lab = s.mechanics!, line = s.lines.single;
      final cut = line.atDistance(140).$1;
      InkEraser(cut).erase(line);
      s.advance(1 / 120);
      expect(lab.sliding, isTrue);
      for (var i = 0; i < 200 && lab.lastSlideExit == null; i++) {
        s.advance(1 / 120);
      }
      expect(lab.lastSlideExit, isNotNull);
      expect(
        lab.lastSlideExit!.position.distance(line.contours.first.last),
        lessThan(2),
      );
      expect(lab.lastSlideExit!.position.x, lessThan(cut.x));
    },
  );

  test(
    'A cut behind preserves current speed and position on the remaining rail',
    () {
      final s = slidingRamp();
      s.advance(.4);
      final lab = s.mechanics!, before = V(s.x, s.y), speed = lab.speed;
      InkEraser(const V(130, 0)).erase(s.lines.single);
      s.advance(1 / 120);
      expect(lab.sliding, isTrue);
      expect(s.x, greaterThan(before.x));
      expect(V(s.x, s.y).distance(before), lessThan(3));
      expect(lab.speed, greaterThan(speed - 2));
      expect(lab.lastSlideExit, isNull);
    },
  );

  test(
    'Short-lived friction flecks and departing boards have bounded storage',
    () {
      final surf = InkSurfAnimation();
      for (var i = 0; i < 100; i++) {
        surf.friction(V(i.toDouble(), 0), -.8, 1);
      }
      expect(surf.dust, hasLength(InkSurfAnimation.maxDust));
      for (var i = 0; i < 5; i++) {
        surf.release(const InkSlideExit(V(0, 0), V(100, 60), 1));
      }
      expect(surf.flights, hasLength(InkSurfAnimation.maxFlights));
      surf.prune(3);
      expect(surf.flights, isEmpty);
      expect(surf.dust, isEmpty);
    },
  );
}
