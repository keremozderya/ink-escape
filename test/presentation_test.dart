import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'package:ink_escape/presentation/ink_motion.dart';
import 'package:ink_escape/presentation/opening_story.dart';
import 'package:ink_escape/presentation/paper_world.dart';

void main() {
  test('Scenery follows terrain one-to-one and survives level rebasing', () {
    const localCamera = 12.0, origin = 7800.0, worldObject = 3000.0;
    final before = PaperScene.screenX(worldObject, 7812);
    final after = PaperScene.screenX(worldObject, localCamera + origin);
    expect(before, after);
    final moved = PaperScene.screenX(worldObject, 7912);
    expect(before - moved, closeTo(100, 1e-8));
    for (final camera in [-96.0, 0.0, 7800.0, 1000000.0]) {
      final start = PaperScene.tileStart(camera, 640);
      expect(start, inInclusiveRange(-640, 0));
      expect(start + 640, greaterThanOrEqualTo(0));
    }
  });
  test('Planted foot stays at same world point while body advances', () {
    for (final d in [1.0, 8.0, 14.0]) {
      final a = InkWalkPose.sample(d, grounded: true, walking: true);
      final b = InkWalkPose.sample(d + 1, grounded: true, walking: true);
      expect(d + a.back.x, closeTo(d + 1 + b.back.x, 1e-8));
    }
    final fall = InkWalkPose.sample(12, grounded: false, walking: false);
    expect(fall.front.planted || fall.back.planted, isFalse);
    expect(fall.front.x, isNot(fall.back.x));
  });
  test('Opening shows both discarded pieces and stops before reunion', () {
    expect(openingShots.length, 12);
    expect(openingShots[7].caption, contains('İki parçayı da çöpe'));
    expect(openingShots.last.title, 'Senin çizgin');
    expect(openingShots.fold<int>(0, (s, shot) => s + shot.seconds), 37);
    for (final shot in openingShots) {
      expect(shot.source.left, greaterThanOrEqualTo(0));
      expect(shot.source.right, lessThanOrEqualTo(1536));
      expect(shot.source.bottom, lessThanOrEqualTo(1024));
    }
  });
  test(
    'Old layout keeps completed levels and migrates current checkpoint safely',
    () {
      final raw = jsonDecode(
        File('assets/data/prototype_levels.json').readAsStringSync(),
      );
      final data = (raw['story'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final save = InkSession(data).snapshot()
        ..remove('layoutRevision')
        ..['levelIndex'] = 1
        ..['x'] = 9000.0
        ..['entryInk'] = 157.0;
      final s = InkSession.restore(data, save);
      expect(s.migratedLayout, isTrue);
      expect(s.levelIndex, 1);
      expect(s.x, 0);
      expect(s.ink, 157);
      expect(s.origin, data.first['width']);
      expect(s.lines, isEmpty);
      expect(s.phase, Phase.ready);
      expect(InkSession.restore(data, s.snapshot()).migratedLayout, isFalse);
    },
  );
}
