import 'package:flutter_test/flutter_test.dart';
import 'dart:math' as math;
import 'package:ink_escape/presentation/ink_motion.dart';
import 'package:ink_escape/core/ink_model.dart';

void main() {
  test('Feet follow a short vertical step instead of sampling flat air', () {
    final s = InkSession([
      {'number': 1, 'title': 'Step', 'width': 2000, 'cells': []},
    ])..start();
    s.level.terrain.add(Surface('approach', const V(0, 0), const V(100, 0)));
    s.lines.add(
      InkLine('step', [const V(100, 0), const V(100, 24), const V(160, 24)]),
    );
    s.x = 100;
    s.y = 12;
    final below = s.groundPointAt(-4)!, above = s.groundPointAt(4)!;
    expect(below.x, 100);
    expect(above.x, 100);
    expect(below.y, 8);
    expect(above.y, 16);
    expect(math.atan(s.groundSlope), closeTo(math.pi / 2, 1e-7));
  });
  test('Walk pose stays continuous across both contacts and loop boundary', () {
    for (final d in [0.0, 20.0, 40.0, 60.0]) {
      final a = InkWalkPose.sample(
        d + 40 - 1e-5,
        grounded: true,
        walking: true,
      );
      final b = InkWalkPose.sample(
        d + 40 + 1e-5,
        grounded: true,
        walking: true,
      );
      expect((a.front.x - b.front.x).abs(), lessThan(.001));
      expect((a.back.x - b.back.x).abs(), lessThan(.001));
      expect((a.rise - b.rise).abs(), lessThan(.001));
      expect((a.width - b.width).abs(), lessThan(.001));
      expect((a.height - b.height).abs(), lessThan(.001));
    }
  });
  test(
    'Foot alternates grounded contact every 20 distance units; idle has no sliding',
    () {
      for (var i = 0; i < 100; i++) {
        final p = InkWalkPose.sample(i * .4, grounded: true, walking: true);
        expect(p.front.lift, greaterThanOrEqualTo(0));
        expect(p.back.lift, greaterThanOrEqualTo(0));
        expect(p.front.planted != p.back.planted, isTrue);
        expect(p.front.planted ? p.front.lift : p.back.lift, 0);
      }
      final a = InkWalkPose.sample(4, grounded: true, walking: false, time: 0);
      final b = InkWalkPose.sample(4, grounded: true, walking: false, time: 5);
      expect(a.front.x, b.front.x);
      expect(a.front.lift, 0);
      expect(b.front.lift, 0);
    },
  );

  test(
    'Steep terrain keeps feet and hips within reach without inverted legs',
    () {
      for (final degrees in [-89.0, -55.0, 0.0, 55.0, 89.0]) {
        final angle = degrees * math.pi / 180;
        final stride = InkGroundPose.strideForAngle(angle);
        expect(stride, inInclusiveRange(.45, 1));
        for (var i = 0; i < 160; i++) {
          final walk = InkWalkPose.sample(i / 4, grounded: true, walking: true);
          final feet = InkGroundPose.place(
            walk,
            grounded: true,
            angle: angle,
            stride: stride,
            sampleGround: (d) => (d * math.cos(angle), d * math.sin(angle)),
          );
          final hipY = -9 - walk.rise - feet.bodyLift;
          for (final foot in [feet.back, feet.front]) {
            expect(foot.y - hipY, inInclusiveRange(5.5, 26));
            expect(foot.x.abs(), lessThan(12));
            expect(foot.angle.isFinite, isTrue);
          }
        }
      }
    },
  );

  test('A stopped gait settles into idle instead of marching in place', () {
    final idle = InkWalkPose.sample(13, grounded: true, walking: false);
    final stopped = InkWalkPose.sample(
      13,
      grounded: true,
      walking: true,
      movement: 0,
    );
    expect(stopped.front.x, idle.front.x);
    expect(stopped.back.x, idle.back.x);
    expect(stopped.front.lift, 0);
    expect(stopped.back.lift, 0);
    for (final weight in [.0, .2, .5, .8, 1.0]) {
      final pose = InkWalkPose.sample(
        13,
        grounded: true,
        walking: true,
        movement: weight,
      );
      expect(pose.front.lift, greaterThanOrEqualTo(0));
      expect(pose.back.lift, greaterThanOrEqualTo(0));
    }
  });

  test(
    'Leaning body attachments and leg bends stay below the body on climbs',
    () {
      for (final degrees in [-55.0, 0.0, 30.0, 55.0, 89.0]) {
        final angle = degrees * math.pi / 180;
        for (var i = 0; i < 160; i++) {
          final walk = InkWalkPose.sample(i / 4, grounded: true, walking: true);
          final feet = InkGroundPose.place(
            walk,
            grounded: true,
            angle: angle,
            stride: InkGroundPose.strideForAngle(angle),
            sampleGround: (d) => (d * math.cos(angle), d * math.sin(angle)),
          );
          final rig = InkBodyRig(
            walk.rise + feet.bodyLift,
            walk.lean + angle * .12,
            walk.width,
            walk.height,
          );
          for (final pair in [(feet.back, -5.0), (feet.front, 5.0)]) {
            final hip = rig.point(pair.$2, -9);
            final curve = InkLegCurve(hip, (pair.$1.x, pair.$1.y - 1.2));
            expect(curve.ankle.$2 - hip.$2, greaterThan(2));
            expect(curve.first.$2, inInclusiveRange(hip.$2, curve.ankle.$2));
            expect(
              curve.second.$2,
              inInclusiveRange(curve.first.$2, curve.ankle.$2),
            );
          }
        }
      }
    },
  );
}
