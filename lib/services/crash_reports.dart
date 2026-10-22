/// Crash reports through Firebase Crashlytics, under the same rule as
/// analytics: release builds, players who chose 18+, outside the EEA, the UK
/// and Switzerland. AndroidManifest.xml and Info.plist keep collection off
/// until [CrashReports.decide] runs for this launch.
///
/// Native crashes are caught by the SDK itself. Flutter and Dart errors are
/// recorded here as non-fatal, since the app keeps running after them. Each
/// report carries the last analytics events (level, offer, purchase step) as
/// breadcrumbs.
library;

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shivapps_shell/shivapps_shell.dart';

abstract final class CrashReports {
  static bool _on = false;

  /// Routes Flutter and Dart errors here. Call once, before runApp.
  static void install() {
    if (!kReleaseMode) return;
    final present = FlutterError.onError;
    FlutterError.onError = (details) {
      present?.call(details);
      if (_on) _send(FirebaseCrashlytics.instance.recordFlutterError(details));
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      if (_on) _send(FirebaseCrashlytics.instance.recordError(error, stack));
      return true;
    };
    Analytics.instance.onEvent = (name, params) {
      if (_on) _send(FirebaseCrashlytics.instance.log(params.isEmpty ? name : '$name $params'));
    };
  }

  /// For this launch, once the age choice is known: on only when analytics
  /// is on. Switched off explicitly too, because the SDK remembers the last
  /// setting; reports kept while off are deleted.
  static Future<void> decide({required bool on}) async {
    if (!kReleaseMode || Firebase.apps.isEmpty) return;
    try {
      final crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setCrashlyticsCollectionEnabled(on);
      if (!on) await crashlytics.deleteUnsentReports();
      _on = on;
    } on Object catch (e) {
      debugPrint('Crash reports unavailable: $e');
    }
  }

  static void _send(Future<void> call) =>
      unawaited(call.catchError((Object e) => debugPrint('Crash report failed: $e')));
}
