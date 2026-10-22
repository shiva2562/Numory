/// One Numory round: numbers on a 5×8 grid, tapped from 1 upward from memory.
///
/// Pure Dart (no Flutter), so every rule is unit-tested. The clock is passed
/// in, so tests control time.
library;

import 'dart:math';

/// The three modes, each with its own leaderboard.
enum Mode {
  easy('easy', 'Easy', 5),
  medium('medium', 'Medium', 9),
  hard('hard', 'Hard', 15);

  const Mode(this.id, this.label, this.count);

  /// Stable key for saves and analytics. Never rename.
  final String id;
  final String label;

  /// How many numbers are on the board.
  final int count;

  static Mode fromId(Object? id) => values.firstWhere((m) => m.id == id, orElse: () => easy);
}

const kCols = 5;
const kRows = 8;
const kCells = kCols * kRows;

/// What a tap did.
enum TapResult {
  /// Empty or already cleared square: nothing happens.
  ignored,

  /// The right number; the round goes on.
  correct,

  /// The last number; the round is won.
  finished,

  /// A wrong number; the round is lost.
  wrong,
}

enum RoundState { playing, won, lost }

class Round {
  Round({required this.mode, required this.cells, required this.startedAt})
    : assert(cells.length == mode.count),
      assert(cells.toSet().length == cells.length);

  /// A round with [mode.count] numbers on distinct random squares.
  factory Round.random(Mode mode, {required DateTime start, Random? random}) {
    final r = random ?? Random.secure();
    final all = List<int>.generate(kCells, (i) => i)..shuffle(r);
    return Round(mode: mode, cells: all.sublist(0, mode.count), startedAt: start);
  }

  final Mode mode;

  /// cells[k] is the square (0..39, row-major) that holds number k + 1.
  final List<int> cells;
  /// When the numbers appeared (the clock starts here).
  final DateTime startedAt;

  /// The next number to tap (1-based).
  int next = 1;
  RoundState state = RoundState.playing;
  Duration? _elapsed;

  /// The number tapped by mistake, when lost.
  int? wrongNumber;

  /// After 1 is tapped the other numbers turn into blank tiles.
  bool get hidden => next > 1;

  /// The number on [cell], or null when the square is empty.
  int? numberAt(int cell) {
    final i = cells.indexOf(cell);
    return i < 0 ? null : i + 1;
  }

  bool isCleared(int number) => number < next;

  /// The square holding the number the player needs now.
  int get neededCell => cells[min(next, mode.count) - 1];

  Duration elapsed(DateTime now) => _elapsed ?? now.difference(startedAt);

  TapResult tap(int cell, DateTime now) {
    if (state != RoundState.playing) return TapResult.ignored;
    final n = numberAt(cell);
    if (n == null || isCleared(n)) return TapResult.ignored;
    if (n != next) {
      state = RoundState.lost;
      wrongNumber = n;
      _elapsed = now.difference(startedAt);
      return TapResult.wrong;
    }
    next++;
    if (next > mode.count) {
      state = RoundState.won;
      _elapsed = now.difference(startedAt);
      return TapResult.finished;
    }
    return TapResult.correct;
  }
}

/// Round to hundredths of a second, the way times are shown, saved and
/// submitted (leaderboards take whole milliseconds; we keep 10 ms steps).
int centis(Duration d) => (d.inMicroseconds / 10000).round();

String formatTime(Duration d) {
  final c = centis(d);
  return '${c ~/ 100}.${(c % 100).toString().padLeft(2, '0')}';
}
