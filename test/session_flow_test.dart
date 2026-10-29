import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'package:ink_escape/core/save_journal.dart';
import 'package:ink_escape/main.dart';
import 'package:ink_escape/presentation/opening_story.dart';
import 'package:ink_escape/soundscape.dart';

import 'journey_core_test.dart' show journeyLevels;
import 'journey_hud_test.dart' show loadArt, capture;
import 'viewport_menu_test.dart' show story;

Future<GameScreenState> mountGame(
  WidgetTester tester,
  InkSession session,
  MemoryStore store, {
  bool restored = false,
  GlobalKey? captureKey,
  Size size = const Size(960, 540),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await loadArt(tester);
  Widget app = InkEscapeApp(
    languageCode: 'tr',
    session: session,
    journal: SaveJournal(store, 'flow'),
    store: store,
    sound: Soundscape(enabled: false),
    restored: restored,
  );
  if (captureKey != null) app = RepaintBoundary(key: captureKey, child: app);
  await tester.pumpWidget(app);
  for (var i = 0; i < 12; i++) {
    await tester.pump();
  }
  final state = tester.state<GameScreenState>(find.byType(GameScreen));
  expect(state.game.sceneReady, isTrue);
  state.game.pauseEngine();
  await tester.pump(const Duration(milliseconds: 500));
  return state;
}

Future<void> unmountGame(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  testWidgets(
    'Three drawing lessons use real input and hold the world safely',
    (tester) async {
      final s = InkSession(story()), store = MemoryStore(), key = GlobalKey();
      final state = await mountGame(tester, s, store, captureKey: key);
      await tester.tap(find.text('Yolculuğa başla'));
      await tester.pump();
      expect(find.byType(InkOpening), findsOneWidget);
      expect(find.byKey(const ValueKey('ink-drawing-lesson')), findsNothing);
      expect(openingShots, hasLength(12));
      expect(openingShots.fold(0, (sum, shot) => sum + shot.seconds), 37);
      await tester.tap(find.text('Hikâyeyi atla'));
      await tester.pump();
      expect(find.text('1 / 3 · Kâğıt kenarından başla'), findsOneWidget);
      final x = s.x, ink = s.ink, time = s.activeTotal;
      state.game.update(20);
      await tester.pump();
      expect(s.x, x);
      expect(s.ink, ink);
      expect(s.activeTotal, time);
      await capture(tester, key, 'tutorial-01-anchor');
      final origin = tester.getTopLeft(
        find.byKey(const ValueKey('ink-drawing-surface')),
      );
      Offset screen(V p) => origin + state.game.point(p) * state.game.scale;
      final pen = await tester.startGesture(screen(const V(320, 0)));
      await tester.pump();
      expect(s.draft, isNotNull);
      expect(find.text('2 / 3 · Yolunu çiz ve bırak'), findsOneWidget);
      for (var i = 1; i <= 24; i++) {
        await pen.moveTo(screen(V(320 + 72 * i / 24, 0)));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await capture(tester, key, 'tutorial-02-release');
      await pen.up();
      await tester.pump();
      expect(s.firstDrawDone, isTrue);
      expect(find.text('3 / 3 · Mürekkebini tanı'), findsOneWidget);
      expect(s.ink, closeTo(108, .01));
      state.game.update(20);
      expect(s.x, x);
      await capture(tester, key, 'tutorial-03-ink');
      await tester.tap(find.text('Yola devam'));
      await tester.pump();
      expect(s.drawingTutorialDone, isTrue);
      expect(find.byKey(const ValueKey('ink-drawing-lesson')), findsNothing);
      state.game.update(.5);
      expect(s.x, greaterThan(x));
      final saved = await tester.runAsync(
        () => SaveJournal(store, 'flow').load(),
      );
      expect(saved!['drawingTutorialDone'], isTrue);
      expect(await store.read('ink.story.opening.v1'), 'seen');
      expect(tester.takeException(), isNull);
      await unmountGame(tester);
    },
  );

  testWidgets(
    'Lifecycle interruption reloads the partial lesson at the same stroke',
    (tester) async {
      final data = story(), s = InkSession(story()), store = MemoryStore();
      store.values['ink.story.opening.v1'] = 'seen';
      var state = await mountGame(tester, s, store);
      await tester.tap(find.text('Yolculuğa başla'));
      await tester.pump();
      Offset screen(V p) => state.game.point(p) * state.game.scale;
      final pen = await tester.startGesture(screen(const V(320, 0)));
      await pen.moveTo(screen(const V(350, 5)));
      state.game.update(5.1);
      await tester.pump();
      final periodic = await tester.runAsync(
        () => SaveJournal(store, 'flow').load(),
      );
      expect(periodic!['draft']['rawPoint'], s.draft!.rawPoint.toJson());
      expect(s.x, 0);
      state.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await tester.pump();
      await pen.cancel();
      expect(s.phase, Phase.paused);
      expect(s.draft, isNotNull);
      final saved = await tester.runAsync(
        () => SaveJournal(store, 'flow').load(),
      );
      expect(saved!['drawingTutorialDone'], isFalse);
      final r = InkSession.restore(data, saved);
      expect(r.draft!.rawPoint.toJson(), s.draft!.rawPoint.toJson());
      expect(r.x, s.x);
      await unmountGame(tester);
      state = await mountGame(tester, r, store, restored: true);
      await tester.tap(find.text('Devam et'));
      await tester.pump();
      expect(r.phase, Phase.resumeStroke);
      state.game.update(10);
      expect(r.x, s.x);
      final resumed = await tester.startGesture(screen(r.draft!.end!));
      await resumed.moveTo(screen(const V(392, 0)));
      await resumed.up();
      await tester.pump();
      expect(r.firstDrawDone, isTrue);
      expect(find.text('3 / 3 · Mürekkebini tanı'), findsOneWidget);
      await tester.tap(find.text('Yola devam'));
      await tester.pump();
      expect(r.drawingTutorialDone, isTrue);
      expect(tester.takeException(), isNull);
      await unmountGame(tester);
    },
  );

  for (final size in [const Size(568, 320), const Size(844, 390)]) {
    testWidgets(
      'Drawing lesson stays usable at ${size.width} x ${size.height}',
      (tester) async {
        final s = InkSession(story()), store = MemoryStore(), key = GlobalKey();
        store.values['ink.story.opening.v1'] = 'seen';
        final state = await mountGame(
          tester,
          s,
          store,
          size: size,
          captureKey: key,
        );
        await tester.tap(find.text('Yolculuğa başla'));
        await tester.pump();
        expect(find.text('1 / 3 · Kâğıt kenarından başla'), findsOneWidget);
        Offset screen(V p) => state.game.point(p) * state.game.scale;
        final pen = await tester.startGesture(screen(const V(320, 0)));
        await tester.pump();
        expect(find.text('2 / 3 · Yolunu çiz ve bırak'), findsOneWidget);
        for (var i = 1; i <= 12; i++) {
          await pen.moveTo(screen(V(320 + 72 * i / 12, 0)));
        }
        await pen.up();
        await tester.pump();
        expect(find.text('3 / 3 · Mürekkebini tanı'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await capture(tester, key, 'tutorial-${size.width.toInt()}-ink');
        await tester.tap(find.text('Yola devam'));
        await tester.pump();
        expect(s.drawingTutorialDone, isTrue);
        expect(tester.takeException(), isNull);
        await unmountGame(tester);
      },
    );
  }

  for (final viaMenu in [false, true]) {
    testWidgets(
      'Replay ${viaMenu ? 'from main menu' : 'directly'} resets persisted chapter distance',
      (tester) async {
        final s = InkSession(journeyLevels())..start();
        s.advance(10);
        s.drawingTutorialDone = true;
        final store = MemoryStore();
        store.values['ink.story.opening.v1'] = 'seen';
        await mountGame(tester, s, store, restored: true);
        expect(s.entryWalked, greaterThan(0));
        if (viaMenu) {
          await tester.tap(find.text('Ana Menüye Dön'));
          await tester.pump(const Duration(milliseconds: 500));
          await tester.tap(find.text('Yeniden başla'));
        } else {
          await tester.tap(find.text('Tekrar oyna'));
        }
        await tester.pump(const Duration(milliseconds: 500));
        expect(s.distanceCm, 0);
        expect(s.entryWalked, 0);
        expect(s.levelIndex, 0);
        expect(s.origin, 0);
        final saved = await tester.runAsync(
          () => SaveJournal(store, 'flow').load(),
        );
        expect(saved!['entryWalked'], 0);
        expect(saved['walked'], 0);
        expect(saved['levelIndex'], 0);
        expect(tester.takeException(), isNull);
        await unmountGame(tester);
      },
    );
  }

  testWidgets('Unseen opening is not lost by saving the initial menu', (
    tester,
  ) async {
    final s = InkSession(story()), store = MemoryStore();
    final state = await mountGame(tester, s, store);
    state.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await tester.pump();
    final saved = await tester.runAsync(
      () => SaveJournal(store, 'flow').load(),
    );
    final r = InkSession.restore(story(), saved!);
    await unmountGame(tester);
    await mountGame(tester, r, store, restored: true);
    await tester.tap(find.text('Devam et'));
    await tester.pump();
    expect(find.byType(InkOpening), findsOneWidget);
    await tester.tap(find.text('Hikâyeyi atla'));
    await tester.pump();
    await tester.tap(find.byTooltip('Duraklat'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Devam et'));
    await tester.pump();
    expect(find.byType(InkOpening), findsNothing);
    expect(tester.takeException(), isNull);
    await unmountGame(tester);
  });
}
