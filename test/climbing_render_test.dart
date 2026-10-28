import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'package:ink_escape/ink_game.dart';

import 'ledge_grip_test.dart' show ledgeScene;

Future<void> renderPose(InkGame game, String name) async {
  final p = game.point(V(game.session.x, game.session.y)) * game.scale;
  final recorder = ui.PictureRecorder();
  final c = ui.Canvas(recorder)
    ..scale(3)
    ..translate(50 - p.dx, 75 - p.dy);
  game.render(c);
  final picture = recorder.endRecording();
  final image = await picture.toImage(300, 300);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  Directory('qa').createSync();
  File('qa/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
}

void main() {
  testWidgets(
    'Slope, short-step and ledge climbing poses remain finite when rendered',
    (tester) async {
      await tester.runAsync(() async {
        for (final angle in [0.0, 55.0, 89.0]) {
          final s = InkSession([
            {'number': 1, 'title': 'Climb', 'width': 2000, 'cells': []},
          ])..start();
          s.level.terrain.clear();
          s.level.terrain.add(
            Surface('base', const V(-100, 0), const V(100, 0)),
          );
          if (angle == 89) {
            s.lines.add(
              InkLine('step', [
                const V(100, 0),
                const V(100, 24),
                const V(200, 24),
              ]),
            );
            s.x = 99.9;
          } else {
            final rise = 100 * math.tan(angle * math.pi / 180);
            s.level.terrain.add(
              Surface('slope', const V(100, 0), V(200, rise)),
            );
            s.x = 98;
          }
          final game = InkGame(s)..onGameResize(Vector2(960, 540));
          await game.onLoad();
          for (var frame = 0; frame < 45; frame++) {
            game.update(1 / 120);
            expect(s.phase, Phase.playing);
            expect(s.grounded, isTrue);
            expect(game.scale.isFinite, isTrue);
            if (frame == 20 || frame == 40) {
              await renderPose(game, 'climb-${angle.toInt()}-$frame');
            }
          }
          game.onRemove();
        }
        final s = ledgeScene()..advance(1 / 120);
        final game = InkGame(s)..onGameResize(Vector2(960, 540));
        await game.onLoad();
        game.update(.5);
        await renderPose(game, 'grip-actual-hang');
        for (var i = 0; i < 3; i++) {
          s.pullLedge();
          game.update(.2);
        }
        await renderPose(game, 'grip-actual-pull');
        for (var i = 0; i < 2; i++) {
          s.pullLedge();
          game.update(.2);
        }
        game.update(.6);
        expect(s.ledge, isNull);
        expect(s.grounded, isTrue);
        await renderPose(game, 'grip-actual-landed');
        game.onRemove();
      });
      expect(tester.takeException(), isNull);
    },
  );
}
