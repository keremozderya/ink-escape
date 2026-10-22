import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'package:ink_escape/ink_game.dart';
import 'package:ink_escape/presentation/ink_death.dart';

void main() {
  test(
    'Ink breakup fades smoothly and leaves no permanent body or droplets',
    () {
      final start = InkDeathPose(0);
      expect(start.bodyOpacity, 1);
      expect(start.bodyLift, 0);
      expect(start.drops, isEmpty);
      var previousOpacity = 1.0;
      for (var i = 0; i <= 100; i++) {
        final pose = InkDeathPose(i / 100);
        expect(pose.bodyOpacity, inInclusiveRange(0, previousOpacity));
        previousOpacity = pose.bodyOpacity;
        for (final drop in pose.drops) {
          expect(
            drop.x.isFinite && drop.y.isFinite && drop.angle.isFinite,
            isTrue,
          );
          expect(drop.opacity, inInclusiveRange(0, 1));
          expect(drop.radius, greaterThan(0));
        }
      }
      expect(InkDeathPose(.2).drops, isNotEmpty);
      for (final age in [InkDeathPose.duration, 2.0]) {
        final end = InkDeathPose(age);
        expect(end.bodyOpacity, 0);
        expect(end.rippleOpacity, 0);
        expect(end.stainOpacity, 0);
        expect(end.drops, isEmpty);
      }
    },
  );

  testWidgets(
    'Ground and falling deaths render until the retry menu can appear',
    (tester) async {
      final raw = jsonDecode(
        File('assets/data/prototype_levels.json').readAsStringSync(),
      );
      final data = (raw['story'] as List)
          .map((level) => Map<String, dynamic>.from(level))
          .toList();
      final session = InkSession(data)..start();
      final game = InkGame(session);
      game.onGameResize(Vector2(960, 540));
      await tester.runAsync(() async {
        await game.onLoad();
        for (final grounded in [true, false]) {
          session.grounded = grounded;
          session.y = grounded ? 0 : -310;
          session.die('test');
          game.effect('death', V(session.x, session.y));
          expect(game.deathEffectComplete, isFalse);
          for (final age in [0.0, .12, .26, .48, .72, InkDeathPose.duration]) {
            game.deadAge = age;
            final recorder = ui.PictureRecorder();
            game.render(ui.Canvas(recorder));
            final picture = recorder.endRecording();
            final image = await picture.toImage(960, 540);
            expect(await image.toByteData(), isNotNull);
            image.dispose();
            picture.dispose();
          }
          expect(game.deathEffectComplete, isTrue);
          session.retry();
          game.resetView();
          expect(game.deadAge, 0);
          session.start();
        }
      });
      expect(tester.takeException(), isNull);
    },
  );
}
