import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shivapps_shell/shivapps_shell.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/crash_reports.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(Analytics.instance.connect(DefaultFirebaseOptions.currentPlatform));
  CrashReports.install();
  runApp(const NumoryApp());
}
