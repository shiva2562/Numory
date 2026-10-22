/// Sound and haptics for every row of the juice table (GOAL.md).
///
/// Backends are injectable so tests can assert what would have played.
library;

import 'dart:async';

import 'package:shivapps_shell/shivapps_shell.dart';

class Juice {
  Juice({SoundBackend? sound, HapticBackend? haptics, required this.soundOn, required this.hapticsOn})
    : _sound = sound ?? FlameSoundBackend(),
      _haptics = haptics ?? SystemHaptics();

  final SoundBackend _sound;
  final HapticBackend _haptics;
  final bool Function() soundOn;
  final bool Function() hapticsOn;

  static final files = [
    for (var k = 1; k <= 15; k++) note(k),
    'start.wav',
    'wrong.wav',
    'done.wav',
    'best.wav',
    'tap.wav',
  ];

  static String note(int number) => 'note_${number.toString().padLeft(2, '0')}.wav';

  Future<void> preload() => _sound.preload(files);

  void _play(String file, [double volume = 0.7]) {
    if (soundOn()) _sound.play(file, volume);
  }

  /// A button on home or in a sheet.
  void tap() {
    _play('tap.wav', 0.5);
    if (hapticsOn()) _haptics.selection();
  }

  /// The numbers appear and the clock starts.
  void start() {
    _play('start.wav', 0.5);
    if (hapticsOn()) _haptics.light();
  }

  /// [number] tapped in order: one note higher per number.
  void correct(int number) {
    _play(note(number.clamp(1, 15)));
    if (hapticsOn()) _haptics.selection();
  }

  void wrong() {
    _play('wrong.wav');
    if (hapticsOn()) _haptics.heavy();
  }

  void done({required bool newBest}) {
    _play(newBest ? 'best.wav' : 'done.wav');
    if (!hapticsOn()) return;
    _haptics.medium();
    if (newBest) Timer(const Duration(milliseconds: 110), _haptics.medium);
  }
}
