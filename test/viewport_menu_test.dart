import 'dart:convert';
import 'dart:io';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'package:ink_escape/core/save_journal.dart';
import 'package:ink_escape/ink_game.dart';
import 'package:ink_escape/main.dart';
import 'package:ink_escape/presentation/centered_menu.dart';
import 'package:ink_escape/soundscape.dart';

import 'journey_hud_test.dart' show loadArt, capture;

List<Map<String, dynamic>> story() {
  final raw = jsonDecode(
    File('assets/data/prototype_levels.json').readAsStringSync(),
  );
  return (raw['story'] as List)
      .map((m) => Map<String, dynamic>.from(m))
      .toList();
}

void main() {
  test(
    'Landscape camera doubles character size and keeps a full stroke ahead',
    () {
      for (final size in [
        const Size(1095, 518),
        const Size(960, 540),
        const Size(844, 390),
        const Size(568, 320),
        const Size(390, 844),
      ]) {
        final s = InkSession(story());
        final g = InkGame(s)..onGameResize(Vector2(size.width, size.height));
        if (size.width > size.height) {
          expect(g.scale / (size.height / 853.333), closeTo(2.13333, .001));
        }
        expect(g.visibleWidth, greaterThanOrEqualTo(480));
        expect(g.visibleWidth - 96, greaterThan(220 + 64));
        for (final point in [
          const V(0, 0),
          const V(320, 0),
          const V(390, 96),
        ]) {
          final back = g.worldPoint(g.point(point) * g.scale);
          expect(back.x, closeTo(point.x, 1e-7));
          expect(back.y, closeTo(point.y, 1e-7));
        }
        final ground = g.point(const V(0, 0)).dy * g.scale;
        expect(ground, lessThan(size.height));
        expect(
          size.height - ground,
          closeTo(InkGame.groundInset * g.scale, 1e-7),
        );
      }
    },
  );

  for (final size in [
    const Size(1095, 518),
    const Size(844, 390),
    const Size(568, 320),
  ]) {
    testWidgets(
      'All menu groups are centered at ${size.width} x ${size.height}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await loadArt(tester);
        final s = InkSession(story()), store = MemoryStore(), key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: InkEscapeApp(
              session: s,
              journal: SaveJournal(store, 'center-menu'),
              store: store,
              sound: Soundscape(enabled: false),
              restored: true,
            ),
          ),
        );
        for (var i = 0; i < 10; i++) {
          await tester.pump();
        }
        final state = tester.state<GameScreenState>(find.byType(GameScreen));
        state.game.pauseEngine();
        for (final phase in [
          Phase.ready,
          Phase.paused,
          Phase.dead,
          Phase.complete,
        ]) {
          s.phase = phase;
          s.message = 'Köprü hazır olmadan kenarı geçtin.';
          state.game.deadAge = 1;
          state.game.onFrame?.call();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          final content = tester.getRect(
            find.byKey(const ValueKey('ink-menu-content')),
          );
          final viewport = tester.getRect(find.byType(InkCenteredMenu));
          if (content.height <= viewport.height) {
            expect(content.center.dy, closeTo(viewport.center.dy, 1));
          }
          expect(find.byKey(const ValueKey('ink-journey-hud')), findsNothing);
          expect(tester.takeException(), isNull);
          if (size.width == 1095 && phase == Phase.dead) {
            await capture(tester, key, 'centered-death-menu');
          }
        }
        // The taller settings menu must remain usable on short phone screens.
        s.phase = Phase.paused;
        state.game.onFrame?.call();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.ensureVisible(find.text('Ses ayarları'));
        await tester.tap(find.text('Ses ayarları'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Yumuşak müzik'), findsOneWidget);
        await tester.ensureVisible(find.text('Geri'));
        await tester.tap(find.text('Geri'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
}
