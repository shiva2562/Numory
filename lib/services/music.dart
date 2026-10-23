/// The synthwave background loop (assets/audio/music.wav, made by
/// tools/make_music.py). Plays while the app is on screen and Music is on.
///
/// The player is injectable so tests can see what would have played.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'save.dart';

abstract class MusicPlayer {
  Future<void> play();
  Future<void> pause();
}

/// Loops the track quietly under the sound effects. It shares the shell's
/// audio context, so it mixes with the player's own music.
class LoopPlayer implements MusicPlayer {
  AudioPlayer? _player;

  @override
  Future<void> play() async {
    try {
      final p = _player ??= await _create();
      await p.resume();
    } on Object catch (e) {
      debugPrint('Music failed: $e');
    }
  }

  static Future<AudioPlayer> _create() async {
    final p = AudioPlayer();
    await p.setReleaseMode(ReleaseMode.loop);
    await p.setVolume(0.35);
    await p.setSource(AssetSource('audio/music.wav'));
    return p;
  }

  @override
  Future<void> pause() async => _player?.pause();
}

class Music {
  Music({required this.profile, MusicPlayer? player}) : _player = player ?? LoopPlayer() {
    profile.addListener(_sync);
  }

  final Profile profile;
  final MusicPlayer _player;
  bool _visible = false;
  bool _playing = false;

  /// Whether the app is on screen. The music stops while it is hidden,
  /// a full-screen ad included.
  set visible(bool on) {
    _visible = on;
    _sync();
  }

  void _sync() {
    final want = _visible && profile.music;
    if (want == _playing) return;
    _playing = want;
    unawaited(want ? _player.play() : _player.pause());
  }
}

/// Remembers what would have played.
class FakeMusicPlayer implements MusicPlayer {
  bool playing = false;

  @override
  Future<void> play() async => playing = true;

  @override
  Future<void> pause() async => playing = false;
}
