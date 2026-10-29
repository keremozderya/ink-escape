import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/core/ink_model.dart';
import 'package:ink_escape/core/save_journal.dart';
import 'package:ink_escape/l10n/catalog.dart';
import 'package:ink_escape/l10n/ink_strings.dart';
import 'package:ink_escape/main.dart';
import 'package:ink_escape/presentation/opening_story.dart';
import 'package:ink_escape/soundscape.dart';

import 'journey_hud_test.dart' show loadArt, capture;
import 'journey_core_test.dart' show journeyLevels;

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  test(
    'All 12 languages cover every message and preserve substitution fields',
    () {
      expect(InkStrings.languages.length, 12);
      final fields = RegExp(r'\{[a-z]+\}');
      for (final entry in inkCatalog.entries) {
        expect(
          entry.value.length,
          InkStrings.languages.length,
          reason: entry.key,
        );
        final expected = fields.allMatches(entry.key).map((m) => m[0]).toSet();
        for (final value in entry.value) {
          expect(value.trim(), isNotEmpty, reason: entry.key);
          expect(
            fields.allMatches(value).map((m) => m[0]).toSet(),
            expected,
            reason: 'Missing argument in $value',
          );
        }
      }
      for (final shot in openingShots) {
        if (shot.title != 'Lumi') expect(inkCatalog, contains(shot.title));
        expect(inkCatalog, contains(shot.caption));
      }
      final model = File('lib/core/ink_model.dart').readAsStringSync();
      for (final match in RegExp(
        r"(?:hint|die)\(\s*'([^']*)'",
      ).allMatches(model)) {
        expect(
          inkCatalog,
          contains(match[1]),
          reason: 'Untranslated runtime message',
        );
      }
      expect(InkStrings.resolve('pt-BR'), 'pt');
      expect(InkStrings.resolve('zh_Hans_CN'), 'zh');
      expect(InkStrings.resolve('xx'), 'en');
      expect(const InkStrings('xx').t('Devam et'), 'Continue');
      expect(
        const InkStrings('de').t('Kalan mürekkep: {n} / 240', {'n': 70}),
        'Verbleibende Tinte: 70 / 240',
      );
    },
  );

  testWidgets(
    'Language selection persists, updates live and restores on reopening',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadArt(tester);
      final store = MemoryStore();
      final session = InkSession(journeyLevels());
      await tester.pumpWidget(
        InkEscapeApp(
          languageCode: 'en',
          session: session,
          journal: SaveJournal(store, 'locale'),
          store: store,
          sound: Soundscape(enabled: false),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('Settings'));
      await settle(tester);
      final selector = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(selector);
      await tester.tap(selector);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Français').last);
      await settle(tester);
      expect(find.text('Paramètres'), findsOneWidget);
      expect(find.text('Langue'), findsOneWidget);
      expect(
        identical(
          tester.state<GameScreenState>(find.byType(GameScreen)).s,
          session,
        ),
        isTrue,
      );
      expect(await store.read('ink.settings.language'), 'fr');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pumpWidget(
        InkEscapeApp(
          session: InkSession(journeyLevels()),
          journal: SaveJournal(store, 'reopen'),
          store: store,
          sound: Soundscape(enabled: false),
        ),
      );
      await settle(tester);
      expect(find.text('Commencer le voyage'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  for (final language in InkStrings.languages) {
    testWidgets('${language.code}: 568×320 menu and settings remain usable', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(568, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadArt(tester);
      final store = MemoryStore(), boundary = GlobalKey();
      final l = InkStrings(language.code);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: InkEscapeApp(
            languageCode: language.code,
            session: InkSession(journeyLevels()),
            journal: SaveJournal(store, 'small-${language.code}'),
            store: store,
            sound: Soundscape(enabled: false),
          ),
        ),
      );
      await settle(tester);
      final screen = tester.state<GameScreenState>(find.byType(GameScreen));
      expect(screen.game.strings.code, language.code);
      expect(
        Directionality.of(tester.element(find.byType(GameScreen))),
        language.code == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
      expect(find.text(l.t('Yolculuğa başla')), findsOneWidget);
      await tester.ensureVisible(find.text(l.t('Ayarlar')));
      await tester.tap(find.text(l.t('Ayarlar')));
      await settle(tester);
      expect(find.text(l.t('Dil')), findsOneWidget);
      await tester.ensureVisible(find.text(l.t('Geri')));
      expect(tester.takeException(), isNull);
      if (['en', 'ar', 'ja'].contains(language.code)) {
        await capture(tester, boundary, 'settings-${language.code}-568');
      }
      await tester.tap(find.text(l.t('Geri')));
      await settle(tester);
      await tester.ensureVisible(find.text(l.t('Yolculuğa başla')));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(l.t('Yolculuğa başla')));
      await settle(tester);
      await tester.tap(find.text(l.t('Hikâyeyi atla')));
      await settle(tester);
      expect(find.byKey(const ValueKey('ink-journey-hud')), findsOneWidget);
      expect(find.text(l.t('LEVEL')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
