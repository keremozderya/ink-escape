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
  Future<void> _tail = Future<void>.value();
  Future<void> _fenceTail = Future<void>.value();

  static int checksum(String s) {
    var hash = 0x811c9dc5;
    for (final code in utf8.encode(s)) {
      hash = ((hash ^ code) * 0x01000193) & 0xffffffff;
    }
    return hash;
  }

  Future<void> save(Map<String, dynamic> snapshot, {required int resetEpoch}) {
    final payload = jsonEncode(snapshot), rev = ++revision;
    if (resetEpoch > epoch) {
      epoch = resetEpoch;
    }
    final capturedEpoch = resetEpoch;
    final encoded = jsonEncode({
      'revision': rev,
      'epoch': capturedEpoch,
      'checksum': checksum(payload),
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
    if (resetEpoch < epoch) {
      return Future<void>.value();
    }
    epoch = resetEpoch;
    final payload = jsonEncode(checkpoint);
    final encoded = jsonEncode({
      'epoch': resetEpoch,
      'checksum': checksum(payload),
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

  Map<String, dynamic>? _decode(String? value) {
    if (value == null) {
      return null;
    }
    try {
      final m = jsonDecode(value) as Map<String, dynamic>;
      if (checksum(m['payload'] as String) != m['checksum']) {
        return null;
      }
      return m;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> load() async {
    final a = _decode(await store.read('$namespace.a'));
    final b = _decode(await store.read('$namespace.b'));
    final fence = _decode(await store.read('$namespace.fence'));
    final minimumEpoch = (fence?['epoch'] as num?)?.toInt() ?? 0;
    epoch = minimumEpoch;
    final candidates = [?a, ?b]
      ..sort((x, y) => (y['revision'] as int).compareTo(x['revision'] as int));
    if (candidates.isNotEmpty) {
      revision = candidates.first['revision'] as int;
    }
    for (final candidate in candidates) {
      if ((candidate['epoch'] as int) >= minimumEpoch) {
        epoch = candidate['epoch'] as int;
        return jsonDecode(candidate['payload'] as String)
            as Map<String, dynamic>;
      }
    }
    return fence == null
        ? null
        : jsonDecode(fence['payload'] as String) as Map<String, dynamic>;
  }
}
