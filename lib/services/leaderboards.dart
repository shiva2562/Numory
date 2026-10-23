/// The three all-time global leaderboards, one per mode, on Google Play
/// Games Services. Times go in as milliseconds; lower is better (set "Smaller
/// is better" and "Time" format on each leaderboard in Play Console).
///
/// A fake stands in for tests and for builds without leaderboard IDs.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart' as gs;

import '../core/round.dart';
import '../release_config.dart';

/// Where a submitted time puts the player.
class RankInfo {
  const RankInfo({required this.rank});

  /// 1-based all-time rank in the world; null when the score went in but
  /// Play Games won't rank it (the player hides their game activity).
  final int? rank;
}

abstract class Leaderboards extends ChangeNotifier {
  /// False while the leaderboard IDs are empty: nothing to submit to.
  bool get available;
  bool get signedIn;

  /// Whether Play Games' automatic sign-in worked; [interactive] (a player's
  /// tap) opens Play Games' sign-in UI.
  Future<bool> signIn({bool interactive = false});

  /// Submits [time] for [mode] and returns the player's rank, or null when
  /// the score couldn't be sent.
  Future<RankInfo?> submit(Mode mode, Duration time);

  /// Opens Play Games' own screen for [mode]'s board.
  Future<void> show(Mode mode);
}

String leaderboardId(Mode mode) => switch (mode) {
  Mode.easy => leaderboardEasyAndroid,
  Mode.medium => leaderboardMediumAndroid,
  Mode.hard => leaderboardHardAndroid,
};

class PlayGamesLeaderboards extends Leaderboards {
  bool _signedIn = false;

  @override
  bool get available =>
      defaultTargetPlatform == TargetPlatform.android && Mode.values.every((m) => leaderboardId(m).isNotEmpty);

  @override
  bool get signedIn => _signedIn;

  @override
  Future<bool> signIn({bool interactive = false}) {
    if (!available) return Future.value(false);
    if (_signedIn) return Future.value(true);
    // Only a player's tap may open Play Games' own sign-in UI. Otherwise ask
    // quietly whether Play Games' automatic sign-in already happened.
    if (interactive) return _signIn();
    return _checking ??= _check();
  }

  Future<bool>? _checking;

  Future<bool> _check() async {
    try {
      _signedIn = await gs.GameAuth.isSignedIn;
    } on Object catch (e) {
      debugPrint('Play Games check failed: $e');
      _signedIn = false;
    }
    _checking = null;
    notifyListeners();
    return _signedIn;
  }

  Future<bool> _signIn() async {
    try {
      await gs.GameAuth.signIn();
      _signedIn = await gs.GameAuth.isSignedIn;
    } on Object catch (e) {
      debugPrint('Play Games sign-in failed: $e');
      _signedIn = false;
    }
    notifyListeners();
    return _signedIn;
  }

  @override
  Future<RankInfo?> submit(Mode mode, Duration time) async {
    if (!await signIn()) return null;
    final id = leaderboardId(mode);
    try {
      await gs.Leaderboards.submitScore(score: gs.Score(androidLeaderboardID: id, value: centis(time) * 10));
    } on Object catch (e) {
      debugPrint('Leaderboard submit failed: $e');
      return null;
    }
    // The score is in. A player who hides their game activity is left off
    // the public board, so Play Games gives them no rank.
    try {
      final me = await gs.Leaderboards.getPlayerScoreObject(
        androidLeaderboardID: id,
        scope: gs.PlayerScope.global,
        timeScope: gs.TimeScope.allTime,
      );
      if (me != null && me.rank > 0) return RankInfo(rank: me.rank);
    } on Object catch (e) {
      debugPrint('Leaderboard rank failed: $e');
    }
    return const RankInfo(rank: null);
  }

  @override
  Future<void> show(Mode mode) async {
    if (!await signIn(interactive: true)) return;
    try {
      await gs.Leaderboards.showLeaderboards(androidLeaderboardID: leaderboardId(mode));
    } on Object catch (e) {
      debugPrint('Leaderboard screen failed: $e');
    }
  }
}

/// For tests and debug builds without IDs: remembers bests, ranks by a
/// made-up crowd so the result card can be seen.
class FakeLeaderboards extends Leaderboards {
  FakeLeaderboards({this.available = true, bool signedIn = true, this.rankHidden = false}) {
    _signedIn = signedIn;
  }

  @override
  final bool available;

  /// Plays a player whose game activity is hidden: scores go in, no rank.
  final bool rankHidden;
  late bool _signedIn;
  final Map<Mode, Duration> bests = {};
  final List<Mode> shown = [];

  @override
  bool get signedIn => _signedIn;

  @override
  Future<bool> signIn({bool interactive = false}) async {
    if (interactive && available) {
      _signedIn = true;
      notifyListeners();
    }
    return _signedIn;
  }

  @override
  Future<RankInfo?> submit(Mode mode, Duration time) async {
    if (!available || !_signedIn) return null;
    final old = bests[mode];
    final best = old == null || time < old ? time : old;
    bests[mode] = best;
    if (rankHidden) return const RankInfo(rank: null);
    // About one player per 10 ms over a typical time for the mode.
    final typical = {Mode.easy: 1200, Mode.medium: 2800, Mode.hard: 7000}[mode]!;
    final rank = 1 + ((best.inMilliseconds - typical / 3).clamp(0, 1e9) / 10).round();
    return RankInfo(rank: rank);
  }

  @override
  Future<void> show(Mode mode) async => shown.add(mode);
}
