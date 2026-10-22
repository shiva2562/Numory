# Numory store screenshots (Google Play, 1080 × 1920 JPEG)

`android/01.jpg` … `04.jpg`, in upload order. The first three carry the pitch:

| # | Headline | Line | Screen |
|---|---|---|---|
| 1 | HOW FAST IS / YOUR MEMORY? | Memorise the numbers. Tap them in order. Beat the clock. | Medium board, numbers showing |
| 2 | TAP 1. / NOW REMEMBER. | The rest turn white. One wrong tap ends the round. | White tiles, sparks |
| 3 | RACE THE / WHOLE WORLD. | Easy, Medium and Hard each have a global leaderboard. | New best + world rank |
| 4 | 5, 9 OR 15 / NUMBERS. | Three modes. Seconds a round. The chimp test game. | Home on Hard |

- Screens are real app widgets (`source/`, from `test/store_screenshots_test.dart`); everything is code-drawn, no AI art. The rank on #3 comes from the test leaderboard.
- Rebuild: `flutter test --dart-define=GENERATE_STORE_SCREENSHOTS=true test/store_screenshots_test.dart`, then `tools/export_posters.sh`. Overview: `preview.png`.
- Play's AI-content labels: the icon and feature graphic are AI-generated (Codex); these screenshots are not.
