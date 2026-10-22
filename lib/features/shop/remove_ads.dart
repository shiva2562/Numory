import 'package:flutter/material.dart';
import 'package:shivapps_shell/shivapps_shell.dart';

import '../../services/juice.dart';
import '../../theme.dart';
import '../common/toast.dart';

/// Buys Remove Ads and says how it went. True once ads are gone. [place] is
/// where the player tapped Buy, for analytics.
Future<bool> buyRemoveAds(BuildContext context, Store store, {String place = 'settings', Juice? juice}) async {
  Analytics.instance.purchaseStart('remove_ads', place);
  final outcome = await store.buy(Products.removeAdsPackage);
  Analytics.instance.purchaseResult('remove_ads', place, outcome);
  if (!context.mounted) return false;
  switch (outcome) {
    case PurchaseOutcome.purchased:
      juice?.done(newBest: true);
      showToast(context, 'Ads removed. Thank you!', icon: Icons.favorite_rounded);
      return true;
    case PurchaseOutcome.cancelled:
      return false;
    case PurchaseOutcome.failed:
      showToast(context, 'The store didn’t answer. Please try again.');
      return false;
    case PurchaseOutcome.unavailable:
      showToast(context, 'The store isn’t available right now.');
      return false;
  }
}

/// Restores earlier purchases and says what came back.
Future<void> restorePurchases(BuildContext context, Store store) async {
  final any = await store.restore();
  Analytics.instance.restore('settings', found: any);
  if (!context.mounted) return;
  showToast(context, any ? 'Purchases restored' : 'No purchases to restore', icon: any ? Icons.check_rounded : null);
}

/// The one-time offer, after `first_offer_round` rounds.
Future<void> showRemoveAdsOffer(BuildContext context, Store store, {Juice? juice}) {
  Analytics.instance.offerShown('remove_ads', 'offer');
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: ListenableBuilder(
          listenable: store,
          builder: (sheet, _) {
            final price = store.price(Products.removeAdsPackage);
            return Column(
              key: const Key('remove-ads-offer'),
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.block_rounded, color: kGold, size: 44),
                const SizedBox(height: 12),
                Text('Play without interruptions', textAlign: TextAlign.center, style: body(size: 22, weight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(
                  'Remove the ads between rounds, once and for all.',
                  textAlign: TextAlign.center,
                  style: body(color: kMuted),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    key: const Key('offer-buy'),
                    style: FilledButton.styleFrom(
                      backgroundColor: kTile,
                      foregroundColor: kInk,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      textStyle: body(size: 17, weight: FontWeight.w900),
                    ),
                    onPressed: () async {
                      juice?.tap();
                      if (await buyRemoveAds(sheet, store, place: 'offer', juice: juice) && sheet.mounted) {
                        Navigator.of(sheet).pop();
                      }
                    },
                    child: Text(price == null ? 'Remove ads' : 'Remove ads · $price'),
                  ),
                ),
                TextButton(
                  key: const Key('offer-later'),
                  onPressed: () => Navigator.of(sheet).pop(),
                  child: Text('Not now', style: body(color: kMuted)),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
