import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';

import 'mechanics_lab_test.dart' show drawLab, prepareLab, runLab;

void main() {
  test(
    'Every plan family has a separate playable case; ledge pulling is replaced',
    () {
      final plan = InkLabCase.all.where((c) => c.family != null).toList();
      expect(InkLabCase.all, hasLength(36));
      expect(plan.map((c) => c.family).toSet(), {
        'G',
        'R',
        'D',
        'S',
        'L',
        'H',
        'K',
        'T',
        'N',
        'A',
        'C',
        'U',
        'B',
        'V',
        'W',
        'Q',
        'E',
        'F',
        'J',
        'M',
        'Y',
        'Z',
      });
      for (final c in plan) {
        final s = c.createSession();
        expect(s.mechanics!.tasks, isNotEmpty);
        expect(s.lines, isEmpty);
        expect(s.ledge, isNull);
      }
    },
  );

  for (final c in InkLabCase.all.where((c) => c.family != null)) {
    final count = c.createSession().mechanics!.tasks.length;
    for (var omit = 0; omit < count; omit++) {
      test(
        '${c.family}: omitting required drawing ${omit + 1} fails the course',
        () {
          final s = c.createSession()..start(), lab = s.mechanics!;
          var next = 0;
          lab.holdDot = false;
          for (
            var frame = 0;
            frame < 120 * 28 && s.phase == Phase.playing;
            frame++
          ) {
            while (next < lab.tasks.length) {
              if (next == omit) {
                next++;
                continue;
              }
              final task = lab.tasks[next];
              if (!task.ready(s)) break;
              drawLab(s, task.points);
              next++;
            }
            s.advance(1 / 120);
            expect(s.activeLines, lessThanOrEqualTo(2));
            expect(s.ledge, isNull);
          }
          expect(s.phase, Phase.dead, reason: '${s.x}, ${s.y}: ${s.message}');
        },
      );
    }
  }

  test(
    'Absorbent paper blocks passive refill and requires the island drop',
    () {
      final s = InkLabCase.byId('plan-A').createSession()..start();
      final lab = s.mechanics!;
      drawLab(s, lab.tasks.first.points);
      final ink = s.ink;
      s.advance(6);
      expect(s.ink, ink);
      expect(ink, lessThan(pathLength(lab.tasks.last.points)));
      expect(lab.tasks.last.ready(s), isFalse);
      s.x = 320;
      s.advance(.01);
      expect(s.collected, contains('island-drop'));
      expect(lab.tasks.last.ready(s), isTrue);
    },
  );

  test(
    'The steps actually use three automatic hops and no ledge interaction',
    () {
      final s = InkLabCase.byId('plan-S').createSession()..start();
      var hops = 0;
      s.onEvent = (name, _) {
        if (name == 'jump') hops++;
      };
      prepareLab(s);
      runLab(s);
      expect(s.phase, Phase.complete);
      expect(hops, greaterThanOrEqualTo(3));
      expect(s.ledge, isNull);
    },
  );

  for (final id in ['plan-Q', 'plan-Y', 'plan-Z', 'plan-J']) {
    test('$id: three committed jobs really reuse two live slots', () {
      final s = InkLabCase.byId(id).createSession()..start();
      var commits = 0, peak = 0;
      s.onEvent = (name, _) {
        if (name == 'commit') commits++;
        if (s.activeLines > peak) peak = s.activeLines;
      };
      prepareLab(s);
      runLab(s);
      expect(s.phase, Phase.complete);
      expect(commits, 3);
      expect(peak, 2);
      if (id != 'plan-J') {
        expect(s.level.balls.single.captured, isTrue);
        expect(s.level.gates.single.open, isTrue);
      }
    });
  }
}
