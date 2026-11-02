part of '../ink_game.dart';

extension _LabPainting on InkGame {
  void _drawFoldPage(Canvas c) {
    final page = session.mechanics?.paper;
    if (page == null) return;
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    Path shape(List<V> vertices) =>
        Path()..addPolygon(vertices.map(point).toList(), true);
    void panel(List<V> vertices, {required bool moving}) {
      if (vertices.length < 3) return;
      final outline = shape(vertices);
      c.drawPath(
        outline.shift(const Offset(1, 2)),
        Paint()..color = const Color(0x18554732),
      );
      c.drawPath(
        outline,
        Paint()
          ..color = moving && page.backFacing
              ? const Color(0xffe9dec7)
              : const Color(0xfff9f3e5),
      );
      c.save();
      c.clipPath(outline);
      V at(V p) => moving ? page.project(p) : p;
      final left = page.cover ? 260.0 : 160.0,
          right = page.cover ? 370.0 : 340.0;
      // Flat paper fibres and a small printed stem belong to the sheet. They
      // follow its material coordinates instead of floating above a bridge.
      for (var y = -9.0; y > -FoldPaper.depth; y -= 12) {
        c.drawLine(
          point(at(V(left + 3, y))),
          point(at(V(right - 3, y + .4))),
          pen
            ..color = const Color(0x168c795c)
            ..strokeWidth = .5,
        );
      }
      if (!moving || page.frontFacing) {
        for (var k = 0; k < 3; k++) {
          final x = left + 32 + k * 41.0, y = -79.0 + k * 7;
          c.drawLine(
            point(at(V(x, y - 15))),
            point(at(V(x + 2, y + 16))),
            pen
              ..color = const Color(0x547c8069)
              ..strokeWidth = .65,
          );
          for (var j = 0; j < 3; j++) {
            final stem = V(x + 1, y - 8 + j * 8.0);
            c.drawLine(
              point(at(stem)),
              point(at(stem + V(j.isEven ? -7 : 7, 5))),
              pen,
            );
          }
          final bud = Path()
            ..addPolygon(
              [
                V(x + 2, y + 14),
                V(x - 3, y + 19),
                V(x + 2, y + 23),
                V(x + 6, y + 19),
              ].map((p) => point(at(p))).toList(),
              true,
            );
          c.drawPath(bud, pen..color = const Color(0x557c7158));
        }
      }
      c.restore();
      c.drawPath(
        outline,
        pen
          ..color = const Color(0xff9b896b)
          ..strokeWidth = .85,
      );
    }

    panel(page.fixed, moving: false);
    if (math.cos(page.angle).abs() > .001) panel(page.polygon, moving: true);
    final delta = page.creaseEnd - page.crease, length = delta.length;
    for (var d = 0.0; d < length; d += 9) {
      c.drawLine(
        point(page.crease + delta * (d / length)),
        point(page.crease + delta * (math.min(length, d + 4) / length)),
        pen
          ..color = const Color(0xcc8b7756)
          ..strokeWidth = 1,
      );
    }
    for (final edge in page.surfaces) {
      c.drawLine(
        point(edge.a),
        point(edge.b),
        pen
          ..color = const Color(0xff78674c)
          ..strokeWidth = 1.2,
      );
    }
  }

