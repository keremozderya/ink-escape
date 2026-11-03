part of '../ink_game.dart';

final _surfOutline = Path()
  ..moveTo(-17, -1.4)
  ..cubicTo(-11, -.1, 7, .2, 18, -4.2)
  ..cubicTo(17, -.4, 11, 2.4, 1, 2.5)
  ..cubicTo(-9, 2.9, -15, 1.7, -17, -1.4)
  ..close();

extension _SurfPainting on InkGame {
  /// A paper-white surf sketch with an ink rim, raised nose and centre stroke.
  /// Local y=0 is the supporting ink, and Dot's existing feet rest on the deck.
  void _drawSurfBoard(Canvas c, {double alpha = 1, double drawn = 1}) {
    final outline = _surfOutline;
    c.drawPath(
      outline,
      Paint()..color = Color.fromRGBO(246, 239, 219, .94 * alpha * drawn),
    );
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.15
      ..color = Color.fromRGBO(55, 49, 39, alpha);
    if (drawn >= 1) {
      c.drawPath(outline, pen);
    } else {
      for (final metric in outline.computeMetrics()) {
        c.drawPath(metric.extractPath(0, metric.length * drawn), pen);
      }
    }
    if (drawn > .6) {
      c.drawPath(
        Path()
          ..moveTo(-10, .8)
          ..quadraticBezierTo(1, 1.6, 12, -1.2),
        pen
          ..strokeWidth = .55
          ..color = Color.fromRGBO(132, 112, 77, .8 * alpha * drawn),
      );
      c.drawLine(const Offset(-12, -.1), const Offset(-9, 1.5), pen);
    }
  }

  void _drawSurfTrail(Canvas c) {
    final now = session.gameTime;
    for (final p in surf.dust) {
      final at = point(p.position(now)), alpha = p.opacity(now);
      if (p.fleck) {
        c.drawLine(
          at,
          at + Offset(-p.size * 1.8, p.size * .6),
          Paint()
            ..color = Color.fromRGBO(79, 65, 43, alpha)
            ..strokeWidth = .8
            ..strokeCap = StrokeCap.round,
        );
      } else {
        c.drawCircle(
          at,
          p.size,
          Paint()..color = Color.fromRGBO(75, 63, 44, alpha),
        );
      }
    }
    for (final board in surf.flights) {
      final p = point(board.position(now));
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(-board.rotation(now));
      _drawSurfBoard(c, alpha: board.opacity(now));
      c.restore();
    }
  }
}
