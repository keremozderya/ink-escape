import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ink_game.dart';

/// The magnified paper is a second view of the same scene. Coordinates sent to
/// physics remain the actual touch coordinates, even near a viewport edge.
class InkDrawingLens extends StatelessWidget {
  const InkDrawingLens({
    super.key,
    required this.game,
    required this.focus,
    required this.viewport,
    required this.label,
    this.costLabel = '',
  });
  final InkGame game;
  final Offset focus;
  final Size viewport;
  final String label, costLabel;

  static Rect bounds(Offset focus, Size viewport) {
    final width = math.min(148.0, viewport.width - 16);
    final height = math.min(102.0, viewport.height - 16);
    final left = (focus.dx - width / 2).clamp(8.0, viewport.width - width - 8);
    var top = focus.dy - height - 52;
    if (top < 8) top = focus.dy + 52;
    top = top.clamp(8.0, viewport.height - height - 8);
    return Rect.fromLTWH(left, top, width, height);
  }

  @override
  Widget build(BuildContext context) {
    final rect = bounds(focus, viewport);
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: Semantics(
          label: '$label. $costLabel',
          child: DecoratedBox(
            key: const ValueKey('ink-drawing-lens'),
            decoration: BoxDecoration(
              color: const Color(0xfff6f1e6),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4438312a),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: CustomPaint(painter: _LensPainter(game, focus, costLabel)),
          ),
        ),
      ),
    );
  }
}

class _LensPainter extends CustomPainter {
  _LensPainter(this.game, this.focus, this.costLabel);
  final InkGame game;
  final Offset focus;
  final String costLabel;
  @override
  void paint(Canvas canvas, Size size) {
    final frame = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(16),
    );
    canvas.save();
    canvas.clipRRect(frame);
    canvas.drawColor(const Color(0xfff6f1e6), BlendMode.srcOver);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(1.75);
    canvas.translate(-focus.dx, -focus.dy);
    game.render(canvas);
    canvas.restore();
    final center = size.center(Offset.zero);
    final pen = Paint()
      ..color = const Color(0xff38312a)
      ..strokeWidth = 1.1;
    for (final direction in const [
      Offset(1, 0),
      Offset(-1, 0),
      Offset(0, 1),
      Offset(0, -1),
    ]) {
      canvas.drawLine(center + direction * 7, center + direction * 13, pen);
    }
    canvas.drawCircle(center, 3.5, pen..style = PaintingStyle.stroke);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 23),
      Paint()..color = const Color(0xfff6f1e6),
    );
    final caption = TextPainter(
      text: TextSpan(
        text: costLabel,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontFamilyFallback: game.strings.fonts,
          fontSize: 11,
          color: const Color(0xff5d5143),
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: game.strings.code == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
    )..layout(maxWidth: size.width - 16);
    caption.paint(canvas, Offset((size.width - caption.width) / 2, 4));
    caption.dispose();
    canvas.restore();
    canvas.drawRRect(
      frame.deflate(.8),
      Paint()
        ..color = const Color(0xff827563)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_LensPainter oldDelegate) => true;
}
