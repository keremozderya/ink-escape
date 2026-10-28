import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'package:ink_escape/presentation/ink_motion.dart';

void main() {
  test(
    'The atlas palm touches the rim throughout the supported part of a pull',
    () {
      for (var i = 0; i <= 55; i++) {
        final rise = i / 100;
        final y = -LedgeGrip.hangDepth * (1 - rise);
        final pose = InkLedgeArmPose(LedgeGrip.bodyInset, y, rise);
        final palm = pose.transform(
          InkLedgeArmPose.palmX,
          InkLedgeArmPose.palmY,
        );
        final shoulder = pose.transform(
          InkLedgeArmPose.shoulderX,
          InkLedgeArmPose.shoulderY,
        );
        expect(palm.$1, closeTo(LedgeGrip.bodyInset, 1e-7));
        expect(palm.$2, closeTo(y, 1e-7));
        expect(shoulder.$1, InkLedgeArmPose.shoulderX);
        expect(shoulder.$2, InkLedgeArmPose.shoulderY);
        expect(pose.lengthScale, inInclusiveRange(.5, 1.3));
      }
    },
  );

  test(
    'The arm returns continuously to its existing sprite pose after stepping up',
    () {
      final pose = InkLedgeArmPose(14, 0, 1);
      for (final point in [
        (InkLedgeArmPose.palmX, InkLedgeArmPose.palmY),
        (InkLedgeArmPose.shoulderX, InkLedgeArmPose.shoulderY),
      ]) {
        final actual = pose.transform(point.$1, point.$2);
        expect(actual.$1, closeTo(point.$1, 1e-7));
        expect(actual.$2, closeTo(point.$2, 1e-7));
      }
    },
  );
}
