// Installs the release APK on a connected Android emulator or phone, opens it,
// and fails if the app crashes. R8 and resource shrinking only run in release
// builds, so debug runs and integration tests never see what they break (Play
// rejected ZipTrail build 5 for a launch crash that only release builds had).
// Run before every Play upload.
// Usage: dart run tools/release_smoke.dart [--no-build]
import 'dart:io';

const apk = 'build/app/outputs/flutter-apk/app-release.apk';
const _abiTargets = {
  'arm64-v8a': 'android-arm64',
  'armeabi-v7a': 'android-arm',
  'x86_64': 'android-x64',
};

String get adb {
  final sdk =
      Platform.environment['ANDROID_HOME'] ??
      '${Platform.environment['HOME']}/Library/Android/sdk';
  final path = '$sdk/platform-tools/adb';
  return File(path).existsSync() ? path : 'adb';
}

Never fail(String message) {
  stderr.writeln('❌ $message');
  exit(1);
}

Future<String> run(String exe, List<String> args) async {
  final result = await Process.run(exe, args);
  return '${result.stdout}${result.stderr}'.trim();
}

Future<String> shell(List<String> args) => run(adb, ['shell', ...args]);

Future<void> main(List<String> args) async {
  final package = RegExp(r'applicationId\s*=\s*"([^"]+)"')
      .firstMatch(File('android/app/build.gradle.kts').readAsStringSync())
      ?.group(1);
  if (package == null) {
    fail('No applicationId in android/app/build.gradle.kts.');
  }

  final devices = (await run(adb, [
    'devices',
  ])).split('\n').where((l) => l.endsWith('\tdevice')).toList();
  if (devices.length != 1) {
    fail(
      'Connect exactly one emulator or phone (found ${devices.length}). Check with: $adb devices',
    );
  }

  if (!args.contains('--no-build')) {
    final abi = await shell(['getprop', 'ro.product.cpu.abi']);
    final target = _abiTargets[abi] ?? fail('Unknown device ABI: $abi');
    stdout.writeln('Building the release APK for $abi…');
    final build = await Process.start('flutter', [
      'build',
      'apk',
      '--release',
      '--target-platform',
      target,
    ], mode: ProcessStartMode.inheritStdio);
    if (await build.exitCode != 0) fail('Release build failed.');
  }

  stdout.writeln('Installing $package…');
  final install = await run(adb, ['install', '-r', apk]);
  if (!install.contains('Success')) {
    fail(
      'Install failed: $install\n'
      'INSTALL_FAILED_UPDATE_INCOMPATIBLE means a Play-signed copy is installed: '
      '"$adb uninstall $package" removes it (and its data on that device). '
      'INSUFFICIENT_STORAGE means the emulator is full: wipe it or free space.',
    );
  }

  await run(adb, ['logcat', '-b', 'crash', '-c']);
  await shell(['am', 'force-stop', package]);
  await shell([
    'monkey',
    '-p',
    package,
    '-c',
    'android.intent.category.LAUNCHER',
    '1',
  ]);
  stdout.writeln('Opened it; watching for 20 seconds…');
  await Future<void>.delayed(const Duration(seconds: 20));

  final crashes = await run(adb, ['logcat', '-d', '-b', 'crash']);
  if (crashes.contains('Process: $package')) {
    fail('The release build crashed:\n$crashes');
  }
  if ((await shell(['pidof', package])).isEmpty) {
    fail('$package is not running after launch. Check: $adb logcat -d');
  }
  stdout.writeln(
    '✅ The release build opened and is still running. Now tap through the main flows by hand.',
  );
}
