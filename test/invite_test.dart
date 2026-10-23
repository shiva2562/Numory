// Settings › Invite friends: the invite card (the best to beat) and its text
// with every store link; golden test/goldens/invite_card.png.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numory/app.dart';
import 'package:numory/app_info.dart';
import 'package:numory/core/round.dart';
import 'package:numory/features/share/invite_card.dart';
import 'package:numory/theme.dart';

import 'helpers.dart';

Future<void> _loadFonts() async {
  for (final (family, file) in [('Orbitron', 'Orbitron.ttf'), ('Nunito', 'Nunito.ttf')]) {
    final bytes = File('assets/fonts/$file').readAsBytesSync();
    await (FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  }
}

void main() {
  test('the invite text: the best to beat and every store link', () {
    const best = (Mode.medium, Duration(milliseconds: 4560));
    expect(inviteText(best), startsWith('Come play $kAppName with me! My best on Medium is 4.56 s. Can you beat it?\n'));
    expect(inviteText(null), startsWith('Come play $kAppName with me!'));
    for (final link in storeLinks) {
      expect(inviteText(best), contains(link));
      expect(inviteText(null), contains(link));
    }
  });

  test('the best to beat is the chosen mode\'s, else the first mode with one', () async {
    final rig = await TestRig.create();
    expect(bestToBeat(rig.profile), isNull);
    rig.profile.roundWon(Mode.hard, const Duration(milliseconds: 9000));
    expect(bestToBeat(rig.profile), (Mode.hard, const Duration(milliseconds: 9000)));
    rig.profile.roundWon(Mode.easy, const Duration(milliseconds: 1500));
    expect(bestToBeat(rig.profile), (Mode.easy, const Duration(milliseconds: 1500)), reason: 'easy is chosen');
    rig.profile.mode = Mode.hard;
    expect(bestToBeat(rig.profile), (Mode.hard, const Duration(milliseconds: 9000)));
  });

  testWidgets('Settings › Invite friends shares the card with the best to beat', (tester) async {
    phone(tester);
    final shared = <String>[];
    InviteCard? drawn;
    final rig = await TestRig.create(
      share: (png, text) async => shared.add(text),
      renderInvite: (card) async {
        drawn = card;
        return Uint8List(1);
      },
    );
    rig.profile.roundWon(Mode.easy, const Duration(milliseconds: 2340));
    await tester.pumpWidget(NumoryApp(services: rig.services));
    await tester.pump();
    await tester.tap(find.byKey(const Key('settings')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.byKey(const Key('invite')));
    await tester.tap(find.byKey(const Key('invite')));
    await tester.pump(const Duration(milliseconds: 300));
    const best = (Mode.easy, Duration(milliseconds: 2340));
    expect(shared, [inviteText(best)]);
    expect(drawn?.best, best);
  });

  testWidgets('the invite card', (tester) async {
    await tester.runAsync(_loadFonts);
    tester.view
      ..physicalSize = const Size(360, 450)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const key = Key('card');
    await tester.pumpWidget(
      MaterialApp(
        theme: numoryTheme(),
        debugShowCheckedModeBanner: false,
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Material(
            child: InviteCard(key: key, best: (Mode.easy, Duration(milliseconds: 2340))),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await expectLater(find.byKey(key), matchesGoldenFile('goldens/invite_card.png'));
  });
}
