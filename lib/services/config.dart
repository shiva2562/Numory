/// Every tunable number in one place. Pure Dart so tools and tests can use it.
library;

import '../core/round.dart';

class GameConfig {
  GameConfig([Map<String, Object?> overrides = const {}]) {
    for (final e in overrides.entries) {
      if (defaults.containsKey(e.key) && e.value != null) _values[e.key] = e.value;
    }
  }

  /// A build for testing the pop-ups on a phone: `--dart-define=FAST_PACING=true`
  /// shows interstitials every round (15 s apart) and lifts the daily offer
  /// caps, so the cards can be seen in a minute. The order of the offers
  /// (2nd ad, every 2nd, doubling) is unchanged. Store builds don't set it.
  factory GameConfig.forBuild() => GameConfig(const bool.fromEnvironment('FAST_PACING') ? fastPacing : const {});

  static const Map<String, Object?> fastPacing = {
    'interstitial_min_rounds': 1,
    'interstitial_every_n_rounds': 1,
    'interstitial_min_seconds': 15,
    'offer_min_gap_s': 15,
    'offer_remove_ads_per_day': 50,
    'offer_per_day': 50,
  };

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
    // Pop-up purchase offers (DESIGN.md "Purchase offers", lib/services/
    // offers.dart). The Remove Ads card follows an interstitial: the first
    // after the 2nd one, then after every 2nd, doubled by each "Not now" in
    // a row (at most 5 doublings). At most 2 Remove Ads cards and 3 pop-up
    // offers a day, 3 minutes apart, never in the first session.
    'offer_first_after_ads': 2,
    'offer_every_ads': 2,
    'offer_remove_ads_per_day': 2,
    'offer_per_day': 3,
    'offer_min_gap_s': 180,
    'offer_max_doublings': 5,
    // A breath between the ad closing and the card appearing.
    'offer_delay_ms': 600,
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

  /// The fastest time [mode] may submit to its leaderboard.
  Duration minValidTime(Mode mode) =>
      Duration(microseconds: (doubleOf('min_valid_seconds_${mode.id}') * 1e6).round());
}
