import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/ink_model.dart';
import 'core/save_journal.dart';
import 'ink_game.dart';
import 'soundscape.dart';
import 'presentation/opening_story.dart';
import 'presentation/journey_hud.dart';
import 'presentation/centered_menu.dart';
import 'presentation/drawing_tutorial.dart';
import 'presentation/drawing_lens.dart';
import 'l10n/ink_strings.dart';

const paper = Color(0xfff6f1e6),
    inkColor = Color(0xff38312a),
    muted = Color(0xff827563);
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  final raw =
      jsonDecode(
            await rootBundle.loadString('assets/data/prototype_levels.json'),
          )
          as Map<String, dynamic>;
  const configuredLab = String.fromEnvironment('INK_LAB');
  final test = configuredLab.isEmpty ? null : configuredLab;
  final lab = raw['labs'][test];
  final data = (lab == null ? raw['story'] : [lab])
      .map<Map<String, dynamic>>((dynamic x) => Map<String, dynamic>.from(x))
      .toList();
  StringStore store;
  String? storageError;
  try {
    store = PrefsStore(await SharedPreferences.getInstance());
  } catch (_) {
    store = MemoryStore();
    storageError = 'Bu cihazda kayıt kullanılamıyor.';
  }
  final journal = SaveJournal(
    store,
    'ink-escape-native-v1-${lab == null ? 'story' : test}',
    backgroundEncoding: true,
  );
  Map<String, dynamic>? saved;
  try {
    saved = await journal.load(
      accepts: (snapshot) {
        InkSession.restore(data, snapshot);
        return true;
      },
    );
    if (saved == null && journal.hadUnreadableRecords) {
      storageError = 'Kayıt kurtarılamadı; yeni yolculuk açıldı.';
    }
  } catch (_) {
    storageError = 'Kayıt okunamadı; bu deneme geçici olacak.';
  }
  InkSession session;
  try {
    session = saved == null
        ? InkSession(data, lab: lab != null)
        : InkSession.restore(data, saved);
  } catch (_) {
    session = InkSession(data, lab: lab != null);
    saved = null;
    storageError = 'Eski kayıt bu sürümle uyumsuz.';
  }
  if (saved == null && (journal.hadUnreadableRecords || journal.epoch > 0)) {
    session.resetEpoch = journal.epoch + 1;
  }
  final sound = Soundscape();
  var language = InkStrings.resolve(
    WidgetsBinding.instance.platformDispatcher.locale.languageCode,
  );
  try {
    sound.musicOn = await store.read('ink.settings.music') != 'off';
    sound.effectsOn = await store.read('ink.settings.effects') != 'off';
  } catch (_) {
    // Optional audio preferences must not prevent a recovered game opening.
  }
  try {
    final savedLanguage = await store.read('ink.settings.language');
    if (savedLanguage != null) language = InkStrings.resolve(savedLanguage);
  } catch (_) {
    // A damaged optional preference falls back to the device language.
  }
  runApp(
    InkEscapeApp(
      session: session,
      journal: journal,
      store: store,
      sound: sound,
      languageCode: language,
      restored: saved != null,
      camera: session.migratedLayout
          ? null
          : (saved?['cameraX'] as num?)?.toDouble(),
      storageError: storageError,
    ),
  );
}

class PrefsStore extends StringStore {
  PrefsStore(this.prefs);
  final SharedPreferences prefs;
  @override
  Future<String?> read(String key) async => prefs.getString(key);
  @override
  Future<void> write(String key, String value) async {
    if (!await prefs.setString(key, value)) {
      throw StateError('Save failed');
    }
  }
}

class MemoryStore extends StringStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class InkEscapeApp extends StatefulWidget {
  const InkEscapeApp({
    super.key,
    required this.session,
    required this.journal,
    required this.store,
    required this.sound,
    this.restored = false,
    this.camera,
    this.storageError,
    this.languageCode,
  });
  final InkSession session;
  final SaveJournal journal;
  final StringStore store;
  final Soundscape sound;
  final bool restored;
  final double? camera;
  final String? storageError;
  final String? languageCode;
  @override
  State<InkEscapeApp> createState() => _InkEscapeAppState();
}

