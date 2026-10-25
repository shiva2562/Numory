// The Remove Ads offers on the screens: the card after the 2nd interstitial,
// "Not now" backing off, buying, and the End card's No ads door. (The timing
// itself is tested in offers_test.dart.)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numory/app.dart';
import 'package:numory/services/config.dart';
import 'package:numory/services/offers.dart';
import 'package:shivapps_shell/shivapps_shell.dart';

import 'helpers.dart';

class _Sink implements AnalyticsSink {
  final events = <(String, Map<String, Object>)>[];
  @override
  Future<void> setEnabled(bool on) async {}
  @override
  Future<void> log(String name, Map<String, Object> params) async => events.add((name, params));

  List<Map<String, Object>> of(String name) => [for (final e in events) if (e.$1 == name) e.$2];
}

void main() {
  // Every round ends an interstitial's worth of rounds, at once.
  const everyRound = InterstitialRules(minLevel: 1, everyNLevels: 1, minSeconds: 0);

  Future<TestRig> start(WidgetTester tester, {String ageGroup = '18_plus', bool owned = false, int sessions = 2}) async {
    phone(tester);
    final rig = await TestRig.create(
      ageGroup: ageGroup,
      config: GameConfig({'offer_delay_ms': 0}),
      rules: everyRound,
    );
    rig.profile.data.sessions = sessions; // the launch counts itself: 2 becomes the 3rd session
    if (owned) await rig.services.store.buy(Products.removeAdsPackage);
    await tester.pumpWidget(NumoryApp(services: rig.services));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return rig;
  }

  /// Opens a round and taps 2 before 1: a lost round, so the end card shows.
  Future<void> loseRound(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('play')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('2'));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byKey(const Key('lose-title')), findsOneWidget);
  }

  /// A sheet needs a frame to start and a few more to finish sliding.
  Future<void> frames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> again(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('again')));
    await tester.pump(const Duration(milliseconds: 50));
    await frames(tester);
  }

  /// Taps 2 before 1 again: the round ends and the end card shows.
  Future<void> loseAgain(WidgetTester tester) async {
    await tester.tap(find.text('2'));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byKey(const Key('lose-title')), findsOneWidget);
  }

  OfferState saved(TestRig rig) => OfferState.fromJson(rig.profile.extra['offers']);

  late _Sink sink;
  setUp(() => sink = _Sink());
  tearDown(() => Analytics.instance.useForTests(null));

  testWidgets('the card comes after the 2nd interstitial, not the 1st; Not now is counted', (tester) async {
    final rig = await start(tester);
    Analytics.instance.useForTests(sink);
    await loseRound(tester);
    await again(tester); // interstitial 1
    expect(rig.ads.shows, 1);
    expect(find.byKey(const Key('remove-ads-offer')), findsNothing);
    await loseAgain(tester);
    await again(tester); // interstitial 2
    expect(rig.ads.shows, 2);
    expect(find.byKey(const Key('remove-ads-offer')), findsOneWidget);
    expect(find.text(r'$4.99'), findsOneWidget, reason: 'the store\'s own price');
    expect(
      sink.of('offer_shown').where((e) => e['place'] == 'after_ad'),
      [
        {'product': 'remove_ads', 'place': 'after_ad'},
      ],
    );
    await tester.tap(find.byKey(const Key('offer-later')));
    await frames(tester);
    expect(find.byKey(const Key('remove-ads-offer')), findsNothing);
    expect((saved(rig).adsShown, saved(rig).adsAtLastOffer, saved(rig).declines), (2, 2, 1));
    expect(rig.services.store.owns(Products.noAds), isFalse);
    // The next round is on screen once the card is closed.
    expect(find.byKey(const Key('clock')), findsOneWidget);
  });

  testWidgets('buying from the card: Buy and result are logged with the same place, and the offer ends', (tester) async {
    final rig = await start(tester);
    Analytics.instance.useForTests(sink);
    await loseRound(tester);
    await again(tester);
    await loseAgain(tester);
    await again(tester);
    await tester.tap(find.byKey(const Key('offer-buy')));
    await frames(tester);
    expect(rig.services.store.owns(Products.noAds), isTrue);
    expect(find.byKey(const Key('remove-ads-offer')), findsNothing);
    expect(sink.of('purchase_start'), [
      {'product': 'remove_ads', 'place': 'after_ad'},
    ]);
    expect(sink.of('purchase_result').single, {'product': 'remove_ads', 'place': 'after_ad', 'outcome': 'purchased'});
    expect(saved(rig).declines, 0, reason: 'buying is not a Not now');
    await tester.pump(const Duration(seconds: 4)); // the thank-you toast fades
  });

  testWidgets('the end card has a No ads button; it opens the card, and closing it is not a Not now', (tester) async {
    final rig = await start(tester);
    Analytics.instance.useForTests(sink);
    await loseRound(tester);
    expect(find.byKey(const Key('no-ads')), findsOneWidget);
    expect(sink.of('offer_shown'), [
      {'product': 'remove_ads', 'place': 'end_card'},
    ]);
    await tester.tap(find.byKey(const Key('no-ads')));
    await frames(tester);
    expect(find.byKey(const Key('remove-ads-offer')), findsOneWidget);
    expect(sink.of('offer_shown'), hasLength(1), reason: 'shown once: the button, not the card it opens');
    await tester.tap(find.byKey(const Key('offer-later')));
    await frames(tester);
    expect(find.byKey(const Key('remove-ads-offer')), findsNothing);
    expect(saved(rig).declines, 0);
    expect(saved(rig).popupsToday, 0, reason: 'the player asked for it: not a pop-up');
    await tester.tap(find.byKey(const Key('no-ads')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('offer-buy')));
    await frames(tester);
    expect(rig.services.store.owns(Products.noAds), isTrue);
    expect(sink.of('purchase_start').single['place'], 'end_card');
    expect(find.byKey(const Key('no-ads')), findsNothing, reason: 'gone once bought');
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('a player who owns Remove Ads sees no button and no card', (tester) async {
    final rig = await start(tester, owned: true);
    await loseRound(tester);
    expect(find.byKey(const Key('no-ads')), findsNothing);
    await again(tester);
    await loseAgain(tester);
    await again(tester);
    expect(find.byKey(const Key('remove-ads-offer')), findsNothing);
    expect(rig.ads.shows, 0, reason: 'no interstitials once bought');
  });

  testWidgets('an under-13 player sees no ads, no button and no card', (tester) async {
    await start(tester, ageGroup: 'under_13');
    await loseRound(tester);
    expect(find.byKey(const Key('no-ads')), findsNothing);
    await again(tester);
    await loseAgain(tester);
    await again(tester);
    expect(find.byKey(const Key('remove-ads-offer')), findsNothing);
  });

  testWidgets('never in the first session', (tester) async {
    final rig = await start(tester, sessions: 0); // this launch is session 1
    await loseRound(tester);
    await again(tester);
    await loseAgain(tester);
    await again(tester);
    expect(rig.profile.sessions, 1);
    expect(find.byKey(const Key('remove-ads-offer')), findsNothing);
    expect(rig.ads.shows, 0, reason: 'the shell shows no interstitial in the first session either');
  });
}
