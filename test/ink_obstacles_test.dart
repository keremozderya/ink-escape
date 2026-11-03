import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'mechanics_lab_test.dart' show drawLab, prepareLab, runLab;

void main() {
  test(
    'Spikes catch a swept foot but an ink bridge above the teeth stays safe',
    () {
      final bed = InkSpikeBed('test', 100, 140);
      expect(bed.hitsBody(const V(0, 0), const V(180, 0)), isTrue);
      expect(bed.hitsBody(const V(0, 11), const V(180, 11)), isFalse);
      expect(bed.hitsBody(const V(120, 50), const V(120, 0)), isTrue);
      expect(bed.hitsBody(const V(10, 0), const V(70, 0)), isFalse);
    },
  );
  test('Stepping on spiked paper dies; the authored arch really completes', () {
    final bare = InkLabCase.byId('spikes').createSession()..start();
    bare.mechanics!.holdDot = false;
    runLab(bare);
    expect(bare.phase, Phase.dead);
    expect(bare.message, contains('Diken'));
    final safe = InkLabCase.byId('spikes').createSession()..start();
    prepareLab(safe);
    runLab(safe);
    expect(safe.phase, Phase.complete, reason: safe.message);
  });
  test('A low paid line is solid but cannot shield feet from spikes', () {
    final s = InkLabCase.byId('spikes').createSession()..start();
    drawLab(s, [
      const V(140, 0),
      const V(166, 5),
      const V(292, 5),
      const V(320, 0),
    ]);
    s.mechanics!.holdDot = false;
    runLab(s);
    expect(s.phase, Phase.dead);
    expect(s.message, contains('Diken'));
  });
  test(
    'The saw has a warning, a full extension and a harmless hidden phase',
    () {
      final saw = InkWallSaw('s', const V(300, 36));
      expect(saw.phaseAt(0), InkSawPhase.hidden);
      expect(saw.phaseAt(2.4), InkSawPhase.warning);
      expect(saw.phaseAt(3.8), InkSawPhase.exposed);
      expect(saw.phaseAt(5.1), InkSawPhase.retracting);
      expect(saw.exposedAt(0), isFalse);
      expect(saw.hitsBody(const V(266, 20), const V(266, 20), 0, .1), isFalse);
      expect(
        saw.hitsBody(const V(266, 20), const V(266, 20), 3.7, 3.8),
        isTrue,
      );
      expect(
        saw.hitsBody(const V(266, 60), const V(266, 60), 3.7, 3.8),
        isFalse,
      );
      expect(
        saw.hitsBody(const V(340, 20), const V(340, 20), 3.7, 3.8),
        isFalse,
      );
    },
  );
  test(
    'Moving cutter versus stationary Dot and a fast rider both sweep continuously',
    () {
      final saw = InkWallSaw('s', const V(300, 36));
      expect(
        saw.hitsBody(const V(266, 20), const V(266, 20), 2.65, 3.6),
        isTrue,
      );
      expect(
        saw.hitsBody(const V(200, 20), const V(330, 20), 3.7, 3.708),
        isTrue,
      );
    },
  );
  test('The high saw route is safe while a low ramp needs timing', () {
    final high = InkLabCase.byId('wall-saw').createSession()..start();
    prepareLab(high);
    runLab(high);
    expect(high.phase, Phase.complete, reason: high.message);
    final low = InkLabCase.byId('wall-saw').createSession()..start();
    drawLab(low, [const V(160, 0), const V(300, 60)]);
    low.mechanics!.holdDot = false;
    runLab(low);
    expect(low.phase, Phase.dead);
    expect(low.message, contains('Bıçak'));
  });
  test('Waiting for the hidden interval makes the lower saw ramp viable', () {
    final s = InkLabCase.byId('wall-saw').createSession()..start();
    drawLab(s, [const V(160, 0), const V(300, 60)]);
    s.advance(2);
    s.mechanics!.holdDot = false;
    runLab(s);
    expect(s.phase, Phase.complete, reason: s.message);
  });

  test('Pause freezes the blade, and retry resets its clock and hazards', () {
    final s = InkLabCase.byId('wall-saw').createSession()..start();
    s.advance(3.8);
    final saw = s.level.wallSaws.single,
        center = saw.centerAt(s.gameTime),
        angle = saw.angleAt(s.gameTime);
    s.pause();
    s.advance(30);
    expect(saw.centerAt(s.gameTime).distance(center), 0);
    expect(saw.angleAt(s.gameTime), angle);
    s.retry();
    expect(s.gameTime, 0);
    expect(s.level.wallSaws, hasLength(1));
    expect(s.level.wallSaws.single.exposedAt(s.gameTime), isFalse);
    expect(s.lines, isEmpty);
  });

  test('Holding Dot does not stop an approaching cutter', () {
    final s = InkLabCase.byId('wall-saw').createSession()..start();
    s.x = 266;
    s.y = 20;
    s.advance(3.8);
    expect(s.phase, Phase.dead);
    expect(s.message, contains('Bıçak'));
  });

  test('Mirrored walls and phase offsets use the same physical cycle', () {
    final left = InkWallSaw('left', const V(300, 36));
    final right = InkWallSaw(
      'right',
      const V(300, 36),
      direction: 1,
      offset: 1,
    );
    expect(left.centerAt(3.8).x + right.centerAt(2.8).x, closeTo(600, 1e-9));
    expect(
      right.hitsBody(const V(334, 20), const V(334, 20), 2.8, 2.81),
      isTrue,
    );
    expect(
      right.hitsBody(const V(266, 20), const V(266, 20), 2.8, 2.81),
      isFalse,
    );
    expect(
      left.centerAt(0).distance(left.centerAt(left.period)),
      closeTo(0, 1e-9),
    );
  });

  test(
    'Optional level and cell obstacles apply offsets without modifying old content',
    () {
      final level = Level.from({
        'number': 1,
        'title': 'Obstacles',
        'width': 2000,
        'spikes': [
          {'id': 'root', 'left': 10, 'right': 30, 'y': 3},
        ],
        'wallSaws': [
          {
            'id': 'root-saw',
            'mount': [900, 36],
          },
        ],
        'cells': [
          {
            'index': 2,
            'offset_x': 250,
            'route': [],
            'pads': [],
            'pickups': [],
            'gates': [],
            'objects': [],
            'hazards': [],
            'absorbent': [],
            'lines': [],
            'spikes': [
              {'left': 20, 'right': 60},
            ],
            'wallSaws': [
              {
                'mount': [200, 36],
                'direction': 1,
              },
            ],
          },
        ],
      });
      expect(level.spikes.map((s) => s.left), [10, 270]);
      expect(level.spikes.first.y, 3);
      expect(level.wallSaws.map((s) => s.mount.x), [900, 450]);
      expect(level.wallSaws.last.direction, 1);
      expect(level.hazards, isEmpty);
    },
  );

  test(
    'A saved ordinary level restores hazard data and blade timing exactly',
    () {
      final data = <Map<String, dynamic>>[
        {
          'number': 1,
          'title': 'Save hazards',
          'width': 2000,
          'cells': [],
          'spikes': [
            {'left': 1000, 'right': 1040},
          ],
          'wallSaws': [
            {
              'mount': [900, 36],
              'offset': .3,
            },
          ],
        },
      ];
      final s = InkSession(data)..start();
      s.x = -300;
      s.advance(2.4);
      s.pause();
      final r = InkSession.restore(data, s.snapshot());
      expect(r.level.spikes, hasLength(1));
      expect(
        r.level.wallSaws.single
            .centerAt(r.gameTime)
            .distance(s.level.wallSaws.single.centerAt(s.gameTime)),
        0,
      );
      s.start();
      r.start();
      s.advance(.9);
      r.advance(.9);
      expect(r.x, closeTo(s.x, 1e-8));
      expect(r.gameTime, closeTo(s.gameTime, 1e-8));
      expect(
        r.level.wallSaws.single
            .centerAt(r.gameTime)
            .distance(s.level.wallSaws.single.centerAt(s.gameTime)),
        0,
      );
    },
  );

  test(
    'Malformed obstacle dimensions cannot create an endless cycle or tooth loop',
    () {
      expect(() => InkSpikeBed('bad', 10, 10), throwsArgumentError);
      expect(() => InkSpikeBed('bad', 10, 30, pitch: 0), throwsArgumentError);
      expect(
        () => InkWallSaw('bad', const V(0, 0), period: 0),
        throwsArgumentError,
      );
      expect(
        () => InkWallSaw('bad', const V(0, 0), direction: 0),
        throwsArgumentError,
      );
    },
  );
}
