import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flame/flame.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'package:ink_escape/core/save_journal.dart';
import 'package:ink_escape/main.dart';
import 'package:ink_escape/soundscape.dart';

void main() {
  testWidgets(
    'Landscape renders actual art; pause freezes world and ignores drawing',
    (tester) async {
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        final material = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await material.load();
        await Flame.images.loadAll([
          'dot_walk.png',
          'props.png',
          'paper_garden.png',
          'paper_ruins.png',
          'storyboard_opening.png',
        ]);
        for (final entry in {
          'Nunito': 'Nunito.ttf',
          'Cormorant': 'CormorantGaramond.ttf',
        }.entries) {
          final font = FontLoader(entry.key)
            ..addFont(rootBundle.load('assets/fonts/${entry.value}'));
          await font.load();
        }
      });
      final raw = jsonDecode(
        File('assets/data/prototype_levels.json').readAsStringSync(),
      );
      final data = (raw['story'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final s = InkSession(data), store = MemoryStore(), key = GlobalKey();
      final sound = Soundscape(enabled: false);
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: InkEscapeApp(
            languageCode: 'tr',
            session: s,
            journal: SaveJournal(store, 'ui'),
            store: store,
            sound: sound,
          ),
        ),
      );
      final state = tester.state<GameScreenState>(find.byType(GameScreen));
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      expect(state.game.sceneReady, isTrue);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(find.text('INK ESCAPE'), findsOneWidget);
      Future<void> capture(String name) async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory('qa').createSync();
          File('qa/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('01-opening');
      await tester.tap(find.text('Yolculuğa başla'));
      await tester.pump();
      expect(s.phase, Phase.ready);
      await tester.pump(const Duration(seconds: 1));
      await capture('04-story-opening');
      await tester.tap(find.text('Hikâyeyi atla'));
      await tester.pump();
      expect(s.phase, Phase.playing);
      // Exercise the real widget event path, not the session API directly.
      s.advance(160 / s.walkSpeed);
      state.game.cameraX = s.x - 96;
      await tester.pump();
      final origin = tester.getTopLeft(
        find.byKey(const ValueKey('ink-drawing-surface')),
      );
      Offset touch(V p) => origin + state.game.point(p) * state.game.scale;
      final pen = await tester.startGesture(touch(const V(320, 0)));
      expect(
        s.draft,
        isNotNull,
        reason: 'Pointer down must reach drawing input',
      );
      for (var i = 1; i <= 24; i++) {
        final t = i / 24;
        await pen.moveTo(touch(V(320 + 72 * t, 7 * 4 * t * (1 - t))));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await capture('drawing-lens');
      await pen.up();
      expect(s.draft, isNull);
      expect(
        s.lines,
        isNotEmpty,
        reason: 'Pointer drag and release must commit the line: ${s.message}',
      );
      s.advance(172.8 / s.walkSpeed);
      state.game.cameraX = s.x - 96;
      state.game.visualTime = s.gameTime;
      state.game.update(0);
      await tester.pump();
      expect(s.phase, Phase.playing);
      expect(s.y, greaterThan(0));
      expect(s.grounded, isTrue);
      await capture('02-first-bridge');
      final savedCamera = state.game.cameraX;
      state.game.cameraX = (data.first['memories'][0]['x'] as num).toDouble();
      await tester.pump();
      await capture('05-note-grounded');
      state.game.cameraX = savedCamera;
      await tester.pump();
      await tester.tap(find.byTooltip('Duraklat'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final x = s.x, t = s.gameTime;
      await tester.dragFrom(const Offset(200, 588), const Offset(100, 0));
      await tester.pump(const Duration(seconds: 2));
      expect(s.phase, Phase.paused);
      expect(s.x, x);
      expect(s.gameTime, t);
      expect(s.draft, isNull);
      expect(tester.takeException(), isNull);
      await capture('03-pause');
      await tester.tap(find.text('Ayarlar'));
      await tester.pump();
      expect(find.text('Yumuşak müzik'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Geri'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Bölümü baştan başlat'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(s.phase, Phase.ready);
      expect(s.x, 0);
      expect(state.game.cameraX, -96);
      await tester.runAsync(() async {
        final save = await SaveJournal(store, 'ui').load();
        expect(save!['cameraX'], -96);
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
