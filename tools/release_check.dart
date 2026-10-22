// Checks the store-specific setup that cannot be supplied by a CI build.
// Usage: dart run tools/release_check.dart [--platform android|ios|all]
import 'dart:io';

const publisher = 'pub-8110930605602997';
const googleTestPublisher = 'pub-3940256099942544';
const _adMobAppId = r'^ca-app-pub-\d{16}~\d{10}$';
const _adMobUnitId = r'^ca-app-pub-\d{16}/\d{10}$';
const _revenueCatKey = r'^(goog|appl)_[A-Za-z0-9]{20,}$';

final results = <(bool ok, String what, String fix)>[];

void check(bool ok, String what, String fix) => results.add((ok, what, fix));

String read(String path) =>
    File(path).existsSync() ? File(path).readAsStringSync() : '';

String? match(String text, RegExp re) => re.firstMatch(text)?.group(1);

String? platformFrom(List<String> args) {
  // Numory is Android only for now.
  if (args.isEmpty) return 'android';
  if (args.length == 1 && args.single.startsWith('--platform=')) {
    final platform = args.single.substring('--platform='.length);
    return {'android', 'ios', 'all'}.contains(platform) ? platform : null;
  }
  if (args.length == 2 && args.first == '--platform') {
    return {'android', 'ios', 'all'}.contains(args.last) ? args.last : null;
  }
  return null;
}

bool selected(String platform, String target) =>
    platform == 'all' || platform == target;

bool validAdMobAppId(String? id) =>
    id != null &&
    RegExp(_adMobAppId).hasMatch(id) &&
    id.startsWith('ca-app-$publisher~');

bool validAdMobUnitId(String? id) =>
    id != null &&
    RegExp(_adMobUnitId).hasMatch(id) &&
    id.startsWith('ca-app-$publisher/');

bool validRevenueCatKey(String? key, String prefix) =>
    key != null &&
    RegExp(_revenueCatKey).hasMatch(key) &&
    key.startsWith(prefix);

void checkAndroid(Map<String, String> config) {
  const manifestPath = 'android/app/src/main/AndroidManifest.xml';
  final manifest = read(manifestPath);
  final androidApp = match(
    manifest,
    RegExp(r'gms\.ads\.APPLICATION_ID"\s*android:value="([^"]+)"'),
  );
  check(
    !read('android/app/build.gradle.kts').contains('com.example') &&
        !manifest.contains('com.example'),
    'No com.example IDs in Android files',
    'Use com.shivapps.numory.',
  );
  check(
    validAdMobAppId(androidApp),
    'Android AdMob app ID is a real Numory ID (${androidApp ?? 'missing'})',
    'AdMob → Apps → Numory (Android) → App settings → App ID; paste it into $manifestPath.',
  );
  check(
    validAdMobUnitId(config['admobInterstitialAndroid']),
    'Android interstitial AdMob unit is a real Numory ID',
    'AdMob → Apps → Numory → Ad units; paste the interstitial ID into lib/release_config.dart.',
  );
  check(
    validRevenueCatKey(config['revenueCatAndroidKey'], 'goog_'),
    'RevenueCat Android key has the full goog_ format',
    'RevenueCat → Project settings → API keys → the Play Store app key (goog_…).',
  );
  check(
    !manifest.contains(googleTestPublisher),
    'Android manifest has no Google test AdMob app ID',
    'Replace the Google test app ID in $manifestPath.',
  );
  check(
    manifest.contains('android.permission.INTERNET'),
    'Android network permission is declared',
    'Add <uses-permission android:name="android.permission.INTERNET"/> to $manifestPath.',
  );
  check(
    read('android/app/proguard-rules.pro')
        .contains('-keep class * extends androidx.room.RoomDatabase { <init>(); }'),
    'R8 keeps the WorkManager database constructor (release launch crash)',
    'Restore the RoomDatabase keep rule in android/app/proguard-rules.pro.',
  );
  final gamesId = match(
    read('android/app/src/main/res/values/games.xml'),
    RegExp(r'name="game_services_project_id"[^>]*>([^<]*)<'),
  );
  check(
    RegExp(r'^\d{6,}$').hasMatch(gamesId ?? ''),
    'Play Games project ID is set (${gamesId?.isEmpty ?? true ? 'missing' : gamesId})',
    'Play Console → Play Games Services → Configuration → Project ID; paste it into res/values/games.xml.',
  );
  for (final mode in ['Easy', 'Medium', 'Hard']) {
    check(
      RegExp(r'^CgkI[\w-]+$').hasMatch(config['leaderboard${mode}Android'] ?? ''),
      '$mode leaderboard ID is set',
      'Play Games Services → Leaderboards → $mode → ID; paste it into lib/release_config.dart.',
    );
  }
  check(
    RegExp(r'^\d+$').hasMatch(config['minOldVersionCode'] ?? '') &&
        int.parse(config['minOldVersionCode']!) <
            int.parse(match(read('pubspec.yaml'), RegExp(r'^version:.*\+(\d+)$', multiLine: true)) ?? '0'),
    'Build number is above the old Numory\'s last version code',
    'Set minOldVersionCode in lib/release_config.dart from Play Console → App bundle explorer, and raise pubspec.yaml if needed.',
  );
  checkAndroidSigning();
}

