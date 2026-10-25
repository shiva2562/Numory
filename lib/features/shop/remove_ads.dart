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

/// The Remove Ads card: what goes away, the store's own price, **Remove ads**
/// and one plain **Not now**. No timer, no guilt. [place] is where it came
/// from (`OfferPlace`), for analytics; [logShown] is false when the screen
/// that opened it already logged the show (the end card's button). True once
/// the player has bought; false for Not now, a swipe away or a failed buy.
Future<bool> showRemoveAdsOffer(
  BuildContext context,
  Store store, {
  required String place,
  bool logShown = true,
  Juice? juice,
}) async {
  if (logShown) Analytics.instance.offerShown('remove_ads', place);
  final bought = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: ListenableBuilder(
          listenable: store,
          builder: (sheet, _) {
            final price = store.price(Products.removeAdsPackage);
            return Column(
              key: const Key('remove-ads-offer'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF12061F),
                    border: Border.all(color: kMagenta, width: 2),
                    boxShadow: boxGlow(kMagenta, strength: 0.7),
                  ),
                  child: Icon(Icons.block_rounded, color: kText, size: 32, shadows: glow(kMagenta, strength: 0.6)),
                ),
                const SizedBox(height: 16),
                Text(
                  'NO MORE ADS',
                  textAlign: TextAlign.center,
                  style: display(size: 22, spacing: 2, glowColor: kMagenta, glowStrength: 0.6),
                ),
                const SizedBox(height: 8),
                Text(
                  'Play without the ads between rounds.\nOne purchase, yours for good.',
                  textAlign: TextAlign.center,
                  style: body(color: kMuted),
                ),
                if (price != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    price,
                    key: const Key('offer-price'),
                    style: display(size: 28, spacing: 1, color: kGold, glowColor: kGold, glowStrength: 0.6),
                  ),
                ],
                const SizedBox(height: 18),
                NeonButton(
                  key: const Key('offer-buy'),
                  label: 'Remove ads',
                  onPressed: () async {
                    juice?.tap();
                    if (await buyRemoveAds(sheet, store, place: place, juice: juice) && sheet.mounted) {
                      Navigator.of(sheet).pop(true);
                    }
                  },
                ),
                const SizedBox(height: 4),
                TextButton(
                  key: const Key('offer-later'),
                  onPressed: () => Navigator.of(sheet).pop(false),
                  child: Text('Not now', style: body(color: kMuted)),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
  return bought ?? false;
}

/// The small **No ads** button on the end card: a door to the same card, for
/// a player who sees ads. Quiet on purpose; it never moves or pulses.
class NoAdsButton extends StatelessWidget {
  const NoAdsButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'No ads',
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: kViolet.withValues(alpha: 0.7)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block_rounded, size: 14, color: kMuted),
              const SizedBox(width: 6),
              Text('No ads', style: body(size: 13, color: kMuted, weight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    ),
  );
}
