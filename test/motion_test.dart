import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/presentation/ink_motion.dart';

void main() {
  test('Walk pose stays continuous across both contacts and loop boundary', () {
    for (final d in [0.0, 14.0, 28.0, 42.0]) {
      final a = InkWalkPose.sample(
        d + 28 - 1e-5,
        grounded: true,
        walking: true,
      );
      final b = InkWalkPose.sample(
        d + 28 + 1e-5,
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
    'Foot alternates grounded contact every 14 distance units; idle has no sliding',
    () {
      for (var i = 0; i < 100; i++) {
        final p = InkWalkPose.sample(i * .28, grounded: true, walking: true);
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
}
