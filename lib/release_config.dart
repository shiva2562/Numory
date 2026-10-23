/// Launch values. Paste the real ones here before a store build;
/// `dart run tools/release_check.dart` lists what is still missing.
///
/// None of these are secrets: ad unit IDs, RevenueCat's public SDK keys and
/// leaderboard IDs ship inside every app binary anyway.
library;

/// AdMob ad units (AdMob → Apps → Numory → Ad units). Release builds use
/// these; debug and profile builds always use Google's test units. The AdMob
/// *app* ID lives in AndroidManifest.xml. Numory has no rewarded videos.
const admobInterstitialAndroid = 'ca-app-pub-8110930605602997/9323557259';
const admobInterstitialIos = '';

/// RevenueCat public SDK keys (RevenueCat → Project settings → API keys).
/// Remove Ads hides while a key is empty.
const revenueCatAndroidKey = 'goog_pXhlTWyxXDJfntNgxnshnnhFFaj';
const revenueCatIosKey = '';

/// Play Games Services leaderboard IDs (Play Console → Numory → Play Games
/// Services → Leaderboards). Each: "Time" format, "Smaller is better".
/// Leaderboards hide while any is empty. The Play Games project ID goes in
/// android/app/src/main/res/values/games.xml.
const leaderboardEasyAndroid = 'CgkI-OHbuJMREAIQFQ';
const leaderboardMediumAndroid = 'CgkI-OHbuJMREAIQFg';
const leaderboardHardAndroid = 'CgkI-OHbuJMREAIQFw';

/// Shiva's feedback relay (Stretchy Frog's `tools/feedback-relay.gs`
/// deployed as a Google Apps Script web app, one for all his apps; the app
/// name goes in the subject): Settings › Send feedback posts here and it
/// emails him. The Send feedback row hides while empty.
const feedbackRelayUrl =
    'https://script.google.com/macros/s/AKfycbyuzcAbFAVDTL3C0BueyYhqCvhMoFydbnaoDK9bxq_gYvw0p8fFv3W4DtmH2g57GABdJQ/exec';

/// Sent with each message; the relay ignores posts without it. Not a
/// secret (it ships in the app), it only keeps stray posts out.
const feedbackRelayToken = 'ff71aff42ecedef938dc39ea';

/// The hosted privacy policy (Settings links to it; Play requires it).
const privacyPolicyUrl = 'https://shiva2562.github.io/privacy.html';

/// The last version code the old Numory (lost source) uploaded; every new
/// build must be above it. Read from Play Console → App bundle explorer.
const minOldVersionCode = '1';

/// No iOS release yet.
const appStoreId = '';

/// Base64url Ed25519 public key for signed Google Play reviewer access codes.
/// Empty disables review-code redemption (fails closed).
const reviewAccessCodePublicKey = '';
