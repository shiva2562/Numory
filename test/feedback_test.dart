// Settings › Send feedback: the relay post (against a local server), the
// form (send, a failed send, no sender without a URL), and the store's own
// rating prompt after a new best (from the 5th round, once in 90 days, and
// only while the result card is still showing).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numory/app.dart';
import 'package:numory/core/round.dart';
import 'package:numory/features/play/play_screen.dart';
import 'package:numory/services/config.dart';
import 'package:numory/services/feedback.dart';
import 'package:numory/theme.dart';

import 'helpers.dart';

void main() {
  group('relayFeedbackSender', () {
    late HttpServer server;
    final bodies = <Map<String, dynamic>>[];
    var reply = (200, '{"success": true}');
    var redirect = false;
    // The widget-test binding answers every request with 400: real HTTP here.
    final mocked = HttpOverrides.current;
    setUpAll(() => HttpOverrides.global = null);
    tearDownAll(() => HttpOverrides.global = mocked);
    setUp(() async {
      bodies.clear();
      reply = (200, '{"success": true}');
      redirect = false;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        if (req.method == 'POST') {
          bodies.add(jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, dynamic>);
          if (redirect) {
            // An Apps Script web app: the output is one redirect away.
            req.response
              ..statusCode = 302
              ..headers.set(HttpHeaders.locationHeader, '/echo');
            await req.response.close();
            return;
          }
        }
        req.response
          ..statusCode = reply.$1
          ..write(reply.$2);
        await req.response.close();
      });
    });
    tearDown(() => server.close(force: true));

    FeedbackSender sender() =>
        relayFeedbackSender(url: Uri.parse('http://127.0.0.1:${server.port}/exec'), token: 't', app: 'Numory');

    test('posts the token, the app, the message and the reply-to', () async {
      expect(await sender()(message: 'Love it', replyTo: 'a@b.c'), isTrue);
      final b = bodies.single;
      expect((b['token'], b['app'], b['message'], b['email']), ('t', 'Numory', 'Love it', 'a@b.c'));
      expect(b['platform'], contains(Platform.operatingSystem));
      expect(await sender()(message: 'No reply'), isTrue);
      expect(bodies.last.containsKey('email'), isFalse);
    });

    test('follows the Apps Script redirect to read the answer', () async {
      redirect = true;
      expect(await sender()(message: 'via redirect'), isTrue);
      reply = (200, '{"success": false}');
      expect(await sender()(message: 'refused'), isFalse);
    });

    test('a refusal, an unreadable answer or no server is a failed send', () async {
      reply = (403, '{"success": false}');
      expect(await sender()(message: 'x'), isFalse);
      reply = (200, 'not json');
      expect(await sender()(message: 'x'), isFalse);
      final down = relayFeedbackSender(
        url: Uri.parse('http://127.0.0.1:1/exec'),
        token: 't',
        app: 'a',
        timeout: const Duration(seconds: 2),
      );
      expect(await down(message: 'x'), isFalse);
    });
  });

  group('the form', () {
    Future<List<(String, String?)>> open(WidgetTester tester, {required bool works}) async {
      phone(tester);
      final sent = <(String, String?)>[];
      final rig = await TestRig.create(
        feedback: ({required message, replyTo}) async {
          sent.add((message, replyTo));
          return works;
        },
      );
      await tester.pumpWidget(NumoryApp(services: rig.services));
      await tester.pump();
      await tester.tap(find.byKey(const Key('settings')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.ensureVisible(find.byKey(const Key('feedback')));
      await tester.tap(find.byKey(const Key('feedback')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      return sent;
    }

    testWidgets('sends the message and the email, thanks, and closes', (tester) async {
      final sent = await open(tester, works: true);
      expect(find.byKey(const Key('feedback-message')), findsOneWidget);
      await tester.tap(find.byKey(const Key('feedback-send')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(sent, isEmpty, reason: 'nothing to send yet');
      await tester.enterText(find.byKey(const Key('feedback-message')), '  The neon is great  ');
      await tester.enterText(find.byKey(const Key('feedback-email')), 'me@x.com');
      await tester.pump();
      await tester.tap(find.byKey(const Key('feedback-send')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(sent, [('The neon is great', 'me@x.com')]);
      expect(find.text('Thanks! Your message is on its way.'), findsOneWidget);
      expect(find.byKey(const Key('feedback-message')), findsNothing);
      await tester.pump(const Duration(seconds: 4)); // the toast fades
    });

    testWidgets('a failed send keeps the text and says so', (tester) async {
      final sent = await open(tester, works: false);
      await tester.enterText(find.byKey(const Key('feedback-message')), 'Bug report');
      await tester.pump();
      await tester.tap(find.byKey(const Key('feedback-send')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(sent, hasLength(1));
      expect(find.byKey(const Key('feedback-error')), findsOneWidget);
      expect(find.text('Bug report'), findsOneWidget);
    });

    test('no relay URL, no sender (and no Send feedback row)', () {
      expect(AppServices.relayFor(''), isNull);
      expect(AppServices.relayFor('https://example.com/exec'), isNotNull);
    });
  });

  group('the rating prompt', () {
    test('a new best asks from the 5th round, then not again for 90 days', () async {
      var asked = 0;
      final rig = await TestRig.create(
        config: GameConfig({'review_delay_s': 0.0}),
        requestReview: () async => asked++,
      );
      final s = rig.services;
      final t0 = DateTime(2026, 10, 24, 12);
      rig.profile.data.rounds = 4;
      await s.newBest(now: t0);
      expect(asked, 0, reason: 'only 4 rounds');
      rig.profile.data.rounds = 5;
      await s.newBest(now: t0);
      expect(asked, 1);
      await s.newBest(now: t0.add(const Duration(days: 89)));
      expect(asked, 1);
      await s.newBest(now: t0.add(const Duration(days: 90)));
      expect(asked, 2);
    });

    test('a player who already left the result card is not asked, and the 90 days do not start', () async {
      var asked = 0;
      final rig = await TestRig.create(
        config: GameConfig({'review_delay_s': 0.0}),
        requestReview: () async => asked++,
      );
      rig.profile.data.rounds = 9;
      await rig.services.newBest(stillOnCard: () => false);
      expect(asked, 0);
      expect(rig.profile.extra.containsKey('review_asked_at'), isFalse);
      await rig.services.newBest(stillOnCard: () => true);
      expect(asked, 1);
    });

    testWidgets('a new best on the result card asks the app; a loss or a repeat does not', (tester) async {
      phone(tester);
      final rig = await TestRig.create();
      final asks = <bool>[];
      var clock = DateTime(2026, 10, 24, 12);
      await tester.pumpWidget(
        MaterialApp(
          theme: numoryTheme(),
          home: PlayScreen(
            mode: Mode.easy,
            profile: rig.profile,
            leaderboards: rig.services.leaderboards,
            juice: rig.services.juice,
            now: () => clock,
            random: Random(7),
            onNewBest: ({stillOnCard}) async => asks.add(stillOnCard!()),
          ),
        ),
      );
      await tester.pump();
      final cells = Round.random(Mode.easy, start: clock, random: Random(7)).cells;
      for (final c in cells) {
        clock = clock.add(const Duration(milliseconds: 300));
        await tester.tapAt(tester.getCenter(find.byKey(Key('cell-$c'))));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('NEW BEST'), findsOneWidget);
      expect(asks, [true], reason: 'asked once, while the card was showing');
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
