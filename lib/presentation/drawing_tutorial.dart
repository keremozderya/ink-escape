import 'package:flutter/material.dart';

/// Contextual controls stay above the route; the drawing surface remains live.
class InkDrawingTutorial extends StatelessWidget {
  const InkDrawingTutorial({
    super.key,
    required this.step,
    required this.ink,
    required this.scale,
    required this.onDone,
  });

  final int step;
  final double ink, scale;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    const titles = [
      'Kâğıt kenarından başla',
      'Yolunu çiz ve bırak',
      'Mürekkebini tanı',
    ];
    final descriptions = [
      'İşaretli sabit kenara dokun. Bu ilk denemede Dot seni bekliyor.',
      'Parmağını sürükleyip bırak. Bitiş serbest; Dot’un yürüyebileceği bir yol çiz.',
      'Çizginin uzunluğu kadar mürekkep harcanır. Kâğıtta yürürken dolar. Hatalı çizim harcamaz.',
    ];
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('ink-drawing-lesson'),
        padding: EdgeInsets.symmetric(
          horizontal: 18 * scale,
          vertical: 10 * scale,
        ),
        decoration: BoxDecoration(
          color: const Color(0xfff6f1e6).withValues(alpha: .97),
          borderRadius: BorderRadius.circular(14 * scale),
          border: Border.all(color: const Color(0x558d6b45)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${step + 1} / 3 · ${titles[step]}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cormorant',
                fontSize: 24 * scale,
                fontWeight: FontWeight.w600,
                color: const Color(0xff38312a),
              ),
            ),
            SizedBox(height: 4 * scale),
            Text(
              descriptions[step],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13 * scale,
                color: const Color(0xff746752),
                height: 1.4,
              ),
            ),
            if (step == 2) ...[
              SizedBox(height: 4 * scale),
              Text(
                'Kalan mürekkep: ${ink.floor()} / 240',
                style: TextStyle(fontSize: 13 * scale),
              ),
            ],
            TextButton(
              key: const ValueKey('ink-lesson-done'),
              onPressed: onDone,
              child: Text(step == 2 ? 'Yola devam' : 'Öğreticiyi geç'),
            ),
          ],
        ),
      ),
    );
  }
}

class InkTutorialAnchor extends StatelessWidget {
  const InkTutorialAnchor({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Semantics(
      label: 'Çizime bu sabit kâğıt kenarından başla.',
      child: SizedBox(
        key: const ValueKey('ink-tutorial-anchor'),
        width: 34,
        height: 34,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0x337b684c),
            border: Border.all(color: const Color(0xff805f3c), width: 2),
          ),
          child: const Icon(Icons.touch_app_rounded, size: 22),
        ),
      ),
    ),
  );
}
