# Numory release state

IDs: `store/ids.md`. Play Console answers: `store/data-safety.md`. Listing draft: `store/listing.md`.

## 2.0.0 (100): first build of the rewrite, ready to upload
- Rebuilt 2026-10-25 with music, Send feedback, the invite card and the in-app review prompt. `release_check` all green; `flutter analyze` clean; 41 tests pass. (`release_smoke` last passed on the 2026-10-23 build on the Pixel 8 Pro emulator.)
- targetSdk 36, BILLING permission present, 16 KB page sizes: zipalign `-P 16` passes and every native library is 16 KB or 64 KB aligned.
- AAB: `build/app/outputs/bundle/release/app-release.aab`, 64.3 MB, SHA-256 `7a7829dd07a30ccbfa6a081d4d822607e4c7ef845dbd1692650b48926c255f4b`, signed with the new upload key (SHA-1 `82:D4:C5:D2…38:13`).
- **The new upload key is accepted from 2026-10-24 21:42 IST** (Play's upload key reset). Uploading earlier fails.

## Steps from here
0. Before the upload: add the two Send feedback rows (email address, other user-generated content) to Data safety (`store/data-safety.md`), and a feedback line to the shared privacy page.
1. After 2026-10-24 21:42 IST: Shiva uploads the AAB to **Internal testing** and installs it from the opt-in link on his phone.
2. On the phone: a round in each mode, Play Games sign-in from the result card, a leaderboard score, Share, Settings.
3. Create the one-time product `remove_ads` at US $2.99 (Play allows it once a billing build is uploaded); activate; check RevenueCat shows it; license-test purchase and restore.
4. **Publish Play Games Services** (Play Console → Play Games Services → Publishing). Until then only testers can sign in and see the leaderboards.
5. Store listing: text from `store/listing.md`, icon `store/icon-512.png`, feature graphic `store/feature_graphic.png`, phone screenshots `store/marketing/android/01–04.jpg` in that order.
6. Promote the tested build to **Production → Send for review**. Approval reinstates the app and clears the policy issues.
7. Once live: AdMob → Numory → add store link (lifts limited ad serving).
