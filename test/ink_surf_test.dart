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
    'Visual rotation is frame-rate independent and takes the shortest turn',
    () {
      for (final fps in [30, 60, 120]) {
        final surf = InkSurfAnimation()..begin(0, angle: -1);
        for (var i = 0; i < fps; i++) {
          surf.follow(.7, 1 / fps);
        }
        expect(surf.rideAngle, closeTo(.7 + (-1 - .7) * math.exp(-18), 1e-10));
      }
      final surf = InkSurfAnimation()..begin(0, angle: math.pi - .02);
      surf.follow(-math.pi + .02, 1 / 60);
      expect(surf.rideAngle, inExclusiveRange(math.pi - .02, math.pi + .02));
      final angle = surf.rideAngle;
      surf.follow(0, 0);
      expect(surf.rideAngle, angle);
      surf.reset();
      expect(surf.rideAngle, 0);
    },
  );

  test(
    'A rough rail has a steadier board tangent while physical motion is unchanged',
    () {
      final s = InkLabCase.byId('slide').createSession()..start();
      final rough = <V>[const V(130, 0)];
      for (var i = 1; i <= 34; i++) {
        rough.add(V(130 + i * 3.0, -i * 5.8 + (i.isEven ? .6 : -.6)));
      }
      rough.add(const V(275, -197.2));
      // Deliberately retain dense, uneven geometry to expose segment-angle jumps.
      s.lines.add(InkLine('rough', rough));
      s.mechanics!.holdDot = false;
      double? previousRail, previousBoard;
      var railChange = 0.0, boardChange = 0.0, samples = 0;
      for (var i = 0; i < 1200 && s.phase == Phase.playing; i++) {
        s.advance(1 / 120);
        final lab = s.mechanics!;
        if (!lab.sliding || s.x < 145 || s.x > 219) continue;
        if (previousRail != null) {
          railChange += (lab.railAngle - previousRail).abs();
          boardChange += (lab.surfAngle - previousBoard!).abs();
        }
        previousRail = lab.railAngle;
        previousBoard = lab.surfAngle;
        samples++;
      }
      expect(samples, greaterThan(20));
      expect(railChange, greaterThan(.5));
      expect(boardChange, lessThan(railChange * .35));
    },
  );

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
