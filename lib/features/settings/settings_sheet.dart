import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shivapps_shell/shivapps_shell.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_info.dart';
import '../../release_config.dart';
import '../../services/juice.dart';
import '../../services/leaderboards.dart';
import '../../services/save.dart';
import '../../theme.dart';
import '../shop/remove_ads.dart';

Future<void> showSettings(
  BuildContext context, {
  required Profile profile,
  required Store store,
  required AgePolicy agePolicy,
  required Leaderboards leaderboards,
  Juice? juice,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (sheet) => SafeArea(
    child: ListenableBuilder(
      listenable: Listenable.merge([profile, store, leaderboards]),
      builder: (sheet, _) {
        final noAds = store.owns(Products.noAds);
        final canBuy = store.available && agePolicy.canServeAds && !noAds;
        return SingleChildScrollView(
          key: const Key('settings-sheet'),
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('Settings', style: body(size: 22, weight: FontWeight.w900)),
              ),
              SwitchListTile(
                key: const Key('sound'),
                title: const Text('Sound'),
                value: profile.sound,
                onChanged: (v) => profile.sound = v,
              ),
              SwitchListTile(
                key: const Key('haptics'),
                title: const Text('Vibration'),
                value: profile.haptics,
                onChanged: (v) => profile.haptics = v,
              ),
              if (leaderboards.available)
                ListTile(
                  key: const Key('play-games'),
                  leading: const Icon(Icons.sports_esports_rounded),
                  title: Text(leaderboards.signedIn ? 'Signed in to Play Games' : 'Sign in to Play Games'),
                  subtitle: const Text('Your times go to the global leaderboards.'),
                  onTap: leaderboards.signedIn ? null : () => unawaited(leaderboards.signIn(interactive: true)),
                ),
              if (canBuy)
                ListTile(
                  key: const Key('settings-remove-ads'),
                  leading: const Icon(Icons.block_rounded),
                  title: Text(
                    store.price(Products.removeAdsPackage) == null
                        ? 'Remove ads'
                        : 'Remove ads · ${store.price(Products.removeAdsPackage)}',
                  ),
                  onTap: () => unawaited(buyRemoveAds(sheet, store, juice: juice)),
                ),
              if (noAds)
                const ListTile(leading: Icon(Icons.favorite_rounded, color: kGold), title: Text('Ads removed. Thank you!')),
              if (store.available)
                ListTile(
                  key: const Key('restore'),
                  leading: const Icon(Icons.restore_rounded),
                  title: const Text('Restore purchases'),
                  onTap: () => unawaited(restorePurchases(sheet, store)),
                ),
              if (agePolicy.canServeAds)
                FutureBuilder<bool>(
                  future: AdMobCore.instance.privacyOptionsRequired(),
                  builder: (_, snap) => snap.data == true
                      ? ListTile(
                          leading: const Icon(Icons.privacy_tip_outlined),
                          title: const Text('Ad privacy choices'),
                          onTap: () => unawaited(AdMobCore.instance.showPrivacyOptions()),
                        )
                      : const SizedBox.shrink(),
                ),
              ListTile(
                key: const Key('more-games'),
                leading: const Icon(Icons.grid_view_rounded),
                title: const Text('More games'),
                onTap: () => unawaited(openMoreGames(sheet, parentalGate: !agePolicy.canServeAds)),
              ),
              if (privacyPolicyUrl.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Privacy policy'),
                  onTap: () => unawaited(launchUrl(Uri.parse(privacyPolicyUrl), mode: LaunchMode.externalApplication)),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  '$kAppName · age group: ${agePolicy.group?.label ?? 'not set'}',
                  style: body(size: 12, color: kMuted),
                ),
              ),
            ],
          ),
        );
      },
    ),
  ),
);

/// Settings › More games: the shell's sheet of the other games. [parentalGate]
/// for players under 13 or who have not said.
Future<void> openMoreGames(BuildContext context, {bool parentalGate = true}) {
  Analytics.instance.moreGamesShown();
  return showMoreGames(
    context,
    bundleId: kBundleId,
    fromId: kPromoId,
    parentalGate: parentalGate,
    style: MoreGamesStyle(titleStyle: body(size: 22, weight: FontWeight.w900)),
    onOpen: (game) => Analytics.instance.moreGamesOpen(game.id),
  );
}
