import 'dart:async';

import 'package:flame_audio/flame_audio.dart';

/// All audio is bundled; no ads, trackers or remote audio requests.
class Soundscape {
  Soundscape({this.enabled = true});
  final bool enabled;
  bool musicOn = true,
      effectsOn = true,
      _ready = false,
      _playing = false,
      _disposed = false;
  bool _pencilPlaying = false;
  bool get isPlaying => _playing;
  int _step = 0;
  DateTime _lastCrumb = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<String, AudioPool> _pools = {};
  AudioPlayer? _music, _pencil;
  Timer? _penIdle;
  String? error;
  static const effects = [
    'step0',
    'step1',
    'step2',
    'step3',
    'step4',
    'step5',
    'commit',
    'pickup',
    'capture',
    'gate',
    'start',
    'complete',
    'crumb',
    'invalid',
    'death',
    'dissolve',
    'land',
    'ballRelease',
  ];
  Future<void> init() async {
    if (!enabled) {
      return;
    }
    try {
      await FlameAudio.audioCache.loadAll([
        ...effects.map((s) => '$s.wav'),
        'pencil.wav',
        'paper_evening.mp3',
      ]);
      if (_disposed) {
        return;
      }
      _music = AudioPlayer()..audioCache = FlameAudio.audioCache;
      _pencil = AudioPlayer()..audioCache = FlameAudio.audioCache;
      await _music!.setReleaseMode(ReleaseMode.loop);
      await _music!.setVolume(.32);
      await _music!.setSource(AssetSource('paper_evening.mp3'));
      await _pencil!.setReleaseMode(ReleaseMode.loop);
      await _pencil!.setVolume(.5);
      await _pencil!.setSource(AssetSource('pencil.wav'));
      for (final s in effects) {
        if (_disposed) {
          return;
        }
        _pools[s] = await FlameAudio.createPool('$s.wav', maxPlayers: 3);
      }
      _ready = true;
      if (_playing && musicOn) {
        _safe(_music!.resume());
      }
    } catch (e) {
      error = 'Ses yüklenemedi';
    }
  }

  void _safe(Future<dynamic> f) {
    unawaited(_guard(f));
  }

  Future<void> _guard(Future<dynamic> f) async {
    try {
      await f;
    } catch (_) {
      error = 'Ses başlatılamadı';
    }
  }

  void resume() {
    _playing = true;
    if (_ready && musicOn) {
      _safe(_music!.resume());
    }
  }

  void pause() {
    _playing = false;
    stopPencil();
    if (_ready) {
      _safe(_music!.pause());
    }
  }

  void setMusic(bool value) {
    musicOn = value;
    if (_ready) {
      _safe(value && _playing ? _music!.resume() : _music!.pause());
    }
  }

  void setEffects(bool value) {
    effectsOn = value;
    if (!value) {
      stopPencil();
    }
  }

  void stopPencil() {
    _penIdle?.cancel();
    _pencilPlaying = false;
    if (_ready) {
      _safe(_pencil!.pause());
    }
  }

  void event(String name) {
    if (name == 'penMove') {
      if (!_ready || !effectsOn || !_playing) {
        return;
      }
      if (!_pencilPlaying) {
        _pencilPlaying = true;
        _safe(_pencil!.resume());
      }
      _penIdle?.cancel();
      _penIdle = Timer(const Duration(milliseconds: 110), stopPencil);
      return;
    }
    if (['penStop', 'pause', 'death', 'complete', 'boundary'].contains(name)) {
      stopPencil();
    }
    if (name == 'pause') {
      pause();
      return;
    }
    if (name == 'start') {
      resume();
    }
    // Music lifecycle is independent of the SFX switch and audio loading.
    if (name == 'death' || name == 'complete') {
      pause();
    }
    if (!_ready || !effectsOn) {
      return;
    }
    if (name == 'step') {
      const sequence = [0, 3, 1, 4, 2, 5];
      name = 'step${sequence[_step++ % sequence.length]}';
    }
    if (name == 'crumb') {
      final now = DateTime.now();
      if (now.difference(_lastCrumb).inMilliseconds < 110) {
        return;
      }
      _lastCrumb = now;
    }
    final pool = _pools[name];
    if (pool != null) {
      _safe(
        pool.start(
          volume: name.startsWith('step')
              ? .48
              : name == 'crumb'
              ? .35
              : .72,
        ),
      );
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _penIdle?.cancel();
    await _music?.dispose();
    await _pencil?.dispose();
    for (final p in _pools.values) {
      await p.dispose();
    }
  }
}
