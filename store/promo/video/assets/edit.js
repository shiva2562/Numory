// The edit: every time in the promo, in seconds, on a 120 BPM grid (a beat is 0.5 s, a bar 2 s, a sixteenth 0.125 s).
// Read by assets/promo.js (the pictures) and score.py (the soundtrack, which parses the JSON between the braces), so
// a tap, a hit or a cut sounds on the frame it shows. Cells are board squares, row * 5 + column, on the game's 5x8 board.
window.NUMORY_EDIT = {
  "bpm": 120,
  "duration": 28.0,
  "hook": {
    "mode": "Medium", "count": 9, "appear": 0.0, "clockOffset": 0.13, "bestBefore": "4.68",
    "cells": {"1": 8, "2": 23, "3": 6, "4": 3, "5": 31, "6": 22, "7": 37, "8": 24, "9": 11},
    "taps": [[1, 2.0], [2, 2.25], [3, 2.5], [4, 2.875], [5, 3.125], [6, 3.375], [7, 3.5], [8, 3.75], [9, 4.0]],
    "card": 4.375, "rank": 458
  },
  "fail": {
    "mode": "Hard", "count": 15, "appear": 8.0, "clockOffset": 0.0, "bestBefore": "6.90",
    "cells": {"1": 1, "2": 14, "3": 5, "4": 17, "5": 28, "6": 4, "7": 30, "8": 21, "9": 38, "10": 12, "11": 25, "12": 19, "13": 32, "14": 8, "15": 36},
    "taps": [[1, 9.0], [2, 9.25], [3, 9.5], [4, 9.75], [5, 10.0], [6, 10.25]],
    "wrong": [12, 10.5], "card": 11.2
  },
  "modes": {
    "step": 0.125,
    "boards": [
      {"mode": "Easy", "count": 5, "start": 12.0, "cells": {"1": 12, "2": 26, "3": 3, "4": 35, "5": 20}},
      {"mode": "Medium", "count": 9, "start": 13.0, "cells": {"1": 8, "2": 23, "3": 6, "4": 3, "5": 31, "6": 22, "7": 37, "8": 24, "9": 11}},
      {"mode": "Hard", "count": 15, "start": 14.0, "cells": {"1": 1, "2": 14, "3": 5, "4": 17, "5": 28, "6": 4, "7": 30, "8": 21, "9": 38, "10": 12, "11": 25, "12": 19, "13": 32, "14": 8, "15": 36}}
    ]
  },
  "rank": {"from": 9999, "to": 458, "start": 16.5, "land": 18.0, "ticks": 12},
  "cuts": {"title": 6.0, "fail": 8.0, "stop": 10.5, "modes": 12.0, "world": 16.0, "chimp": 20.0, "chimpDrop": 22.0, "end": 24.0, "final": 26.0}
};
