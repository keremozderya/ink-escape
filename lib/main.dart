import 'dart:async';
import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/ink_model.dart';
import 'core/save_journal.dart';
import 'ink_game.dart';
import 'soundscape.dart';
import 'presentation/opening_story.dart';

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
  final raw = jsonDecode(
    await rootBundle.loadString('assets/data/prototype_levels.json'),
  ) as Map<String, dynamic>;
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
  );
  Map<String, dynamic>? saved;
  try {
    saved = await journal.load();
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
  final sound = Soundscape();
  sound.musicOn = await store.read('ink.settings.music') != 'off';
  sound.effectsOn = await store.read('ink.settings.effects') != 'off';
  runApp(
    InkEscapeApp(
      session: session,
      journal: journal,
      store: store,
      sound: sound,
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

class InkEscapeApp extends StatelessWidget {
  const InkEscapeApp({
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
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Ink Escape',
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Nunito',
      scaffoldBackgroundColor: const Color(0xffe6dfd0),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff74634e),
        surface: paper,
      ),
      textTheme: const TextTheme(bodyMedium: TextStyle(color: inkColor)),
    ),
    home: GameScreen(
      session: session,
      journal: journal,
      store: store,
      sound: sound,
      restored: restored,
      camera: camera,
      storageError: storageError,
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
  InkSession get s => widget.session;
  bool _loading = true, _settings = false, _saved = false, _saveError = false;
  int? _pointer;
  bool _opening = false, _openingSeen = false;
  bool _mainMenu = false;
  Timer? _saveIndicator;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    game = InkGame(
      s,
      initialCamera: widget.camera,
      onFrame: () {
        if (mounted) {
          setState(() {
            _loading = !game.sceneReady;
          });
        }
      },
      onEffect: widget.sound.event,
    );
    s.onSaveRequested = (forced) {
      unawaited(_save());
    };
    unawaited(widget.sound.init());
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
      setState(() {
        _saved = true;
        _saveError = false;
      });
      _saveIndicator?.cancel();
      _saveIndicator = Timer(const Duration(milliseconds: 850), () {
        if (mounted) {
          setState(() => _saved = false);
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
    if (mounted) {
      setState(() => _settings = false);
    }
    unawaited(_save());
  }

  void _returnToMenu() {
    s.pause();
    widget.sound.pause();
    _pointer = null;
    setState(() {
      _mainMenu = true;
      _settings = false;
      _opening = false;
    });
    unawaited(_save());
  }

  void _start() async {
    if (_mainMenu && s.phase == Phase.complete) {
      s.levelIndex = 0;
      s.entryInk = 180;
      s.origin = 0;
      _retry();
    }
    _mainMenu = false;
    if (!_openingSeen &&
        !widget.restored &&
        !s.lab &&
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

  void _retry() {
    game.cameraX = -96;
    s.retry();
    game.resetView();
    setState(() => _settings = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveIndicator?.cancel();
    s.onSaveRequested = null;
    game.pauseEngine();
    unawaited(widget.sound.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                        if (_pointer == null && game.sceneReady) {
                          if (s.beginStroke(game.worldPoint(e.localPosition))) {
                            _pointer = e.pointer;
                          }
                        }
                      },
                      onPointerMove: (e) {
                        if (e.pointer == _pointer) {
                          s.moveStroke(game.worldPoint(e.localPosition));
                        }
                      },
                      onPointerUp: (e) {
                        if (e.pointer == _pointer) {
                          s.moveStroke(game.worldPoint(e.localPosition));
                          s.endStroke();
                          _pointer = null;
                          setState(() {});
                        }
                      },
                      onPointerCancel: (e) {
                        if (e.pointer == _pointer) {
                          s.losePointer();
                          _pointer = null;
                          widget.sound.pause();
                          setState(() {});
                        }
                      },
                      child: GameWidget(
                        game: game,
                        loadingBuilder: (_) => const ColoredBox(
                          color: paper,
                          child: Center(child: Text('Kâğıtlar hazırlanıyor…')),
                        ),
                      ),
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
                  if (!_loading)
                    Positioned(
                      left: 30 * factor,
                      right: 26 * factor,
                      top: 30 * factor,
                      child: _hud(factor),
                    ),
                  if (!_loading && !_mainMenu && s.stuckCountdown != null)
                    Positioned(
                      top: 90 * factor,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(child: _stuckWarning(factor)),
                    ),
                  if (!_loading &&
                      s.phase == Phase.playing &&
                      !s.firstDrawDone &&
                      s.x > 60)
                    Positioned(
                      left: 24 * factor,
                      right: 24 * factor,
                      bottom: 65 * factor,
                      child: _instruction(
                        'Sabit bir kâğıt kenarından başlayıp yolunu çiz.\nBitiş noktası serbest; Dot çıkamazsa takılır.',
                        factor,
                      ),
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
                            child: const Text('Bu çizgiden vazgeç'),
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
                  if (!_loading &&
                      (_mainMenu ||
                          s.phase == Phase.ready ||
                          s.phase == Phase.paused ||
                          s.phase == Phase.complete ||
                          (s.phase == Phase.dead && game.deathEffectComplete)))
                    Positioned.fill(child: _overlay(factor)),
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
                        widget.storageError ?? 'Kayıt yazılamadı.',
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
        label: '$remaining saniye. Dot ilerleyemiyor.',
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
                  'Dot ilerleyemiyor',
                  style: TextStyle(fontSize: 13 * f, color: muted),
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
          label: 'Mürekkep ${s.ink.floor()}, en fazla 240',
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
        const Spacer(),
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
            tooltip: 'Duraklat',
            onPressed: _pause,
            icon: Icon(Icons.pause_rounded, color: inkColor, size: 25 * f),
          ),
      ],
    );
  }

  Widget _instruction(String text, double f) => Text(
    text,
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
      width: 250 * f,
      height: 51 * f,
      child: primary
          ? FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: inkColor,
                foregroundColor: paper,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11 * f),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(fontSize: 15 * f, fontWeight: FontWeight.w700),
              ),
            )
          : TextButton(
              onPressed: onTap,
              child: Text(
                text,
                style: TextStyle(fontSize: 13 * f, color: muted),
              ),
            ),
    ),
  );
  Widget _overlay(double f) {
    final ready = _mainMenu || s.phase == Phase.ready,
        dead = s.phase == Phase.dead,
        complete = s.phase == Phase.complete;
    final title = _settings
        ? 'Sesler'
        : ready
        ? 'INK ESCAPE'
        : dead
        ? 'Bir çizgi daha.'
        : complete
        ? 'İlk izler tamam.'
        : _settings
        ? 'Sesler'
        : 'Küçük bir mola.';
    String subtitle;
    if (_settings) {
      subtitle = 'Kâğıdın sesini kendine göre ayarla.';
    } else if (ready) {
      subtitle = s.lab
          ? '${s.level.title}\n${s.level.rain.isNotEmpty
                ? 'Yolun üstüne koruyucu bir çatı çiz.'
                : s.level.balls.isNotEmpty
                ? 'Bilyeyi çiçekli yuvaya ulaştır.'
                : 'İki boşluk için çizgilerini sırayla kullan.'}'
          : widget.restored || s.x > 0
          ? (s.migratedLayout
                ? 'Parkur yenilendi. Tamamladığın bölümler korundu;\nmevcut bölümün başından devam edeceksin.'
                : 'Kâğıt seni bekliyor.')
          : 'Her çizgi, biraz daha yakın.';
    } else if (dead) {
      subtitle = s.message;
    } else if (complete) {
      subtitle = s.lab ? 'Bu mekanik denemesi tamamlandı.' : 'İlk iki bölümün sonuna ulaştın.\nYolculuğun bu ilk taslağı burada bitiyor.';
    } else {
      subtitle = _settings
          ? 'Kâğıdın sesini kendine göre ayarla.'
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
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (ready)
                      Text(
                        s.lab ? 'MEKANİK DENEMESİ' : 'BİR MÜREKKEP YOLCULUĞU',
                        style: TextStyle(
                          fontSize: 10 * f,
                          letterSpacing: 3 * f,
                          color: muted,
                        ),
                      ),
                    SizedBox(height: ready ? 16 * f : 0),
                    Text(
                      title,
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
                      subtitle,
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
                        child: SwitchListTile(
                          title: Text(
                            'Yumuşak müzik',
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
                            'Kalem ve dünya sesleri',
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
                        'Ses ayarları',
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
                        'Bu bölümün başlangıcından.',
                        style: TextStyle(fontSize: 11 * f, color: muted),
                      ),
                    ] else if (complete) ...[
                      _button('Tekrar oyna', () {
                        if (s.levelIndex > 0) {
                          s.levelIndex = 0;
                          s.entryInk = 180;
                          s.origin = 0;
                        }
                        _retry();
                      }, f),
                    ] else ...[
                      _button('Devam et', _start, f),
                      _button(
                        'Ses ayarları',
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
                        'Dot kendi yürür. Sen ona bir yol çiz.',
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
