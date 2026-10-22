// Store screenshot captures: real app widgets, bundled fonts, no network.
// Opt-in, so normal test runs skip it:
//   flutter test --dart-define=GENERATE_STORE_SCREENSHOTS=true test/store_screenshots_test.dart
// Writes store/marketing/source/*.png (1080 x 2340); store/marketing/posters.html
// frames them into the upload-ready posters.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numory/app.dart';
import 'package:numory/core/round.dart';
import 'package:numory/features/play/play_screen.dart';
import 'package:numory/services/leaderboards.dart';
import 'package:numory/theme.dart';

import 'helpers.dart';

const _generate = bool.fromEnvironment('GENERATE_STORE_SCREENSHOTS');
const _out = 'store/marketing/source';

Future<void> _loadFonts() async {
  for (final (family, file) in [('Orbitron', 'Orbitron.ttf'), ('Nunito', 'Nunito.ttf')]) {
    final bytes = File('assets/fonts/$file').readAsBytesSync();
    await (FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  }
  final icons = File('${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)))).load();
  }
}

void _phone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1080, 2340)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('capture')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_out).createSync(recursive: true);
    File('$_out/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(_loadFonts);

  Widget wrap(Widget child) => RepaintBoundary(
    key: const Key('capture'),
    child: MaterialApp(debugShowCheckedModeBanner: false, theme: numoryTheme(), home: child),
  );

  Future<(TestRig, PlayScreen, List<int>)> round(WidgetTester tester, Mode mode, {int seed = 11}) async {
    final rig = await TestRig.create(boards: FakeLeaderboards());
    rig.profile.setFlag('played');
    rig.profile.roundWon(mode, Duration(milliseconds: mode.count * 520));
    var clock = DateTime(2026, 10, 24, 12);
    final screen = PlayScreen(
      mode: mode,
      profile: rig.profile,
      leaderboards: rig.boards,
      juice: rig.services.juice,
      now: () => clock = clock.add(const Duration(milliseconds: 230)),
      random: Random(seed),
    );
    return (rig, screen, Round.random(mode, start: clock, random: Random(seed)).cells);
  }

  Future<void> tap(WidgetTester tester, int cell) async {
    await tester.tapAt(tester.getCenter(find.byKey(Key('cell-$cell'))));
    await tester.pump(const Duration(milliseconds: 16));
  }

  testWidgets('store screenshots', skip: !_generate, (tester) async {
    _phone(tester);

    // 1. Numbers on the board, clock running.
    var (_, screen, cells) = await round(tester, Mode.medium);
    await tester.pumpWidget(wrap(screen));
    await tester.pump(const Duration(milliseconds: 600));
    await _capture(tester, 'numbers');

    // 2. 1 and 2 tapped: the rest are white tiles, sparks flying from 3.
    await tap(tester, cells[0]);
    await tap(tester, cells[1]);
    await tap(tester, cells[2]);
    await tester.pump(const Duration(milliseconds: 170));
    await _capture(tester, 'tiles');

    // 3. A finished round: new best and a world rank.
    (_, screen, cells) = await round(tester, Mode.hard, seed: 4);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(wrap(screen));
    await tester.pump();
    for (final c in cells) {
      await tap(tester, c);
    }
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 100));
    await _capture(tester, 'result');

    // 4. Home on Hard, with a best time.
    final rig = await TestRig.create(boards: FakeLeaderboards());
    rig.profile.roundWon(Mode.hard, const Duration(milliseconds: 6420));
    rig.profile.mode = Mode.hard;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(RepaintBoundary(key: const Key('capture'), child: NumoryApp(services: rig.services)));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1000)));
    await tester.pump(const Duration(milliseconds: 1300));
    await _capture(tester, 'home');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
