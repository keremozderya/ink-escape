import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/presentation/ink_motion.dart';

void main() {
  test(
    'Walk, fall, grip and landing weights ease across changes and pause',
    () {
      final pose = InkAnimationBlend();
      pose.advance(1 / 120, grounded: false, gripping: false, vy: -200);
      expect(pose.support, inExclusiveRange(0, 1));
      expect(pose.fall, inExclusiveRange(0, .8));
      final falling = pose.fall;
      pose.advance(0, grounded: false, gripping: true, vy: 0);
      expect(pose.grip, 0);
      expect(pose.fall, falling);
      pose.advance(1 / 120, grounded: false, gripping: true, vy: 0);
      expect(pose.grip, inExclusiveRange(0, 1));
      expect(pose.fall, lessThan(falling));
      for (var frame = 0; frame < 120; frame++) {
        pose.advance(1 / 120, grounded: false, gripping: true, vy: 0);
      }
      expect(pose.grip, closeTo(1, 1e-6));
      pose.advance(1 / 120, grounded: true, gripping: false, vy: 0);
      expect(pose.grip, inExclusiveRange(0, 1));
      expect(pose.support, inExclusiveRange(0, 1));
    },
  );
  test('Animation settling is independent of render frame rate', () {
    final a = InkAnimationBlend(), b = InkAnimationBlend();
    a.advance(.2, grounded: false, gripping: true, vy: 0);
    for (var i = 0; i < 24; i++) {
      b.advance(1 / 120, grounded: false, gripping: true, vy: 0);
    }
    expect(a.support, closeTo(b.support, 1e-9));
    expect(a.grip, closeTo(b.grip, 1e-9));
  });
  test(
    'Arm target converts through the exact body transform without drift',
    () {
      for (final angle in [-.3, 0.0, .3]) {
        final rig = InkBodyRig(3, angle, 1.01, .98);
        final local = rig.inverse(14, -12),
            world = rig.point(local.$1, local.$2);
        expect(world.$1, closeTo(14, 1e-8));
        expect(world.$2, closeTo(-12, 1e-8));
      }
    },
  );
}
