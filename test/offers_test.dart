// When the Remove Ads card may appear (lib/services/offers.dart): the pure
// timing function, tuned by the offer_* numbers in config.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:numory/services/config.dart';
import 'package:numory/services/offers.dart';

void main() {
  final rules = OfferRules.of(GameConfig());
  final noon = DateTime(2026, 10, 25, 12);

  /// The state after [ads] interstitials, other fields as given.
  OfferState state({int ads = 2, int? at, int declines = 0, DateTime? last, DateTime? on, int popups = 0, int cards = 0}) =>
      OfferState(
        adsShown: ads,
        adsAtLastOffer: at,
        declines: declines,
        lastPopup: last,
        day: on == null ? '' : OfferState.dayKey(on),
        popupsToday: popups,
        removeAdsToday: cards,
      );

  bool due(
    OfferState s, {
    DateTime? now,
    int session = 2,
    bool owned = false,
    bool seesAds = true,
    bool under13 = false,
    bool storeReady = true,
    OfferRules? r,
  }) => removeAdsAfterAdDue(
    rules: r ?? rules,
    state: s,
    now: now ?? noon,
    session: session,
    owned: owned,
    seesAds: seesAds,
    underThirteen: under13,
    storeReady: storeReady,
  );

  test('the numbers: after the 2nd ad, every 2nd, 2 cards and 3 pop-ups a day, 3 minutes apart', () {
    expect(rules.firstAfterAds, 2);
    expect(rules.everyAds, 2);
    expect(rules.removeAdsPerDay, 2);
    expect(rules.perDay, 3);
    expect(rules.minGap, const Duration(minutes: 3));
  });

  group('the first card', () {
    test('not after the 1st interstitial, yes after the 2nd', () {
      expect(due(state(ads: 0)), isFalse);
      expect(due(state(ads: 1)), isFalse);
      expect(due(state(ads: 2)), isTrue);
    });

    test('never in the first session', () {
      expect(due(state(ads: 2), session: 1), isFalse);
      expect(due(state(ads: 2), session: 2), isTrue);
    });

    test('a card held back (store not ready, day cap) comes at the next ad, not never', () {
      expect(due(state(ads: 2), storeReady: false), isFalse);
      expect(due(state(ads: 3)), isTrue);
    });
  });

  group('who never sees it', () {
    test('a player who owns Remove Ads (a purchase or a restore)', () => expect(due(state(), owned: true), isFalse));
    test('a player under 13', () => expect(due(state(), under13: true), isFalse));
    test('a player who sees no ads', () => expect(due(state(), seesAds: false), isFalse));
    test('while the store has no price to show', () => expect(due(state(), storeReady: false), isFalse));
  });

  group('then every 2nd interstitial', () {
    test('after a card at the 2nd, not the 3rd, yes the 4th', () {
      expect(due(state(ads: 3, at: 2)), isFalse);
      expect(due(state(ads: 4, at: 2)), isTrue);
      expect(due(state(ads: 5, at: 2)), isTrue, reason: 'a held-back card still comes');
    });

    test('a played-through sequence', () {
      final s = OfferState();
      final shown = <int>[];
      var now = noon;
      for (var ad = 1; ad <= 10; ad++) {
        s.adPlayed();
        now = now.add(const Duration(minutes: 4)); // interstitials are 3+ minutes apart
        if (due(s, now: now, r: OfferRules.of(GameConfig({'offer_remove_ads_per_day': 99, 'offer_per_day': 99})))) {
          s.removeAdsShown(now);
          shown.add(ad);
        }
      }
      expect(shown, [2, 4, 6, 8, 10]);
    });
  });

  group('"Not now" doubles the gap', () {
    test('every 2nd, then 4th, then 8th', () {
      expect([for (var d = 0; d < 4; d++) removeAdsGap(rules, state(declines: d))], [2, 4, 8, 16]);
      expect(due(state(ads: 5, at: 2, declines: 1)), isFalse);
      expect(due(state(ads: 6, at: 2, declines: 1)), isTrue);
      expect(due(state(ads: 9, at: 2, declines: 2)), isFalse);
      expect(due(state(ads: 10, at: 2, declines: 2)), isTrue);
    });

    test('stops doubling at offer_max_doublings', () {
      expect(removeAdsGap(rules, state(declines: 5)), 64);
      expect(removeAdsGap(rules, state(declines: 50)), 64);
    });

    test('a decline is counted by the state', () {
      final s = state()..removeAdsDeclined();
      expect(s.declines, 1);
    });
  });

  group('the day and the clock', () {
    test('at most 2 Remove Ads cards a day, and a new day starts again', () {
      final s = state(ads: 6, at: 4, on: noon, popups: 2, cards: 2, last: noon.subtract(const Duration(hours: 1)));
      expect(due(s), isFalse);
      expect(due(s, now: noon.add(const Duration(days: 1))), isTrue);
    });

    test('at most 3 pop-ups a day across all products', () {
      final s = state(ads: 6, at: 4, on: noon, popups: 3, cards: 1, last: noon.subtract(const Duration(hours: 1)));
      expect(due(s), isFalse);
      expect(due(state(ads: 6, at: 4, on: noon, popups: 2, cards: 1, last: noon.subtract(const Duration(hours: 1)))), isTrue);
    });

    test('at least 3 minutes after the last pop-up', () {
      final s = state(ads: 6, at: 4, on: noon, popups: 1, cards: 1, last: noon.subtract(const Duration(minutes: 3) - const Duration(seconds: 1)));
      expect(due(s), isFalse);
      expect(due(state(ads: 6, at: 4, on: noon, popups: 1, cards: 1, last: noon.subtract(const Duration(minutes: 3)))), isTrue);
    });

    test('showing a card counts it today, resets yesterday\'s counts and remembers the ad count', () {
      final s = state(ads: 4, at: 2, on: noon.subtract(const Duration(days: 1)), popups: 3, cards: 2);
      s.removeAdsShown(noon);
      expect((s.popupsOn(noon), s.removeAdsOn(noon), s.adsAtLastOffer, s.lastPopup), (1, 1, 4, noon));
      expect(s.popupsOn(noon.add(const Duration(days: 1))), 0);
    });
  });

  test('the state survives being saved and read back; junk reads as a fresh state', () {
    final s = state(ads: 7, at: 6, declines: 2, last: noon, on: noon, popups: 2, cards: 1);
    final back = OfferState.fromJson(s.toJson());
    expect(back.toJson(), s.toJson());
    expect(OfferState.fromJson(null).toJson(), OfferState().toJson());
    expect(OfferState.fromJson('nonsense').adsShown, 0);
  });
}
