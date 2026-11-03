import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/ink_model.dart';

/// A small, static map of the actual course. No game engine, textures, timers
/// or image downloads are needed while scrolling the level picker.
class InkMechanicsThumbnail extends StatelessWidget {
  const InkMechanicsThumbnail({super.key, required this.session});
  final InkSession session;
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _CourseMap(session),
      child: const SizedBox.expand(),
    ),
  );
}

class _CourseMap extends CustomPainter {
  _CourseMap(this.session);
  final InkSession session;
  @override
  void paint(Canvas canvas, Size size) {
    final level = session.level, lab = session.mechanics!;
    final routes = lab.guides.isNotEmpty
        ? lab.guides.first
        : lab.tasks.map((t) => t.points).toList();
    final vertices = [
      const V(0, 0),
      for (final edge in level.terrain) ...[edge.a, edge.b],
      for (final route in routes) ...route,
      for (final anchor in level.anchors) anchor.a,
    ];
    final top = math.max(65.0, vertices.map((p) => p.y).reduce(math.max) + 28),
        bottom = math.min(
          -70.0,
          vertices.map((p) => p.y).reduce(math.min) - 24,
        ),
        right = math.min(
          level.width,
          vertices.map((p) => p.x).reduce(math.max),
        );
    const left = -15.0;
    final scale = math.min(
      (size.width - 12) / (right - left),
      (size.height - 10) / (top - bottom),
    );
    final dx = (size.width - (right - left) * scale) / 2,
        dy = (size.height - (top - bottom) * scale) / 2;
    Offset at(V p) =>
        Offset(dx + (p.x - left) * scale, dy + (top - p.y) * scale);
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xfff3eddf),
    );
    for (var y = 10.0; y < size.height; y += 13) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        pen
          ..color = const Color(0x0e867458)
          ..strokeWidth = .6,
      );
    }
    for (final edge in level.terrain) {
      if (edge.b.x < left || edge.a.x > right) continue;
      final a = at(
            V(math.max(left, edge.a.x), edge.yAt(math.max(left, edge.a.x))),
          ),
          b = at(
            V(math.min(right, edge.b.x), edge.yAt(math.min(right, edge.b.x))),
          );
      final body = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(b.dx, b.dy + 7)
        ..lineTo(a.dx, a.dy + 7)
        ..close();
      canvas.drawPath(body, Paint()..color = const Color(0xffdccdaf));
      canvas.drawLine(
        a,
        b,
        pen
          ..color = const Color(0xff887656)
          ..strokeWidth = 1.2,
      );
    }
    final page = lab.paper;
    if (page != null) {
      final shape = Path()..addPolygon(page.source.map(at).toList(), true);
      canvas.drawPath(shape, Paint()..color = const Color(0xffe7d9bb));
      canvas.drawPath(
        shape,
        pen
          ..color = const Color(0xff9a835e)
          ..strokeWidth = .65,
      );
      final from = at(page.crease), to = at(page.creaseEnd), d = to - from;
      for (var t = 0.0; t < 1; t += .17) {
        canvas.drawLine(
          from + d * t,
          from + d * math.min(1, t + .08),
          pen
            ..color = const Color(0xff7a6545)
            ..strokeWidth = .9,
        );
      }
      canvas.drawCircle(
        at(const V(FoldPaper.buttonX, 0)),
        2,
        Paint()..color = const Color(0xff9b7960),
      );
    }
    for (final route in routes) {
      final path = Path()..moveTo(at(route.first).dx, at(route.first).dy);
      for (final p in route.skip(1)) {
        path.lineTo(at(p).dx, at(p).dy);
      }
      for (final metric in path.computeMetrics()) {
        for (var d = 0.0; d < metric.length; d += 5) {
          canvas.drawPath(
            metric.extractPath(d, math.min(d + 3, metric.length)),
            pen
              ..color = const Color(0xff648c88)
              ..strokeWidth = 1.2,
          );
        }
      }
    }
    for (final bed in level.spikes) {
      for (final triangle in bed.teeth) {
        final shape = Path()..addPolygon(triangle.map(at).toList(), true);
        canvas.drawPath(shape, Paint()..color = const Color(0xff78513c));
      }
    }
    for (final saw in level.wallSaws) {
      final center = at(saw.centerAt(saw.period * .72 - saw.offset));
      final wall = at(saw.mount);
      canvas.drawLine(
        wall,
        center,
        pen
          ..color = const Color(0xff9a805e)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(
        center,
        saw.radius * scale,
        Paint()..color = const Color(0xff9b7851),
      );
      canvas.drawCircle(
        center,
        saw.radius * scale * .38,
        Paint()..color = const Color(0xffe8ddc6),
      );
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        final d = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(
          center + d * saw.radius * scale * .75,
          center + d * saw.radius * scale * 1.13,
          pen
            ..color = const Color(0xff694a34)
            ..strokeWidth = .8,
        );
      }
    }
    for (final hazard in level.hazards) {
      final box = Rect.fromPoints(
        at(V(hazard[0], hazard[1])),
        at(V(hazard[2], hazard[3])),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(2)),
        Paint()..color = const Color(0x99785751),
      );
    }
    for (final gate in level.gates) {
      final p = at(V(gate.x, 0));
      canvas.drawLine(
        p,
        p - const Offset(0, 12),
        pen
          ..color = const Color(0xff97784e)
          ..strokeWidth = 2,
      );
    }
    for (final ball in level.balls) {
      canvas.drawCircle(
        at(ball.source),
        2.8,
        Paint()..color = const Color(0xffb18c53),
      );
    }
    for (final rain in level.rain) {
      for (var x = rain.left; x < rain.right; x += 20) {
        final p = at(V(x, 45));
        canvas.drawLine(
          p,
          p + const Offset(-1, 4),
          pen
            ..color = const Color(0xff8aa4a5)
            ..strokeWidth = .8,
        );
      }
    }
    if (lab.spec.id == 'crumble') {
      final a = at(const V(160, 0)), b = at(const V(275, 0));
      canvas.drawRect(
        Rect.fromLTRB(a.dx, a.dy, b.dx, a.dy + 6),
        Paint()..color = const Color(0xffceb78c),
      );
      for (var i = 1; i < 5; i++) {
        final x = a.dx + (b.dx - a.dx) * i / 5;
        canvas.drawPath(
          Path()
            ..moveTo(x, a.dy)
            ..relativeLineTo(1, 3)
            ..relativeLineTo(-2, 3),
          pen
            ..color = const Color(0xff755d3c)
            ..strokeWidth = .8,
        );
      }
    }
    if (lab.spec.id == 'eraser') {
      final p = at(lab.eraser);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: 9, height: 6),
          const Radius.circular(1),
        ),
        Paint()..color = const Color(0xffb68f80),
      );
    }
    if (lab.spec.id == 'pulley') {
      final p = at(const V(315, 145)), q = at(lab.pulleyDeck!.b);
      canvas.drawLine(
        p,
        q,
        pen
          ..color = const Color(0xff9a8055)
          ..strokeWidth = .7,
      );
      canvas.drawCircle(p, 3, pen);
    }
    for (final pickup in level.pickups) {
      canvas.drawCircle(
        at(pickup.p),
        1.8,
        Paint()..color = const Color(0xff5e8981),
      );
    }
    final dot = at(const V(22, 0));
    canvas.drawCircle(
      dot - const Offset(0, 6),
      2.3,
      Paint()..color = const Color(0xff453d32),
    );
    canvas.drawLine(
      dot - const Offset(0, 3),
      dot,
      pen
        ..color = const Color(0xff453d32)
        ..strokeWidth = 1.7,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CourseMap oldDelegate) =>
      oldDelegate.session != session;
}
