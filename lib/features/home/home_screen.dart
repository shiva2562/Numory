import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/round.dart';
import '../../services/juice.dart';
import '../../services/leaderboards.dart';
import '../../services/save.dart';
import '../../theme.dart';
import '../play/play_screen.dart';

/// Wordmark, mode picker, Play, best time, leaderboard and settings.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.profile,
    required this.leaderboards,
    required this.onPlay,
    required this.onSettings,
    this.juice,
  });

  final Profile profile;
  final Leaderboards leaderboards;
  final Juice? juice;
  final void Function(Mode mode) onPlay;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Dusk(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([profile, leaderboards]),
            builder: (context, _) {
              final mode = profile.mode;
              final best = profile.best(mode);
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            key: const Key('settings'),
                            tooltip: 'Settings',
                            onPressed: () {
                              juice?.tap();
                              onSettings();
                            },
                            icon: const Icon(Icons.settings_rounded, color: kMuted),
                          ),
                        ),
                        const Spacer(flex: 2),
                        const Wordmark(),
                        const SizedBox(height: 10),
                        Text(
                          'Remember the numbers. Tap them in order.',
                          textAlign: TextAlign.center,
                          style: body(color: kMuted),
                        ),
                        const Spacer(flex: 2),
                        _ModePicker(
                          mode: mode,
                          onChanged: (m) {
                            juice?.tap();
                            profile.mode = m;
                          },
                        ),
                        const SizedBox(height: 14),
                        Text('${mode.count} numbers', style: body(color: kMuted)),
                        const SizedBox(height: 4),
                        Text(
                          best == null ? 'No best yet' : 'Best ${formatTime(best)} s',
                          key: const Key('home-best'),
                          style: display(size: 22, color: best == null ? kMuted : kGold, spacing: 1),
                        ),
                        const SizedBox(height: 26),
                        PrimaryButton(
                          key: const Key('play'),
                          label: 'Play',
                          onPressed: () {
                            juice?.tap();
                            onPlay(mode);
                          },
                        ),
                        const SizedBox(height: 14),
                        if (leaderboards.available)
                          OutlinedButton.icon(
                            key: const Key('leaderboard'),
                            onPressed: () {
                              juice?.tap();
                              unawaited(leaderboards.show(mode));
                            },
                            icon: const Icon(Icons.leaderboard_rounded, size: 20),
                            label: Text('${mode.label} leaderboard'),
                          ),
                        const Spacer(flex: 3),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// NUMORY in Orbitron, gently bobbing letter by letter.
class Wordmark extends StatefulWidget {
  const Wordmark({super.key});

  @override
  State<Wordmark> createState() => _WordmarkState();
}

class _WordmarkState extends State<Wordmark> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      unawaited(_c.repeat());
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const letters = 'NUMORY';
    return Semantics(
      label: 'Numory',
      child: ExcludeSemantics(
        child: FittedBox(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < letters.length; i++)
                  Transform.translate(
                    offset: Offset(0, -4 * _wave(_c.value - i * 0.08)),
                    child: Text(letters[i], style: display(size: 52, spacing: 4)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static double _wave(double t) {
    final x = t % 1;
    return x < 0.3 ? Curves.easeInOut.transform(x < .15 ? x / .15 : (0.3 - x) / .15) : 0;
  }
}

class _ModePicker extends StatelessWidget {
  const _ModePicker({required this.mode, required this.onChanged});
  final Mode mode;
  final ValueChanged<Mode> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: kCell, borderRadius: BorderRadius.circular(999)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final m in Mode.values)
          Semantics(
            selected: m == mode,
            button: true,
            child: GestureDetector(
              key: Key('mode-${m.id}'),
              onTap: () => onChanged(m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: m == mode ? kTile : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  m.label.toUpperCase(),
                  style: body(size: 13, weight: FontWeight.w900, color: m == mode ? kInk : kMuted),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
