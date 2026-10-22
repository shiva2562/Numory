/// Firebase for Numory: none yet. Analytics and crash reports stay off until
/// Numory has its own app in the shivapps-games project (FORK.md step 7).
library;

import 'package:firebase_core/firebase_core.dart';

abstract final class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform => null;
}