class _InkEscapeAppState extends State<InkEscapeApp> {
  late String _language;
  bool _languageSelected = false;
  Future<void> _languageWrite = Future.value();
  @override
  void initState() {
    super.initState();
    _language = InkStrings.resolve(
      widget.languageCode ??
          WidgetsBinding.instance.platformDispatcher.locale.languageCode,
    );
    if (widget.languageCode == null) unawaited(_restoreLanguage());
  }

  Future<void> _restoreLanguage() async {
    try {
      final saved = await widget.store.read('ink.settings.language');
      if (mounted && !_languageSelected && saved != null) {
        setState(() => _language = InkStrings.resolve(saved));
      }
    } catch (_) {
      // Optional settings cannot block opening a recovered game.
    }
  }

  void _setLanguage(String language) {
    _languageSelected = true;
    final next = InkStrings.resolve(language);
    setState(() => _language = next);
    _languageWrite = _languageWrite
        .then((_) => widget.store.write('ink.settings.language', next))
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Ink Escape',
    locale: Locale(_language),
    supportedLocales: InkStrings.languages.map((l) => Locale(l.code)),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => InkLocale(
      strings: InkStrings(_language),
      onChanged: _setLanguage,
      child: child!,
    ),
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Nunito',
      fontFamilyFallback: InkStrings(_language).fonts,
      scaffoldBackgroundColor: const Color(0xffe6dfd0),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff74634e),
        surface: paper,
      ),
      textTheme: const TextTheme(bodyMedium: TextStyle(color: inkColor)),
    ),
    home: GameScreen(
      session: widget.session,
      journal: widget.journal,
      store: widget.store,
      sound: widget.sound,
      restored: widget.restored,
      camera: widget.camera,
      storageError: widget.storageError,
    ),
  );
}

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.session,
    required this.journal,
    required this.store,
    required this.sound,
    this.restored = false,
    this.camera,
    this.storageError,
  });
  final InkSession session;
  final SaveJournal journal;
  final StringStore store;
  final Soundscape sound;
  final bool restored;
  final double? camera;
  final String? storageError;
  @override
  State<GameScreen> createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final InkGame game;
  late final Widget _gameView;
  final _hudTick = ValueNotifier<int>(0);
  Object? _lastOverlayState;
  InkSession get s => widget.session;
  InkStrings get strings => InkStrings.of(context);
  String _t(String source, [Map<String, Object> args = const {}]) =>
      strings.t(source, args);
  bool _loading = true, _settings = false, _saved = false, _saveError = false;
  int? _pointer, _pullPointer;
  Offset? _drawFocus;
  bool _opening = false, _openingSeen = false;
  bool _mainMenu = false;
  bool _teachingDraw = false;
  bool get _drawingLessonActive =>
      _teachingDraw &&
      !s.drawingTutorialDone &&
      s.ledge == null &&
      !_opening &&
      !_mainMenu;
  V? get _lessonAnchor {
    if (s.firstDrawDone || s.draft != null) return null;
    for (final reference in s.level.reference) {
      final points = reference['points'] as List<V>;
      if (points.isNotEmpty && s.anchorAt(points.first) != null) {
        return points.first;
      }
    }
    return s.level.terrain.firstOrNull?.b;
  }

  Timer? _saveIndicator;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    game.strings = strings;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    game = InkGame(
      s,
      initialCamera: widget.camera,
      holdForLesson: () => _drawingLessonActive,
      onFrame: _onGameFrame,
      onEffect: widget.sound.event,
    );
    // Keep Flame's widget identity stable when HUD values or the drawing
    // lens change; its render loop already paints independently.
    _gameView = GameWidget(
      game: game,
      loadingBuilder: (context) => ColoredBox(
        color: paper,
        child: Center(
          child: Text(InkStrings.of(context).t('Kâğıtlar hazırlanıyor…')),
        ),
      ),
    );
    s.onSaveRequested = (forced) {
      unawaited(_save());
    };
    unawaited(widget.sound.init());
  }

  void _onGameFrame() {
    if (!mounted) return;
    final overlayState = (
      game.sceneReady,
      s.phase,
      s.levelIndex,
      s.stuckCountdown,
      s.ledge?.pulls,
      s.firstDrawDone,
      s.drawingTutorialDone,
      s.ledgeTutorialDone,
      s.x > 60,
      s.realTime < s.messageUntil,
      s.message,
      game.deathEffectComplete,
    );
    if (overlayState != _lastOverlayState) {
      _lastOverlayState = overlayState;
      setState(() => _loading = !game.sceneReady);
    }
    _hudTick.value++;
  }

  Future<void> _save() async {
    final snap = s.snapshot()..['cameraX'] = game.cameraX;
    final epoch = s.resetEpoch, wasDead = s.phase == Phase.dead;
    try {
      if (epoch > widget.journal.epoch) {
        await widget.journal.fence(epoch, s.checkpointSnapshot());
      }
      if (!wasDead) {
        await widget.journal.save(snap, resetEpoch: epoch);
      }
      if (!mounted) {
        return;
      }
      _saved = true;
      if (_saveError) setState(() => _saveError = false);
      _hudTick.value++;
      _saveIndicator?.cancel();
      _saveIndicator = Timer(const Duration(milliseconds: 850), () {
        if (mounted) {
          _saved = false;
          _hudTick.value++;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _saveError = true);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _pause();
    }
  }

  void _pause() {
    s.pause();
    widget.sound.pause();
    _pointer = null;
    _pullPointer = null;
    _drawFocus = null;
    if (mounted) {
      setState(() => _settings = false);
    }
    unawaited(_save());
  }

  void _returnToMenu() {
    s.pause();
    widget.sound.pause();
    _pointer = null;
    _pullPointer = null;
    _drawFocus = null;
    setState(() {
      _mainMenu = true;
      _settings = false;
      _opening = false;
    });
    unawaited(_save());
  }

  void _start() async {
    if (_mainMenu && s.phase == Phase.complete) {
      _retry(newJourney: true);
    }
    _mainMenu = false;
    if (!_openingSeen &&
        !s.lab &&
        !s.firstDrawDone &&
        s.x == 0 &&
        s.levelIndex == 0) {
      String? seen;
      try {
        seen = await widget.store.read('ink.story.opening.v1');
      } catch (_) {}
      if (!mounted) return;
      _openingSeen = seen == 'seen';
      if (!_openingSeen) {
        setState(() => _opening = true);
        return;
      }
    }
    _teachingDraw = !s.lab && s.levelIndex == 0 && !s.drawingTutorialDone;
    s.start();
    widget.sound.resume();
    setState(() => _settings = false);
  }

  void _finishOpening() {
    _openingSeen = true;
    setState(() => _opening = false);
    unawaited(
      widget.store.write('ink.story.opening.v1', 'seen').catchError((_) {}),
    );
    _start();
  }

  void _finishDrawingLesson() {
    setState(() {
      s.drawingTutorialDone = true;
      _teachingDraw = false;
    });
    unawaited(_save());
  }

  void _retry({bool newJourney = false}) {
    _pointer = null;
    _pullPointer = null;
    _drawFocus = null;
    game.cameraX = -96;
    if (newJourney) {
      s.restartJourney();
    } else {
      s.retry();
    }
    game.resetView();
    setState(() => _settings = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveIndicator?.cancel();
    s.onSaveRequested = null;
    _hudTick.dispose();
    game.pauseEngine();
    unawaited(widget.sound.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showMenu =
        _mainMenu ||
        s.phase == Phase.ready ||
        s.phase == Phase.paused ||
        s.phase == Phase.complete ||
        (s.phase == Phase.dead && game.deathEffectComplete);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final factor = (constraints.maxHeight / 480)
                .clamp(0.65, 1.25)
                .toDouble();
            return ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Listener(
                      key: const ValueKey('ink-drawing-surface'),
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (e) {
                        if (_pointer == null &&
                            _pullPointer == null &&
                            game.sceneReady) {
                          if (s.phase == Phase.playing && s.ledge != null) {
                            _pullPointer = e.pointer;
                            return;
                          }
                          if (s.beginStroke(game.worldPoint(e.localPosition))) {
                            _pointer = e.pointer;
                            setState(() {
                              _drawFocus = e.kind == PointerDeviceKind.touch
                                  ? e.localPosition
                                  : null;
                            });
                          }
                        }
                      },
                      onPointerMove: (e) {
                        if (e.pointer == _pointer) {
                          s.moveStroke(game.worldPoint(e.localPosition));
                          if (_drawFocus != null) {
                            setState(() => _drawFocus = e.localPosition);
                          }
                        }
                      },
                      onPointerUp: (e) {
                        if (e.pointer == _pullPointer) {
                          s.pullLedge();
                          _pullPointer = null;
                          setState(() {});
                          return;
                        }
                        if (e.pointer == _pointer) {
                          s.moveStroke(game.worldPoint(e.localPosition));
                          final committed = s.endStroke();
                          if (committed && _drawingLessonActive) {
                            unawaited(_save());
                          }
                          _pointer = null;
                          _drawFocus = null;
                          setState(() {});
                        }
                      },
                      onPointerCancel: (e) {
                        if (e.pointer == _pullPointer) {
                          _pullPointer = null;
                          _pause();
                          return;
                        }
                        if (e.pointer == _pointer) {
                          s.losePointer();
                          _pointer = null;
                          _drawFocus = null;
                          widget.sound.pause();
                          setState(() {});
                        }
                      },
                      child: _gameView,
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0x22887559),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!_loading && !showMenu && !_opening)
                    Positioned(
                      left: 30 * factor,
                      right: 26 * factor,
                      top: 30 * factor,
                      child: RepaintBoundary(
                        child: ValueListenableBuilder<int>(
                          valueListenable: _hudTick,
                          builder: (context, tick, child) => _hud(
                            (constraints.maxWidth / 600)
                                .clamp(.5, factor)
                                .toDouble(),
                          ),
                        ),
                      ),
                    ),
                  if (!_loading && !_mainMenu && s.stuckCountdown != null)
                    Positioned(
                      top: 90 * factor,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(child: _stuckWarning(factor)),
                    ),
                  if (!_loading &&
                      !showMenu &&
                      s.phase == Phase.playing &&
                      s.ledge != null)
                    Positioned(
                      top: 110 * factor,
                      left: 24 * factor,
                      right: 24 * factor,
                      child: IgnorePointer(child: _ledgeWarning(factor)),
                    ),
                  if (!_loading &&
                      !showMenu &&
                      _drawingLessonActive &&
                      s.phase == Phase.playing)
                    Positioned(
                      left: 24 * factor,
                      right: 24 * factor,
                      top: 105 * factor,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 480 * factor),
                          child: InkDrawingTutorial(
                            step: s.firstDrawDone
                                ? 2
                                : s.draft != null
                                ? 1
                                : 0,
                            ink: s.ink,
                            scale: factor,
                            onDone: _finishDrawingLesson,
                          ),
                        ),
                      ),
                    ),
                  if (!_loading &&
                      !showMenu &&
                      _drawingLessonActive &&
                      s.phase == Phase.playing &&
                      _lessonAnchor != null)
                    Positioned(
                      left: game.point(_lessonAnchor!).dx * game.scale - 17,
                      top: game.point(_lessonAnchor!).dy * game.scale - 17,
                      child: const InkTutorialAnchor(),
                    ),
                  if (s.phase == Phase.resumeStroke)
                    Positioned(
                      left: 22 * factor,
                      right: 22 * factor,
                      bottom: 55 * factor,
                      child: Column(
                        children: [
                          _instruction(
                            'Yarım kalan çizginin ucuna dokun\nve kaldığın yerden devam et.',
                            factor,
                          ),
                          TextButton(
                            onPressed: () {
                              s.cancelDraft();
                              s.phase = Phase.playing;
                              widget.sound.resume();
                              setState(() {});
                            },
                            child: Text(_t('Bu çizgiden vazgeç')),
                          ),
                        ],
                      ),
                    ),
                  if (s.phase == Phase.playing &&
                      s.message.isNotEmpty &&
                      s.realTime < s.messageUntil)
                    Positioned(
                      left: 24 * factor,
                      right: 24 * factor,
                      bottom: 24 * factor,
                      child: _instruction(s.message, factor),
                    ),
                  if (!_loading && showMenu)
                    Positioned.fill(child: _overlay(factor)),
                  if (_drawFocus != null &&
                      s.draft != null &&
                      s.phase == Phase.playing &&
                      !showMenu &&
                      !_opening)
                    InkDrawingLens(
                      game: game,
                      focus: _drawFocus!,
                      viewport: constraints.biggest,
                      label: _t('Çizim büyüteci'),
                      costLabel:
                          '${pathLength(s.validatedDraft().$1 ?? smoothStroke(s.draft!.points)).ceil()} ${_t('Ink')}',
                    ),
                  if (_opening && !_loading)
                    Positioned.fill(
                      child: InkOpening(
                        art: game.openingArt,
                        onComplete: _finishOpening,
                      ),
                    ),
                  if (_saveError || widget.storageError != null)
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 6,
                      child: Text(
                        _t(widget.storageError ?? 'Kayıt yazılamadı.'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10 * factor,
                          color: const Color(0xff916a4a),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _stuckWarning(double f) {
    final remaining = s.stuckCountdown!;
    return Center(
      child: Semantics(
        liveRegion: true,
        label: _t('{n} saniye. Dot ilerleyemiyor.', {'n': remaining}),
        child: ExcludeSemantics(
          child: Container(
            key: const ValueKey('ink-stuck-countdown'),
            padding: EdgeInsets.symmetric(horizontal: 24 * f, vertical: 8 * f),
            decoration: BoxDecoration(
              color: paper.withValues(alpha: .94),
              borderRadius: BorderRadius.circular(14 * f),
              border: Border.all(color: const Color(0x558d6b45)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Text(
                    '$remaining',
                    key: ValueKey(remaining),
                    style: TextStyle(
                      fontFamily: 'Cormorant',
                      fontSize: 46 * f,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: const Color(0xff805f3c),
                    ),
                  ),
                ),
                SizedBox(height: 3 * f),
                Text(
                  _t('Dot ilerleyemiyor'),
                  style: TextStyle(fontSize: 13 * f, color: muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ledgeWarning(double f) {
    final pulls = s.ledge!.pulls;
    return Center(
      child: Semantics(
        liveRegion: true,
        label: _t('Dot köşeye tutundu. Ekrana basıp bırak. {n} / {total}', {
          'n': pulls,
          'total': LedgeGrip.requiredPulls,
        }),
        child: ExcludeSemantics(
          child: Container(
            key: const ValueKey('ink-ledge-warning'),
            padding: EdgeInsets.symmetric(horizontal: 22 * f, vertical: 12 * f),
            decoration: BoxDecoration(
              color: paper.withValues(alpha: .96),
              borderRadius: BorderRadius.circular(14 * f),
              border: Border.all(color: const Color(0x558d6b45)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _t('Dot köşeye tutundu'),
                  style: TextStyle(
                    fontFamily: 'Cormorant',
                    fontSize: 25 * f,
                    fontWeight: FontWeight.w600,
                    color: inkColor,
                  ),
                ),
                Text(
                  pulls < LedgeGrip.requiredPulls
                      ? _t('Bas–çek yaparak tırman')
                      : _t('Dot tırmanıyor…'),
                  style: TextStyle(fontSize: 14 * f, color: muted),
                ),
                if (!s.ledgeTutorialDone)
                  Text(
                    _t('Ekrana {n} kez basıp bırak. Basılı tutmak sayılmaz.', {
                      'n': LedgeGrip.requiredPulls - pulls,
                    }),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12 * f, color: muted),
                  ),
                SizedBox(height: 9 * f),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    LedgeGrip.requiredPulls,
                    (i) => Container(
                      margin: EdgeInsets.symmetric(horizontal: 4 * f),
                      width: 9 * f,
                      height: 9 * f,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < pulls ? inkColor : const Color(0x227b684c),
                        border: Border.all(color: const Color(0x66877558)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hud(double f) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: _t('Mürekkep {n}, en fazla 240', {'n': s.ink.floor()}),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.water_drop_rounded, size: 18 * f, color: inkColor),
                  SizedBox(width: 8 * f),
                  Text(
                    '${s.ink.floor()}',
                    style: TextStyle(
                      fontSize: 23 * f,
                      fontWeight: FontWeight.w700,
                      color: inkColor,
                    ),
                  ),
                  Text(
                    ' / 240',
                    style: TextStyle(fontSize: 11 * f, color: muted),
                  ),
                ],
              ),
              SizedBox(height: 5 * f),
              SizedBox(
                width: 100 * f,
                height: 2 * f,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: s.ink / 240,
                    color: const Color(0xff736047),
                    backgroundColor: const Color(0x22877558),
                  ),
                ),
              ),
              SizedBox(height: 9 * f),
              Row(
                children: List.generate(
                  2,
                  (i) => Container(
                    margin: EdgeInsets.only(right: 5 * f),
                    width: 13 * f,
                    height: 3 * f,
                    decoration: BoxDecoration(
                      color: i < s.activeLines
                          ? const Color(0xff685442)
                          : const Color(0x267b684c),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 24 * f),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 440 * f),
              child: InkJourneyHud(
                distanceCm: s.distanceCm,
                progress: s.levelProgress,
                level: s.level.number,
                scale: f,
              ),
            ),
          ),
        ),
        SizedBox(width: 12 * f),
        AnimatedOpacity(
          opacity: _saved ? .7 : 0,
          duration: const Duration(milliseconds: 250),
          child: Padding(
            padding: EdgeInsets.only(top: 12 * f, right: 15 * f),
            child: Icon(
              Icons.check_circle_outline_rounded,
              size: 15 * f,
              color: muted,
            ),
          ),
        ),
        if (s.phase == Phase.playing || s.phase == Phase.resumeStroke)
          IconButton(
            tooltip: _t('Duraklat'),
            onPressed: _pause,
            icon: Icon(Icons.pause_rounded, color: inkColor, size: 25 * f),
          ),
      ],
    );
  }

  Widget _instruction(String text, double f) => Text(
    _t(text),
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: 14 * f,
      height: 1.65,
      color: const Color(0xff746752),
    ),
  );
  Widget _button(
    String text,
    VoidCallback onTap,
    double f, {
    bool primary = true,
  }) => Padding(
    padding: EdgeInsets.symmetric(vertical: 6 * f),
    child: SizedBox(
      width: math.max(220, 250 * f),
      height: math.max(48, 51 * f),
      child: FilledButton(
        key: ValueKey('ink-menu-button-$text'),
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: primary ? inkColor : const Color(0xfffff6e5),
          foregroundColor: primary ? paper : inkColor,
          elevation: primary ? 3 : 1,
          shadowColor: const Color(0x553d3226),
          side: BorderSide(
            color: primary ? inkColor : const Color(0xffa28a66),
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11 * f),
          ),
        ),
        child: Text(
          _t(text),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: (primary ? 15 : 14) * math.max(.85, f),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
  Widget _overlay(double f) {
    final ready = _mainMenu || s.phase == Phase.ready,
        dead = s.phase == Phase.dead,
        complete = s.phase == Phase.complete;
    final title = _settings
        ? 'Ayarlar'
        : ready
        ? 'INK ESCAPE'
        : dead
        ? 'Bir çizgi daha.'
        : complete
        ? 'İlk izler tamam.'
        : _settings
        ? 'Ayarlar'
        : 'Küçük bir mola.';
    String subtitle;
    if (_settings) {
      subtitle = 'Ses ve dil seçeneklerini kendine göre ayarla.';
    } else if (ready) {
      subtitle = s.lab
          ? '${_t(s.level.title)}\n${_t(s.level.rain.isNotEmpty
                ? 'Yolun üstüne koruyucu bir çatı çiz.'
                : s.level.balls.isNotEmpty
                ? 'Bilyeyi çiçekli yuvaya ulaştır.'
                : 'İki boşluk için çizgilerini sırayla kullan.')}'
          : widget.restored || s.x > 0
          ? (s.migratedLayout
                ? 'Parkur yenilendi. Tamamladığın bölümler korundu;\nmevcut bölümün başından devam edeceksin.'
                : 'Kâğıt seni bekliyor.')
          : 'Her çizgi, biraz daha yakın.';
    } else if (dead) {
      subtitle = _t(s.message);
    } else if (complete) {
      subtitle = s.lab
          ? 'Bu mekanik denemesi tamamlandı.'
          : 'İlk iki bölümün sonuna ulaştın.\nYolculuğun bu ilk taslağı burada bitiyor.';
    } else {
      subtitle = _settings
          ? 'Ses ve dil seçeneklerini kendine göre ayarla.'
          : 'Bıraktığın her iz yerinde.';
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey('${s.phase.name}-$_settings'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - value)),
          child: child,
        ),
      ),
      child: Material(
        color: paper.withValues(alpha: .47),
        child: Stack(
          children: [
            Positioned(
              left: 25 * f,
              right: 25 * f,
              top: 12 * f,
              bottom: 12 * f,
              child: InkCenteredMenu(
                child: Column(
                  key: const ValueKey('ink-menu-content'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (ready)
                      Text(
                        _t(
                          s.lab ? 'MEKANİK DENEMESİ' : 'BİR MÜREKKEP YOLCULUĞU',
                        ),
                        style: TextStyle(
                          fontSize: 10 * f,
                          letterSpacing: strings.tracking(3 * f),
                          color: muted,
                        ),
                      ),
                    SizedBox(height: ready ? 16 * f : 0),
                    Text(
                      _t(title),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Cormorant',
                        fontSize: (ready ? 59 : 43) * f,
                        fontWeight: FontWeight.w500,
                        letterSpacing: ready ? 2 * f : 0,
                        color: inkColor,
                        height: 1.05,
                      ),
                    ),
                    SizedBox(height: 17 * f),
                    Text(
                      _t(subtitle),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14 * f,
                        height: 1.7,
                        color: muted,
                      ),
                    ),
                    SizedBox(height: 25 * f),
                    if (_settings) ...[
                      SizedBox(
                        width: 285 * f,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('ink-language-${strings.code}'),
                          initialValue: strings.code,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: _t('Dil')),
                          items: InkStrings.languages
                              .map(
                                (language) => DropdownMenuItem(
                                  value: language.code,
                                  child: Text(
                                    language.name,
                                    textDirection: language.code == 'ar'
                                        ? TextDirection.rtl
                                        : TextDirection.ltr,
                                    style: TextStyle(fontSize: 14 * f),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              InkLocale.of(context)?.onChanged?.call(value);
                            }
                          },
                        ),
                      ),
                      SizedBox(
                        width: 285 * f,
                        child: SwitchListTile(
                          title: Text(
                            _t('Yumuşak müzik'),
                            style: TextStyle(fontSize: 14 * f),
                          ),
                          value: widget.sound.musicOn,
                          onChanged: (v) {
                            widget.sound.setMusic(v);
                            unawaited(
                              widget.store.write(
                                'ink.settings.music',
                                v ? 'on' : 'off',
                              ),
                            );
                            setState(() {});
                          },
                        ),
                      ),
                      SizedBox(
                        width: 285 * f,
                        child: SwitchListTile(
                          title: Text(
                            _t('Kalem ve dünya sesleri'),
                            style: TextStyle(fontSize: 14 * f),
                          ),
                          value: widget.sound.effectsOn,
                          onChanged: (v) {
                            widget.sound.setEffects(v);
                            unawaited(
                              widget.store.write(
                                'ink.settings.effects',
                                v ? 'on' : 'off',
                              ),
                            );
                            setState(() {});
                          },
                        ),
                      ),
                      _button(
                        'Geri',
                        () => setState(() => _settings = false),
                        f,
                      ),
                    ] else if (ready) ...[
                      _button(
                        s.phase == Phase.complete
                            ? 'Yeniden başla'
                            : widget.restored || s.x > 0
                            ? 'Devam et'
                            : 'Yolculuğa başla',
                        _start,
                        f,
                      ),
                      if (!s.lab)
                        _button(
                          'Hikâyeyi izle',
                          () => setState(() => _opening = true),
                          f,
                          primary: false,
                        ),
                      _button(
                        'Ayarlar',
                        () => setState(() => _settings = true),
                        f,
                        primary: false,
                      ),
                    ] else if (dead) ...[
                      _button('Bölümü yeniden dene', () {
                        _retry();
                        _start();
                      }, f),
                      Text(
                        _t('Bu bölümün başlangıcından.'),
                        style: TextStyle(fontSize: 11 * f, color: muted),
                      ),
                    ] else if (complete) ...[
                      _button('Tekrar oyna', () {
                        _retry(newJourney: true);
                      }, f),
                    ] else ...[
                      _button('Devam et', _start, f),
                      _button(
                        'Ayarlar',
                        () => setState(() => _settings = true),
                        f,
                        primary: false,
                      ),
                      _button(
                        'Bölümü baştan başlat',
                        _retry,
                        f,
                        primary: false,
                      ),
                    ],
                    if (ready && !_settings) ...[
                      SizedBox(height: 12 * f),
                      Text(
                        _t('Dot kendi yürür. Sen ona bir yol çiz.'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13 * f, color: muted),
                      ),
                    ],
                    if (!_settings && !ready && !dead)
                      _button(
                        'Ana Menüye Dön',
                        _returnToMenu,
                        f,
                        primary: false,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
