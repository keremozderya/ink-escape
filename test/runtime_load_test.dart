import 'dart:convert';
import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'package:ink_escape/core/save_journal.dart';
import 'package:ink_escape/main.dart';
import 'package:ink_escape/presentation/journey_hud.dart';

import 'save_journal_test.dart' show JournalStore, InFlightStore;
import 'session_flow_test.dart' show mountGame, unmountGame;

void main() {
  test(
    'Worker and inline records are byte-identical and mutually readable',
    () async {
      final inline = JournalStore(), worker = JournalStore();
      final a = SaveJournal(inline, 'save');
      final b = SaveJournal(worker, 'save', backgroundEncoding: true);
      final snapshot = <String, dynamic>{
        'resetEpoch': 1,
        'x': 157.4,
        'draft': {
          'points': [
            [1.0, 2.0],
            [3.0, 4.0],
          ],
        },
      };
      await a.fence(1, snapshot);
      await b.fence(1, snapshot);
      await a.save(snapshot, resetEpoch: 1);
      await b.save(snapshot, resetEpoch: 1);
      expect(worker.values, inline.values);
      expect(await SaveJournal(worker, 'save').load(), snapshot);
    },
  );

  test(
    'Queued worker saves capture nested state before later mutations',
    () async {
      final store = InFlightStore();
      final journal = SaveJournal(store, 'save', backgroundEncoding: true);
      final old = journal.save({'n': 0}, resetEpoch: 0);
      await store.entered.future;
      final snapshot = <String, dynamic>{
        'nested': [1, 2],
      };
      final next = journal.save(snapshot, resetEpoch: 0);
      (snapshot['nested'] as List).add(3);
      store.release.complete();
      await old;
      await next;
      expect(await SaveJournal(store, 'save').load(), {
        'nested': [1, 2],
      });
    },
  );

  test(
    'Worker reset fence wins while an old disk write remains in flight',
    () async {
      final store = InFlightStore();
      final journal = SaveJournal(store, 'save', backgroundEncoding: true);
      final old = journal.save({'x': 90}, resetEpoch: 0);
      await store.entered.future;
      final checkpoint = <String, dynamic>{
        'x': 0,
        'nested': [1],
      };
      final resetting = journal.fence(1, checkpoint);
      (checkpoint['nested'] as List).add(2);
      await store.fenceWritten.future;
      expect(await SaveJournal(store, 'save').load(), {
        'x': 0,
        'nested': [1],
      });
      store.release.complete();
      await old;
      await resetting;
      await journal.save({'x': 999}, resetEpoch: 0);
      expect(await SaveJournal(store, 'save').load(), {
        'x': 0,
        'nested': [1],
      });
    },
  );

  test(
    'Concurrent worker encodes retain write order and recover after failure',
    () async {
      final store = JournalStore()..writeErrors.add('save.b');
      final journal = SaveJournal(store, 'save', backgroundEncoding: true);
      await expectLater(
        journal.save({'n': -1}, resetEpoch: 0),
        throwsStateError,
      );
      await Future.wait([
        for (var i = 0; i < 8; i++) journal.save({'n': i}, resetEpoch: 0),
      ]);
      expect(await SaveJournal(store, 'save').load(), {'n': 7});
    },
  );

  testWidgets('HUD and autosave refresh without rebuilding the game screen', (
    tester,
  ) async {
    final s = InkSession([
      {'number': 1, 'title': 'Runtime load', 'width': 2000, 'cells': []},
    ]);
    s.level.terrain.add(Surface('floor', const V(0, 0), const V(2000, 0)));
    s.x = 100;
    s.ink = 240;
    s.drawingTutorialDone = true;
    s.firstDrawDone = true;
    final store = MemoryStore();
    final state = await mountGame(tester, s, store, restored: true);
    await tester.tap(find.text('Devam et'));
    await tester.pump();
    state.game.update(.1);
    await tester.pump();
    final gameFinder = find.byWidgetPredicate((widget) => widget is GameWidget);
    final gameWidget = tester.widget(gameFinder);
    final oldHook = debugOnRebuildDirtyWidget;
    var screenBuilds = 0, hudBuilds = 0;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      oldHook?.call(element, builtOnce);
      if (element.widget is GameScreen) screenBuilds++;
      if (element.widget is InkJourneyHud) hudBuilds++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = oldHook);
    s.saveElapsed = 4.9;
    for (var frame = 0; frame < 120; frame++) {
      state.game.update(1 / 60);
      await tester.pump(const Duration(microseconds: 16667));
    }
    Directory('qa').createSync();
    File('qa/runtime-rebuilds.json').writeAsStringSync(
      jsonEncode({
        'simulated_frames': 120,
        'simulated_fps': 60,
        'game_screen_rebuilds': screenBuilds,
        'journey_hud_rebuilds': hudBuilds,
        'autosave_written': store.values.containsKey('flow.b'),
        'method': 'Flutter widget build hook; not native device frame timing',
      }),
    );
    expect(screenBuilds, 0);
    expect(hudBuilds, greaterThanOrEqualTo(30));
    expect(
      identical(tester.widget(gameFinder), gameWidget),
      isTrue,
    );
    expect(await store.read('flow.b'), isNotNull);
    expect(s.x, greaterThan(200));
    expect(tester.takeException(), isNull);
    debugOnRebuildDirtyWidget = oldHook;
    await unmountGame(tester);
  });
}
