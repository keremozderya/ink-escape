import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/save_journal.dart';

class JournalStore extends StringStore {
  final values = <String, String>{};
  final readErrors = <String>{}, writeErrors = <String>{};
  @override
  Future<String?> read(String key) async {
    if (readErrors.contains(key)) throw StateError('read failed');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (writeErrors.remove(key)) throw StateError('write failed');
    values[key] = value;
  }
}

class InFlightStore extends JournalStore {
  final entered = Completer<void>(), release = Completer<void>();
  final fenceWritten = Completer<void>();
  bool first = true;
  @override
  Future<void> write(String key, String value) async {
    if (first) {
      first = false;
      entered.complete();
      await release.future;
    }
    await super.write(key, value);
    if (key.endsWith('.fence') && !fenceWritten.isCompleted) {
      fenceWritten.complete();
    }
  }
}

String record(dynamic snapshot, {int epoch = 0, int revision = 2}) {
  final payload = jsonEncode(snapshot);
  return jsonEncode({
    'revision': revision,
    'epoch': epoch,
    'checksum': SaveJournal.checksum(payload),
    'payload': payload,
  });
}

void main() {
  final badRecords = <String, String>{
    'torn envelope': '{',
    'non-map envelope': '[]',
    'non-map payload': record([1, 2]),
    'null payload': record(null),
    'missing revision': jsonEncode(
      jsonDecode(record({'n': 2}))..remove('revision'),
    ),
    'string revision': jsonEncode(
      jsonDecode(record({'n': 2}))..['revision'] = '2',
    ),
    'negative revision': jsonEncode(
      jsonDecode(record({'n': 2}))..['revision'] = -1,
    ),
    'fractional revision': jsonEncode(
      jsonDecode(record({'n': 2}))..['revision'] = 2.5,
    ),
    'missing epoch': jsonEncode(jsonDecode(record({'n': 2}))..remove('epoch')),
    'string epoch': jsonEncode(jsonDecode(record({'n': 2}))..['epoch'] = '0'),
    'negative epoch': jsonEncode(jsonDecode(record({'n': 2}))..['epoch'] = -1),
    'wrong checksum': jsonEncode(
      jsonDecode(record({'n': 2}))..['checksum'] = -1,
    ),
    'checksummed invalid JSON': jsonEncode({
      'revision': 2,
      'epoch': 0,
      'payload': '{',
      'checksum': SaveJournal.checksum('{'),
    }),
  };
  for (final entry in badRecords.entries) {
    test('${entry.key} falls back to the intact sibling', () async {
      final store = JournalStore();
      final writer = SaveJournal(store, 's');
      await writer.save({'n': 1}, resetEpoch: 0);
      store.values['s.a'] = entry.value;
      final reader = SaveJournal(store, 's');
      expect(await reader.load(), {'n': 1});
      expect(reader.hadUnreadableRecords, isTrue);
    });
  }

  test('An unreadable slot does not hide the other copy', () async {
    final store = JournalStore();
    await SaveJournal(store, 's').save({'n': 1}, resetEpoch: 0);
    store.readErrors.add('s.a');
    expect(await SaveJournal(store, 's').load(), {'n': 1});
  });

  for (final field in ['epoch', 'revision']) {
    test('New checksum also protects the $field metadata', () async {
      final store = JournalStore();
      final writer = SaveJournal(store, 's');
      await writer.save({'n': 1}, resetEpoch: 0);
      await writer.save({'n': 2}, resetEpoch: 0);
      final corrupted =
          jsonDecode(store.values['s.a']!) as Map<String, dynamic>;
      corrupted[field] = 999;
      store.values['s.a'] = jsonEncode(corrupted);
      expect(await SaveJournal(store, 's').load(), {'n': 1});
    });
  }

  test('Original payload-only checksums still load', () async {
    final store = JournalStore();
    store.values['s.a'] = record({'n': 7}, revision: 6);
    expect(await SaveJournal(store, 's').load(), {'n': 7});
  });

  test(
    'Unavailable storage is reported instead of mistaken for a new game',
    () async {
      final store = JournalStore()
        ..readErrors.addAll(['s.a', 's.b', 's.fence']);
      await expectLater(SaveJournal(store, 's').load(), throwsStateError);
    },
  );

  test(
    'New reset generation outranks old revision even with a torn fence',
    () async {
      final store = JournalStore();
      store.values['s.a'] = record({'world': 'old'}, epoch: 0, revision: 100);
      store.values['s.b'] = record({'world': 'new'}, epoch: 1, revision: 2);
      store.values['s.fence'] = 'torn';
      final journal = SaveJournal(store, 's');
      expect(await journal.load(), {'world': 'new'});
      expect(journal.epoch, 1);
      expect(journal.revision, 100);
      await journal.save({'world': 'continued'}, resetEpoch: 1);
      expect(journal.revision, 101);
      expect(await SaveJournal(store, 's').load(), {'world': 'continued'});
    },
  );

  test(
    'Kill after fence persistence cannot resurrect the in-flight world',
    () async {
      final store = InFlightStore(), checkpoint = {'x': 0, 'alive': false};
      final journal = SaveJournal(store, 's');
      final old = journal.save({'x': 90, 'alive': true}, resetEpoch: 0);
      await store.entered.future;
      final resetting = journal.fence(1, checkpoint);
      await store.fenceWritten.future;
      // Simulate reopening before the pending old write has finished.
      expect(await SaveJournal(store, 's').load(), checkpoint);
      store.release.complete();
      await old;
      await resetting;
      expect(await SaveJournal(store, 's').load(), checkpoint);
      await journal.save({'x': 99, 'alive': true}, resetEpoch: 0);
      expect(await SaveJournal(store, 's').load(), checkpoint);
    },
  );

  test('Write failure does not poison the next save or reset', () async {
    final store = JournalStore()..writeErrors.add('s.b');
    final journal = SaveJournal(store, 's');
    await expectLater(journal.save({'n': 1}, resetEpoch: 0), throwsStateError);
    await journal.save({'n': 2}, resetEpoch: 0);
    expect(await SaveJournal(store, 's').load(), {'n': 2});
    store.writeErrors.add('s.fence');
    await expectLater(journal.fence(1, {'n': 3}), throwsStateError);
    await journal.fence(2, {'n': 4});
    expect(await SaveJournal(store, 's').load(), {'n': 4});
  });

  test('Snapshot is captured before queued writes run', () async {
    final store = InFlightStore();
    final journal = SaveJournal(store, 's');
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
    expect(await SaveJournal(store, 's').load(), {
      'nested': [1, 2],
    });
  });

  test(
    'Checksummed incompatible state can recover the same-generation sibling',
    () async {
      final store = JournalStore();
      final journal = SaveJournal(store, 's');
      await journal.save({'state': 1}, resetEpoch: 0);
      await journal.save({'missing': true}, resetEpoch: 0);
      final reader = SaveJournal(store, 's');
      expect(await reader.load(accepts: (s) => s['state'] is int), {
        'state': 1,
      });
      expect(reader.hadUnreadableRecords, isTrue);
    },
  );

  test('Invalid new generation cannot fall back across a reset', () async {
    final store = JournalStore();
    final journal = SaveJournal(store, 's');
    await journal.save({'state': 1}, resetEpoch: 0);
    await journal.fence(1, {'incompatible': true});
    expect(
      await SaveJournal(store, 's').load(accepts: (s) => s['state'] is int),
      isNull,
    );
  });
}
