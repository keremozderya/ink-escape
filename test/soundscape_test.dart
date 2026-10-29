import 'package:flutter_test/flutter_test.dart';
import 'package:ink_escape/soundscape.dart';

void main() {
  for (final event in ['death', 'complete', 'pause']) {
    for (final effects in [true, false]) {
      test(
        '$event stops music intent with effects=$effects before audio is ready',
        () async {
          final sound = Soundscape(enabled: false)..setEffects(effects);
          sound.event('start');
          expect(sound.isPlaying, isTrue);
          sound.event(event);
          expect(sound.isPlaying, isFalse);
          // Deferred initialization must not start music after the run ended.
          await sound.init();
          expect(sound.isPlaying, isFalse);
          sound.event('start');
          expect(sound.isPlaying, isTrue);
          expect(sound.effectsOn, effects);
          await sound.dispose();
        },
      );
    }
  }

  test('SFX and music choices do not change each other', () async {
    final sound = Soundscape(enabled: false)..event('start');
    sound.setEffects(false);
    expect(sound.musicOn, isTrue);
    expect(sound.isPlaying, isTrue);
    sound.setMusic(false);
    sound.event('complete');
    sound.event('start');
    expect(sound.musicOn, isFalse);
    expect(sound.effectsOn, isFalse);
    await sound.dispose();
  });
}
