import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../l10n/ink_strings.dart';

/// Read-only paper ruler: never intercepts the player's drawing gestures.
class InkJourneyHud extends StatelessWidget {
  const InkJourneyHud({
    super.key,
    required this.distanceCm,
    required this.progress,
    required this.level,
    this.scale = 1,
  });

  final double distanceCm, progress, scale;
  final int level;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xff38312a), pencil = Color(0xff827563);
    final l = InkStrings.of(context);
    final distance = l.distance(distanceCm);
    final fraction = progress.clamp(0.0, 1.0).toDouble();
    final f = scale;
    return IgnorePointer(
      child: Semantics(
        label: l.t(
          'Kat edilen yol {distance} santimetre. Bölüm {level}, yüzde {percent} tamamlandı.',
          {
            'distance': distance,
            'level': level,
            'percent': (fraction * 100).floor(),
          },
        ),
        child: ExcludeSemantics(
          child: SizedBox(
            key: const ValueKey('ink-journey-hud'),
            height: 62 * f,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text.rich(
                            key: const ValueKey('ink-distance-cm'),
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: distance,
                                  style: TextStyle(
                                    fontSize: 24 * f,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                    color: ink,
                                  ),
                                ),
                                TextSpan(
                                  text: ' ${l.t('cm')}',
                                  style: TextStyle(
                                    fontSize: 12 * f,
                                    color: pencil,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 3 * f),
                      SizedBox(
                        height: 23 * f,
                        width: double.infinity,
                        child: CustomPaint(
                          key: const ValueKey('ink-level-progress'),
                          painter: InkJourneyPainter(fraction),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 14 * f),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l.t('LEVEL'),
                      style: TextStyle(
                        fontSize: 9 * f,
                        letterSpacing: l.tracking(1.7 * f),
                        fontWeight: FontWeight.w600,
                        color: pencil,
                      ),
                    ),
                    Text(
                      '$level',
                      key: const ValueKey('ink-level-number'),
                      style: TextStyle(
                        fontFamily: 'Cormorant',
                        fontSize: 32 * f,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stable pencil contours and dry-brush texture; no random jitter per frame.
class InkJourneyPainter extends CustomPainter {
  const InkJourneyPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 12 || size.height <= 0) return;
    final f = size.height / 23;
    final left = 3 * f, right = size.width - 3 * f;
    final width = right - left;
    final top = 3 * f, bottom = 13 * f;
    const ink = Color(0xff38312a);
    final outline = Path()
      ..moveTo(left + 4 * f, top)
      ..cubicTo(
        width * .30 + left,
        top - .8 * f,
        width * .70 + left,
        top + .8 * f,
        right - 4 * f,
        top,
      )
      ..quadraticBezierTo(right + .5 * f, top, right, bottom - 4 * f)
      ..quadraticBezierTo(right, bottom + .5 * f, right - 4 * f, bottom)
      ..cubicTo(
        width * .65 + left,
        bottom + .7 * f,
        width * .25 + left,
        bottom - .6 * f,
        left + 4 * f,
        bottom,
      )
      ..quadraticBezierTo(left - .6 * f, bottom, left, top + 4 * f)
      ..quadraticBezierTo(left, top, left + 4 * f, top)
      ..close();
    canvas.drawPath(outline, Paint()..color = const Color(0x147b684c));
    final fillX = left + width * progress.clamp(0.0, 1.0);
    if (progress > 0) {
      canvas.save();
      canvas.clipPath(outline);
      canvas.clipRect(Rect.fromLTRB(left - f, 0, fillX, size.height));
      canvas.drawRect(
        Rect.fromLTRB(left - f, top - f, right + f, bottom + f),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xff74604b), ink, Color(0xff4c4034)],
            stops: [0, .55, 1],
          ).createShader(Rect.fromLTRB(left, top, right, bottom)),
      );
      // Fine paper fibres show through the ink like a dry pen stroke.
      for (var i = 0; i < 3; i++) {
        final y = top + (2.0 + i * 2.6) * f;
        canvas.drawLine(
          Offset(left + (7 + i * 11) * f, y),
          Offset(right - (10 + i * 7) * f, y + .25 * f),
          Paint()
            ..color = const Color(0x44f6f1e6)
            ..strokeWidth = .45 * f,
        );
      }
      canvas.restore();
      if (progress < .995) {
        // A tiny nib of wet ink follows the leading edge of the stroke.
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(fillX, 8 * f),
            width: 3 * f,
            height: 7 * f,
          ),
          Paint()..color = ink,
        );
      }
    }
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 * f
        ..color = const Color(0xff82715b),
    );
    // The faint second pencil pass and ruler ticks match the drawn world.
    canvas.drawPath(
      outline.shift(Offset(.3 * f, 1.2 * f)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .55 * f
        ..color = const Color(0x447b684c),
    );
    for (var i = 0; i <= 8; i++) {
      final x = left + width * i / 8;
      canvas.drawLine(
        Offset(x, 17 * f),
        Offset(x + math.sin(i * 2.3) * .5 * f, (i.isEven ? 21 : 19) * f),
        Paint()
          ..strokeWidth = .8 * f
          ..strokeCap = StrokeCap.round
          ..color = const Color(0x887b684c),
      );
    }
  }

  @override
  bool shouldRepaint(InkJourneyPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
