# GOAL: Rebuild "Numory", a number-memory speed game, on the shared shell services

> Store name: **Numory - Brain Training App** today (chosen at the checkpoint; a "Chimp Test" keyword is on the table). Keep the name in one constant (`kAppName`).
> Package: **`com.shivapps.numory`**, an existing Play app (removed May 2024 for a missing Data safety form). The original source was lost; this is a rewrite. Releases are signed by Play; the upload key was reset on 2026-10-22 (`android/numory-upload.jks`, git-ignored).
> `reference/prototype.html` is the approved playable prototype (Classic version). Match its rules and feel.
> This repo started as a copy of Rani for its Android setup, release guards and tools. **It is not a map game.** It uses `shivapps_shell` (ads, consent, age policy, interstitial rules, purchases, reviewer codes, sound) and its own small screens.

## How to work on this goal

- One milestone at a time. After each: `flutter analyze` (zero issues), `flutter test` (all green), one commit named `N<n>: <title>`.
- At a 🛑 checkpoint, stop and list exactly what is needed. Never invent ad unit IDs, product IDs, leaderboard IDs or legal text. Never reuse another game's live IDs.
- Never edit the other games' repos.
- Every tunable number lives in `lib/services/config.dart`.

## Product in one paragraph

A fast memory game. Numbers appear on a grid, the clock starts at once, the player taps 1 (the rest turn white) and then the rest in order from memory. Lowest time wins. Three modes with their own all-time global leaderboards. It's Shiva's fun project: revenue is ads between rounds plus one Remove Ads purchase. **This game breaks the shell's "no timers, no fail state" rule on purpose**: the timer and the one-mistake rule are the game (see DECISIONS.md).

## Rules (exact)

- Board: 5 columns × 8 rows. Modes: **Easy 5**, **Medium 9**, **Hard 15** numbers, placed on distinct random squares (`Random.secure`, not seeded: there is no daily in v1).
- The clock starts the moment the numbers appear (memorising counts) and stops on the last correct tap. Time shown and stored to 0.01 s.
- Tapping **1** turns every other number into a blank white tile.
- Tapping the next number clears it. Tapping an empty or already-cleared square **does nothing**. Tapping any other number ends the round (the wrong tile flashes red, the needed one shows in gold).
- Before tapping 1, tapping a different number also ends the round (it's a wrong number).
- A finished round: new personal best per mode saved locally, score submitted to that mode's leaderboard.
- Anti-cheat floor: a finished time below `min_valid_seconds_<mode>` is shown but never submitted.

## Leaderboards (Google Play Games Services v2)

- One all-time leaderboard per mode, IDs in `release_config.dart` (empty until Shiva creates them in Play Console → Play Games Services). Scores are submitted in milliseconds, lower is better.
- After a round: the player's all-time rank and "faster than X%" when Play Games can tell us; otherwise only the time.
- Home has a Leaderboards button per mode that opens Play Games' own leaderboard screen.
- Sign-in is Play Games' silent automatic sign-in. If the player isn't signed in, rounds still work; scores aren't submitted; the leaderboard button offers to sign in.
- Weekly and daily boards come for free from Play Games; the UI only uses all-time in v1.

## Look

Black board, dark grey empty squares, white tiles, dusk-purple background, the NUMORY wordmark. Close to the prototype. Fonts: Orbitron (display) and Nunito (body), both SIL OFL, bundled.

## Juice

| Moment | Visual | Sound | Haptic |
|---|---|---|---|
| Numbers appear | board fades in, clock turns on | soft start ping | light |
| Correct tap | tile pops green and clears | rising note per number | selection |
| Wrong tap | red tile shakes, needed one in gold | low buzz | heavy |
| Round done | big time, rank card slides up | rising chord | medium |
| New best | "NEW BEST" in gold | chord + sparkle | double |

## Ads and purchases

- Interstitials: through the shell's `InterstitialFlow`, counting finished or failed rounds as "levels". Not in the first session, from round 10, at most one per 3 rounds and per 180 s, never with Remove Ads, under-13: none.
- One product: `remove_ads` (RevenueCat, `$rc_lifetime` package), $2.99. Nothing that changes a time is ever sold.
- No rewarded videos in v1.

## Onboarding

Age gate (shell, unchanged), then home. The first round shows one line: "Remember them. Tap 1, then the rest in order."

## Milestones

### N0 — Fork and strip
- Rename to numory everywhere, reset IDs to placeholders, delete map/puzzle/hint/daily code and tests. Analyze clean, tests green, debug build runs.
### N1 — Core round
- Pure-Dart round logic and timer; tests for every rule above.
### N2 — Screens
- Home (mode picker, Play, best per mode, Leaderboards, Settings), play screen, result card, settings (sound, haptics, Remove Ads, restore, privacy, age), age gate. Widget tests.
### N3 — Leaderboards and ads
- Play Games wrapper with a fake for tests and debug; interstitial flow; Remove Ads.
- 🛑 CHECKPOINT: install on Shiva's phone. Needed: Play Games Services project linked to the app + 3 leaderboard IDs, AdMob app + interstitial unit, RevenueCat project + `remove_ads` product, Firebase app, privacy policy (shared page?), last uploaded version code of the old app.
### N4 — Release prep (skill RELEASE.md)
- Live IDs, reviewer code, screenshots, listing, Data safety form answers, `release_check` green, release smoke test, `RELEASE.md`. Shiva uploads.

## Out of scope for v1
Daily board, weekly boards in the UI, Calm mode, hints, levels, accounts, cloud save, iOS.
