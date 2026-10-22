import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:numory/core/round.dart';

void main() {
  final t0 = DateTime(2026, 10, 22, 12);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  Round round(Mode mode, List<int> cells) => Round(mode: mode, cells: cells, startedAt: t0);

  test('modes have 5, 9 and 15 numbers', () {
    expect([for (final m in Mode.values) m.count], [5, 9, 15]);
    expect(Mode.fromId('hard'), Mode.hard);
    expect(Mode.fromId('nonsense'), Mode.easy);
  });

  test('random rounds use distinct squares on the 5x8 board', () {
    for (var seed = 0; seed < 300; seed++) {
      for (final m in Mode.values) {
        final r = Round.random(m, start: t0, random: Random(seed));
        expect(r.cells.length, m.count);
        expect(r.cells.toSet().length, m.count);
        expect(r.cells.every((c) => c >= 0 && c < kCells), isTrue);
      }
    }
  });

  test('tapping in order wins, and the clock counts from the start', () {
    final r = round(Mode.easy, [0, 7, 13, 22, 39]);
    expect(r.hidden, isFalse);
    expect(r.tap(0, at(400)), TapResult.correct);
    expect(r.hidden, isTrue);
    expect(r.tap(7, at(600)), TapResult.correct);
    expect(r.tap(13, at(800)), TapResult.correct);
    expect(r.tap(22, at(1000)), TapResult.correct);
    expect(r.tap(39, at(1234)), TapResult.finished);
    expect(r.state, RoundState.won);
    expect(r.elapsed(at(9999)), const Duration(milliseconds: 1234));
  });

  test('empty and cleared squares do nothing', () {
    final r = round(Mode.easy, [0, 1, 2, 3, 4]);
    expect(r.tap(30, at(100)), TapResult.ignored);
    expect(r.tap(0, at(200)), TapResult.correct);
    expect(r.tap(0, at(300)), TapResult.ignored);
    expect(r.tap(35, at(300)), TapResult.ignored);
    expect(r.state, RoundState.playing);
    expect(r.next, 2);
  });

  test('a wrong number ends the round, also before 1', () {
    final r = round(Mode.easy, [0, 1, 2, 3, 4]);
    expect(r.tap(2, at(500)), TapResult.wrong);
    expect(r.state, RoundState.lost);
    expect(r.wrongNumber, 3);
    expect(r.neededCell, 0);
    expect(r.tap(0, at(600)), TapResult.ignored);

    final r2 = round(Mode.easy, [0, 1, 2, 3, 4]);
    r2.tap(0, at(100));
    expect(r2.tap(4, at(200)), TapResult.wrong);
    expect(r2.wrongNumber, 5);
    expect(r2.neededCell, 1);
  });

  test('times round to hundredths', () {
    expect(formatTime(const Duration(milliseconds: 1234)), '1.23');
    expect(formatTime(const Duration(milliseconds: 1235)), '1.24');
    expect(formatTime(const Duration(milliseconds: 9)), '0.01');
    expect(formatTime(const Duration(seconds: 61, milliseconds: 50)), '61.05');
    expect(centis(const Duration(milliseconds: 2099)), 210);
  });
}
