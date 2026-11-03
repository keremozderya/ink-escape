part of '../ink_game.dart';

final _spikeSketches = Expando<(Path, Path)>();
final _bladeOutline = Path()
  ..addPolygon([
    for (var i = 0; i < 36; i++)
      Offset(math.cos(i * math.pi / 18), math.sin(i * math.pi / 18)) *
          (i % 3 == 0 ? 1 : .78),
  ], true);

extension _ObstaclePainting on InkGame {
  void _drawLevelObstacles(Canvas canvas, Level level, {double offsetX = 0}) {
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final bed in level.spikes) {
      if (bed.right + offsetX < cameraX - 30 ||
          bed.left + offsetX > cameraX + visibleWidth + 30) {
        continue;
      }
      final sketch = _spikeSketches[bed] ??= () {
        final shape = Path(), hatch = Path();
        for (final triangle in bed.teeth) {
          final a = triangle[0], b = triangle[1], tip = triangle[2];
          shape.addPolygon([
            Offset(a.x, -a.y),
            Offset(tip.x, -tip.y),
            Offset(b.x, -b.y),
          ], true);
          hatch.moveTo(a.x + 2, -a.y + .2);
          hatch.lineTo(tip.x, -tip.y + 2.4);
        }
        return (shape, hatch);
      }();
      canvas.save();
      canvas.translate(offsetX - cameraX, groundY);
      canvas.drawPath(sketch.$1, Paint()..color = const Color(0xff6b5140));
      canvas.drawPath(
        sketch.$1,
        pen
          ..color = const Color(0xff352e28)
          ..strokeWidth = 1.05,
      );
      canvas.drawPath(
        sketch.$2,
        pen
          ..color = const Color(0xffc4ad88)
          ..strokeWidth = .55,
      );
      canvas.drawLine(
        Offset(bed.left - 2, -bed.y + 1),
        Offset(bed.right + 2, -bed.y + 1),
        pen
          ..color = const Color(0xff49382e)
          ..strokeWidth = 1.4,
      );
      canvas.restore();
    }
    for (final saw in level.wallSaws) {
      final center = saw.centerAt(session.gameTime) + V(offsetX, 0);
      final wallX = saw.mount.x + offsetX,
          mount = point(saw.mount + V(offsetX, 0));
      if (wallX < cameraX - 120 || wallX > cameraX + visibleWidth + 120) {
        continue;
      }
      final innerX = mount.dx - saw.direction * 4;
      // The narrow graphite slot belongs to the actual vertical paper face.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(innerX, mount.dy),
            width: 7,
            height: saw.radius * 2 + 9,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xffb7a58a),
      );
      canvas.drawLine(
        Offset(mount.dx, mount.dy - saw.radius - 4),
        Offset(mount.dx, mount.dy + saw.radius + 4),
        pen
          ..color = const Color(0xff55493a)
          ..strokeWidth = 1.1,
      );
      final markColor = saw.phaseAt(session.gameTime) == InkSawPhase.warning
          ? Color.fromRGBO(
              153,
              88,
              48,
              .55 + .35 * math.sin(session.gameTime * 24).abs(),
            )
          : const Color(0xffa18c6c);
      for (final dy in [-1.0, 1.0]) {
        canvas.drawLine(
          Offset(
            mount.dx + saw.direction * 2,
            mount.dy + dy * (saw.radius + 7),
          ),
          Offset(
            mount.dx + saw.direction * 9,
            mount.dy + dy * (saw.radius + 10),
          ),
          pen
            ..color = markColor
            ..strokeWidth = 1.2,
        );
      }
      canvas.save();
      // Teeth behind the paper never appear or act as an exposed obstacle.
      canvas.clipRect(
        Rect.fromLTRB(
          saw.direction < 0 ? -2000 : mount.dx,
          -2000,
          saw.direction < 0 ? mount.dx : visibleWidth + 2000,
          visibleHeight + 2000,
        ),
      );
      final p = point(center);
      canvas.drawLine(
        mount,
        p,
        pen
          ..color = const Color(0xff8e795b)
          ..strokeWidth = 3,
      );
      canvas.translate(p.dx, p.dy);
      canvas.rotate(-saw.angleAt(session.gameTime));
      canvas.scale(saw.radius);
      canvas.drawPath(_bladeOutline, Paint()..color = const Color(0xffe4d7b9));
      canvas.drawPath(
        _bladeOutline,
        pen
          ..color = const Color(0xff3e362c)
          ..strokeWidth = 1.1 / saw.radius,
      );
      canvas.drawCircle(
        Offset.zero,
        .55,
        pen
          ..color = const Color(0xff9a8260)
          ..strokeWidth = .8 / saw.radius,
      );
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3;
        canvas.drawLine(
          Offset(math.cos(a), math.sin(a)) * .25,
          Offset(math.cos(a + .15), math.sin(a + .15)) * .5,
          pen
            ..color = const Color(0xff8b7658)
            ..strokeWidth = .65 / saw.radius,
        );
      }
      canvas.drawCircle(
        Offset.zero,
        .18,
        Paint()..color = const Color(0xff574738),
      );
      canvas.drawCircle(
        Offset.zero,
        .065,
        Paint()..color = const Color(0xffede2cd),
      );
      canvas.restore();
    }
  }
}
