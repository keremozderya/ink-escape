import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'package:ink_escape/main.dart';
import 'mechanics_lab_ui_test.dart' show openTest;
import 'session_flow_test.dart' show mountGame, unmountGame;
import 'viewport_menu_test.dart' show story;

void main() {
  for (final size in [const Size(568, 320), const Size(960, 540)]) {
    for (final id in ['fold', 'fold-cover']) {
      testWidgets(
        '$id: actual drawing and a walking button press finish at $size',
        (tester) async {
          final storySession = InkSession(story()), store = MemoryStore();
          await mountGame(tester, storySession, store, size: size);
          await tester.ensureVisible(
            find.byKey(const ValueKey('ink-open-mechanics')),
          );
          await tester.tap(find.byKey(const ValueKey('ink-open-mechanics')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          final state = await openTest(tester, id);
          final s = state.widget.session, lab = state.widget.session.mechanics!;
          await tester.tap(find.byKey(const ValueKey('ink-test-guide')));
          await tester.pump();
          Offset screen(V p) => state.game.point(p) * state.game.scale;
          for (final points in lab.guides.first) {
            final pen = await tester.startGesture(screen(points.first));
            for (var i = 1; i < points.length; i++) {
              for (var j = 1; j <= 20; j++) {
                final at = screen(
                  points[i - 1] + (points[i] - points[i - 1]) * (j / 20),
                );
                expect(at.dx, inInclusiveRange(0, size.width));
                expect(at.dy, inInclusiveRange(120, size.height));
                await pen.moveTo(at);
              }
            }
            await pen.up();
            await tester.pump();
          }
          expect(
            s.lines,
            hasLength(lab.guides.first.length),
            reason: s.message,
          );
          final ink = s.lines.last;
          expect(lab.paper!.pressed, isFalse);
          await tester.tap(find.byKey(const ValueKey('ink-test-walk')));
          for (var i = 0; i < 30 * 20 && s.phase == Phase.playing; i++) {
            state.game.update(1 / 30);
            if (i % 6 == 0) await tester.pump();
          }
          expect(
            s.phase,
            Phase.complete,
            reason: '${s.x}, ${s.y}: ${s.message}',
          );
          expect(lab.paper!.pressed, isTrue);
          expect(lab.paper!.settled, isTrue);
          expect(ink.concealed, isTrue);
          expect(storySession.x, 0);
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
