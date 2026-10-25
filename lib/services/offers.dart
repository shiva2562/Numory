/// When a pop-up purchase offer may appear (Shiva, 2026-10-25: "a little
/// annoying, but nobody should uninstall or resent the app"; DESIGN.md
/// "Purchase offers"). Pure Dart, so the numbers can be tuned and tested
/// without a screen.
///
/// Numory sells one product, Remove Ads, so there is one pop-up: its card
/// right after an interstitial closes. The "happy moment" card for a second
/// product does not exist here. Two doors are not pop-ups and live in the
/// screens: the **No ads** button on the end card, and Settings.
library;

import 'dart:math' as math;

import 'config.dart';

/// The `place` of an offer in analytics (`Analytics.offerShown`,
/// `purchaseStart`, `purchaseResult`).
abstract final class OfferPlace {
  /// The pop-up right after an interstitial closed.
  static const afterAd = 'after_ad';

  /// A pop-up at a happy moment (a second product; Numory has none).
  static const happy = 'happy';

  /// The small **No ads** button on the end card.
  static const endCard = 'end_card';

  /// The "new" dot on a shop button (Numory has no shop).
  static const badge = 'badge';
}

/// The offer numbers, from `config.dart` (`offer_*`).
class OfferRules {
  const OfferRules({
    required this.firstAfterAds,
    required this.everyAds,
    required this.removeAdsPerDay,
    required this.perDay,
    required this.minGap,
    required this.maxDoublings,
    required this.delay,
  });

  factory OfferRules.of(GameConfig c) => OfferRules(
    firstAfterAds: c.intOf('offer_first_after_ads'),
    everyAds: c.intOf('offer_every_ads'),
    removeAdsPerDay: c.intOf('offer_remove_ads_per_day'),
    perDay: c.intOf('offer_per_day'),
    minGap: Duration(seconds: c.intOf('offer_min_gap_s')),
    maxDoublings: c.intOf('offer_max_doublings'),
    delay: Duration(milliseconds: c.intOf('offer_delay_ms')),
  );

  /// The first Remove Ads card comes after this many interstitials.
  final int firstAfterAds;

  /// Then after every this many more, doubled by each "Not now" in a row.
  final int everyAds;

  /// At most this many Remove Ads cards a day.
  final int removeAdsPerDay;

  /// At most this many pop-up offers a day, all products together.
  final int perDay;

  /// At least this long between two pop-up offers.
  final Duration minGap;

  /// "Not now" doubles the gap at most this many times.
  final int maxDoublings;

  /// A breath between the ad closing and the card appearing.
  final Duration delay;
}

/// What the offers remember, saved in the profile's `extra['offers']`.
class OfferState {
  OfferState({
    this.adsShown = 0,
    this.adsAtLastOffer,
    this.declines = 0,
    this.lastPopup,
    this.day = '',
    this.popupsToday = 0,
    this.removeAdsToday = 0,
  });

  factory OfferState.fromJson(Object? json) {
    final j = json is Map ? json : const {};
    return OfferState(
      adsShown: (j['adsShown'] as num?)?.toInt() ?? 0,
      adsAtLastOffer: (j['adsAtLastOffer'] as num?)?.toInt(),
      declines: (j['declines'] as num?)?.toInt() ?? 0,
      lastPopup: DateTime.tryParse(j['lastPopup'] as String? ?? ''),
      day: j['day'] as String? ?? '',
      popupsToday: (j['popupsToday'] as num?)?.toInt() ?? 0,
      removeAdsToday: (j['removeAdsToday'] as num?)?.toInt() ?? 0,
    );
  }

  /// Interstitials played, ever.
  int adsShown;

  /// [adsShown] when the Remove Ads card last appeared; null before the first.
  int? adsAtLastOffer;

  /// "Not now" taps in a row on the Remove Ads card.
  int declines;

  /// When the last pop-up offer (any product) appeared.
  DateTime? lastPopup;

  /// The local day the two counters below belong to.
  String day;
  int popupsToday;
  int removeAdsToday;

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Pop-ups shown on [now]'s day, all products.
  int popupsOn(DateTime now) => day == dayKey(now) ? popupsToday : 0;

  /// Remove Ads cards shown on [now]'s day.
  int removeAdsOn(DateTime now) => day == dayKey(now) ? removeAdsToday : 0;

  /// An interstitial played and closed.
  void adPlayed() => adsShown++;

  /// The Remove Ads card appeared at [now].
  void removeAdsShown(DateTime now) {
    final key = dayKey(now);
    if (day != key) {
      day = key;
      popupsToday = 0;
      removeAdsToday = 0;
    }
    popupsToday++;
    removeAdsToday++;
    lastPopup = now;
    adsAtLastOffer = adsShown;
  }

  /// The player closed the Remove Ads card without buying.
  void removeAdsDeclined() => declines++;

  Map<String, Object?> toJson() => {
    'adsShown': adsShown,
    'adsAtLastOffer': adsAtLastOffer,
    'declines': declines,
    'lastPopup': lastPopup?.toIso8601String(),
    'day': day,
    'popupsToday': popupsToday,
    'removeAdsToday': removeAdsToday,
  };
}

/// How many interstitials must play between two Remove Ads cards: every 2nd,
/// then 4th, 8th... as "Not now" taps pile up (at most [OfferRules.maxDoublings]
/// doublings).
int removeAdsGap(OfferRules rules, OfferState state) =>
    rules.everyAds * (1 << math.min(state.declines, rules.maxDoublings));

/// Whether the Remove Ads card may appear now, right after an interstitial
/// closed ([OfferState.adPlayed] has already counted it).
///
/// Never: in the first session ([session] 1), for a player who chose under
/// 13, who sees no ads, who owns Remove Ads (a purchase or a restore ends the
/// offer), or while the store has no price to show. Otherwise: from the
/// [OfferRules.firstAfterAds]-th interstitial, then every
/// [removeAdsGap]-th since the last card, at most [OfferRules.removeAdsPerDay]
/// cards and [OfferRules.perDay] pop-ups a day, and [OfferRules.minGap] after
/// the last pop-up.
bool removeAdsAfterAdDue({
  required OfferRules rules,
  required OfferState state,
  required DateTime now,
  required int session,
  required bool owned,
  required bool seesAds,
  required bool underThirteen,
  required bool storeReady,
}) {
  if (owned || underThirteen || !seesAds || !storeReady) return false;
  if (session <= 1) return false;
  if (state.popupsOn(now) >= rules.perDay) return false;
  if (state.removeAdsOn(now) >= rules.removeAdsPerDay) return false;
  final last = state.lastPopup;
  if (last != null && now.difference(last) < rules.minGap) return false;
  if (state.adsShown < rules.firstAfterAds) return false;
  final since = state.adsAtLastOffer;
  if (since == null) return true;
  return state.adsShown - since >= removeAdsGap(rules, state);
}
