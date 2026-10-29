import 'dart:convert';

abstract class StringStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SaveJournal {
  SaveJournal(this.store, this.namespace);
  final StringStore store;
  final String namespace;
  int epoch = 0, revision = 0;
  bool hadUnreadableRecords = false;
  Future<void> _tail = Future<void>.value();
  Future<void> _fenceTail = Future<void>.value();

  static int checksum(String s) {
    var hash = 0x811c9dc5;
    for (final code in utf8.encode(s)) {
      hash = ((hash ^ code) * 0x01000193) & 0xffffffff;
    }
    return hash;
  }

  static int _recordChecksum(String payload, int epoch, int revision) =>
      checksum('$epoch:$revision:$payload');

  Future<void> save(Map<String, dynamic> snapshot, {required int resetEpoch}) {
    if (resetEpoch < 0) {
      throw RangeError.value(resetEpoch, 'resetEpoch');
    }
    if (resetEpoch < epoch) {
      return Future<void>.value();
    }
    final payload = jsonEncode(snapshot), rev = ++revision;
    if (resetEpoch > epoch) {
      epoch = resetEpoch;
    }
    final capturedEpoch = resetEpoch;
    final encoded = jsonEncode({
      'format': 2,
      'revision': rev,
      'epoch': capturedEpoch,
      'checksum': _recordChecksum(payload, capturedEpoch, rev),
      'payload': payload,
    });
    _tail = _tail.catchError((Object _) {}).then((_) async {
      if (capturedEpoch < epoch) {
        return;
      }
      await store.write('$namespace.${rev.isEven ? 'a' : 'b'}', encoded);
    });
    return _tail;
  }

  /// Separate reset fence survives even if an older in-flight autosave completes later.
  Future<void> fence(int resetEpoch, Map<String, dynamic> checkpoint) {
    if (resetEpoch < 0) throw RangeError.value(resetEpoch, 'resetEpoch');
    if (resetEpoch < epoch) {
      return Future<void>.value();
    }
    epoch = resetEpoch;
    final payload = jsonEncode(checkpoint);
    final encoded = jsonEncode({
      'format': 2,
      'epoch': resetEpoch,
      'checksum': _recordChecksum(payload, resetEpoch, 0),
      'payload': payload,
    });
    _fenceTail = _fenceTail.catchError((Object _) {}).then((_) async {
      if (resetEpoch < epoch) {
        return;
      }
      await store.write('$namespace.fence', encoded);
    });
    return _fenceTail.then((_) => save(checkpoint, resetEpoch: resetEpoch));
  }

  _JournalRecord? _decode(String? value, {bool fence = false}) {
    if (value == null) {
      return null;
    }
    try {
      final m = jsonDecode(value) as Map<String, dynamic>;
      final payload = m['payload'];
      final epoch = m['epoch'];
      final revision = fence ? 0 : m['revision'];
      final format = m['format'];
      if (payload is! String ||
          epoch is! int ||
          epoch < 0 ||
          revision is! int ||
          revision < (fence ? 0 : 1) ||
          m['checksum'] is! int ||
          (format != null && format != 2)) {
        return null;
      }
      final expected = format == 2
          ? _recordChecksum(payload, epoch, revision)
          : checksum(payload);
      if (expected != m['checksum']) {
        return null;
      }
      final snapshot = jsonDecode(payload) as Map<String, dynamic>;
      if (snapshot.containsKey('resetEpoch') &&
          snapshot['resetEpoch'] != epoch) {
        return null;
      }
      return _JournalRecord(epoch, revision, snapshot);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> load({
    bool Function(Map<String, dynamic>)? accepts,
  }) async {
    hadUnreadableRecords = false;
    final candidates = <_JournalRecord>[];
    _JournalRecord? fence;
    var readFailures = 0;
    for (final slot in ['a', 'b', 'fence']) {
      try {
        final raw = await store.read('$namespace.$slot');
        final record = _decode(raw, fence: slot == 'fence');
        if (raw != null && record == null) hadUnreadableRecords = true;
        if (slot == 'fence') {
          fence = record;
        } else if (record != null) {
          candidates.add(record);
        }
      } catch (_) {
        hadUnreadableRecords = true;
        readFailures++;
      }
    }
    if (readFailures == 3) throw StateError('Save storage is unavailable');
    // A reset generation outranks every older revision, even if the fence's
    // bytes were torn. Never resurrect the world before a death or boundary.
    epoch = fence?.epoch ?? 0;
    revision = 0;
    for (final record in candidates) {
      if (record.epoch > epoch) epoch = record.epoch;
      if (record.revision > revision) revision = record.revision;
    }
    candidates.sort((a, b) => b.revision.compareTo(a.revision));
    for (final record in [...candidates, ?fence]) {
      if (record.epoch != epoch) continue;
      try {
        if (accepts == null || accepts(record.snapshot)) return record.snapshot;
      } catch (_) {
        // A checksummed but incompatible snapshot can still use a healthy
        // sibling or the checkpoint of the same reset generation.
      }
      hadUnreadableRecords = true;
    }
    return null;
  }
}

class _JournalRecord {
  const _JournalRecord(this.epoch, this.revision, this.snapshot);
  final int epoch, revision;
  final Map<String, dynamic> snapshot;
}
