import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'package:ink_escape/main.dart';
import 'session_flow_test.dart' show mountGame, unmountGame;
import 'journey_hud_test.dart' show capture;
import 'viewport_menu_test.dart' show story;

Future<GameScreenState> openTest(WidgetTester tester, String id) async {
  await tester.pump(const Duration(milliseconds: 500));
  final tile = find.byKey(ValueKey('ink-test-$id'));
  await tester.scrollUntilVisible(
    tile,
    120,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey('ink-mechanics-list')),
      matching: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
    ),
  );
  await tester.ensureVisible(tile);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(tile);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  for (var i = 0; i < 12; i++) {
    await tester.pump();
  }
  final state = tester.state<GameScreenState>(
    find.byWidgetPredicate((w) => w is GameScreen && w.labCase != null),
  );
  state.game.pauseEngine();
  expect(state.game.sceneReady, isTrue);
  await tester.ensureVisible(find.text('Parkuru aç'));
  await tester.tap(find.text('Parkuru aç'));
  await tester.pump();
  return state;
}

Future<void> captureLab(
  WidgetTester tester,
  GlobalKey key,
  GameScreenState state,
  String name,
) async {
  state.game.renderBox.markNeedsPaint();
  await tester.pump();
  await capture(tester, key, name);
}

void main() {
  for (final size in [const Size(568, 320), const Size(960, 540)]) {
    testWidgets(
      'Picker, real slide drawing and return preserve story at $size',
      (tester) async {
        final s = InkSession(story())
          ..x = 70
          ..firstDrawDone = true
          ..drawingTutorialDone = true;
        final store = MemoryStore(), key = GlobalKey();
        await mountGame(
          tester,
          s,
          store,
          restored: true,
          captureKey: key,
          size: size,
        );
        final baseline = s.snapshot();
        final button = find.byKey(const ValueKey('ink-open-mechanics'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(InkMechanicsPicker), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('ink-test-filter-plan')));
        await tester.pump();
        expect(find.byKey(const ValueKey('ink-test-plan-G')), findsOneWidget);
        expect(find.byKey(const ValueKey('ink-test-slide')), findsNothing);
        final drawingFilter = find.byKey(
          const ValueKey('ink-test-filter-drawing'),
        );
        await tester.ensureVisible(drawingFilter);
        await tester.tap(drawingFilter);
        await tester.pump();
        await capture(tester, key, 'mechanics-picker-${size.width.toInt()}');
        final state = await openTest(tester, 'ramp');
        final lab = state.widget.session.mechanics!;
        expect(lab.holdDot, isTrue);
        state.game.update(1);
        await tester.pump();
        expect(state.widget.session.x, 0);
        await tester.tap(find.byKey(const ValueKey('ink-test-guide')));
        await tester.pump();
        expect(lab.showGuide, isTrue);
        Offset screen(V p) => state.game.point(p) * state.game.scale;
        final points = lab.guides.first.first;
        final pen = await tester.startGesture(screen(points.first));
        for (var i = 1; i < points.length; i++) {
          for (var j = 1; j <= 8; j++) {
            final p = points[i - 1] + (points[i] - points[i - 1]) * (j / 8);
            final q = screen(p);
            expect(q.dx, inInclusiveRange(0, size.width));
            expect(q.dy, inInclusiveRange(120, size.height));
            await pen.moveTo(q);
          }
        }
        await pen.up();
        await tester.pump();
        expect(
          state.widget.session.lines.length,
          1,
          reason: state.widget.session.message,
        );
        expect(lab.holdDot, isTrue);
        await captureLab(
          tester,
          key,
          state,
          'mechanics-ramp-ready-${size.width.toInt()}',
        );
        await tester.tap(find.byKey(const ValueKey('ink-test-walk')));
        state.game.update(2.4);
        await tester.pump();
        expect(lab.motion, InkLabMotion.entryHop);
        await captureLab(
          tester,
          key,
          state,
          'mechanics-entry-hop-${size.width.toInt()}',
        );
        state.game.update(.8);
        await tester.pump();
        expect(lab.sliding, isTrue);
        await captureLab(
          tester,
          key,
          state,
          'mechanics-slide-${size.width.toInt()}',
        );
        state.game.update(1);
        await tester.pump();
        expect(lab.motion, InkLabMotion.airborne);
        await captureLab(
          tester,
          key,
          state,
          'mechanics-flight-${size.width.toInt()}',
        );
        await tester.tap(find.byTooltip('Testleri seç'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(InkMechanicsPicker), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(s.x, baseline['x']);
        expect(s.ink, baseline['ink']);
        expect(s.levelIndex, baseline['levelIndex']);
        expect(s.walked, baseline['walked']);
        expect(store.values.keys.any((k) => k.contains('mechanics')), isFalse);
        expect(tester.takeException(), isNull);
        await unmountGame(tester);
      },
    );
  }
  testWidgets('Every case opens, retries and returns to the picker', (
    tester,
  ) async {
    final s = InkSession(story()), store = MemoryStore();
    await mountGame(tester, s, store);
    final button = find.byKey(const ValueKey('ink-open-mechanics'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    for (final spec in InkLabCase.all) {
      final state = await openTest(tester, spec.id);
      state.game.update(.1);
      await tester.pump();
      expect(find.byKey(const ValueKey('ink-test-walk')), findsOneWidget);
      if (spec.id == 'eraser') {
        final time = state.widget.session.gameTime;
        await tester.tap(find.byIcon(Icons.help_outline_rounded));
        await tester.pump();
        state.game.update(10);
        expect(state.widget.session.gameTime, time);
        await tester.tap(find.text('Tamam'));
        await tester.pump();
        expect(state.widget.session.phase, Phase.playing);
      }

      await tester.tap(find.byTooltip('Yeniden dene'));
      await tester.pump();
      expect(state.widget.session.mechanics!.holdDot, isTrue);
      expect(state.widget.session.x, 0);
      await tester.tap(find.byTooltip('Testleri seç'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(InkMechanicsPicker), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await unmountGame(tester);
  });
}
