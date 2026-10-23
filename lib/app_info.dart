import 'release_config.dart';

/// The game's name. Change it here and in Android's `android:label`.
const String kAppName = 'Numory';

/// The store identifier (an existing Play app since before the rewrite).
const String kBundleId = 'com.shivapps.numory';

/// The store link shared with results. `--dart-define=STORE_URL` replaces it.
String get storeLink {
  const override = String.fromEnvironment('STORE_URL');
  if (override.isNotEmpty) return override;
  return 'https://play.google.com/store/apps/details?id=$kBundleId';
}

/// Every store's link, for invites. `--dart-define=STORE_URL` replaces them.
List<String> get storeLinks {
  const override = String.fromEnvironment('STORE_URL');
  if (override.isNotEmpty) return [override];
  return [
    'Android: https://play.google.com/store/apps/details?id=$kBundleId',
    if (appStoreId.isNotEmpty) 'iPhone: https://apps.apple.com/app/id$appStoreId',
  ];
}
