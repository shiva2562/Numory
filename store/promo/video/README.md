# Promo video

A 28-second promo for Numory in two cuts from one edit: **16:9** for YouTube and the Play listing (`landscape/`) and **9:16** for Reels and Shorts (`portrait/`). It's built with [HyperFrames](https://github.com/heygen-com/hyperframes) (HTML + GSAP rendered by headless Chrome), like Updo's. The play screen is the game's own, rebuilt in HTML from `lib/features/play/play_screen.dart` and `lib/theme.dart` (same layout, colours, glows, fonts, rules, sparks and clock), and the soundtrack is written in code around the game's own sound effects.

```
npm install
python3 score.py   # the soundtrack -> assets/gen/soundtrack.wav (not committed)
npm run render     # -> ../renders/numory_promo_16x9.mp4 and numory_promo_9x16.mp4 (render.mjs)
```

Needs Node 22+, Python 3 with numpy, scipy and pyloudnorm, FFmpeg, and a Chromium for HyperFrames (`npx hyperframes browser ensure`, or point `HYPERFRAMES_BROWSER_PATH` at one). The rendered MP4s go to `store/promo/renders/`, which is git-ignored.

## The edit

120 BPM, so a beat is 0.5 s and a bar 2 s; every cut, tap and hit is on that grid. All the times live in `assets/edit.js`, which both the pictures (`assets/promo.js`) and the soundtrack (`score.py`) read, so a change there moves both.

| Time | Scene |
|---|---|
| 0.0 | A Medium board, the clock already running: **MEMORISE.** (on from the first frame, so it is the thumbnail). The viewer gets two seconds to try |
| 2.0 | The beat drops on the tap of 1: the rest turn white. **TAP 1. NOW REMEMBER.** 2 to 9 are tapped on sixteenths, each with the game's rising note and its sparks |
| 4.0 | The last tap: the 70-spark burst and the flash, 4.13 s. **BEAT THE CLOCK.** The NEW BEST card with a world rank |
| 6.0 | Title: the sun comes up over the grid and the NUMORY sign catches (the app's own flicker timings); REMEMBER · TAP IN ORDER · BEAT THE CLOCK, one per beat |
| 8.0 | A laser wipe into a Hard board. **ONE WRONG TAP...** Six good taps, then the wrong square at 10.5: red, the gold square that was needed, the shake and the red glitch. **...AND IT'S OVER.** The music tape-stops; OOPS at 11.2 (the app's 0.7 s); a riser |
| 12.0 | **5, 9 OR 15 NUMBERS.** Easy, Medium and Hard boards fill one number per sixteenth with the game's notes |
| 16.0 | **RACE THE WHOLE WORLD.** A wireframe globe; the rank counts down a step per sixteenth and lands on #458 at 18.0 |
| 20.0 | Lights out, then a neon chimp sign catches on a brick wall: **THE CHIMP TEST** |
| 22.0 | The chimp himself rises in front of it: **CAN YOU BEAT A CHIMP?** |
| 24.0 | End card: the home screen's sun and grid, the sign, **HOW FAST IS YOUR MEMORY?**, the call to action; the last hit at 26.0 |

## How it's made

| Step | Script | Output |
|---|---|---|
| Art | `art.py` | `assets/art/`: the two chimps from `art/promo/` (made with Codex's ChatGPT image generation, 2026-11-01; the neon sign's black turned into transparency) and the app icon from `art/app_icon_neon.png` |
| Fonts | `fonts.py` | `assets/fonts/`: the game's own Orbitron and Nunito (`assets/fonts/`, SIL OFL), subset to the characters used, variable weight kept |
| Soundtrack | `score.py` | `assets/gen/soundtrack.wav`: synthwave in A minor on the game's chords (Am, F, C, G), all synthesized, with `assets/audio/*.wav` (the rising note per number, start, wrong, best, tap) on the edit's cues. Mastered to -14 LUFS, peaks under -2 dBTP |
| Scenes | `assets/promo.js`, `assets/promo.css` | Every scene, transition and effect, for both formats (the layout branches on the aspect ratio). The board, its clock, the sparks (the app's counts, speeds and physics, in closed form), the synthwave floor and the globe are pure functions of time drawn by one ticker tween, so any frame renders the same on its own |
| Compositions | `landscape/index.html`, `portrait/index.html` | Each folder is a HyperFrames project; `assets` is a symlink to the shared `assets/` |

If you change on-screen text, re-run `fonts.py`. If you change a time, change it in `assets/edit.js` and re-run `score.py`.

## The call to action

The end card says "Coming soon to Google Play" (Numory isn't live yet). For launch, change it at render time without touching the code:

```
node render.mjs --suffix=_live -- --variables '{"cta":"Free on Google Play"}'
```

`render.mjs` renders each cut with `hyperframes render` (60 fps), then replaces its audio with the mastered `soundtrack.wav` as 256 kbps AAC. After changing only the music, `node render.mjs --mux-only` swaps the new soundtrack into the existing renders in seconds.

## Previewing and checking

```
cd landscape && npx hyperframes preview      # the HyperFrames studio
npx hyperframes snapshot . --at 2.6,10.6,22.4  # stills at given times
npx hyperframes lint .
```

## Honest bits

- The rounds are scripted, not screen recordings: the taps are placed on the beat, and the clock reads the real time of the round as shown (the Medium round reads 4.13 s because it is 4.13 s long, counting 0.13 s before the first frame).
- The world rank (#458) is illustrative, as on the store screenshots.
- Play's AI-content label: the two chimps are AI-generated (Codex / ChatGPT), like the icon.
