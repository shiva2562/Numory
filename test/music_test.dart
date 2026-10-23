// The music against a player whose calls take time: one call at a time, and
// quick trips out of the app and back, the Music switch and a failing player
// all end in the right state. Then the app wiring: hiding the app pauses the
// music, showing it plays on, and iOS's audio interruption asks for it again.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numory/app.dart';
import 'package:numory/services/music.dart';
import 'package:numory/services/save.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// Each call waits until the test finishes it, like a real platform call.
class SlowPlayer implements MusicPlayer {
  final calls = <String>[];
  final _pending = <Completer<void>>[];
  var _inFlight = 0, maxInFlight = 0;

  /// What a real player would be doing after the calls finished so far.
  String state = 'idle';

  Future<void> _call(String name, String after) async {
    calls.add(name);
    maxInFlight = ++_inFlight > maxInFlight ? _inFlight : maxInFlight;
    final c = Completer<void>();
    _pending.add(c);
    await c.future;
    state = after;
    _inFlight--;
  }

  bool get busy => _pending.isNotEmpty;

  /// Finishes the oldest call and lets the music send its next one.
  Future<void> finish() async {
    _pending.removeAt(0).complete();
    await pumpEventQueue();
  }

  /// Finishes calls until none is waiting.
  Future<void> settle() async {
    await pumpEventQueue();
    while (busy) {
      await finish();
    }
  }

  @override
  Future<void> play() => _call('play', 'playing');

  @override
  Future<void> pause() => _call('pause', 'paused');
}

/// The first play fails, like a platform call that throws.
class FlakyPlayer extends FakeMusicPlayer {
  var _failed = false;

  @override
  Future<void> play() async {
    if (!_failed) {
      _failed = true;
      throw PlatformException(code: 'nope');
    }
    await super.play();
  }
}

void main() {
  late Profile profile;
  late SlowPlayer p;
  late Music m;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    profile = Profile(store: await SaveStore.open());
    p = SlowPlayer();
    m = Music(profile: profile, player: p);
  });

  test('plays only while the app is on screen: nothing before it is shown', () async {
    await p.settle();
    expect(p.calls, isEmpty);
    m.visible = true;
    await p.settle();
    expect(p.state, 'playing');
    m.visible = false;
    await p.settle();
    expect(p.state, 'paused');
    m.visible = true;
    await p.settle();
    expect(p.state, 'playing');
    expect(p.calls, ['play', 'pause', 'play']);
  });

  test('out and back before the pause finished: playing', () async {
    m.visible = true;
    await p.settle();
    m.visible = false;
    await pumpEventQueue();
    expect(p.calls.last, 'pause');
    m.visible = true; // back while the pause is still on its way
    await p.settle();
    expect(p.state, 'playing');
    expect(p.maxInFlight, 1, reason: 'one call at a time');
  });

  test('hidden while the loop is still loading: paused, not playing in the background', () async {
    m.visible = true;
    await pumpEventQueue();
    m.visible = false;
    await p.settle();
    expect(p.state, 'paused');
    m.visible = true;
    await p.settle();
    expect(p.state, 'playing');
    expect(p.maxInFlight, 1);
  });

  test('a burst of lifecycle changes ends where the last one says', () async {
    m.visible = true;
    await p.settle();
    // screen off then on: hidden, shown, hidden, shown, hidden in a row
    for (final v in [false, true, false, true, false]) {
      m.visible = v;
    }
    await p.settle();
    expect(p.state, 'paused');
    m.visible = true;
    await p.settle();
    expect(p.state, 'playing');
    expect(p.maxInFlight, 1);
  });

  test('back in sight asks again even if the system paused it unseen', () async {
    m.visible = true;
    await p.settle();
    p.state = 'paused'; // a phone call paused it; the app only went inactive
    m.visible = true;
    await p.settle();
    expect(p.state, 'playing');
  });

  test('the Music switch stops it, and coming back never plays with Music off', () async {
    m.visible = true;
    await p.settle();
    profile.music = false;
    await p.settle();
    expect(p.state, 'paused');
    m.visible = false;
    m.visible = true;
    await p.settle();
    expect(p.state, 'paused');
    profile.music = true;
    await p.settle();
    expect(p.state, 'playing');
  });

  test('a failed play is tried again the next time the app is shown', () async {
    final flaky = FlakyPlayer();
    final music = Music(profile: profile, player: flaky);
    music.visible = true;
    await pumpEventQueue();
    expect(flaky.playing, isFalse);
    music.visible = true;
    await pumpEventQueue();
    expect(flaky.playing, isTrue);
  });

  group('the app', () {
    Future<TestRig> start(WidgetTester tester) async {
      phone(tester);
      final rig = await TestRig.create();
      await tester.pumpWidget(NumoryApp(services: rig.services));
      await tester.pump();
      return rig;
    }

    testWidgets('pauses the music when hidden and plays it when back', (tester) async {
      final rig = await start(tester);
      expect(rig.musicPlayer.playing, isTrue);
      for (final st in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
        tester.binding.handleAppLifecycleStateChanged(st);
      }
      await tester.pump();
      expect(rig.musicPlayer.playing, isFalse);
      for (final st in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(st);
      }
      await tester.pump();
      expect(rig.musicPlayer.playing, isTrue);
    });

    testWidgets('iOS: an audio interruption while the game is in front plays the music on', (tester) async {
      final rig = await start(tester);
      Future<void> interrupted() => tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'numory/audio',
        const StandardMethodCodec().encodeMethodCall(const MethodCall('resume')),
        (_) {},
      );
      int plays() => rig.musicPlayer.calls.where((c) => c == 'play').length;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final before = plays();
      await interrupted();
      await tester.pump();
      expect(plays(), before + 1);
      // in the background the app's own return plays it on, not this
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      await interrupted();
      await tester.pump();
      expect((rig.services.music.visible, plays()), (false, before + 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  });
}
