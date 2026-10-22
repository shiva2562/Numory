# Numory release state

IDs: `store/ids.md`. Play Console answers: `store/data-safety.md`. Listing draft: `store/listing.md`.

## 2.0.0 (100): first build of the rewrite, ready to upload
- Built 2026-10-23. `release_check` all green; `flutter analyze` clean; 18 tests pass; `release_smoke` passed on the Pixel 8 Pro emulator (release APK opened and stayed up; age gate and home checked by hand).
- targetSdk 36, BILLING permission present, 16 KB page sizes: zipalign `-P 16` passes and every native library is 16 KB or 64 KB aligned.
- AAB: `build/app/outputs/bundle/release/app-release.aab`, 58.5 MB, SHA-256 `1d3f04cdc788119516e03a7c92940bfd2b3a33d9d1b59e97055a0a2cf5751bf3`, signed with the new upload key (SHA-1 `82:D4:C5:D2…38:13`).
- **The new upload key is accepted from 2026-10-24 21:42 IST** (Play's upload key reset). Uploading earlier fails.

## Steps from here
1. After 2026-10-24 21:42 IST: Shiva uploads the AAB to **Internal testing** and installs it from the opt-in link on his phone.
2. On the phone: a round in each mode, Play Games sign-in from the result card, a leaderboard score, Share, Settings.
3. Create the one-time product `remove_ads` at US $2.99 (Play allows it once a billing build is uploaded); activate; check RevenueCat shows it; license-test purchase and restore.
4. **Publish Play Games Services** (Play Console → Play Games Services → Publishing). Until then only testers can sign in and see the leaderboards.
5. Store listing: text from `store/listing.md`, icon `store/icon-512.png`, feature graphic `store/feature_graphic.png`, 4+ new screenshots.
6. Promote the tested build to **Production → Send for review**. Approval reinstates the app and clears the policy issues.
7. Once live: AdMob → Numory → add store link (lifts limited ad serving).
