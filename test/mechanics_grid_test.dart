import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'package:ink_escape/main.dart';
import 'package:ink_escape/presentation/mechanics_thumbnail.dart';
import 'journey_hud_test.dart' show capture;
import 'session_flow_test.dart' show mountGame, unmountGame;
import 'viewport_menu_test.dart' show story;

void main() {
  for (final size in [const Size(568, 320), const Size(960, 540)]) {
    testWidgets(
      'Five course maps per row, filter and final row are reachable at $size',
      (tester) async {
        final key = GlobalKey();
        await mountGame(
          tester,
          InkSession(story()),
          MemoryStore(),
          size: size,
          captureKey: key,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('ink-open-mechanics')),
        );
        await tester.tap(find.byKey(const ValueKey('ink-open-mechanics')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final boxes = [
          for (final spec in InkLabCase.all.take(6))
            tester.getRect(find.byKey(ValueKey('ink-test-${spec.id}'))),
        ];
        for (var i = 0; i < 5; i++) {
          expect(boxes[i].top, boxes.first.top);
          expect(boxes[i].width, greaterThanOrEqualTo(90));
          expect(
            find.byKey(ValueKey('ink-test-preview-${InkLabCase.all[i].id}')),
            findsOneWidget,
          );
          if (i > 0) expect(boxes[i].left, greaterThan(boxes[i - 1].right));
        }
        expect(boxes[5].left, boxes.first.left);
        expect(boxes[5].top, greaterThan(boxes.first.bottom));
        await capture(tester, key, 'level-grid-${size.width.toInt()}');
        if (size.width == 568) {
          expect(
            find.byType(InkMechanicsThumbnail).evaluate().length,
            lessThan(InkLabCase.all.length),
          );
        }
        final last = find.byKey(ValueKey('ink-test-${InkLabCase.all.last.id}'));
        await tester.scrollUntilVisible(
          last,
          150,
          scrollable: find.descendant(
            of: find.byKey(const ValueKey('ink-mechanics-list')),
            matching: find.byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            ),
          ),
        );
        await tester.ensureVisible(last);
        await tester.pump();
        expect(tester.getRect(last).bottom, lessThanOrEqualTo(size.height));
        final list = tester.widget<CustomScrollView>(
          find.byKey(const ValueKey('ink-mechanics-list')),
        );
        list.controller!.jumpTo(0);
        await tester.pump();
        final filter = find.byKey(
          const ValueKey('ink-test-filter-environment'),
        );
        await tester.ensureVisible(filter);
        await tester.tap(filter);
        await tester.pump();
        expect(find.byKey(const ValueKey('ink-test-slide')), findsNothing);
        expect(find.byKey(const ValueKey('ink-test-fold')), findsOneWidget);
        await capture(
          tester,
          key,
          'level-grid-obstacles-${size.width.toInt()}',
        );
        final maps = tester.widgetList<InkMechanicsThumbnail>(
          find.byType(InkMechanicsThumbnail),
        );
        expect(
          maps.map((m) => m.session.mechanics!.spec.id).toSet().length,
          maps.length,
        );
        expect(tester.takeException(), isNull);
        await unmountGame(tester);
      },
    );
  }
}
