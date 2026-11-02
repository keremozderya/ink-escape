import 'dart:io';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'package:ink_escape/ink_game.dart';
import 'journey_hud_test.dart' show loadArt;
import 'mechanics_lab_test.dart' show prepareLab;

void main() {
  testWidgets(
    'Flat paper folds and layered cracks render through the real game',
    (tester) async {
      await loadArt(tester);
      await tester.runAsync(() async {
        const preview = bool.fromEnvironment('FOLD_PREVIEW');
        for (final id in ['fold', 'fold-cover', 'crumble']) {
          final s = InkLabCase.byId(id).createSession()..start();
          if (id == 'crumble') {
            s.mechanics!.holdDot = false;
          } else {
            prepareLab(s);
          }
          final game = InkGame(s)..onGameResize(Vector2(960, 540));
          await game.onLoad();
          final directory = preview
              ? 'qa/flat_fold_preview/$id'
              : 'qa/flat_fold_frames/$id';
          Directory(directory).createSync(recursive: true);
          for (var i = 0; i <= (id == 'crumble' ? 162 : 120); i++) {
            if (i > 0) game.update(1 / 30);
            if (preview && i.isOdd) continue;
            if (!preview && ![0, 50, 65, 85, 104, 129].contains(i)) continue;
            final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
            if (preview) canvas.scale(2 / 3);
            game.render(canvas);
            if (preview) {
              canvas.drawRect(
                const Rect.fromLTWH(0, 0, 960, 90),
                Paint()..color = const Color(0xeff6f1e6),
              );
              final title = TextPainter(
                text: TextSpan(
                  text: s.mechanics!.spec.title('tr'),
                  style: const TextStyle(
                    fontFamily: 'Cormorant',
                    fontSize: 32,
                    color: Color(0xff38312a),
                  ),
                ),
                textDirection: TextDirection.ltr,
              )..layout(maxWidth: 900);
              title.paint(canvas, const Offset(26, 14));
              title.dispose();
              final page = s.mechanics!.paper;
              final text = page == null
                  ? !s.mechanics!.collapsed
                        ? 'Kalın kâğıt katmanlarında çatlaklar yayılarak büyür.'
                        : 'Aynı yırtık kenarlar, ayrı kâğıt parçaları olarak düşer.'
                  : !page.pressed
                  ? 'Önce çiz. Dot yürüyerek düğmeye bassın.'
                  : !page.settled
                  ? 'Kâğıt katlanıyor, çizim onunla birlikte değişiyor.'
                  : page.backFacing
                  ? 'Ön yüzdeki mürekkep artık kâğıdın arkasında.'
                  : 'Köşe aynı düzlemde kat izinin öbür tarafına kapanır.';
              final caption = TextPainter(
                text: TextSpan(
                  text: text,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    color: Color(0xff756852),
                  ),
                ),
                textDirection: TextDirection.ltr,
              )..layout(maxWidth: 900);
              caption.paint(canvas, const Offset(28, 56));
              caption.dispose();
            }
            final picture = recorder.endRecording(),
                im = await picture.toImage(
                  preview ? 640 : 960,
                  preview ? 360 : 540,
                );
            final data = await im.toByteData(format: ui.ImageByteFormat.png);
            File(
              '$directory/${i.toString().padLeft(3, '0')}.png',
            ).writeAsBytesSync(data!.buffer.asUint8List());
            im.dispose();
            picture.dispose();
          }
          if (id != 'crumble') {
            expect(s.phase, Phase.playing, reason: id);
            expect(s.mechanics!.paper!.settled, isTrue);
          } else {
            expect(s.mechanics!.collapsed, isTrue);
          }
          game.onRemove();
        }
      });
      expect(tester.takeException(), isNull);
    },
  );
}
