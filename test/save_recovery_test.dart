import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'package:ink_escape/core/save_journal.dart';

import 'journey_core_test.dart' show journeyLevels;
import 'save_journal_test.dart' show JournalStore, InFlightStore;

List<Map<String, dynamic>> gripLevels() => [
  {
    'number': 1,
    'title': 'Saved grip',
    'width': 2000,
    'cells': [
      {
        'index': 1,
        'offset_x': 0,
        'route': [
          {
            'kind': 'natural',
            'points': [
              [100, 0],
              [180, 0],
            ],
          },
        ],
        'pads': [],
        'pickups': [],
        'gates': [],
        'objects': [],
        'hazards': [],
        'absorbent': [],
        'lines': [],
      },
    ],
  },
];

void main() {
  test(
    'A new journey resets every run counter and persists zero distance',
    () async {
      final levels = journeyLevels(), s = InkSession(journeyLevels())..start();
      s.advance(10);
      expect(s.phase, Phase.complete);
      expect(s.entryWalked, greaterThan(0));
      s.drawingTutorialDone = true;
      s.restartJourney();
      expect(s.levelIndex, 0);
      expect(s.distanceCm, 0);
      expect(s.entryWalked, 0);
      expect(s.origin, 0);
      expect(s.activeTotal, 0);
      expect(s.ink, 180);
      expect(s.firstDrawDone, isFalse);
      expect(s.drawingTutorialDone, isTrue);
      final store = JournalStore();
      final writer = SaveJournal(store, 's');
      await writer.fence(s.resetEpoch, s.checkpointSnapshot());
      await writer.save(s.snapshot(), resetEpoch: s.resetEpoch);
      final restored = InkSession.restore(
        levels,
        (await SaveJournal(store, 's').load())!,
      );
      expect(restored.distanceCm, 0);
      expect(restored.phase, Phase.ready);
    },
  );

  test('A single-level lab replay also starts with its original ink', () {
    final s = InkSession([journeyLevels().first], lab: true)..start();
    s.advance(10);
    s.ink = 35;
    s.entryInk = 35;
    s.entryWalked = 120;
    s.restartJourney();
    expect(s.ink, 180);
    expect(s.walked, 0);
    expect(s.entryWalked, 0);
  });

  test('Five-second autosave stops with the world and restarts its cadence on retry', () {
    final level = journeyLevels().last..['width'] = 50000.0;
    ((level['cells'] as List).first['route'] as List).first['points'] = [
      [0, 0],
      [50000, 0],
    ];
    final s = InkSession([level])..start();
    final times = <double>[];
    s.onSaveRequested = (forced) {
      if (!forced) times.add(s.activeTotal);
    };
    s.advance(5.1);
    expect(times, hasLength(1));
    expect(times.single, closeTo(5, .01));
    s.pause();
    s.advance(20);
    expect(times, hasLength(1));
    s.start();
    s.advance(4.91);
    expect(times, hasLength(2));
    s.retry();
    s.start();
    s.advance(4.9);
    expect(times, hasLength(2));
    s.advance(.11);
    expect(times, hasLength(3));
  });

  test(
    'Partial stroke survives journal reopening and still requires its endpoint',
    () async {
      final data = journeyLevels(), s = InkSession(journeyLevels())..start();
      s.beginStroke(const V(20, 0));
      s.moveStroke(const V(60, 15));
      s.advance(.2);
      s.pause();
      final store = JournalStore();
      await SaveJournal(
        store,
        's',
      ).save(s.snapshot(), resetEpoch: s.resetEpoch);
      final r = InkSession.restore(
        data,
        (await SaveJournal(store, 's').load())!,
      );
      expect(r.phase, Phase.ready);
      expect(r.draft!.points, hasLength(s.draft!.points.length));
      expect(r.ink, s.ink);
      final x = r.x;
      r.advance(5);
      expect(r.x, x);
      r.start();
      expect(r.phase, Phase.resumeStroke);
      expect(r.beginStroke(const V(110, 80)), isFalse);
      expect(r.beginStroke(r.draft!.rawPoint), isTrue);
      r.moveStroke(const V(90, 0));
      expect(r.endStroke(), isTrue);
    },
  );

  for (var pulls = 0; pulls <= LedgeGrip.requiredPulls; pulls++) {
    test('Journal reopening preserves $pulls completed ledge pulls', () async {
      final data = gripLevels(), s = InkSession(gripLevels())..start();
      s
        ..x = 90
        ..y = .1
        ..vy = -40
        ..grounded = false;
      s.advance(1 / 120);
      expect(s.ledge, isNotNull);
      for (var i = 0; i < pulls; i++) {
        s.pullLedge();
        s.advance(.02);
      }
      s.pause();
      final store = JournalStore();
      await SaveJournal(
        store,
        's',
      ).save(s.snapshot(), resetEpoch: s.resetEpoch);
      final r = InkSession.restore(
        data,
        (await SaveJournal(store, 's').load())!,
      );
      expect(r.ledge!.pulls, pulls);
      expect(r.ledge!.progress, s.ledge!.progress);
      expect(r.x, s.x);
      expect(r.y, s.y);
      expect(r.ledgeTutorialDone, pulls == 5);
      r.advance(10);
      expect(r.y, s.y);
      r.start();
      for (var i = pulls; i < 5; i++) {
        r.pullLedge();
      }
      r.advance(1.2);
      expect(r.ledge, isNull);
      expect(r.grounded, isTrue);
      expect(r.ledgeTutorialDone, isTrue);
    });
  }

  test(
    'Chapter boundary fences the previous chapter before its old save finishes',
    () async {
      final data = journeyLevels(), s = InkSession(journeyLevels())..start();
      s
        ..x = 127.9
        ..walked = 127.9;
      final store = InFlightStore();
      final writer = SaveJournal(store, 's');
      final old = writer.save(s.snapshot(), resetEpoch: s.resetEpoch);
      await store.entered.future;
      final pending = <Future<void>>[];
      Future<void> persist() async {
        final snapshot = s.snapshot(),
            checkpoint = s.checkpointSnapshot(),
            epoch = s.resetEpoch;
        if (epoch > writer.epoch) await writer.fence(epoch, checkpoint);
        await writer.save(snapshot, resetEpoch: epoch);
      }

      s.onSaveRequested = (_) => pending.add(persist());
      s.advance(1 / 120);
      expect(s.levelIndex, 1);
      expect(s.resetEpoch, 1);
      await store.fenceWritten.future;
      final recovered = InkSession.restore(
        data,
        (await SaveJournal(store, 's').load())!,
      );
      expect(recovered.levelIndex, 1);
      expect(recovered.x, 0);
      expect(recovered.walked, s.entryWalked);
      store.release.complete();
      await old;
      await Future.wait(pending);
      final current = InkSession.restore(
        data,
        (await SaveJournal(store, 's').load())!,
      );
      expect(current.levelIndex, 1);
      expect(current.x, s.x);
    },
  );

  test(
    'Previous layout migrates at the current checkpoint through the journal',
    () async {
      final levels = journeyLevels(), s = InkSession(journeyLevels())..start();
      s.advance(3);
      final snapshot = s.snapshot()..['layoutRevision'] = 0;
      final store = JournalStore();
      await SaveJournal(store, 's').save(snapshot, resetEpoch: s.resetEpoch);
      final r = InkSession.restore(
        levels,
        (await SaveJournal(store, 's').load())!,
      );
      expect(r.levelIndex, 1);
      expect(r.migratedLayout, isTrue);
      expect(r.x, 0);
      expect(r.phase, Phase.ready);
    },
  );
}
