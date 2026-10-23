import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numory/app.dart';
import 'package:numory/features/share/invite_card.dart';
import 'package:numory/services/config.dart';
import 'package:numory/services/feedback.dart';
import 'package:numory/services/juice.dart';
import 'package:numory/services/leaderboards.dart';
import 'package:numory/services/music.dart';
import 'package:numory/services/save.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shivapps_shell/shivapps_shell.dart';

class FakeInterstitialAds implements InterstitialAds {
  int shows = 0;
  @override
  Future<void> gatherConsent() async {}
  @override
  Future<void> preload() async {}
  @override
  Future<bool> show() async {
    shows++;
    return true;
  }
}

class TestRig {
  TestRig._(this.services, this.ads, this.sounds, this.boards, this.musicPlayer);
  final AppServices services;
  final FakeInterstitialAds ads;
  final RecordingBackend sounds;
  final FakeLeaderboards boards;
  final FakeMusicPlayer musicPlayer;

  Profile get profile => services.profile;

  static Future<TestRig> create({
    Map<String, Object> prefs = const {},
    String? ageGroup = '18_plus',
    FakeLeaderboards? boards,
    GameConfig? config,
    FeedbackSender? feedback,
    Future<void> Function()? requestReview,
    Sharer? share,
    Future<Uint8List> Function(InviteCard card)? renderInvite,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final profile = Profile(store: await SaveStore.open(), config: config);
    if (ageGroup != null) profile.extra['age_group'] = ageGroup;
    final ads = FakeInterstitialAds();
    final sounds = RecordingBackend();
    final b = boards ?? FakeLeaderboards();
    final store = FakeStore(owned: profile.entitlements, onChange: profile.setEntitlements);
    final musicPlayer = FakeMusicPlayer();
    final services = AppServices(
      profile: profile,
      juice: Juice(sound: sounds, haptics: sounds, soundOn: () => profile.sound, hapticsOn: () => profile.haptics),
      store: store,
      interstitials: InterstitialFlow(
        save: profile,
        rules: const InterstitialRules(minLevel: 10, everyNLevels: 3, minSeconds: 180),
        ads: ads,
        store: store,
      ),
      leaderboards: b,
      music: Music(profile: profile, player: musicPlayer),
      requestReview: requestReview ?? () async {},
      // Never the real relay in tests.
      feedback: feedback ?? ({required message, replyTo}) async => true,
      share: share ?? (png, text) async {},
      renderInvite: renderInvite ?? (card) async => Uint8List(0),
    );
    return TestRig._(services, ads, sounds, b, musicPlayer);
  }
}

/// A phone-sized screen (412 x 915 dp) for the rest of the test.
void phone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1236, 2745)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}
