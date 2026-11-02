import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'mechanics_lab_test.dart' show drawLab;

void main() {
  test(
    'Touching the middle cuts only the local ink and preserves cost, identity and ends',
    () {
      final line = InkLine('paid', [const V(0, 0), const V(100, 0)]),
          source = line.points;
      const eraser = InkEraser(V(50, 0));
      expect(eraser.erase(line), isTrue);
      expect(line.contours, hasLength(2));
      expect(line.yAt(50), isNull);
      expect(line.yAt(15), 0);
      expect(line.yAt(85), 0);
      expect(line.points, same(source));
      expect(line.cost, 100);
      expect(line.retired, isFalse);
      final revision = line.geometryRevision;
      expect(eraser.erase(line), isFalse);
      expect(line.geometryRevision, revision);
    },
  );

  test(
    'A returning stroke loses only the touched run and never joins across a hole',
    () {
      final line = InkLine('loop', [
        const V(0, 0),
        const V(100, 0),
        const V(100, 50),
        const V(0, 50),
      ]);
      expect(const InkEraser(V(50, 0)).erase(line), isTrue);
      expect(line.contours, hasLength(2));
      expect(line.crossingsAt(50).map((hit) => hit.$1), [50]);
      expect(line.yAt(10), 50);
      expect(line.cost, 250);
      const InkEraser(V(75, 50)).erase(line);
      expect(line.contours, hasLength(3));
      expect(line.crossingsAt(75).map((hit) => hit.$1), [0]);
    },
  );

  test(
    'The rounded corner of the drawn eraser leaves nearby untouching ink intact',
    () {
      V world(double x, double y) => V(
        x * math.cos(InkEraser.angle) - y * math.sin(InkEraser.angle),
        x * math.sin(InkEraser.angle) + y * math.cos(InkEraser.angle),
      );
      final outside = InkLine('outside', [world(13.7, 9.6), world(13.9, 9.8)]),
          inside = InkLine('inside', [world(11, 8), world(12, 8)]);
      expect(const InkEraser(V(0, 0)).erase(outside), isFalse);
      expect(const InkEraser(V(0, 0)).erase(inside), isTrue);
      expect(inside.concealed, isTrue);
    },
  );

  test(
    'Erasing uses world contours, including verticals, rather than paid source coordinates',
    () {
      final line = InkLine('moved', [const V(0, 0), const V(100, 0)])
        ..setContours([
          [const V(50, 10), const V(50, 110)],
        ]);
      expect(const InkEraser(V(50, -20)).erase(line), isFalse);
      expect(const InkEraser(V(50, 60)).erase(line), isTrue);
      expect(line.contours, hasLength(2));
      expect(line.contours.first.last.y, lessThan(51));
      expect(line.contours.last.first.y, greaterThan(69));
      expect(line.cost, 100);
    },
  );

  test(
    'Several surviving pieces still occupy one slot; erasing every piece frees it without a refund',
    () {
      final s = InkLabCase.byId('eraser').createSession()..start();
      drawLab(s, [const V(160, 0), const V(330, 0)]);
      final line = s.lines.single, paid = s.ink;
      const InkEraser(V(245, 0)).erase(line);
      expect(s.activeLines, 1);
      expect(s.lines, hasLength(1));
      for (var x = 160.0; x <= 340; x += 12) {
        InkEraser(V(x, 0)).erase(line);
      }
      expect(s.activeLines, 0);
      expect(s.ink, paid);
    },
  );

  test(
    'A cut invalidates warmed collision geometry and removes support below Dot',
    () {
      final s = InkLabCase.byId('eraser').createSession()..start();
      drawLab(s, [const V(160, 0), const V(330, 0)]);
      s.x = 245;
      s.y = 0;
      s.grounded = true;
      s.onNatural = false;
      s.mechanics!.holdDot = false;
      s.advance(1 / 120);
      expect(s.grounded, isTrue);
      InkEraser(V(s.x, s.y)).erase(s.lines.single);
      s.advance(1 / 120);
      expect(s.grounded, isFalse);
      expect(s.y, lessThan(0));
    },
  );
}
