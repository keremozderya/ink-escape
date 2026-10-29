import 'dart:convert';
import 'dart:io';

import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'package:ink_escape/core/save_journal.dart';
import 'package:ink_escape/main.dart';
import 'package:ink_escape/soundscape.dart';

void main() {
  testWidgets(
    'The visible countdown progresses 3, 2, 1 and allows drawing through it',
    (tester) async {
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await Flame.images.loadAll([
          'dot_walk.png',
          'props.png',
          'paper_garden.png',
          'paper_ruins.png',
          'storyboard_opening.png',
        ]);
        for (final entry in {
          'Nunito': 'assets/fonts/Nunito.ttf',
          'Cormorant': 'assets/fonts/CormorantGaramond.ttf',
          'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
        }.entries) {
          final font = FontLoader(entry.key)
            ..addFont(rootBundle.load(entry.value));
          await font.load();
        }
      });
      final raw = jsonDecode(
        File('assets/data/prototype_levels.json').readAsStringSync(),
      );
      final session = InkSession(
        (raw['story'] as List)
            .map((level) => Map<String, dynamic>.from(level))
            .toList(),
      )..start();
      session.beginStroke(const V(100, 0));
      session.moveStroke(const V(100, 80));
      expect(session.endStroke(), isTrue);
      session.x = 90;
      final store = MemoryStore();
      await tester.pumpWidget(
        InkEscapeApp(
          languageCode: 'tr',
          session: session,
          journal: SaveJournal(store, 'countdown'),
          store: store,
          sound: Soundscape(enabled: false),
          restored: true,
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump();
      }
      final state = tester.state<GameScreenState>(find.byType(GameScreen));
      expect(state.game.sceneReady, isTrue);
      final warning = find.byKey(const ValueKey('ink-stuck-countdown'));
      expect(warning, findsNothing);
      session.advance(.2);
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        find.descendant(of: warning, matching: find.text('3')),
        findsOneWidget,
      );
      expect(find.text('Dot ilerleyemiyor'), findsOneWidget);

      // Put a real paper anchor under the warning and send an actual pointer
      // gesture through its centre. The warning must not steal drawing input.
      final point = tester.getCenter(warning);
      final origin = tester.getTopLeft(
        find.byKey(const ValueKey('ink-drawing-surface')),
      );
      final anchor = state.game.worldPoint(point - origin);
      session.level.terrain.add(
        Surface(
          'warning-input',
          anchor - const V(20, 0),
          anchor + const V(70, 0),
        ),
      );
      final pen = await tester.startGesture(point);
      expect(session.draft, isNotNull);
      await pen.moveTo(point + const Offset(20, 0));
      await pen.up();
      expect(session.draft, isNull);
      session.advance(.9);
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.descendant(of: warning, matching: find.text('2')),
        findsOneWidget,
      );
      session.advance(.9);
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.descendant(of: warning, matching: find.text('1')),
        findsOneWidget,
      );
      session.advance(1);
      await tester.pump(const Duration(milliseconds: 80));
      expect(session.phase, Phase.dead);
      expect(warning, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