  void _drawFoldButton(Canvas c, FoldPaper page) {
    final p = point(const V(FoldPaper.buttonX, 0));
    final down = page.pressed ? 0.0 : 3.5;
    final pen = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xff77674e);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(p.dx - 12, p.dy - 1, 24, 4),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xffbaa47c),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(p.dx - 9, p.dy - down - 3, 18, 4),
        const Radius.circular(2),
      ),
      Paint()
        ..color = page.pressed
            ? const Color(0xff879078)
            : const Color(0xffd2bc91),
    );
    c.drawLine(p + Offset(-8, -down - 3), p + Offset(8, -down - 3), pen);
    if (!page.pressed) {
      final bob = 1.2 * math.sin(visualTime * 3);
      final arrow = Path()
        ..moveTo(p.dx, p.dy - 25 + bob)
        ..lineTo(p.dx, p.dy - 14 + bob)
        ..moveTo(p.dx - 3, p.dy - 18 + bob)
        ..lineTo(p.dx, p.dy - 14 + bob)
        ..lineTo(p.dx + 3, p.dy - 18 + bob);
      c.drawPath(arrow, pen..color = const Color(0xaa65786f));
    }
    final end = point(page.crease - const V(0, 9));
    c.drawLine(
      p + const Offset(12, 4),
      end,
      pen
        ..color = const Color(0x4479674f)
        ..strokeWidth = .6,
    );
  }

  void _drawPulley(Canvas c, MechanicsLab lab) {
    final deck = lab.pulleyDeck!;
    _labDeck(c, deck.a, deck.b);
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0xff857359)
      ..strokeCap = StrokeCap.round;
    const wheel = V(315, 145), second = V(350, 145);
    final weight = V(350, 90 - deck.b.y * .6);
    final rope = Path()
      ..moveTo(point(deck.b).dx, point(deck.b).dy)
      ..lineTo(point(wheel).dx - 7, point(wheel).dy)
      ..lineTo(point(wheel).dx, point(wheel).dy - 7)
      ..lineTo(point(second).dx, point(second).dy - 7)
      ..lineTo(point(second).dx + 7, point(second).dy)
      ..lineTo(point(weight).dx + 7, point(weight).dy);
    c.drawPath(rope, pen);
    c.drawLine(
      point(const V(368, 0)),
      point(const V(368, 162)),
      pen..color = const Color(0x66857359),
    );
    c.drawLine(point(const V(300, 162)), point(const V(368, 162)), pen);
    for (final at in [wheel, second]) {
      c.drawCircle(point(at), 8, Paint()..color = const Color(0xffd6c6a7));
      c.drawCircle(point(at), 8, pen..color = const Color(0xff857359));
      c.drawLine(
        point(at) + const Offset(-5, 0),
        point(at) + const Offset(5, 0),
        pen,
      );
      c.drawCircle(point(at), 1.5, Paint()..color = const Color(0xff77674f));
    }
    final box = Rect.fromCenter(
      center: point(weight) + const Offset(7, 8),
      width: 16,
      height: 20,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(2)),
      Paint()..color = const Color(0xffb8a382),
    );
    c.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(2)), pen);
    c.drawLine(
      box.topLeft + const Offset(3, 4),
      box.bottomRight - const Offset(3, 4),
      pen..color = const Color(0x6677674f),
    );
    c.drawCircle(point(deck.a), 3.5, Paint()..color = const Color(0xff8c7755));
  }

  void _labDeck(Canvas c, V a, V b, {double alpha = 1}) {
    final pen = Paint()..strokeCap = StrokeCap.round;
    c.drawLine(
      point(a) + const Offset(0, 3),
      point(b) + const Offset(0, 3),
      pen
        ..color = Color.fromRGBO(120, 103, 78, .45 * alpha)
        ..strokeWidth = 7,
    );
    c.drawLine(
      point(a),
      point(b),
      pen
        ..color = Color.fromRGBO(238, 226, 204, alpha)
        ..strokeWidth = 6,
    );
    c.drawLine(
      point(a) - const Offset(0, .8),
      point(b) - const Offset(0, .8),
      pen
        ..color = Color.fromRGBO(92, 78, 60, alpha)
        ..strokeWidth = 1,
    );
    final length = a.distance(b), dir = (b - a) * (1 / math.max(.001, length));
    for (var d = 8.0; d < length; d += 13) {
      final at = point(a + dir * d);
      c.drawLine(
        at + const Offset(0, 1),
        at + const Offset(-2, 4),
        pen
          ..color = Color.fromRGBO(120, 103, 78, .4 * alpha)
          ..strokeWidth = .6,
      );
    }
  }

  void _drawCrackingPaper(Canvas c, MechanicsLab lab) {
    const depth = MechanicsLab.crackDepth;
    final breaks = MechanicsLab.crackBreaks;
    final progress = lab.crackProgress;
    final age = lab.crackAt == null
        ? 0.0
        : session.gameTime - lab.crackAt! - MechanicsLab.crackDuration;
    if (lab.collapsed && age > 1.6) {
      return;
    }
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    List<Offset> tear(int boundary) {
      if (boundary == 0 || boundary == breaks.length - 1) {
        return [Offset.zero, const Offset(0, depth)];
      }
      final direction = boundary.isEven ? -1.0 : 1.0;
      return [
        Offset.zero,
        Offset((1.2 + boundary % 3 * .5) * direction, 4.0 + boundary % 3),
        Offset((-1.0 - boundary % 2) * direction, 9.0 + boundary % 3),
        Offset((2.1 + boundary % 3 * .4) * direction, 15.0 + boundary % 2),
        Offset((-1.2 + boundary % 3 * .5) * direction, 21.0 + boundary % 2),
        const Offset(0, depth),
      ];
    }

    for (var i = 0; i < breaks.length - 1; i++) {
      final x = breaks[i], width = breaks[i + 1] - x;
      final left = tear(i), right = tear(i + 1);
      final fragment = Path()
        ..moveTo(0, 0)
        ..lineTo(width, 0);
      for (final p in right.skip(1)) {
        fragment.lineTo(width + p.dx, p.dy);
      }
      fragment.lineTo(width * .68, depth + .7);
      fragment.lineTo(width * .31, depth - .4);
      for (final p in left.reversed) {
        fragment.lineTo(p.dx, p.dy);
      }
      fragment.close();
      final delay = ((x + width / 2 - lab.crackContactX).abs() / 115) * .12;
      final fall = lab.collapsed ? math.max(0.0, age - delay) : 0.0;
      final alpha = lab.collapsed ? (1 - fall / 1.4).clamp(0.0, 1.0) : 1.0;
      final spread = lab.collapsed ? (i - 2.5) * 5 * fall : 0.0;
      c.save();
      final origin = point(V(x + spread, -180 * fall * fall));
      c.translate(origin.dx, origin.dy);
      if (lab.collapsed) {
        c.translate(width / 2, depth / 2);
        c.rotate(fall * (i.isEven ? -.85 : .7));
        c.translate(-width / 2, -depth / 2);
      }
      c.drawPath(
        fragment.shift(const Offset(1, 2)),
        Paint()..color = Color.fromRGBO(88, 69, 42, .16 * alpha),
      );
      c.drawPath(
        fragment,
        Paint()
          ..color = Color.fromRGBO(
            240 + i % 2 * 5,
            230 + i % 2 * 5,
            209 + i % 2 * 7,
            alpha,
          ),
      );
      c.save();
      c.clipPath(fragment);
      for (var layer = 5.0; layer < depth; layer += 5) {
        c.drawLine(
          Offset(-3, layer),
          Offset(width + 3, layer + .6),
          pen
            ..color = Color.fromRGBO(133, 109, 74, .16 * alpha)
            ..strokeWidth = .65,
        );
      }
      c.drawRect(
        Rect.fromLTWH(-3, 0, width + 6, 3),
        Paint()..color = Color.fromRGBO(250, 242, 221, alpha),
      );
      c.restore();
      c.drawLine(
        Offset.zero,
        Offset(width, 0),
        pen
          ..color = Color.fromRGBO(99, 76, 45, alpha)
          ..strokeWidth = 1.3,
      );
      c.drawLine(
        const Offset(0, depth),
        Offset(width, depth),
        pen
          ..color = Color.fromRGBO(129, 104, 66, .7 * alpha)
          ..strokeWidth = .8,
      );
      // A short pre-existing nick signals brittle paper before it is stepped on.
      if (!lab.collapsed && i > 0) {
        final delay = (x - lab.crackContactX).abs() / 115 * .3;
        final amount = progress == 0
            ? .08
            : ((progress - delay) / (.8 - delay)).clamp(.08, 1.0);
        final seam = Path()..addPolygon(left, false);
        for (final metric in seam.computeMetrics()) {
          c.drawPath(
            metric.extractPath(0, metric.length * amount),
            pen
              ..color = Color.fromRGBO(91, 67, 37, .65 + amount * .35)
              ..strokeWidth = .8 + amount * .55,
          );
        }
        if (amount > .45) {
          final branch = (amount - .45) / .55;
          c.drawLine(
            left[2],
            left[2] + Offset(5 * branch, 3 * branch),
            pen..strokeWidth = .7,
          );
          c.drawLine(left[3], left[3] + Offset(-4 * branch, 2 * branch), pen);
        }
      } else if (lab.collapsed) {
        c.drawPath(
          fragment,
          pen
            ..color = Color.fromRGBO(112, 87, 51, .7 * alpha)
            ..strokeWidth = .8,
        );
      }
      c.restore();
    }
    if (lab.collapsed && age > 0) {
      for (var i = 0; i < 12; i++) {
        final fall = math.max(0.0, age - (i % 3) * .035),
            fade = (1 - fall / 1.1).clamp(0.0, 1.0);
        final p = point(
          V(168 + i * 8.0 + (i % 3 - 1) * fall * 18, -9 - 85 * fall * fall),
        );
        c.drawLine(
          p,
          p + Offset(i.isEven ? 2 : -2, 2 + i % 3.0),
          pen
            ..color = Color.fromRGBO(130, 108, 71, .6 * fade)
            ..strokeWidth = .8,
        );
      }
    }
  }

  void _drawLab(Canvas c) {
    final lab = session.mechanics;
    if (lab == null) return;
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (lab.showGuide && lab.guides.isNotEmpty) {
      final route =
          lab.paper?.guidePaths(lab.guides[lab.guideRoute]) ??
          lab.guides[lab.guideRoute];
      for (final entry in route.indexed) {
        final path = Path()
          ..moveTo(point(entry.$2.first).dx, point(entry.$2.first).dy);
        for (final p in entry.$2.skip(1)) {
          final q = point(p);
          path.lineTo(q.dx, q.dy);
        }
        for (final metric in path.computeMetrics()) {
          for (var d = 0.0; d < metric.length; d += 10) {
            c.drawPath(
              metric.extractPath(d, math.min(d + 5, metric.length)),
              pen
                ..color = const Color(0x88467578)
                ..strokeWidth = 1.2,
            );
          }
        }
        final start = point(entry.$2.first);
        c.drawCircle(
          start,
          5,
          pen
            ..color = const Color(0xaa467578)
            ..strokeWidth = 1,
        );
        _text(
          c,
          '${entry.$1 + 1}',
          start + const Offset(-4, -23),
          size: 11,
          color: const Color(0xff467578),
        );
      }
    }
    if (lab.spec.id == 'eraser') {
      final p = point(lab.eraser);
      final trace = Path();
      for (var i = 0; i <= 28; i++) {
        final t = session.gameTime - 1 + i / 14;
        final q = point(
          V(245 + 24 * math.sin(t * 1.1), 38 + 38 * math.cos(t * .75)),
        );
        if (i == 0) {
          trace.moveTo(q.dx, q.dy);
        } else {
          trace.lineTo(q.dx, q.dy);
        }
      }
      c.drawPath(
        trace,
        pen
          ..color = const Color(0x338b675f)
          ..strokeWidth = .6,
      );
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(-InkEraser.angle);
      final box = RRect.fromRectAndRadius(
        const Rect.fromLTWH(
          -InkEraser.halfWidth,
          -InkEraser.halfHeight,
          InkEraser.halfWidth * 2,
          InkEraser.halfHeight * 2,
        ),
        const Radius.circular(InkEraser.corner),
      );
      c.drawRRect(box, Paint()..color = const Color(0xffb6897f));
      c.drawRRect(
        box,
        pen
          ..color = const Color(0xff735d52)
          ..strokeWidth = 1,
      );
      c.drawRect(
        const Rect.fromLTWH(2, -9, 11, 18),
        Paint()..color = const Color(0xffb5ae9e),
      );
      for (var i = 0; i < 4; i++) {
        c.drawLine(
          Offset(-10.0 + i * 3, -6),
          Offset(-12.0 + i * 3, 6),
          pen
            ..color = const Color(0x55745c50)
            ..strokeWidth = .6,
        );
      }
      c.restore();
    }
    if (lab.pulleyDeck != null) _drawPulley(c, lab);
    if (lab.paper != null) _drawFoldButton(c, lab.paper!);
    if (lab.spec.id == 'crumble') _drawCrackingPaper(c, lab);
    if (lab.spec.id == 'repair') {
      for (final p in [const V(190, 90), const V(290, 90)]) {
        c.drawCircle(point(p), 7, Paint()..color = const Color(0xffd0b47d));
        c.drawCircle(
          point(p),
          7,
          pen
            ..color = const Color(0xff79613e)
            ..strokeWidth = 1,
        );
        c.drawCircle(point(p), 2, Paint()..color = const Color(0xff79613e));
      }
      final a = const V(160, 0),
          angle = (1 - lab.repairProgress) * math.pi * .48;
      _labDeck(c, a, a + V(220 * math.cos(angle), 220 * math.sin(angle)));
      c.drawCircle(point(a), 4, Paint()..color = const Color(0xff8b754e));
      final cord = Path()
        ..moveTo(point(const V(190, 90)).dx, point(const V(190, 90)).dy)
        ..lineTo(point(const V(160, 35)).dx, point(const V(160, 35)).dy)
        ..lineTo(point(a).dx, point(a).dy);
      c.drawPath(
        cord,
        pen
          ..color = const Color(0x668b754e)
          ..strokeWidth = .8,
      );
    }
    if (lab.spec.id == 'weight') {
      final p = point(const V(280, 63));
      final pressed = session.level.balls.first.captured;
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(p.dx - 14, p.dy + (pressed ? 3 : 0), 28, 5),
          const Radius.circular(2),
        ),
        Paint()
          ..color = pressed ? const Color(0xff7c8b69) : const Color(0xffb09561),
      );
      c.drawLine(
        p + const Offset(0, 7),
        point(const V(340, 0)) + const Offset(0, 5),
        pen
          ..color = const Color(0x7779684b)
          ..strokeWidth = .8,
      );
    }
  }
}
