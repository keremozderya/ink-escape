import 'dart:io';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/ink_game.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'journey_hud_test.dart' show loadArt;
import 'free_line_support_test.dart' show screenshotScene;

void main() {
  testWidgets(
    'The real game shows a bounded entry hop and feet riding the free-origin contour',
    (tester) async {
      await loadArt(tester);
      await tester.runAsync(() async {
        const preview = bool.fromEnvironment('INK_FREE_ENTRY_PREVIEW');
        final s = screenshotScene(),
            game = InkGame(s)..onGameResize(Vector2(960, 540));
        await game.onLoad();
        final directory = Directory('qa/free_entry')
          ..createSync(recursive: true);
        var hopped = false, rode = false, paused = false, handed = false;
        for (var frame = 0; frame <= 120; frame++) {
          if (frame > 0) game.update(1 / 30);
          String? stage;
          if (frame == 0) stage = 'ready';
          if (!s.grounded && s.vy > 0 && !hopped) {
            hopped = true;
            stage = 'entry-hop';
          }
          if (s.grounded && !s.onNatural && s.y > .75 && !rode) {
            rode = true;
            stage = 'on-ink';
            final time = s.gameTime, at = V(s.x, s.y);
            s.pause();
            game.update(1);
            expect(s.gameTime, time);
            expect(V(s.x, s.y).distance(at), 0);
            s.start();
            paused = true;
          }
          if (s.x > 95 && !handed) {
            handed = true;
            stage = 'handoff';
          }
          if (!preview && stage == null) continue;
          final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
          game.render(canvas);
          if (preview) {
            canvas.drawRect(
              const Rect.fromLTWH(0, 0, 960, 76),
              Paint()..color = const Color(0xeff6f1e6),
            );
            final title = TextPainter(
              text: const TextSpan(
                text: 'Serbest başlayan çizgi: gerçek ayak teması',
                style: TextStyle(
                  fontFamily: 'Cormorant',
                  fontSize: 29,
                  color: Color(0xff38312a),
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: 900);
            title.paint(canvas, const Offset(25, 12));
            title.dispose();
            final caption = TextPainter(
              text: TextSpan(
                text: !s.grounded && s.vy > 0
                    ? 'Ulaşılabilen uca kısa sıçrama'
                    : s.grounded && !s.onNatural
                    ? 'Dot çizginin üstünde ilerliyor'
                    : 'Kâğıda temas eden çizgi korunuyor',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15,
                  color: Color(0xff756852),
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: 900);
            caption.paint(canvas, const Offset(27, 47));
            caption.dispose();
          }
          final picture = recorder.endRecording(),
              image = await picture.toImage(960, 540);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final name = preview ? frame.toString().padLeft(3, '0') : stage!;
          File(
            '${directory.path}/$name.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          picture.dispose();
          image.dispose();
        }
        expect(hopped && rode && paused, isTrue);
        game.onRemove();
      });
      expect(tester.takeException(), isNull);
    },
  );
}
