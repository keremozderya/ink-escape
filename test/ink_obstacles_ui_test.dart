import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'package:ink_escape/main.dart';
import 'mechanics_lab_ui_test.dart' show openTest, captureLab;
import 'session_flow_test.dart' show mountGame, unmountGame;
import 'viewport_menu_test.dart' show story;

void main() {
  for (final size in [const Size(568, 320), const Size(960, 540)]) {
    for (final id in ['spikes', 'wall-saw']) {
      testWidgets(
        '$id has a real card, pointer-drawn solution and campaign isolation at $size',
        (tester) async {
          final original = InkSession(story()),
              store = MemoryStore(),
              key = GlobalKey();
          await mountGame(tester, original, store, size: size, captureKey: key);
          await tester.ensureVisible(
            find.byKey(const ValueKey('ink-open-mechanics')),
          );
          await tester.tap(find.byKey(const ValueKey('ink-open-mechanics')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tester.ensureVisible(
            find.byKey(const ValueKey('ink-test-filter-environment')),
          );
          await tester.tap(
            find.byKey(const ValueKey('ink-test-filter-environment')),
          );
          await tester.pump();
          final state = await openTest(tester, id), s = state.widget.session;
          Offset screen(V p) => state.game.point(p) * state.game.scale;
          final points = s.mechanics!.guides.first.first;
          final pen = await tester.startGesture(screen(points.first));
          for (var i = 1; i < points.length; i++) {
            for (var step = 1; step <= 20; step++) {
              await pen.moveTo(
                screen(
                  points[i - 1] + (points[i] - points[i - 1]) * (step / 20),
                ),
              );
            }
          }
          await pen.up();
          await tester.pump();
          expect(s.lines, hasLength(1), reason: s.message);
          await captureLab(
            tester,
            key,
            state,
            'obstacle-$id-${size.width.toInt()}',
          );
          await tester.tap(find.byKey(const ValueKey('ink-test-walk')));
          for (var i = 0; i < 600 && s.phase == Phase.playing; i++) {
            state.game.update(1 / 30);
            if (i % 10 == 0) await tester.pump();
          }
          expect(s.phase, Phase.complete, reason: s.message);
          expect(original.x, 0);
          expect(
            store.values.keys.any((k) => k.contains('mechanics')),
            isFalse,
          );
          expect(tester.takeException(), isNull);
          await unmountGame(tester);
        },
      );
    }
  }
}
