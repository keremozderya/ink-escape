import 'dart:io';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'package:ink_escape/ink_game.dart';
import 'mechanics_lab_test.dart' show prepareLab, drawPendingPlan;

void main() {
  testWidgets(
    'All experimental scenery and motion renders through the real game',
    (tester) async {
      await tester.runAsync(() async {
        for (final spec in InkLabCase.all) {
          final s = spec.createSession()..start();
          prepareLab(s);
          final game = InkGame(s)..onGameResize(Vector2(960, 540));
          await game.onLoad();
          s.mechanics!.showGuide = true;
          for (var i = 0; i < 396; i++) {
            drawPendingPlan(s);
            game.update(1 / 120);
            expect(s.x.isFinite && s.y.isFinite, isTrue);
            expect(s.phase, Phase.playing, reason: spec.id);
          }
          final recorder = ui.PictureRecorder();
          game.render(ui.Canvas(recorder));
          final picture = recorder.endRecording();
          final image = await picture.toImage(960, 540);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory('qa').createSync();
          File(
            'qa/lab-render-${spec.id}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
          picture.dispose();
          game.onRemove();
        }
      });
      expect(tester.takeException(), isNull);
    },
  );
}
