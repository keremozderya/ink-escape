import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';

InkSession scene() {
  final s = InkSession([
    {'number': 1, 'title': 'Contact', 'width': 2000, 'cells': []},
  ])..start();
  s.level.terrain
    ..clear()
    ..add(Surface('paper', const V(100, 0), const V(200, 0)));
  return s..ink = 240;
}

bool stroke(InkSession s, List<V> points) {
  if (!s.beginStroke(points.first)) return false;
  for (final p in points.skip(1)) {
    s.moveStroke(p);
  }
  return s.endStroke();
}

void main() {
  for (final entry in <String, List<V>>{
    'start': [const V(200, 0), const V(240, 25)],
    'end': [const V(240, 40), const V(200, 0)],
    'middle with both ends free': [
      const V(70, 40),
      const V(150, 0),
      const V(230, 40),
    ],
    'crossing between sparse pointer samples': [
      const V(130, 40),
      const V(160, -40),
    ],
    'reverse drawing': [const V(230, 40), const V(150, 0), const V(70, 40)],
    'vertical drawing': [const V(150, 40), const V(150, -30)],
    'ink rim contact': [const V(70, 1), const V(230, 1)],
  }.entries) {
    test(
      'Accepts paper contact at ${entry.key} and charges the final path',
      () {
        final s = scene(), ink = s.ink;
        expect(stroke(s, entry.value), isTrue, reason: s.message);
        final line = s.lines.single;
        expect(line.cost, closeTo(pathLength(line.points), 1e-9));
        expect(s.ink, closeTo(ink - line.cost, 1e-9));
        expect(
          line.points.any((p) => p.y.abs() < 1e-7 && p.x >= 100 && p.x <= 200),
          isTrue,
        );
      },
    );
  }

  test(
    'A sharp interior touch survives smoothing and the preview matches commit',
    () {
      final s = scene();
      expect(s.beginStroke(const V(70, 40)), isTrue);
      for (final p in [
        const V(149, 10),
        const V(150, 0),
        const V(151, 10),
        const V(230, 40),
      ]) {
        s.moveStroke(p);
      }
      final (preview, error) = s.validatedDraft();
      expect(error, isEmpty);
      expect(preview!.any((p) => p.distance(const V(150, 0)) < 1e-7), isTrue);
      expect(s.endStroke(), isTrue);
      expect(
        s.lines.single.points.map((p) => p.toJson()),
        preview.map((p) => p.toJson()),
      );
      expect(s.lines.single.yAt(150), closeTo(0, 1e-7));
    },
  );

  test(
    'Detached ink is rejected on release without payment or a consumed slot',
    () {
      final s = scene(), ink = s.ink;
      expect(s.beginStroke(const V(70, 40)), isTrue);
      s.moveStroke(const V(230, 40));
      expect(s.validatedDraft().$1, isNull);
      expect(s.endStroke(), isFalse);
      expect(s.message, 'Çizginin bir noktası kâğıda değsin.');
      expect(s.ink, ink);
      expect(s.activeLines, 0);
      expect(s.draft, isNull);
      expect(stroke(s, [const V(240, 40), const V(200, 0)]), isTrue);
    },
  );

  test(
    'Only existing ink and a near miss beyond the ink rim do not anchor',
    () {
      final s = scene();
      s.lines.add(InkLine('floating', [const V(250, 40), const V(300, 40)]));
      final ink = s.ink;
      expect(stroke(s, [const V(270, 80), const V(270, 40)]), isFalse);
      expect(stroke(s, [const V(70, 4), const V(230, 4)]), isFalse);
      expect(s.ink, ink);
      expect(s.lines, hasLength(1));
    },
  );

  test(
    'An interior contact uses the roof anchor role rather than the free origin',
    () {
      final s = scene();
      s.level.terrain.clear();
      s.level.anchors.add(
        Surface('roof', const V(100, 80), const V(120, 80), tag: 'roof'),
      );
      expect(
        stroke(s, [const V(60, 110), const V(110, 80), const V(170, 110)]),
        isTrue,
      );
      expect(s.lines.single.role, 'roof');
    },
  );

  test(
    'Free origins still obey the ink budget, maximum length and two-slot limit',
    () {
      final s = scene()..ink = 10;
      expect(stroke(s, [const V(240, 40), const V(200, 0)]), isFalse);
      expect(s.ink, 10);
      s.ink = 240;
      expect(
        stroke(s, [const V(40, 120), const V(150, 0), const V(260, 120)]),
        isFalse,
      );
      expect(s.ink, 240);
      expect(stroke(s, [const V(240, 40), const V(200, 0)]), isTrue);
      expect(stroke(s, [const V(70, 40), const V(100, 0)]), isTrue);
      expect(s.beginStroke(const V(150, 60)), isFalse);
      expect(s.activeLines, 2);
    },
  );

  test(
    'A floating draft survives pause and save, then resumes from its endpoint',
    () {
      // Restore rebuilds surfaces from level data, so use a real story-like route.
      final data = <Map<String, dynamic>>[
        {'number': 1, 'title': 'Resume', 'width': 2000, 'cells': []},
      ];
      final s = InkSession(data)..start();
      expect(s.beginStroke(const V(1930, 80)), isTrue);
      s.moveStroke(const V(1960, 45));
      s.pause();
      final restored = InkSession.restore(data, s.snapshot());
      expect(restored.draft, isNotNull);
      expect(restored.draft!.start, isNull);
      restored.start();
      expect(restored.phase, Phase.resumeStroke);
      expect(restored.beginStroke(const V(1800, 100)), isFalse);
      expect(restored.beginStroke(restored.draft!.end!), isTrue);
      restored.moveStroke(const V(2000, 0));
      expect(restored.endStroke(), isTrue, reason: restored.message);
      expect(restored.lines.single.points.first.toJson(), [1930.0, 80.0]);
    },
  );
}
