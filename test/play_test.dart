import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numory/core/round.dart';
import 'package:numory/features/play/play_screen.dart';
import 'package:numory/services/leaderboards.dart';
import 'package:numory/theme.dart';

import 'helpers.dart';

void main() {
  late TestRig rig;
  late DateTime clock;

  Future<List<int>> open(WidgetTester tester, Mode mode, {int seed = 7, FakeLeaderboards? boards}) async {
    rig = await TestRig.create(boards: boards);
    clock = DateTime(2026, 10, 22, 12);
    await tester.pumpWidget(
      MaterialApp(
        theme: numoryTheme(),
        home: PlayScreen(
          mode: mode,
          profile: rig.profile,
          leaderboards: rig.services.leaderboards,
          juice: rig.services.juice,
          interstitials: rig.services.interstitials,
          now: () => clock,
          random: Random(seed),
        ),
      ),
    );
    await tester.pump();
    return Round.random(mode, start: clock, random: Random(seed)).cells;
  }

  Future<void> tapCell(WidgetTester tester, int cell, {int afterMs = 150}) async {
    clock = clock.add(Duration(milliseconds: afterMs));
    await tester.tapAt(tester.getCenter(find.byKey(Key('cell-$cell'))));
    await tester.pump();
  }

  testWidgets('numbers show at once and hide after 1', (tester) async {
    phone(tester);
    final cells = await open(tester, Mode.easy);
    for (var k = 0; k < 5; k++) {
      expect(find.descendant(of: find.byKey(Key('cell-${cells[k]}')), matching: find.text('${k + 1}')), findsOneWidget);
    }
    expect(find.text('Remember them. Tap 1, then the rest in order.'), findsOneWidget);
    expect(rig.sounds.calls, contains('sound:start.wav'));
    await tapCell(tester, cells[0]);
    expect(find.text('2'), findsNothing);
    expect(find.text('Next: 2'), findsOneWidget);
  });

  testWidgets('empty squares do nothing; in order wins with time, best and rank', (tester) async {
    phone(tester);
    final cells = await open(tester, Mode.easy);
    final empty = List.generate(kCells, (i) => i).firstWhere((c) => !cells.contains(c));
    await tapCell(tester, empty);
    expect(find.byKey(const Key('lose-title')), findsNothing);
    for (final c in cells) {
      await tapCell(tester, c, afterMs: 200);
    }
    // 6 taps of 150-200 ms after the numbers appeared.
    expect(find.text('NEW BEST'), findsOneWidget);
    expect(find.text('1.15 s'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('rank')), findsOneWidget);
    expect(rig.profile.best(Mode.easy), const Duration(milliseconds: 1150));
    expect(rig.boards.bests[Mode.easy], const Duration(milliseconds: 1150));
    expect(rig.sounds.calls, containsAllInOrder(['sound:note_01.wav', 'sound:note_05.wav', 'sound:best.wav']));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a wrong number loses and shows the needed one', (tester) async {
    phone(tester);
    final cells = await open(tester, Mode.medium);
    await tapCell(tester, cells[0]);
    await tapCell(tester, cells[2]);
    expect(rig.sounds.calls, contains('sound:wrong.wav'));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('OOPS'), findsOneWidget);
    expect(rig.profile.rounds, 1);
    expect(rig.profile.best(Mode.medium), isNull);
    await tester.tap(find.byKey(const Key('again')));
    await tester.pump();
    await tester.pump();
    expect(find.text('OOPS'), findsNothing);
    expect(find.byKey(const Key('clock')), findsOneWidget);
  });

  testWidgets('impossible times stay off the leaderboard', (tester) async {
    phone(tester);
    final cells = await open(tester, Mode.easy);
    for (final c in cells) {
      await tapCell(tester, c, afterMs: 20);
    }
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('Too fast'), findsOneWidget);
    expect(rig.boards.bests, isEmpty);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('not signed in: the card offers Play Games sign-in, then ranks', (tester) async {
    phone(tester);
    final cells = await open(tester, Mode.easy, boards: FakeLeaderboards(signedIn: false));
    for (final c in cells) {
      await tapCell(tester, c, afterMs: 300);
    }
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('rank-sign-in')), findsOneWidget);
    await tester.tap(find.byKey(const Key('rank-sign-in')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('rank')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('hidden game activity: score sent, the card links to the board instead of a rank', (tester) async {
    phone(tester);
    final boards = FakeLeaderboards(rankHidden: true);
    final cells = await open(tester, Mode.easy, boards: boards);
    for (final c in cells) {
      await tapCell(tester, c, afterMs: 300);
    }
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('rank')), findsNothing);
    expect(find.textContaining('Couldn’t reach'), findsNothing);
    expect(boards.bests, contains(Mode.easy));
    await tester.tap(find.byKey(const Key('rank-hidden')));
    expect(boards.shown, [Mode.easy]);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('no leaderboard IDs: no rank card at all', (tester) async {
    phone(tester);
    final cells = await open(tester, Mode.easy, boards: FakeLeaderboards(available: false));
    for (final c in cells) {
      await tapCell(tester, c, afterMs: 300);
    }
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('rank')), findsNothing);
    expect(find.byKey(const Key('rank-sign-in')), findsNothing);
    expect(find.text('NEW BEST'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
}
