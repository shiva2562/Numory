/// Every tunable number in one place. Pure Dart so tools and tests can use it.
library;

import '../core/round.dart';

class GameConfig {
  GameConfig([Map<String, Object?> overrides = const {}]) {
    for (final e in overrides.entries) {
      if (defaults.containsKey(e.key) && e.value != null) _values[e.key] = e.value;
    }
  }

  static const Map<String, Object?> defaults = {
    // Interstitials count finished or failed rounds as "levels" (shell
    // InterstitialFlow): never in the first session, not before this many
    // rounds in total, then at most one per N rounds and per N seconds.
    'interstitial_min_rounds': 10,
    'interstitial_every_n_rounds': 3,
    'interstitial_min_seconds': 180,
    // Times below these are impossible for a human and never reach the
    // leaderboard (they are still shown and saved locally).
    'min_valid_seconds_easy': 0.4,
    'min_valid_seconds_medium': 0.9,
    'min_valid_seconds_hard': 1.8,
    // The one-time Remove Ads offer, after this many rounds.
    'first_offer_round': 25,
    // The store's own rating sheet on a new best: from this round on, at
    // most once in this many days, this long after the result card shows.
    'review_min_rounds': 5,
    'review_every_days': 90,
    'review_delay_s': 1.6,
  };

  final Map<String, Object?> _values = Map.of(defaults);

  int intOf(String key) => (_values[key]! as num).toInt();
  double doubleOf(String key) => (_values[key]! as num).toDouble();

  int get interstitialMinRounds => intOf('interstitial_min_rounds');
  int get interstitialEveryNRounds => intOf('interstitial_every_n_rounds');
  int get interstitialMinSeconds => intOf('interstitial_min_seconds');
  int get firstOfferRound => intOf('first_offer_round');

  /// The fastest time [mode] may submit to its leaderboard.
  Duration minValidTime(Mode mode) =>
      Duration(microseconds: (doubleOf('min_valid_seconds_${mode.id}') * 1e6).round());
}
