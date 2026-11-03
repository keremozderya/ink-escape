import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'package:ink_escape/main.dart' show MemoryStore;

import 'journey_hud_test.dart' show capture;
import 'session_flow_test.dart' show mountGame, unmountGame;
import 'stroke_contact_test.dart' show scene;

void main() {
  testWidgets(
    'A real pointer draws from air, touches paper in the middle and releases in air',
    (tester) async {
      final s = scene()..drawingTutorialDone = true;
      final key = GlobalKey();
      final state = await mountGame(tester, s, MemoryStore(), captureKey: key);
      Offset screen(V p) => state.game.point(p) * state.game.scale;
      final ink = s.ink;
      final pen = await tester.startGesture(screen(const V(70, 40)));
      expect(s.draft, isNotNull);
      expect(s.draft!.start, isNull);
      await pen.moveTo(screen(const V(150, 0)));
      await pen.moveTo(screen(const V(230, 40)));
      final preview = s.validatedDraft().$1;
      expect(preview, isNotNull);
      await tester.pump();
      await capture(tester, key, 'free-stroke-preview');
      await pen.up();
      await tester.pump();
      expect(s.lines, hasLength(1));
      expect(s.lines.single.points.first.toJson(), [70.0, 40.0]);
      expect(s.lines.single.points.last.toJson(), [230.0, 40.0]);
      expect(
        s.lines.single.points.map((p) => p.toJson()),
        preview!.map((p) => p.toJson()),
      );
      expect(s.lines.single.yAt(150), closeTo(0, 1e-7));
      expect(s.ink, closeTo(ink - s.lines.single.cost, 1e-7));
      await capture(tester, key, 'free-stroke-accepted');
      final paid = s.ink;
      final floating = await tester.startGesture(screen(const V(70, 75)));
      await floating.moveTo(screen(const V(230, 75)));
      await floating.up();
      await tester.pump();
      expect(s.lines, hasLength(1));
      expect(s.ink, paid);
      expect(tester.takeException(), isNull);
      await unmountGame(tester);
    },
  );
}
