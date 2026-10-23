/// Player feedback, emailed to Shiva (Settings › Send feedback). Posted over
/// dart:io to his Google Apps Script relay (Stretchy Frog's
/// `tools/feedback-relay.gs`, one for all his apps; the app name goes in the
/// subject), which sends it from his own Gmail. (Web3Forms' free plan
/// refuses posts that don't come from a web page.)
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Sends one message (and the address to reply to, when the player gave
/// one); true once it was accepted. Tests use a fake.
typedef FeedbackSender = Future<bool> Function({required String message, String? replyTo});

/// Posts `{token, app, message, email, platform}` to the relay at [url]. An
/// Apps Script web app answers a POST with a redirect to its output, which
/// is followed to read `{"success": true}`.
FeedbackSender relayFeedbackSender({
  required Uri url,
  required String token,
  required String app,
  Duration timeout = const Duration(seconds: 20),
}) {
  return ({required message, replyTo}) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.postUrl(url).timeout(timeout);
      req.headers.contentType = ContentType.json;
      req.write(
        jsonEncode({
          'token': token,
          'app': app,
          'message': message,
          if (replyTo != null && replyTo.isNotEmpty) 'email': replyTo,
          'platform': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
        }),
      );
      var res = await req.close().timeout(timeout);
      final to = res.headers.value(HttpHeaders.locationHeader);
      // A POST's 302 isn't a redirect to dart:io (only 303 is); Apps Script sends 302.
      if (const {301, 302, 303, 307, 308}.contains(res.statusCode) && to != null) {
        await res.drain<void>();
        res = await (await client.getUrl(url.resolve(to)).timeout(timeout)).close().timeout(timeout);
      }
      final body = await res.transform(utf8.decoder).join().timeout(timeout);
      final ok = res.statusCode == 200 && (jsonDecode(body) as Map<String, dynamic>)['success'] == true;
      if (!ok) debugPrint('feedback: ${res.statusCode} $body');
      return ok;
    } on Object catch (e) {
      debugPrint('feedback: $e');
      return false;
    } finally {
      client.close();
    }
  };
}
