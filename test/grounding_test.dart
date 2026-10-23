import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/ink_game.dart';
import 'package:ink_escape/presentation/paper_world.dart';

Future<ui.Image> tile(Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(
    recorder,
  ).drawRect(const Rect.fromLTWH(0, 0, 2, 2), Paint()..color = color);
  final picture = recorder.endRecording();
  final image = await picture.toImage(2, 2);
  picture.dispose();
  return image;
}

Future<int> alphaAt(PaperWorld world, double ground, int x, int y) async {
  final recorder = ui.PictureRecorder();
  world.background(Canvas(recorder), 0, groundY: ground);
  final picture = recorder.endRecording();
  final image = await picture.toImage(480, 853);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final alpha = bytes!.getUint8((y * 480 + x) * 4 + 3);
  image.dispose();
  picture.dispose();
  return alpha;
}

void main() {
  testWidgets(
    'Both scenery layers reach the ground when its position changes',
    (tester) async {
      await tester.runAsync(() async {
        final black = await tile(Colors.black);
        final world = PaperWorld(black, black, []);
        for (final ground in [588.0, 650.0, InkGame.baseline]) {
          expect(
            await alphaAt(world, ground, 210, ground.toInt() - 5),
            greaterThan(150),
          );
        }
        black.dispose();
      });
    },
  );
  testWidgets('Notes rest on the ground instead of floating above the scene', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final clear = await tile(Colors.transparent);
      final world = PaperWorld(clear, clear, [const PaperMemory(0, false)]);
      for (final ground in [588.0, 650.0, InkGame.baseline]) {
        expect(
          await alphaAt(world, ground, 210, ground.toInt() - 50),
          greaterThan(200),
        );
        expect(await alphaAt(world, ground, 210, 280), 0);
      }
      clear.dispose();
    });
  });
  testWidgets(
    'The bundled irregular ruins footer touches ground across the viewport',
    (tester) async {
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(
          File('assets/images/paper_ruins.png').readAsBytesSync(),
        );
        final ruins = (await codec.getNextFrame()).image;
        final clear = await tile(Colors.transparent);
        final world = PaperWorld(clear, ruins, []);
        for (final camera in [0.0, 1350.0]) {
          final recorder = ui.PictureRecorder();
          world.background(Canvas(recorder), camera, groundY: InkGame.baseline);
          final picture = recorder.endRecording();
          final image = await picture.toImage(480, 853);
          final bytes = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          for (var x = 0; x < 480; x++) {
            expect(
              bytes!.getUint8(
                ((InkGame.baseline.toInt() - 1) * 480 + x) * 4 + 3,
              ),
              greaterThan(5),
              reason: 'Floating footer at x=$x, camera=$camera',
            );
          }
          image.dispose();
          picture.dispose();
        }
        clear.dispose();
        ruins.dispose();
        codec.dispose();
      });
    },
  );
}
