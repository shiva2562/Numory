import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shivapps_shell/shivapps_shell.dart';

import 'app_info.dart';
import 'core/round.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/age_screen.dart';
import 'features/play/play_screen.dart';
import 'features/settings/feedback_sheet.dart';
import 'features/settings/settings_sheet.dart';
import 'features/share/invite_card.dart';
import 'features/shop/remove_ads.dart';
import 'release_config.dart';
import 'services/crash_reports.dart';
import 'services/feedback.dart';
import 'services/juice.dart';
import 'services/leaderboards.dart';
import 'services/music.dart';
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
    Music? music,
    Future<void> Function()? requestReview,
    Sharer? share,
    Future<Uint8List> Function(InviteCard card)? renderInvite,
    FeedbackSender? feedback,
  }) : requestReview = requestReview ?? _requestStoreReview,
       feedback = feedback ?? relayFor(feedbackRelayUrl),
       share = share ?? sharePng,
       renderInvite = renderInvite ?? renderInviteCard {
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
    this.music = music ?? Music(profile: profile);
  }

  final Profile profile;

  /// Sound and haptics; the app builds the real one when null.
  final Juice? juice;
  late final AgePolicy agePolicy;
  late final Store store;
  late final InterstitialFlow interstitials;
  late final Leaderboards leaderboards;
  late final Music music;

  /// Asks the store for a rating.
  final Future<void> Function() requestReview;

  /// Shares a picture and its text (the invite); tests record instead.
  final Sharer share;

  /// The invite card as a PNG.
  final Future<Uint8List> Function(InviteCard card) renderInvite;

  /// Emails a player's feedback to Shiva; null (no Send feedback row)
  /// until the relay's URL is set.
  final FeedbackSender? feedback;

  /// The relay at [url], or none while it is empty.
  static FeedbackSender? relayFor(String url) =>
      url.isEmpty ? null : relayFeedbackSender(url: Uri.parse(url), token: feedbackRelayToken, app: kAppName);

  /// The OS's own rating sheet (it decides whether to actually show it).
  static Future<void> _requestStoreReview() async {
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) await review.requestReview();
    } on Object catch (e) {
      debugPrint('Review prompt failed: $e');
    }
  }

  /// A round ended on a new best: the store's own rating prompt, from the
  /// `review_min_rounds`-th round and at most once every `review_every_days`,
  /// `review_delay_s` after the result card shows. No question of ours comes
  /// before it (Apple's 5.6.1 and Google's in-app review rules). [stillOnCard]
  /// says whether the player is still looking at that card: a sheet that
  /// came up over the next round would cost them time, so it is skipped
  /// (and the 90 days don't start).
  Future<void> newBest({DateTime? now, bool Function()? stillOnCard}) async {
    final c = profile.config, at = now ?? DateTime.now();
    if (profile.rounds < c.intOf('review_min_rounds')) return;
    final last = profile.extra['review_asked_at'];
    if (last is int && at.difference(DateTime.fromMillisecondsSinceEpoch(last)).inDays < c.intOf('review_every_days')) {
      return;
    }
    await Future<void>.delayed(Duration(milliseconds: (c.doubleOf('review_delay_s') * 1000).round()));
    if (stillOnCard != null && !stillOnCard()) return;
    profile.extra['review_asked_at'] = at.millisecondsSinceEpoch;
    await profile.save();
    await requestReview();
  }

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
  late final AppLifecycleListener _lifecycle;

  /// iOS: the audio session was interrupted while the game is in front, or
  /// an interruption ended (`GameViewController`).
  static const _audio = MethodChannel('numory/audio');

  @override
  void initState() {
    super.initState();
    s.music.visible = true;
    // The music pauses while the app is out of sight. Back in front, it
    // plays on (asked again at resumed, in case the system paused it).
    _lifecycle = AppLifecycleListener(
      onShow: () => s.music.visible = true,
      onHide: () => s.music.visible = false,
      onResume: () => s.music.visible = true,
    );
    _audio.setMethodCallHandler((call) async {
      if (call.method == 'resume' && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        s.music.visible = true;
      }
    });
    s.profile.startSession();
    if (!s.agePolicy.needsSelection) _startNetworkServices();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(juice.preload()));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _audio.setMethodCallHandler(null);
    super.dispose();
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
          onNewBest: s.newBest,
        ),
      ),
    ),
  );

  /// Settings › Send feedback.
  void _openFeedback() {
    final send = s.feedback;
    if (send == null) return;
    unawaited(showFeedbackSheet(context, send: send, juice: juice));
  }

  bool _inviting = false;

  /// Settings › Invite friends: the invite card (the best to beat) and its
  /// text with the store links.
  Future<void> _invite() async {
    if (_inviting) return;
    _inviting = true;
    juice.tap();
    try {
      final best = bestToBeat(s.profile);
      final png = await s.renderInvite(InviteCard(best: best));
      await s.share(png, inviteText(best));
    } on Object catch (e) {
      debugPrint('invite: $e');
    } finally {
      _inviting = false;
    }
  }

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
          onInvite: _invite,
          onFeedback: s.feedback == null ? null : _openFeedback,
        ),
      ),
    );
  }
}
