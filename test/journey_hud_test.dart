import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'package:ink_escape/core/save_journal.dart';
import 'package:ink_escape/main.dart';
import 'package:ink_escape/presentation/journey_hud.dart';
import 'package:ink_escape/soundscape.dart';

import 'journey_core_test.dart' show journeyLevels;

Future<void> loadArt(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Flame.images.loadAll([
      'dot_walk.png',
      'props.png',
      'paper_garden.png',
      'paper_ruins.png',
      'storyboard_opening.png',
    ]);
    for (final entry in {
      'Nunito': 'assets/fonts/Nunito.ttf',
      'Cormorant': 'assets/fonts/CormorantGaramond.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('qa').createSync();
    File('qa/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets('Journey displays centimeters, level and accessible progress', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 320,
            child: InkJourneyHud(distanceCm: 24.6, progress: .5, level: 2),
          ),
        ),
      ),
    );
    final distance = tester.widget<Text>(
      find.byKey(const ValueKey('ink-distance-cm')),
    );
    expect(distance.textSpan!.toPlainText(), '24,6 cm');
    expect(find.text('LEVEL'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Kat edilen yol 24,6 santimetre. Bölüm 2, yüzde 50 tamamlandı.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
      semantics.dispose();
  });

  testWidgets('Journey does not intercept drawing beneath it', (tester) async {
    var downs = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => downs++,
          child: const Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: paper)),
              Positioned(
                left: 20,
                top: 20,
                width: 320,
                child: InkJourneyHud(distanceCm: 1, progress: .3, level: 1),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('ink-journey-hud'))),
    );
    expect(downs, 1);
  });

  testWidgets('Empty, full and very large distances fit the drawn meter', (
    tester,
  ) async {
    for (final width in [140.0, 280.0, 440.0]) {
      for (final progress in [0.0, .01, .5, 1.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: width,
                child: InkJourneyHud(
                  distanceCm: 999999.9,
                  progress: progress,
                  level: 12,
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets(
    'Real game updates the HUD and crosses chapters without a menu or camera jump',
    (tester) async {
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadArt(tester);
      final s = InkSession(journeyLevels())..start();
      s.x = 127.9;
      s.walked = 127.9;
      final store = MemoryStore(), key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: InkEscapeApp(
            session: s,
            journal: SaveJournal(store, 'journey-ui'),
            store: store,
            sound: Soundscape(enabled: false),
            restored: true,
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump();
      }
      final state = tester.state<GameScreenState>(find.byType(GameScreen));
      state.game.pauseEngine();
      expect(state.game.sceneReady, isTrue);
      expect(find.text('1'), findsOneWidget);
      await capture(tester, key, 'journey-before-boundary');
      final screenBefore = state.game.point(V(s.x, s.y));
      final timeBefore = state.game.visualTime;
      state.game.update(.01);
      // Notify Flutter immediately rather than waiting for the HUD's 50 ms refresh.
    state.game.onFrame?.call();
      await tester.pump();
      expect(s.phase, Phase.playing);
      expect(s.levelIndex, 1);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Küçük bir mola.'), findsNothing);
      expect(find.text('İlk izler tamam.'), findsNothing);
      expect(find.text('Yolculuğa başla'), findsNothing);
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('ink-level-progress')),
                  )
                  .painter!
              as InkJourneyPainter;
      expect(painter.progress, lessThan(.01));
      expect(s.distanceCm, greaterThan(127.9 / 32));
      expect(
        state.game.point(V(s.x, s.y)).dx - screenBefore.dx,
        closeTo(.5, .1),
      );
      expect(state.game.visualTime, greaterThan(timeBefore));
      await capture(tester, key, 'journey-after-boundary');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
