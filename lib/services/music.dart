/// The synthwave background loop (assets/audio/music.wav, made by
/// tools/make_music.py). Plays while the app is on screen and Music is on.
///
/// The player is injectable so tests can see what would have played.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'save.dart';

/// The looping player under [Music]. Each call is made after the last one
/// has finished.
abstract class MusicPlayer {
  /// Loads the loop on the first call, then plays it.
  Future<void> play();
  Future<void> pause();
}

/// Loops the track quietly under the sound effects. It shares the shell's
/// audio context, so it mixes with the player's own music.
class LoopPlayer implements MusicPlayer {
  AudioPlayer? _player;

  @override
  Future<void> play() async {
    final p = _player ??= await _create();
    await p.resume();
  }

  static Future<AudioPlayer> _create() async {
    // No per-frame position polling on a looping player (SHELL-FIXES 11).
    final p = AudioPlayer()..positionUpdater = null;
    await p.setReleaseMode(ReleaseMode.loop);
    await p.setVolume(0.35);
    // iOS tells the loop from the effects by this name (GameViewController).
    await p.setSource(AssetSource('audio/music.wav'));
    return p;
  }

  @override
  Future<void> pause() async => _player?.pause();
}

/// Keeps the player at what is wanted: Music on and the app in sight.
/// Calls go to the player one at a time, each chosen when the last one
/// ends, so a quick trip out of the app and back ends in the right state.
/// (Calls used to overlap: a pause sent while the loop was still loading
/// found no player, and the loop then started in the background.)
class Music {
  Music({required this.profile, MusicPlayer? player}) : _player = player ?? LoopPlayer() {
    profile.addListener(_sync);
  }

  final Profile profile;
  final MusicPlayer _player;
  bool _visible = false;

  /// What the player was last told.
  bool _playing = false;
  bool _busy = false;

  /// Whether the app is on screen. The music stops while it is hidden,
  /// a full-screen ad included. Back in sight, the player is asked to play
  /// again even if it was never told to pause: the system may have paused
  /// it (a call, another app, iOS deactivating the audio session).
  bool get visible => _visible;
  set visible(bool on) {
    _visible = on;
    if (on) _playing = false;
    _sync();
  }

  void _sync() {
    if (_busy) return; // the running loop sees the change
    _busy = true;
    unawaited(() async {
      try {
        while (await _next()) {}
      } finally {
        _busy = false;
      }
    }());
  }

  /// Sends the one call that brings the player to what is wanted; false
  /// once it is there.
  Future<bool> _next() async {
    final want = _visible && profile.music;
    if (want == _playing) return false;
    _playing = want;
    try {
      await (want ? _player.play() : _player.pause());
      return true;
    } on Object catch (e) {
      // Tried again on the next change.
      debugPrint('music: $e');
      _playing = false;
      return false;
    }
  }
}

/// Remembers what would have played.
class FakeMusicPlayer implements MusicPlayer {
  bool playing = false;

  /// Calls so far, in order.
  final calls = <String>[];

  @override
  Future<void> play() async {
    calls.add('play');
    playing = true;
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    playing = false;
  }
}
