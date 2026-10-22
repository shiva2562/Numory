import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numory/app.dart';
import 'package:numory/core/round.dart';

import 'helpers.dart';

void main() {
  testWidgets('first launch asks the age group, then shows home', (tester) async {
    phone(tester);
    final rig = await TestRig.create(ageGroup: null);
    await tester.pumpWidget(NumoryApp(services: rig.services));
    await tester.pump();
    expect(find.text('Which age group are you in?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('age-choice-18_plus')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('play')), findsOneWidget);
  });

  testWidgets('mode picker switches mode, count and best', (tester) async {
    phone(tester);
    final rig = await TestRig.create();
    rig.profile.roundWon(Mode.hard, const Duration(milliseconds: 7820));
    await tester.pumpWidget(NumoryApp(services: rig.services));
    await tester.pump();
    expect(find.text('5 numbers'), findsOneWidget);
    expect(find.text('No best yet'), findsOneWidget);
    await tester.tap(find.byKey(const Key('mode-hard')));
    await tester.pump();
    expect(find.text('15 numbers'), findsOneWidget);
    expect(find.text('Best 7.82 s'), findsOneWidget);
    expect(rig.profile.mode, Mode.hard);
    await tester.tap(find.byKey(const Key('leaderboard')));
    await tester.pump();
    expect(rig.boards.shown, [Mode.hard]);
  });

  testWidgets('Play opens a round in the chosen mode', (tester) async {
    phone(tester);
    final rig = await TestRig.create();
    rig.profile.mode = Mode.medium;
    await tester.pumpWidget(NumoryApp(services: rig.services));
    await tester.pump();
    await tester.tap(find.byKey(const Key('play')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Medium · 9'), findsOneWidget);
    for (var k = 1; k <= 9; k++) {
      expect(find.text('$k'), findsOneWidget);
    }
  });

  testWidgets('settings has sound, vibration and Remove Ads', (tester) async {
    phone(tester);
    final rig = await TestRig.create();
    await tester.pumpWidget(NumoryApp(services: rig.services));
    await tester.pump();
    await tester.tap(find.byKey(const Key('settings')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('settings-remove-ads')), findsOneWidget);
    await tester.tap(find.byKey(const Key('sound')));
    await tester.pump();
    expect(rig.profile.sound, isFalse);
  });
}
