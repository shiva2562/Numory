/// Local save: one JSON blob in shared preferences. No accounts, no cloud.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shivapps_shell/shivapps_shell.dart';

import '../core/round.dart';
import 'config.dart';

class SaveData {
  SaveData({
    Map<String, int>? bestCentis,
    this.rounds = 0,
    this.mode = Mode.easy,
    Set<String>? flags,
    this.sound = true,
    this.haptics = true,
    this.sessions = 0,
    Map<String, Object?>? extra,
  }) : bestCentis = bestCentis ?? {},
       flags = flags ?? {},
       extra = extra ?? {};

  /// Best time per mode id, in hundredths of a second.
  final Map<String, int> bestCentis;

  /// Rounds played (won or lost), for the interstitial and offer rules.
  int rounds;

  /// The last mode picked on home.
  Mode mode;
  final Set<String> flags;
  bool sound;
  bool haptics;

  /// App launches, for "never in the first session" rules.
  int sessions;

  /// The shell's own keys (age group, ads, entitlements, reviewer access).
  final Map<String, Object?> extra;

  Map<String, Object?> toJson() => {
    'v': 1,
    'best': bestCentis,
    'rounds': rounds,
    'mode': mode.id,
    'flags': flags.toList()..sort(),
    'sound': sound,
    'haptics': haptics,
    'sessions': sessions,
    'extra': extra,
  };

  factory SaveData.fromJson(Map<String, Object?> j) => SaveData(
    bestCentis: {
      for (final e in ((j['best'] as Map<String, Object?>?) ?? const {}).entries) e.key: (e.value! as num).toInt(),
    },
    rounds: (j['rounds'] as num?)?.toInt() ?? 0,
    mode: Mode.fromId(j['mode']),
    flags: {for (final f in (j['flags'] as List<Object?>?) ?? const []) f! as String},
    sound: j['sound'] as bool? ?? true,
    haptics: j['haptics'] as bool? ?? true,
    sessions: (j['sessions'] as num?)?.toInt() ?? 0,
    extra: Map.of((j['extra'] as Map<String, Object?>?) ?? const {}),
  );
}

/// Loads and writes [SaveData].
class SaveStore {
  SaveStore(this._prefs);

  static const key = 'numory_save_v1';

  /// A save that couldn't be read is kept here, for support, instead of
  /// being overwritten.
  static const corruptKey = 'numory_save_v1_corrupt';
  final SharedPreferences _prefs;

  static Future<SaveStore> open() async => SaveStore(await SharedPreferences.getInstance());

  /// The save, or a fresh one if it is missing or unreadable (never throws).
  SaveData load() {
    final raw = _prefs.getString(key);
    if (raw == null) return SaveData();
    try {
      return SaveData.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      unawaited(_prefs.setString(corruptKey, raw));
      return SaveData();
    }
  }

  Future<void> write(SaveData data) => _prefs.setString(key, jsonEncode(data.toJson()));
}

/// The player's bests and settings, persisted after every change.
class Profile extends ChangeNotifier implements ShellSave {
  Profile({required this.store, GameConfig? config}) : config = config ?? GameConfig(), data = store.load();

  final SaveStore store;
  final GameConfig config;
  final SaveData data;

  @override
  Map<String, Object?> get extra => data.extra;

  @override
  int get sessions => data.sessions;

  @override
  bool hasFlag(String flag) => data.flags.contains(flag);

  @override
  void setFlag(String flag) {
    if (data.flags.add(flag)) unawaited(save());
  }

  @override
  Future<void> save() => store.write(data);

  void startSession() {
    data.sessions++;
    unawaited(save());
  }

  Mode get mode => data.mode;
  set mode(Mode m) {
    if (data.mode == m) return;
    data.mode = m;
    unawaited(save());
    notifyListeners();
  }

  bool get sound => data.sound;
  set sound(bool on) {
    data.sound = on;
    unawaited(save());
    notifyListeners();
  }

  bool get haptics => data.haptics;
  set haptics(bool on) {
    data.haptics = on;
    unawaited(save());
    notifyListeners();
  }

  int get rounds => data.rounds;

  /// Best time for [mode], or null before the first win.
  Duration? best(Mode mode) {
    final c = data.bestCentis[mode.id];
    return c == null ? null : Duration(milliseconds: c * 10);
  }

  /// Counts a finished round. Returns true when [time] is a new best.
  bool roundWon(Mode mode, Duration time) {
    data.rounds++;
    final c = centis(time);
    final old = data.bestCentis[mode.id];
    final isBest = old == null || c < old;
    if (isBest) data.bestCentis[mode.id] = c;
    unawaited(save());
    notifyListeners();
    return isBest;
  }

  void roundLost() {
    data.rounds++;
    unawaited(save());
    notifyListeners();
  }

  /// Store unlocks (entitlement IDs), kept so they hold offline.
  List<String> get entitlements => [
    for (final e in (data.extra['entitlements'] as List<Object?>?) ?? const []) e! as String,
  ];

  void setEntitlements(Set<String> owned) {
    data.extra['entitlements'] = owned.toList()..sort();
    unawaited(save());
    notifyListeners();
  }
}
