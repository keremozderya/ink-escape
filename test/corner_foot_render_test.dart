import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/ink_game.dart';

import 'climbing_render_test.dart' show renderPose;
import 'corner_foot_test.dart' show cornerScene;

void main() {
  testWidgets('Corner contact renders walking feet without a hand-grip pose', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final s = cornerScene();
      final game = InkGame(s)..onGameResize(Vector2(960, 540));
      await game.onLoad();
      for (var i = 0; i < 3; i++) {
        game.update(.1);
        expect(s.grounded, isTrue);
        expect(s.ledge, isNull);
        expect(s.cornerSupport, isNull);
        final sample = s.groundPointAt(8);
        if (sample != null) {
          expect((sample.x - s.x).abs(), lessThanOrEqualTo(12.001));
        }
        await renderPose(game, 'corner-foot-$i');
      }
      game.onRemove();
    });
    expect(tester.takeException(), isNull);
  });
}
