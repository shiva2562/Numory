/// Creates a reusable Play-review license. Run with a restrictive umask.
/// Only the public key is printed; the signing seed and code stay in ignored files.
library;

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

Future<void> main() async {
  final algorithm = Ed25519();
  final keyFile = File('android/review-access-signing.json');
  final codeFile = File('store/play-review-access.txt');
  final SimpleKeyPair keyPair;
  if (await keyFile.exists()) {
    final saved =
        jsonDecode(await keyFile.readAsString()) as Map<String, dynamic>;
    keyPair = await algorithm.newKeyPairFromSeed(
      base64Url.decode(saved['seed'] as String),
    );
  } else {
    keyPair = await algorithm.newKeyPair();
    final data = await keyPair.extract();
    await keyFile.writeAsString(
      jsonEncode({'seed': base64UrlEncode(data.bytes)}),
    );
  }
  final publicKey = await keyPair.extractPublicKey();
  final payload = utf8.encode(
    jsonEncode({
      'v': 1,
      'app': 'com.shivapps.numory',
      'scope': 'Playreview',
      'entitlements': ['no_ads', 'solutions'],
    }),
  );
  final signature = await algorithm.sign(payload, keyPair: keyPair);
  if (!await algorithm.verify(payload, signature: signature)) {
    throw StateError('Review code verification failed');
  }
  String part(List<int> bytes) => base64UrlEncode(bytes).replaceAll('=', '');
  await codeFile.writeAsString(
    'zt1.${part(payload)}.${part(signature.bytes)}\n',
  );
  stdout.writeln('Public verification key: ${part(publicKey.bytes)}');
  stdout.writeln(
    'Private signing seed and review code saved to ignored local files.',
  );
}
