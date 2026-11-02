import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';

void main() {
  test(
    'Brittle paper waits for real foot contact and collapses once, on time',
    () {
      final s = InkLabCase.byId('crumble').createSession()..start(),
          lab = s.mechanics!;
      s.advance(3);
      expect(lab.crackAt, isNull);
      s.x = 210;
      s.y = 12;
      s.grounded = false;
      s.advance(.1);
      expect(lab.crackAt, isNull);
      s.y = 0;
      s.grounded = true;
      s.advance(.01);
      expect(lab.crackAt, isNotNull);
      expect(lab.crackContactX, 210);
      s.advance(.4);
      expect(lab.crackProgress, inExclusiveRange(0, 1));
      expect(lab.collapsed, isFalse);
      s.pause();
      final progress = lab.crackProgress;
      s.advance(10);
      expect(lab.crackProgress, progress);
      s.start();
      var breaks = 0;
      s.onEvent = (event, _) {
        if (event == 'crumb') breaks++;
      };
      s.advance(.6);
      expect(lab.collapsed, isTrue);
      expect(s.level.terrain.any((edge) => edge.id == 'lab-crack'), isFalse);
      s.advance(2);
      expect(breaks, 1);
      s.retry();
      expect(s.mechanics!.crackAt, isNull);
      expect(s.mechanics!.collapsed, isFalse);
      expect(s.level.terrain.any((edge) => edge.id == 'lab-crack'), isTrue);
    },
  );
}
