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

## 2026-10-23 — Neon / synthwave look (Shiva: "go full neon")
- Palette: violet-black void, neon magenta, cyan, violet; green = finished, red = wrong, yellow = the number you needed / best.
- Home: animated synthwave floor and striped sun; the NUMORY sign flickers on, bobs, and one letter stutters each loop; chromatic magenta/cyan split.
- Round: the floor stands still (no repaint behind the board, nothing pulling the eye while memorising); neon board; sparks on every correct tap, a 70-spark burst and a flash on the last; wrong tap shakes the board with a red glitch; synthwave synth notes on a minor pentatonic (never a sour note).
- Cost: grid glow uses wide faint strokes, not blur; reduce-motion turns off the flicker, bob, floor, sparks and shake.
- Play Games: only a player's tap opens Play's sign-in UI; launch and after-round checks are silent (the plugin's signIn() is interactive and popped a Play dialog at launch).
- Board numbers in heavy Nunito, not Orbitron: Orbitron's 1/7 and 2/8 looked alike while memorising (Shiva, 2026-10-23). Orbitron stays on titles and the clock.
- Background music: one synthesized synthwave loop (`tools/make_music.py`, 40 s, Am-F-C-G at 96 BPM), quiet under the effects, own Music switch, stops while the app is hidden (Shiva, 2026-10-23).

## 2026-10-24 — Stretchy Frog shell fixes 18, 19, 22, 23 (SHELL-FIXES.md)
- **18, iPhone effect burst on return:** `GameViewController` (in `ios/Runner/SceneDelegate.swift`, set as the storyboard's root with `customModule="Runner"`) pauses any non-music `AVPlayer` whose rate changes without `.setRateCalled`, and pauses sounding effects on `willResignActive` / `didBecomeActive`. The loop is told apart from effects by its file name (`music.wav`, prefix `music`). Not verified on a device.
- **19, music ordering:** `Music` now sends one call at a time, each chosen from the wanted state (Music switch and app in sight), so a quick trip out of the app, a pause racing a load, or a failed call ends right. The old code skipped a call when the flag already matched, so a pause still on its way left the music off. Back in sight (show or resume) it asks to play again even if it was never paused. iOS: `setActive(true)` on `didBecomeActive`; an interruption that ends or arrives while active reactivates the session and calls `resume` on the `numory/audio` channel. The loop's `positionUpdater` is null (SHELL-FIXES 11).
- **20, touches near the left/right edge (kept, a judgement call):** Numory times a tap when it reaches the game, so iOS holding an edge-column tap back would cost the player time. `GameViewController` defers the system edge gestures and sets `delaysTouchesBegan = false`. Edge swipes need a second swipe; the game has none of its own. The Dart half of fix 20 (stamping late holds) does not apply: taps are instant. To drop it, delete those three lines.
- **21, countdown chip: not applicable.** Numory's home has no countdown and no `Wrap`.
- **22, Send feedback and rating:** Settings › Send feedback posts to Shiva's Apps Script relay (`feedbackRelayUrl` / `feedbackRelayToken` copied from Stretchy Frog; the app name goes in the subject; `lib/services/feedback.dart` follows the 302 by hand). The row hides while the URL is empty. Rating: `in_app_review`, with no question of ours before it, on a **new best from round 5, at most once every 90 days, 1.6 s after the result card shows** (`review_min_rounds`, `review_every_days`, `review_delay_s` in `config.dart`). Numory's next round starts at once on Play again, so the prompt is skipped, and the 90 days don't start, if the player has left that card by then. Tests default to a fake sender, so they never touch the real relay.
- **23, Invite friends:** Settings › Invite friends shares a 360x450 card (the NUMORY sign over the striped sun, a slice of the neon board with its numbers showing on the grid floor, the best to beat, store line) with text carrying every store link (`storeLinks` in `app_info.dart`; the App Store line appears once `appStoreId` is set). The best to beat is the chosen mode's, else the first mode that has one. Golden test: `test/goldens/invite_card.png` (not generated yet: run `flutter test --update-goldens test/invite_test.dart` and look at it; the layout is unverified).
