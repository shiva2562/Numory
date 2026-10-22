# Numory decisions

## 2026-10-22 — Rewrite on the shell's services, not a map fork
- The original Numory source and upload key were lost. Play still signs releases, so the upload key was reset (new key `android/numory-upload.jks`, git-ignored; back it up outside this Mac).
- Copied from Rani at `2ca80c4` for the Android project, release guards (`proguard-rules.pro`, `keep.xml`, `tools/release_check.dart`, `tools/release_smoke.dart`) and the age gate. Everything map, level, hint, daily, tutorial and Flame related was deleted. Services come from `shivapps_shell` (ads, consent, age policy, interstitial rules, purchases, analytics hook, sound).
- **Shiva chose Classic** over the prototype's Calm mode: a timer from the first frame and one wrong tap ends the round. This breaks the shell's "no timers, no fail state" rule on purpose: the speed run is the game.
- Taps on empty or already-cleared squares do nothing (Shiva).
- Modes Easy 5 / Medium 9 / Hard 15 on the original 5×8 board.
- **Leaderboards: Google Play Games Services**, one all-time board per mode. No backend, free, rank built in. Android only; move to Supabase only if an iOS version needs one shared board. Daily board deferred: no users at launch (Shiva).
- Rank shown as "#N in the world"; Play Games doesn't give the board size, so no percentile.
- Times are kept and submitted in 10 ms steps; anything under `min_valid_seconds_<mode>` stays off the board.
- Revenue: interstitials between rounds (shell rules with rounds as levels: from round 10, one per 3 rounds and 180 s, never in the first session) plus `remove_ads` one-time. No rewarded videos: nothing fair to reward without breaking the leaderboard. Nothing that changes a time is ever sold.
- No Play reviewer codes in v1: Remove Ads gates no content.
- No Firebase until Numory has its own app in `shivapps-games` (checkpoint). `firebase_options.dart` returns null, so analytics and crash reports stay off.
- The play screen opens with no transition, and the clock starts on the first drawn frame, so the player never loses time to an animation.
- Version starts at `2.0.0+100`, assumed above the old app's last version code. Confirm in Play Console (App bundle explorer) before the first upload.
- Privacy policy: the shared page https://shiva2562.github.io/privacy.html (Shiva, 2026-10-23). No Firebase in v1 (Shiva).
