import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shivapps_shell/shivapps_shell.dart';

import 'core/round.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/age_screen.dart';
import 'features/play/play_screen.dart';
import 'features/settings/settings_sheet.dart';
import 'features/shop/remove_ads.dart';
import 'release_config.dart';
import 'services/crash_reports.dart';
import 'services/juice.dart';
import 'services/leaderboards.dart';
import 'services/save.dart';
import 'shell_setup.dart';
import 'theme.dart';

/// Everything the game needs, built once at start-up.
class AppServices {
  AppServices({
    required this.profile,
    this.juice,
    Store? store,
    AgePolicy? agePolicy,
    InterstitialFlow? interstitials,
    Leaderboards? leaderboards,
  }) {
    this.agePolicy = agePolicy ?? AgePolicy.forSave(profile);
    this.store = store ?? _defaultStore(profile);
    this.interstitials =
        interstitials ??
        InterstitialFlow(
          save: profile,
          rules: interstitialRules(profile.config),
          ads: AdMobInterstitialAds(units: kAdUnits, adsEligible: this.agePolicy.adEligibility),
          store: this.store,
        );
    this.leaderboards = leaderboards ?? _defaultLeaderboards();
  }

  final Profile profile;

  /// Sound and haptics; the app builds the real one when null.
  final Juice? juice;
  late final AgePolicy agePolicy;
  late final Store store;
  late final InterstitialFlow interstitials;
  late final Leaderboards leaderboards;

  /// RevenueCat; in debug builds without its key, a pretend store that "buys"
  /// instantly. Release builds without a key sell nothing.
  static Store _defaultStore(Profile profile) {
    final real = RevenueCatStore(
      owned: profile.entitlements,
      onChange: profile.setEntitlements,
      androidKey: revenueCatAndroidKey,
      iosKey: revenueCatIosKey,
    );
    if (real.available || kReleaseMode) return real;
    return FakeStore(owned: profile.entitlements, onChange: profile.setEntitlements);
  }

  /// Play Games; in debug builds without leaderboard IDs, a pretend one so
  /// the rank card can be seen.
  static Leaderboards _defaultLeaderboards() {
    final real = PlayGamesLeaderboards();
    if (real.available || kReleaseMode) return real;
    return FakeLeaderboards();
  }

  static Future<AppServices> load() async => AppServices(profile: Profile(store: await SaveStore.open()));
}

class NumoryApp extends StatefulWidget {
  const NumoryApp({super.key, this.services});

  /// Pre-built services (tests). Loaded from disk when null.
  final AppServices? services;

  @override
  State<NumoryApp> createState() => _NumoryAppState();
}

class _NumoryAppState extends State<NumoryApp> {
  AppServices? _services;

  @override
  void initState() {
    super.initState();
    _services = widget.services;
    if (_services == null) {
      unawaited(
        AppServices.load().then((s) {
          if (mounted) setState(() => _services = s);
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Numory',
    debugShowCheckedModeBanner: false,
    theme: numoryTheme(),
    home: _services == null ? const Scaffold(body: Backdrop(child: SizedBox.expand())) : _Root(services: _services!),
  );
}

class _Root extends StatefulWidget {
  const _Root({required this.services});
  final AppServices services;

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  AppServices get s => widget.services;
  late final Juice juice =
      s.juice ?? Juice(soundOn: () => s.profile.sound, hapticsOn: () => s.profile.haptics);
  bool _networkStarted = false;

  @override
  void initState() {
    super.initState();
    s.profile.startSession();
    if (!s.agePolicy.needsSelection) _startNetworkServices();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(juice.preload()));
  }

  void _startNetworkServices() {
    if (_networkStarted) return;
    _networkStarted = true;
    unawaited(s.store.start());
    // Only players 13+ reach UMP or Mobile Ads; teens and undisclosed ages
    // get Google's teen treatment.
    final policy = s.agePolicy;
    if (policy.canServeAds) {
      AdMobCore.instance.teenTreatment = policy.teenTreatment;
      unawaited(AdMobCore.instance.consentInfo());
    }
    unawaited(
      Analytics.instance
          .start(
            adult: policy.group == AgeGroup.adult18Plus,
            consentNotRequired: AdMobCore.instance.consentNotRequired,
          )
          .then((_) => CrashReports.decide(on: Analytics.instance.enabled)),
    );
    unawaited(s.leaderboards.signIn());
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(s.interstitials.launched(inTutorial: false)));
  }

  /// The one-time Remove Ads offer, once enough rounds are played.
  Future<void> _afterRound(BuildContext context) async {
    final p = s.profile;
    if (p.rounds < p.config.firstOfferRound || p.hasFlag('offer_shown')) return;
    if (!s.store.available || !s.agePolicy.canServeAds || s.store.owns(Products.noAds)) return;
    p.setFlag('offer_shown');
    await showRemoveAdsOffer(context, s.store, juice: juice);
  }

  void _play(Mode mode) => unawaited(
    Navigator.of(context).push(
      // No slide-in: the clock starts with the first frame, so the board
      // must be fully on screen in that frame.
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => PlayScreen(
          mode: mode,
          profile: s.profile,
          leaderboards: s.leaderboards,
          juice: juice,
          interstitials: s.interstitials,
          afterRound: _afterRound,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (s.agePolicy.needsSelection) {
      return AgeScreen(
        policy: s.agePolicy,
        onComplete: () => setState(_startNetworkServices),
      );
    }
    return HomeScreen(
      profile: s.profile,
      leaderboards: s.leaderboards,
      juice: juice,
      onPlay: _play,
      onSettings: () => unawaited(
        showSettings(
          context,
          profile: s.profile,
          store: s.store,
          agePolicy: s.agePolicy,
          leaderboards: s.leaderboards,
          juice: juice,
        ),
      ),
    );
  }
}
