import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'package:ink_escape/core/save_journal.dart';
import 'package:ink_escape/main.dart';
import 'package:ink_escape/soundscape.dart';

void main() {
  for (final config in [
    ('phone touch', const Size(390, 844), PointerDeviceKind.touch),
    ('desktop mouse', const Size(1280, 800), PointerDeviceKind.mouse),
  ]) {
    testWidgets(
      '${config.$1}: actual pointer drag commits a visible curved bridge',
      (tester) async {
        tester.view.physicalSize = config.$2;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          await Flame.images.loadAll([
            'dot_walk.png',
            'props.png',
            'paper_garden.png',
            'paper_ruins.png',
            'storyboard_opening.png',
          ]);
        });
        final raw = jsonDecode(
          File('assets/data/prototype_levels.json').readAsStringSync(),
        );
        final s = InkSession(
          (raw['story'] as List)
              .map((m) => Map<String, dynamic>.from(m))
              .toList(),
        );
        final store = MemoryStore();
        await tester.pumpWidget(
          InkEscapeApp(
            session: s,
            journal: SaveJournal(store, 'input'),
            store: store,
            sound: Soundscape(enabled: false),
          ),
        );
        for (var i = 0; i < 10; i++) {
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.text('Yolculuğa başla'));
        await tester.pump();
        await tester.tap(find.text('Hikâyeyi atla'));
        await tester.pump();
        final state = tester.state<GameScreenState>(find.byType(GameScreen));
        s.advance(128 / s.walkSpeed);
        state.game.cameraX = s.x - 96;
        await tester.pump();
        final origin = tester.getTopLeft(
          find.byKey(const ValueKey('ink-drawing-surface')),
        );
        Offset point(V p) => origin + state.game.point(p) * state.game.scale;
        final pen = await tester.startGesture(
          point(const V(320, 0)),
          kind: config.$3,
        );
        expect(s.draft, isNotNull);
        final before = s.ink;
        for (var i = 1; i <= 30; i++) {
          final t = i / 30;
          final wobble = i == 30 ? 0.0 : (i.isOdd ? 1.5 : -1.5);
          await pen.moveTo(
            point(V(320 + 72 * t, 5 * 4 * t * (1 - t) + wobble)),
          );
          await tester.pump(const Duration(milliseconds: 12));
        }
        expect(s.lines, isEmpty);
        expect(s.ink, greaterThanOrEqualTo(before));
        await pen.up();
        await tester.pump();
        expect(s.lines.length, 1, reason: s.message);
        expect(s.ink, lessThan(before));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
}
