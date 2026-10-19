import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Absolute world coordinates survive level-local origin rebasing and saves.
class PaperParallax {
  static const far = .10, ruins = .32, memories = .58, foreground = 1.12;
  static double screenX(double worldX, double camera, double factor) =>
      worldX - camera * factor;
  static double tileStart(double camera, double factor, double width) =>
      -(camera * factor % width);
}

class PaperMemory {
  const PaperMemory(this.worldX, this.letter);
  final double worldX;
  final bool letter;
}

class PaperWorld {
  PaperWorld(this.garden, this.ruins, this.memories);
  final ui.Image garden, ruins;
  final List<PaperMemory> memories;
  final Map<bool, TextPainter> _notes = {};

  void _tile(
    Canvas c,
    ui.Image image,
    double camera,
    double factor,
    double height,
    double top,
    double alpha,
  ) {
    final width = image.width / image.height * height;
    final start = PaperParallax.tileStart(camera, factor, width);
    for (var x = start - width; x < 480; x += width) {
      c.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(x, top, width + .5, height),
        Paint()
          ..color = Color.fromRGBO(255, 255, 255, alpha)
          ..filterQuality = FilterQuality.medium,
      );
    }
  }

  void background(Canvas c, double camera) {
    _tile(c, garden, camera, PaperParallax.far, 570, 0, .25);
    // Low contrast, separate silhouette: discarded drawings have depth.
    _tile(c, ruins, camera, PaperParallax.ruins, 288, 286, .52);
    for (final memory in memories) {
      // Authored positions are camera encounter positions, not repeating tiles.
      final x =
          210 +
          PaperParallax.screenX(
            memory.worldX * PaperParallax.memories,
            camera,
            PaperParallax.memories,
          );
      if (x < -240 || x > 690) continue;
      _memory(c, x, memory.letter);
    }
    // Folded, torn scraps behind the physical route. Never colliders.
    const spacing = 370.0;
    final start = PaperParallax.tileStart(camera, .76, spacing);
    for (var x = start - spacing; x < 600; x += spacing) {
      final path = Path()
        ..moveTo(x - 85, 610)
        ..lineTo(x - 48, 531)
        ..lineTo(x - 39, 538)
        ..lineTo(x - 15, 515)
        ..lineTo(x + 2, 527)
        ..lineTo(x + 62, 496)
        ..lineTo(x + 105, 554)
        ..lineTo(x + 157, 610)
        ..close();
      c.drawPath(path, Paint()..color = const Color(0x44ded2b9));
      c.drawPath(
        path,
        Paint()
          ..color = const Color(0x2d8e8066)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7,
      );
      c.drawLine(
        Offset(x + 62, 498),
        Offset(x + 32, 608),
        Paint()
          ..color = const Color(0x278e8066)
          ..strokeWidth = .8,
      );
    }
    c.drawRect(
      const Rect.fromLTWH(0, 0, 480, 205),
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, const Offset(0, 205), [
          const Color(0xfff6f2e9),
          const Color(0x00f6f2e9),
        ]),
    );
  }

  void _memory(Canvas c, double x, bool letter) {
    c.save();
    c.translate(x, letter ? 268 : 242);
    c.rotate(letter ? .08 : -.09);
    final page = Path()
      ..moveTo(-94, -58)
      ..lineTo(75, -63)
      ..lineTo(94, -45)
      ..lineTo(90, 63)
      ..lineTo(54, 61)
      ..lineTo(48, 66)
      ..lineTo(-90, 58)
      ..close();
    c.drawPath(
      page.shift(const Offset(2, 3)),
      Paint()..color = const Color(0x10908060),
    );
    c.drawPath(page, Paint()..color = const Color(0xddece2cf));
    c.drawPath(
      page,
      Paint()
        ..color = const Color(0x558e8066)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .65,
    );
    c.drawLine(
      const Offset(75, -62),
      const Offset(72, -43),
      Paint()..color = const Color(0x338e8066),
    );
    final text = _notes.putIfAbsent(
      letter,
      () => TextPainter(
        text: TextSpan(
          text: letter
              ? 'Sana söyleyemediklerim…\n\nBelki bir gün aynı sayfada\nyeniden buluşuruz.\n\nSevgilerle,'
              : 'DERS NOTLARI   /   17.10\n\nv = dx / dt\nV = I · R\n\nSalı: eskiz defterini unutma',
          style: const TextStyle(
            fontFamily: 'Cormorant',
            fontSize: 12.5,
            height: 1.25,
            fontStyle: FontStyle.italic,
            color: Color(0x99736755),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 163),
    );
    text.paint(c, const Offset(-78, -44));
    if (letter) {
      final heart = Path()
        ..moveTo(65, 46)
        ..cubicTo(40, 30, 55, 20, 65, 30)
        ..cubicTo(75, 20, 90, 30, 65, 46);
      c.drawPath(
        heart,
        Paint()
          ..color = const Color(0x558e6860)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8,
      );
    } else {
      final pen = Paint()
        ..color = const Color(0x55847867)
        ..strokeWidth = .7;
      c.drawLine(const Offset(30, -24), const Offset(30, 16), pen);
      c.drawLine(const Offset(24, 10), const Offset(76, 10), pen);
      final graph = Path()..moveTo(30, 6);
      for (var i = 0; i < 45; i++) {
        graph.lineTo(30 + i.toDouble(), 0 - 10 * math.sin(i / 10));
      }
      c.drawPath(graph, pen..style = PaintingStyle.stroke);
    }
    c.restore();
  }

  void foreground(Canvas c, double camera) {
    // Restricted to the bottom margin, clear of every gameplay contact.
    const width = 640.0;
    final start = PaperParallax.tileStart(
      camera,
      PaperParallax.foreground,
      width,
    );
    for (var x = start - width; x < 560; x += width) {
      final p = Path()
        ..moveTo(x - 30, 854)
        ..lineTo(x + 30, 777)
        ..lineTo(x + 45, 784)
        ..lineTo(x + 92, 760)
        ..lineTo(x + 168, 830)
        ..lineTo(x + 220, 854)
        ..close();
      c.drawPath(p, Paint()..color = const Color(0x5ac6b899));
      c.drawPath(
        p,
        Paint()
          ..color = const Color(0x3385755c)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8,
      );
      for (var i = 0; i < 12; i++) {
        final xx = x + 27 + i * 7.0;
        c.drawLine(
          Offset(xx, 815 + i % 3 * 4),
          Offset(xx - 7, 838),
          Paint()
            ..color = const Color(0x1885755c)
            ..strokeWidth = .7,
        );
      }
    }
  }
}
