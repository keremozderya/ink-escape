import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';

import 'mechanics_lab_test.dart' show drawLab, runLab;

void main() {
  final descents = <String, List<V>>{
    'short flat lead-in': [
      const V(130, 0),
      const V(138, 0),
      const V(153, -43),
      const V(173, -78),
      const V(203, -96),
      const V(260, -96),
    ],
    'vertical entry': [
      const V(130, 0),
      const V(130, -24),
      const V(147, -55),
      const V(175, -83),
      const V(203, -96),
      const V(260, -96),
    ],
    'small backwards hand wobble': [
      const V(130, 0),
      const V(143, -28),
      const V(142, -32),
      const V(157, -64),
      const V(180, -86),
      const V(210, -96),
      const V(260, -96),
    ],
    'start inside the paper snap radius': [
      const V(121, 1),
      const V(127, -7),
      const V(147, -43),
      const V(167, -78),
      const V(200, -96),
      const V(260, -96),
    ],
  };
  for (final entry in descents.entries) {
    for (final fps in [30, 73, 144]) {
      test(
        'A hand-drawn slide with ${entry.key} gathers speed at $fps FPS',
        () {
          final s = InkLabCase.byId('slide').createSession()..start();
          drawLab(s, entry.value);
          final events = <String>[];
          s.onEvent = (name, _) => events.add(name);
          s.mechanics!.holdDot = false;
          var peakSpeed = 0.0;
          for (var i = 0; i < fps * 18 && s.phase == Phase.playing; i++) {
            s.advance(1 / fps);
            if (s.mechanics!.speed > peakSpeed) peakSpeed = s.mechanics!.speed;
          }
          expect(events, contains('slideStart'));
          expect(events.where((e) => e == 'slideHop'), hasLength(1));
          expect(peakSpeed, greaterThan(140));
          expect(
            s.phase,
            Phase.complete,
            reason: '${s.x}, ${s.y}: ${s.message}',
          );
        },
      );
    }
  }

  test(
    'Slide entry uses the contacted descent instead of the stroke origin',
    () {
      final s = InkLabCase.byId('slide').createSession()..start();
      drawLab(s, s.mechanics!.guides.first.first);
      s.x = 147;
      s.y = s.lines.single.yAt(s.x)!;
      s.onNatural = false;
      final events = <String>[];
      s.onEvent = (name, _) => events.add(name);
      s.mechanics!.holdDot = false;
      runLab(s);
      expect(s.phase, Phase.complete);
      expect(events.where((e) => e == 'slideHop'), hasLength(1));
      expect(events, contains('slideStart'));
    },
  );

  test('A floating descent above step reach cannot pull Dot off the paper', () {
    final s = InkLabCase.byId('slide').createSession()..start();
    s.lines.add(
      InkLine('floating', [
        const V(130, 15),
        const V(145, -36),
        const V(161, -68),
      ]),
    );
    s.x = 129;
    s.mechanics!.holdDot = false;
    s.advance(.02);
    expect(s.mechanics!.motion, InkLabMotion.walking);
    expect(s.y, lessThanOrEqualTo(0));
  });

  test(
    'A deliberate backwards loop remains visible and cannot become a slide',
    () {
      final s = InkLabCase.byId('slide').createSession()..start();
      drawLab(s, [
        const V(130, 0),
        const V(112, -35),
        const V(134, -52),
        const V(169, -78),
        const V(200, -96),
        const V(260, -96),
      ]);
      expect(s.lines.single.points.any((p) => p.x < 115), isTrue);
      final events = <String>[];
      s.onEvent = (name, _) => events.add(name);
      s.mechanics!.holdDot = false;
      s.advance(4);
      expect(events, isNot(contains('slideHop')));
    },
  );

  test('A small intentional return at an exact anchor is preserved', () {
    final s = InkLabCase.byId('slide').createSession()..start();
    drawLab(s, [
      const V(130, 0),
      const V(125, -6),
      const V(132, -10),
      const V(148, -50),
      const V(173, -78),
      const V(205, -96),
      const V(260, -96),
    ]);
    expect(s.lines.single.points.any((p) => p.x < 127), isTrue);
  });

  for (final rise in [.51, .6, .74]) {
    for (final ink in [false, true]) {
      test('A $rise-unit ${ink ? 'ink' : 'paper'} seam cannot trap Dot', () {
        final s = InkSession([
          {'number': 1, 'title': 'Seam', 'width': 1000, 'cells': []},
        ])..start();
        s.level.terrain.clear();
        s.level.terrain.add(Surface('start', const V(-100, 0), const V(40, 0)));
        if (ink) {
          s.lines.add(InkLine('bridge', [V(40, rise), V(300, rise)]));
        } else {
          s.level.terrain.add(Surface('end', V(40, rise), V(300, rise)));
        }
        s.advance(2);
        expect(s.phase, Phase.playing);
        expect(s.x, greaterThan(90));
        expect(s.y, closeTo(rise, .001));
        expect(s.grounded, isTrue);
      });
    }
  }

  test('A joined second ink stroke keeps the slide momentum', () {
    final s = InkLabCase.byId('slide').createSession()..start();
    s.level.anchors.add(
      Surface('join', const V(195, -94), const V(195.001, -94)),
    );
    drawLab(s, [
      const V(130, 0),
      const V(147, -43),
      const V(167, -78),
      const V(195, -94),
    ]);
    drawLab(s, [const V(195, -94), const V(225, -96), const V(260, -96)]);
    s.mechanics!.holdDot = false;
    while (s.x < 201 && s.phase == Phase.playing) {
      s.advance(1 / 120);
    }
    expect(s.mechanics!.motion, InkLabMotion.sliding);
    expect(s.mechanics!.speed, greaterThan(130));
    runLab(s);
    expect(s.phase, Phase.complete, reason: '${s.x}, ${s.y}: ${s.message}');
  });
}
