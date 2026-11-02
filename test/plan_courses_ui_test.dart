import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'package:ink_escape/main.dart';

import 'journey_hud_test.dart' show capture;
import 'mechanics_lab_ui_test.dart' show openTest;
import 'session_flow_test.dart' show mountGame, unmountGame;
import 'viewport_menu_test.dart' show story;

void main() {
  for (final size in [const Size(568, 320), const Size(960, 540)]) {
    testWidgets(
      'Three-job PDF course can be drawn and played through its UI at $size',
      (tester) async {
        final storySession = InkSession(story());
        final store = MemoryStore(), key = GlobalKey();
        await mountGame(
          tester,
          storySession,
          store,
          captureKey: key,
          size: size,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('ink-open-mechanics')),
        );
        await tester.tap(find.byKey(const ValueKey('ink-open-mechanics')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.byKey(const ValueKey('ink-test-filter-plan')));
        await tester.pump();
        final state = await openTest(tester, 'plan-Q');
        final s = state.widget.session, lab = state.widget.session.mechanics!;
        await tester.tap(find.byKey(const ValueKey('ink-test-guide')));
        await tester.pump();
        var next = 0;
        for (
          var frame = 0;
          frame < 30 * 25 && s.phase == Phase.playing;
          frame++
        ) {
          if (next < lab.tasks.length && lab.tasks[next].ready(s)) {
            if (!lab.holdDot) {
              await tester.tap(find.byKey(const ValueKey('ink-test-walk')));
              await tester.pump();
            }
            Offset screen(V p) => state.game.point(p) * state.game.scale;
            final p = lab.tasks[next].points;
            for (final point in p) {
              final at = screen(point);
              expect(at.dx, inInclusiveRange(0, size.width));
              expect(at.dy, inInclusiveRange(120, size.height));
            }
            final pen = await tester.startGesture(screen(p.first));
            for (var i = 1; i < p.length; i++) {
              for (var j = 1; j <= 16; j++) {
                await pen.moveTo(
                  screen(p[i - 1] + (p[i] - p[i - 1]) * (j / 16)),
                );
              }
            }
            await pen.up();
            await tester.pump();
            expect(s.activeLines, inInclusiveRange(1, 2));
            expect(s.draft, isNull);
            next++;
            await tester.tap(find.byKey(const ValueKey('ink-test-walk')));
            await tester.pump();
          }
          state.game.update(1 / 30);
          if (frame % 6 == 0) await tester.pump();
        }
        await tester.pump();
        expect(next, 3);
        expect(s.level.balls.single.captured, isTrue);
        expect(s.phase, Phase.complete, reason: '${s.x}, ${s.y}: ${s.message}');
        expect(storySession.x, 0);
        expect(store.values.keys.any((k) => k.contains('mechanics')), isFalse);
        expect(tester.takeException(), isNull);
        state.game.update(.1);
        state.game.renderBox.markNeedsPaint();
        await tester.pump();
        await capture(tester, key, 'plan-three-jobs-${size.width.toInt()}');
        await unmountGame(tester);
      },
    );
  }
}
