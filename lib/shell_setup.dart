/// Numory's settings for the shared shell (package shivapps_shell): its IDs
/// from release_config.dart.
library;

import 'package:shivapps_shell/shivapps_shell.dart';

import 'app_info.dart';
import 'release_config.dart';
import 'services/config.dart';

/// Numory has no rewarded videos; their units stay empty.
const kAdUnits = AdUnits(
  rewardedAndroid: '',
  rewardedIos: '',
  interstitialAndroid: admobInterstitialAndroid,
  interstitialIos: admobInterstitialIos,
);

/// Checks Play reviewer codes signed for Numory.
ReviewAccessVerifier reviewVerifier() =>
    ReviewAccessVerifier(app: kBundleId, publicKey: reviewAccessCodePublicKey);

/// Rounds stand in for the shell's "map levels".
InterstitialRules interstitialRules(GameConfig config) => InterstitialRules(
  minLevel: config.interstitialMinRounds,
  everyNLevels: config.interstitialEveryNRounds,
  minSeconds: config.interstitialMinSeconds,
);
