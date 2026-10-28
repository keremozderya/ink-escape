import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'package:ink_escape/core/save_journal.dart';
import 'package:ink_escape/main.dart';
import 'package:ink_escape/soundscape.dart';

import 'journey_hud_test.dart' show loadArt, capture;
import 'ledge_grip_test.dart' show ledgeScene;

void main() {
  testWidgets(
    'The corner prompt receives completed taps, pauses safely and returns to drawing',
    (tester) async {
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadArt(tester);
      final s = ledgeScene()..advance(1 / 120);
      final store = MemoryStore(), key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: InkEscapeApp(
            session: s,
            journal: SaveJournal(store, 'ledge-ui'),
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
      expect(state.game.sceneReady, isTrue);
      state.game.update(.5);
      await tester.pump();
      final warning = find.byKey(const ValueKey('ink-ledge-warning'));
      expect(warning, findsOneWidget);
      expect(find.text('Bas–çek yaparak tırman'), findsOneWidget);
      expect(find.byKey(const ValueKey('ink-stuck-countdown')), findsNothing);
      await capture(tester, key, 'ledge-hanging');
      final touch = tester.getCenter(warning);
      final held = await tester.startGesture(touch);
      state.game.update(2);
      await tester.pump();
      expect(
        s.ledge!.pulls,
        0,
        reason: 'Holding does not count as repeated taps',
      );
      await held.up();
      await tester.pump();
      expect(s.ledge!.pulls, 1);
      expect(s.draft, isNull);
      await tester.tap(find.byTooltip('Duraklat'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(s.phase, Phase.paused);
      expect(warning, findsNothing);
      state.game.update(10);
      expect(s.ledge!.pulls, 1);
      await tester.tap(find.text('Devam et'));
      await tester.pump();
      for (var i = 1; i < LedgeGrip.requiredPulls; i++) {
        await tester.tapAt(touch);
        state.game.update(.18);
        await tester.pump();
      }
      expect(s.ledge?.pulls, LedgeGrip.requiredPulls);
      await capture(tester, key, 'ledge-pulling');
      state.game.update(1);
      await tester.pump();
      expect(s.ledge, isNull);
      expect(s.grounded, isTrue);
      expect(s.phase, Phase.playing);
      expect(warning, findsNothing);
      await capture(tester, key, 'ledge-landed');
      Offset screen(V p) => state.game.point(p) * state.game.scale;
      final pen = await tester.startGesture(screen(const V(145, 0)));
      expect(s.draft, isNotNull);
      await pen.moveTo(screen(const V(170, 2)));
      await pen.up();
      await tester.pump();
      expect(s.lines, isNotEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
