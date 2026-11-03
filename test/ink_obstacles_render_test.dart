import 'dart:io';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'package:ink_escape/ink_game.dart';
import 'journey_hud_test.dart' show loadArt;
import 'mechanics_lab_test.dart' show drawLab;

void main() {
  testWidgets(
    'Spikes, hidden and emerging wall teeth use the real game renderer',
    (tester) async {
      await loadArt(tester);
      await tester.runAsync(() async {
        const preview = bool.fromEnvironment('INK_OBSTACLE_PREVIEW');
        for (final id in ['spikes', 'wall-saw']) {
          final s = InkLabCase.byId(id).createSession()..start();
          drawLab(s, s.mechanics!.guides.first.first);
          if (id == 'wall-saw') {
            s.x = 185;
            s.y = s.lines.single.yAt(185)!;
            s.onNatural = false;
          } else {
            s.mechanics!.holdDot = false;
          }
          final game = InkGame(s, initialCamera: id == 'wall-saw' ? 120 : null)
            ..onGameResize(Vector2(960, 540));
          await game.onLoad();
          final directory = Directory('qa/obstacles/$id')
            ..createSync(recursive: true);
          final phases = <InkSawPhase>{};
          var crossedSpikes = false;
          for (var frame = 0; frame <= (id == 'spikes' ? 240 : 300); frame++) {
            if (frame > 0) game.update(1 / 30);
            if (id == 'wall-saw' && frame == 180) s.mechanics!.holdDot = false;
            expect(s.phase, Phase.playing, reason: '$id: ${s.message}');
            String? stage;
            if (frame == 0) stage = 'ready';
            if (id == 'spikes' && s.x > 200 && !crossedSpikes) {
              crossedSpikes = true;
              stage = 'over-spikes';
            }
            if (id == 'wall-saw') {
              final phase = s.level.wallSaws.single.phaseAt(s.gameTime);
              if (phases.add(phase)) stage = phase.name;
              if (frame == 235) stage = 'safe-high-route';
            }
            if (!preview && stage == null) continue;
            final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
            game.render(canvas);
            if (preview) {
              canvas.drawRect(
                const Rect.fromLTWH(0, 0, 960, 79),
                Paint()..color = const Color(0xeff6f1e6),
              );
              final title = TextPainter(
                text: TextSpan(
                  text: id == 'spikes'
                      ? 'Dikenli zemin'
                      : 'Duvardan çıkan döner bıçak',
                  style: const TextStyle(
                    fontFamily: 'Cormorant',
                    fontSize: 32,
                    color: Color(0xff38312a),
                  ),
                ),
                textDirection: TextDirection.ltr,
              )..layout(maxWidth: 900);
              title.paint(canvas, const Offset(25, 10));
              title.dispose();
              final phase = id == 'wall-saw'
                  ? s.level.wallSaws.single.phaseAt(s.gameTime)
                  : null;
              final caption = TextPainter(
                text: TextSpan(
                  text: id == 'spikes'
                      ? 'Dikenlere basmak ölümcül; çizilen kemer ayakları korur.'
                      : phase == InkSawPhase.hidden
                      ? 'Bıçak kâğıdın arkasında: güvenli aralık.'
                      : phase == InkSawPhase.warning
                      ? 'Çıkmadan önce mürekkep işareti verir.'
                      : phase == InkSawPhase.retracting
                      ? 'Bıçak yeniden duvara çekilir.'
                      : 'Temas ölümcül; yüksek çizgi güvenli bir yol sağlar.',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    color: Color(0xff756852),
                  ),
                ),
                textDirection: TextDirection.ltr,
              )..layout(maxWidth: 900);
              caption.paint(canvas, const Offset(27, 49));
              caption.dispose();
            }
            final picture = recorder.endRecording(),
                image = await picture.toImage(960, 540);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            File(
              '${directory.path}/${preview ? frame.toString().padLeft(3, '0') : stage!}.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            picture.dispose();
            image.dispose();
          }
          if (id == 'wall-saw') {
            expect(phases.length, InkSawPhase.values.length);
          } else {
            expect(crossedSpikes, isTrue);
          }
          game.onRemove();
        }
      });
      expect(tester.takeException(), isNull);
    },
  );
}
