import 'dart:io';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'package:ink_escape/ink_game.dart';
import 'package:ink_escape/presentation/ink_surf.dart';
import 'journey_hud_test.dart' show loadArt;
import 'mechanics_lab_test.dart' show drawLab, prepareLab;

void main() {
  testWidgets(
    'Local erasing, surf stance, friction and departing ink render in the real game',
    (tester) async {
      await loadArt(tester);
      await tester.runAsync(() async {
        const preview = bool.fromEnvironment('INK_SURF_PREVIEW');
        for (final id in ['eraser', 'ramp']) {
          final s = InkLabCase.byId(id).createSession()..start();
          if (id == 'eraser') {
            drawLab(s, s.mechanics!.guides.first.first);
          } else {
            prepareLab(s);
          }
          final game = InkGame(s)..onGameResize(Vector2(960, 540));
          await game.onLoad();
          final directory = Directory(
            'qa/${preview ? 'surf_preview' : 'surf_frames'}/$id',
          )..createSync(recursive: true);
          final captured = <String>{};
          var rode = false, released = false, faded = false, paused = false;
          for (var i = 0; i <= 180; i++) {
            if (i > 0) game.update(1 / 30);
            final lab = s.mechanics!;
            String? stage;
            if (i == 0) stage = 'ready';
            if (id == 'eraser' && i == 150) stage = 'local-cut';
            if (id == 'ramp') {
              if (lab.sliding && game.surf.dust.length >= 4 && !rode) {
                rode = true;
                stage = 'riding';
              }
              if (lab.sliding &&
                  lab.railAngle.abs() < .3 &&
                  !captured.contains('bowl')) {
                stage = 'bowl';
              }
              if (game.surf.flights.isNotEmpty) {
                if (!released) {
                  released = true;
                  stage = 'release';
                }
                final board = game.surf.flights.first;
                if (s.gameTime - board.started > .4 &&
                    !captured.contains('flight')) {
                  stage = 'flight';
                }
                if (!paused) {
                  s.pause();
                  final time = s.gameTime,
                      at = board.position(time),
                      alpha = board.opacity(time);
                  game.update(2);
                  expect(s.gameTime, time);
                  expect(board.position(s.gameTime).distance(at), 0);
                  expect(board.opacity(s.gameTime), alpha);
                  s.start();
                  paused = true;
                }
              }
              if (released && game.surf.flights.isEmpty && !faded) {
                faded = true;
                stage = 'faded';
              }
            }
            expect(
              game.surf.dust.length,
              lessThanOrEqualTo(InkSurfAnimation.maxDust),
            );
            if (preview && i.isOdd && stage == null) continue;
            if (!preview && stage == null) continue;
            final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
            game.render(canvas);
            if (preview) {
              canvas.drawRect(
                const Rect.fromLTWH(0, 0, 960, 90),
                Paint()..color = const Color(0xeff6f1e6),
              );
              final title = TextPainter(
                text: TextSpan(
                  text: id == 'eraser'
                      ? 'Silgi yalnız dokunduğu mürekkebi siler'
                      : 'Mürekkep surf tahtası',
                  style: const TextStyle(
                    fontFamily: 'Cormorant',
                    fontSize: 32,
                    color: Color(0xff38312a),
                  ),
                ),
                textDirection: TextDirection.ltr,
              )..layout(maxWidth: 910);
              title.paint(canvas, const Offset(26, 14));
              title.dispose();
              final caption = TextPainter(
                text: TextSpan(
                  text: id == 'eraser'
                      ? 'Kalan çizgi parçaları görünür ve yürünebilir kalır.'
                      : lab.sliding
                      ? 'Tahta ayakların altında; küçük mürekkep izleri geride kalır.'
                      : lab.motion == InkLabMotion.airborne
                      ? 'Tahta 8° farklı yöne uçar ve havada solar.'
                      : 'Dik çizgiye kısa bir atlayış, ardından kayış.',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    color: Color(0xff756852),
                  ),
                ),
                textDirection: TextDirection.ltr,
              )..layout(maxWidth: 910);
              caption.paint(canvas, const Offset(28, 56));
              caption.dispose();
            }
            final picture = recorder.endRecording(),
                image = await picture.toImage(960, 540);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final name = preview ? i.toString().padLeft(3, '0') : stage!;
            File(
              '${directory.path}/$name.png',
            ).writeAsBytesSync(data!.buffer.asUint8List());
            if (stage != null) captured.add(stage);
            image.dispose();
            picture.dispose();
          }
          if (id == 'ramp') {
            expect(rode && released && faded && paused, isTrue);
            expect(
              captured,
              containsAll(['riding', 'release', 'flight', 'faded']),
            );
            s.retry();
            game.resetView();
            expect(game.surf.flights, isEmpty);
            expect(game.surf.dust, isEmpty);
          } else {
            expect(s.lines.single.contours, hasLength(2));
          }
          game.onRemove();
        }
      });
      expect(tester.takeException(), isNull);
    },
  );
}
