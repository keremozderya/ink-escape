import 'dart:convert';
import 'dart:io';
import 'package:ink_escape/core/ink_model.dart';

void main() {
  final raw = jsonDecode(
    File('assets/data/prototype_levels.json').readAsStringSync(),
  );
  final results = <Map<String, dynamic>>[];
  for (final key in ['story', 'zero-ink', 'two', 'roof', 'ball']) {
    final list = key == 'story' || key == 'zero-ink'
        ? raw['story']
        : [raw['labs'][key]];
    final data = (list as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final s = InkSession(data, lab: key != 'story' && key != 'zero-ink')
      ..start();
    if (key == 'zero-ink') {
      s.ink = 0;
    }
    final done = <String>{};
    final boundaries = <double>[];
    var gestures = 0, maxSlots = 0;
    s.onEvent = (name, p) {
      if (name == 'boundary') {
        boundaries.add(s.activeTotal);
      }
    };
    while (s.phase == Phase.playing && s.activeTotal < 1000) {
      for (final r in s.level.reference) {
        final id = '${s.levelIndex}:${r['id']}';
        if (!done.contains(id) && s.x >= r['cue']) {
          done.add(id);
          final points = r['points'] as List<V>;
          if (!s.beginStroke(points.first)) {
            throw StateError('Cannot start $key $id ${s.message}');
          }
          final path = InkLine('reference', points);
          final n = (path.cost / 3).ceil();
          for (var j = 1; j <= n; j++) {
            s.moveStroke(path.atDistance(path.cost * j / n).$1);
            s.advance(1 / n);
          }
          if (!s.endStroke()) {
            throw StateError('Cannot finish $key $id ${s.message}');
          }
          gestures++;
        }
      }
      if (s.activeLines > maxSlots) {
        maxSlots = s.activeLines;
      }
      s.advance(1 / 60);
    }
    if (s.phase != Phase.complete) {
      throw StateError('$key failed: ${s.message}');
    }
    results.add({
      'scenario': key,
      'passed': true,
      'active_real_seconds': double.parse(s.activeTotal.toStringAsFixed(3)),
      'level_boundaries_seconds': boundaries
          .map((x) => double.parse(x.toStringAsFixed(3)))
          .toList(),
      'committed_human_api_gestures': gestures,
      'max_active_lines': maxSlots,
      'final_ink': double.parse(s.ink.toStringAsFixed(3)),
      'balls_captured': s.level.balls.where((b) => b.captured).length,
      'gates_open': s.level.gates.where((g) => g.open).length,
    });
  }
  final report = {
    'prototype': '0.3',
    'date': '2026-10-18',
    'gesture_real_seconds': 1,
    'step_seconds': 1 / 120,
    'method':
        'Authored reference points through public begin/move/end stroke API, while time advances; no injected solid lines.',
    'results': results,
  };
  Directory('qa').createSync();
  File(
    'qa/route-verification.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
}
