import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/round.dart';
import '../../services/juice.dart';
import '../../services/leaderboards.dart';
import '../../services/save.dart';
import '../../theme.dart';

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
      body: Backdrop(
        sun: true,
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
                            icon: Icon(Icons.settings_rounded, color: kCyan, shadows: glow(kCyan, strength: 0.5)),
                          ),
                        ),
                        const Spacer(flex: 1),
                        const Wordmark(),
                        const SizedBox(height: 10),
                        Text(
                          'REMEMBER · TAP IN ORDER · BEAT THE CLOCK',
                          textAlign: TextAlign.center,
                          style: body(size: 11, weight: FontWeight.w900, color: kCyan, glowColor: kCyan),
                        ),
                        const Spacer(flex: 5),
                        _ModePicker(
                          mode: mode,
                          onChanged: (m) {
                            juice?.tap();
                            profile.mode = m;
                          },
                        ),
                        const SizedBox(height: 14),
                        Text('${mode.count} numbers', style: body(color: kText)),
                        const SizedBox(height: 4),
                        Text(
                          best == null ? 'No best yet' : 'Best ${formatTime(best)} s',
                          key: const Key('home-best'),
                          style: display(
                            size: 22,
                            color: best == null ? kMuted : const Color(0xFFFFF6C2),
                            spacing: 1,
                            glowColor: best == null ? null : kGold,
                          ),
                        ),
                        const SizedBox(height: 26),
                        NeonButton(
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
                        const Spacer(flex: 1),
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

/// NUMORY as a neon sign: magenta and cyan ghosts either side (chromatic
/// split), the tube flickers on at launch, bobs letter by letter, and every
/// few seconds one letter stutters.
class Wordmark extends StatefulWidget {
  const Wordmark({super.key});

  @override
  State<Wordmark> createState() => _WordmarkState();
}

class _WordmarkState extends State<Wordmark> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4800));
  final _born = Stopwatch()..start();

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

  static const _letters = 'NUMORY';

  /// The tube catching at launch: dark beats in the first ~0.9 s.
  double _launch() {
    final ms = _born.elapsedMilliseconds;
    if (ms > 900) return 1;
    const dark = [(0, 120), (260, 330), (480, 520), (700, 740)];
    return dark.any((d) => ms >= d.$1 && ms < d.$2) ? 0.12 : 1;
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'Numory',
      child: ExcludeSemantics(
        child: FittedBox(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) {
              final v = _c.value;
              // One letter stutters once a loop.
              final stutter = (v > 0.62 && v < 0.64) || (v > 0.66 && v < 0.67) ? 3 : -1;
              final on = still ? 1.0 : _launch();
              return Opacity(
                opacity: on,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < _letters.length; i++)
                      Transform.translate(
                        offset: Offset(0, still ? 0 : -4 * _wave(v * 1.5 - i * 0.06)),
                        child: Opacity(
                          opacity: i == stutter ? 0.25 : 1,
                          child: _NeonLetter(_letters[i]),
                        ),
                      ),
                  ],
                ),
              );
            },
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

class _NeonLetter extends StatelessWidget {
  const _NeonLetter(this.letter);
  final String letter;

  @override
  Widget build(BuildContext context) {
    final style = display(size: 56, spacing: 4);
    return Stack(
      children: [
        Transform.translate(
          offset: const Offset(-2.5, 0),
          child: Text(letter, style: style.copyWith(color: kMagenta.withValues(alpha: 0.85), shadows: glow(kMagenta))),
        ),
        Transform.translate(
          offset: const Offset(2.5, 0),
          child: Text(letter, style: style.copyWith(color: kCyan.withValues(alpha: 0.85), shadows: glow(kCyan))),
        ),
        Text(letter, style: style.copyWith(color: const Color(0xFFFFF4FD))),
      ],
    );
  }
}

class _ModePicker extends StatelessWidget {
  const _ModePicker({required this.mode, required this.onChanged});
  final Mode mode;
  final ValueChanged<Mode> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xCC0E061C),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: kViolet.withValues(alpha: 0.6)),
    ),
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
                  color: m == mode ? kMagenta.withValues(alpha: 0.18) : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: m == mode ? kMagenta : Colors.transparent, width: 1.5),
                  boxShadow: m == mode ? boxGlow(kMagenta, strength: 0.6) : null,
                ),
                child: Text(
                  m.label.toUpperCase(),
                  style: body(
                    size: 13,
                    weight: FontWeight.w900,
                    color: m == mode ? const Color(0xFFFFE3F8) : kMuted,
                    glowColor: m == mode ? kMagenta : null,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