void checkAndroidSigning() {
  final keyProps = read('android/key.properties');
  final properties = <String, String>{
    for (final key in ['storeFile', 'storePassword', 'keyAlias', 'keyPassword'])
      key:
          match(
            keyProps,
            RegExp('^${RegExp.escape(key)}=(.+)\\s*\$', multiLine: true),
          )?.trim() ??
          '',
  };
  final missing = properties.entries
      .where((entry) => entry.value.isEmpty)
      .map((entry) => entry.key)
      .toList();
  final storeFile = properties['storeFile']!;
  final file = storeFile.startsWith('/')
      ? File(storeFile)
      : File('android/app/$storeFile');
  check(
    missing.isEmpty && file.existsSync(),
    'Android upload key and signing properties are complete',
    missing.isNotEmpty
        ? 'Set ${missing.join(', ')} in android/key.properties (see RELEASE.md → Android upload key).'
        : 'The storeFile in android/key.properties does not exist: ${file.path}.',
  );
}

void checkIos(Map<String, String> config) {
  const infoPath = 'ios/Runner/Info.plist';
  final info = read(infoPath);
  final iosApp = match(
    info,
    RegExp(
      r'<key>GADApplicationIdentifier</key>\s*(?:<!--[\s\S]*?-->\s*)?<string>([^<]+)</string>',
    ),
  );
  check(
    !read('ios/Runner.xcodeproj/project.pbxproj').contains('com.example'),
    'No com.example IDs in iOS project',
    'Use com.shivapps.numory.',
  );
  check(
    validAdMobAppId(iosApp),
    'iOS AdMob app ID is a real Numory ID (${iosApp ?? 'missing'})',
    'AdMob → Apps → Numory (iOS) → App settings → App ID; paste it into $infoPath.',
  );
  check(
    validAdMobUnitId(config['admobRewardedIos']),
    'iOS rewarded AdMob unit is a real Numory ID',
    'AdMob → Apps → Numory → Ad units; paste the rewarded ID into lib/release_config.dart.',
  );
  check(
    validAdMobUnitId(config['admobInterstitialIos']),
    'iOS interstitial AdMob unit is a real Numory ID',
    'AdMob → Apps → Numory → Ad units; paste the interstitial ID into lib/release_config.dart.',
  );
  check(
    validRevenueCatKey(config['revenueCatIosKey'], 'appl_'),
    'RevenueCat iOS key has the full appl_ format',
    'RevenueCat → Project settings → API keys → the App Store app key (appl_…).',
  );
  check(
    !info.contains(googleTestPublisher),
    'iOS Info.plist has no Google test AdMob app ID',
    'Replace the Google test app ID in $infoPath.',
  );
  check(
    RegExp(r'^\d+$').hasMatch(config['appStoreId'] ?? ''),
    'iOS App Store ID is set',
    'App Store Connect → App Information → Apple ID; set appStoreId in lib/release_config.dart.',
  );
}

void main(List<String> args) {
  final platform = platformFrom(args);
  if (platform == null) {
    stderr.writeln(
      'Usage: dart run tools/release_check.dart [--platform android|ios|all]',
    );
    exitCode = 64;
    return;
  }

  final config = {
    for (final m in RegExp(
      r"const (\w+) = '([^']*)';",
    ).allMatches(read('lib/release_config.dart')))
      m.group(1)!: m.group(2)!,
  };
  if (selected(platform, 'android')) checkAndroid(config);
  if (selected(platform, 'ios')) checkIos(config);

  check(
    (config['privacyPolicyUrl'] ?? '').startsWith('https://'),
    'Privacy policy URL is set',
    'Host legal/privacy.html and paste its https URL into lib/release_config.dart.',
  );
  final version = match(
    read('pubspec.yaml'),
    RegExp(r'^version:\s*(\d+\.\d+\.\d+\+\d+)$', multiLine: true),
  );
  check(
    version != null,
    'App version has a production version and build number',
    'Set pubspec.yaml version to MAJOR.MINOR.PATCH+BUILD, for example 1.0.0+1.',
  );

  stdout.writeln(
    'Numory $platform release check · version ${version ?? 'invalid'}\n',
  );
  for (final (ok, what, fix) in results) {
    stdout.writeln('${ok ? '✅' : '❌'} $what');
    if (!ok) stdout.writeln('     → $fix');
  }
  final missing = results.where((r) => !r.$1).length;
  stdout.writeln(
    missing == 0
        ? '\nStatic $platform release configuration passed. Store validation and device testing remain.'
        : '\n$missing item(s) to fix before a $platform store build.',
  );
  exitCode = missing == 0 ? 0 : 1;
}
