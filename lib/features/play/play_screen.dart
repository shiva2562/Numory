import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shivapps_shell/shivapps_shell.dart';

import '../../app_info.dart';
import '../../core/round.dart';
import '../../services/juice.dart';
import '../../services/leaderboards.dart';
import '../../services/save.dart';
import '../../theme.dart';
import 'sparks.dart';

/// One round after another in [mode], until the player goes home.
class PlayScreen extends StatefulWidget {
  const PlayScreen({
    super.key,
    required this.mode,
    required this.profile,
    required this.leaderboards,
    this.juice,
    this.interstitials,
    this.afterRound,
    this.now = DateTime.now,
    this.random,
  });

  final Mode mode;
  final Profile profile;
  final Leaderboards leaderboards;
  final Juice? juice;
  final InterstitialFlow? interstitials;

  /// Runs between rounds (the one-time Remove Ads offer).
  final Future<void> Function(BuildContext context)? afterRound;

  /// The clock (tests pass their own).
  final DateTime Function() now;

  /// Where numbers land (tests pass a seeded one).
  final Random? random;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

/// What the result card shows about the leaderboard.
enum RankState { loading, ranked, notSignedIn, tooFast, unavailable, failed }

class _PlayScreenState extends State<PlayScreen> with TickerProviderStateMixin {
  late Round _round;
  late final Ticker _ticker = createTicker((_) => _clock.value = _round.elapsed(widget.now()));
  final _clock = ValueNotifier(Duration.zero);
  final _sparks = SparksController();

  /// Wrong tap: the board shakes and glitches red.
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  /// Finish: a flash of light over the board.
  late final AnimationController _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  bool _showResult = false;
  bool _newBest = false;
  RankState _rank = RankState.loading;
  RankInfo? _rankInfo;
  late final bool _firstRound = !widget.profile.hasFlag('played');
  Size _boardSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _round = Round.random(widget.mode, start: widget.now(), random: widget.random);
    // The clock starts when the board is first drawn, not when it was built.
    final cells = _round.cells;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(_round.cells, cells) && _round.next == 1 && _round.state == RoundState.playing) {
        _round = Round(mode: widget.mode, cells: cells, startedAt: widget.now());
      }
    });
    _clock.value = Duration.zero;
    _showResult = false;
    _newBest = false;
    _rank = RankState.loading;
    _rankInfo = null;
    _shake.value = 0;
    _flash.value = 0;
    widget.juice?.start();
    widget.interstitials?.levelOpened(widget.profile.rounds + 1);
    Analytics.instance.levelStart(widget.profile.rounds + 1);
    if (!_ticker.isActive) unawaited(_ticker.start());
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    _shake.dispose();
    _flash.dispose();
    _sparks.dispose();
    super.dispose();
  }

  /// The centre of [cell] in board coordinates (the board has 6 px padding).
  Offset _cellCenter(int cell) {
    const pad = 6.0;
    final cw = (_boardSize.width - 2 * pad) / kCols;
    final ch = (_boardSize.height - 2 * pad) / kRows;
    return Offset(pad + cw * (cell % kCols + 0.5), pad + ch * (cell ~/ kCols + 0.5));
  }

  bool get _still => MediaQuery.disableAnimationsOf(context);

  void _tap(int cell) {
    final now = widget.now();
    final number = _round.numberAt(cell);
    final result = _round.tap(cell, now);
    switch (result) {
      case TapResult.ignored:
        return;
      case TapResult.correct:
        widget.juice?.correct(number!);
        if (!_still) _sparks.burst(_cellCenter(cell), count: 14, colors: const [kCyan, kMagenta, kTile]);
      case TapResult.finished:
        widget.juice?.correct(number!);
        if (!_still) {
          _sparks.burst(_cellCenter(cell), count: 70, speed: 2.2, colors: const [kCyan, kMagenta, kGold, kGood, kTile]);
          unawaited(_flash.forward(from: 0));
        }
        _finish(won: true);
      case TapResult.wrong:
        widget.juice?.wrong();
        if (!_still) {
          unawaited(_shake.forward(from: 0));
          _sparks.burst(_cellCenter(cell), count: 24, colors: const [kBad, kMagenta]);
        }
        _finish(won: false);
    }
    setState(() {});
  }

  void _finish({required bool won}) {
    _ticker.stop();
    final time = _round.elapsed(widget.now());
    _clock.value = time;
    widget.profile.setFlag('played');
    if (!won) {
      widget.profile.roundLost();
      // A beat to see the red and gold squares before the card covers them.
      Timer(const Duration(milliseconds: 700), () {
        if (mounted && _round.state == RoundState.lost) setState(() => _showResult = true);
      });
      return;
    }
    _newBest = widget.profile.roundWon(widget.mode, time);
    widget.juice?.done(newBest: _newBest);
    _showResult = true;
    unawaited(_submit(time));
  }

  Future<void> _submit(Duration time) async {
    final boards = widget.leaderboards;
    RankState state;
    RankInfo? info;
    if (!boards.available) {
      state = RankState.unavailable;
    } else if (time < widget.profile.config.minValidTime(widget.mode)) {
      state = RankState.tooFast;
    } else if (!await boards.signIn()) {
      state = RankState.notSignedIn;
    } else {
      info = await boards.submit(widget.mode, time);
      state = info == null ? RankState.failed : RankState.ranked;
    }
    if (!mounted) return;
    setState(() {
      _rank = state;
      _rankInfo = info;
    });
  }

  /// Between rounds: maybe an interstitial, maybe the one-time offer.
  Future<void> _between() async {
    await widget.interstitials?.levelFinished(widget.profile.rounds, beforeReveal: false);
    if (mounted) await widget.afterRound?.call(context);
  }

  Future<void> _again() async {
    widget.juice?.tap();
    await _between();
    if (mounted) setState(_start);
  }

  Future<void> _home() async {
    widget.juice?.tap();
    await _between();
    if (mounted) Navigator.of(context).pop();
  }

  void _share() {
    widget.juice?.tap();
    final time = formatTime(_round.elapsed(widget.now()));
    final rank = _rankInfo == null ? '' : ' (#${_rankInfo!.rank} in the world)';
    unawaited(
      SharePlus.instance.share(
        ShareParams(
          text: 'I memorised ${widget.mode.count} numbers in $time s on Numory ${widget.mode.label}$rank. '
              'Can you beat it?\n$storeLink',
        ),
      ),
    );
  }

  String get _line {
    if (_round.state == RoundState.lost) return '';
    if (!_round.hidden) {
      return _firstRound ? 'Remember them. Tap 1, then the rest in order.' : 'Tap 1, then the rest in order.';
    }
    return 'Next: ${_round.next}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Backdrop(
        calm: true,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    _TopBar(
                      mode: widget.mode,
                      clock: _clock,
                      state: _round.state,
                      best: widget.profile.best(widget.mode),
                      onHome: _home,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: kCols / kRows,
                          child: AnimatedBuilder(
                            animation: _shake,
                            builder: (_, child) {
                              final t = _shake.value;
                              final dx = t == 0 ? 0.0 : sin(t * pi * 9) * 12 * (1 - t);
                              return Transform.translate(offset: Offset(dx, 0), child: child);
                            },
                            child: LayoutBuilder(
                              builder: (context, box) {
                                _boardSize = box.biggest;
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    _Board(round: _round, onTap: _tap),
                                    Positioned.fill(child: IgnorePointer(child: _Glitch(_shake))),
                                    Positioned.fill(child: IgnorePointer(child: _Flash(_flash))),
                                    Positioned.fill(child: IgnorePointer(child: Sparks(controller: _sparks))),
                                    if (_showResult)
                                      Positioned.fill(
                                        child: _round.state == RoundState.won
                                            ? _WinCard(
                                                time: _round.elapsed(widget.now()),
                                                best: widget.profile.best(widget.mode)!,
                                                newBest: _newBest,
                                                rank: _rank,
                                                rankInfo: _rankInfo,
                                                onAgain: _again,
                                                onShare: _share,
                                                onSignIn: () async {
                                                  await widget.leaderboards.signIn(interactive: true);
                                                  if (mounted && widget.leaderboards.signedIn) {
                                                    setState(() => _rank = RankState.loading);
                                                    unawaited(_submit(_round.elapsed(widget.now())));
                                                  }
                                                },
                                              )
                                            : _LoseCard(round: _round, onAgain: _again),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 24,
                      child: Text(
                        _showResult ? '' : _line,
                        key: const Key('play-line'),
                        style: body(color: _round.hidden ? kCyan : kMuted, glowColor: _round.hidden ? kCyan : null),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.mode, required this.clock, required this.state, required this.best, required this.onHome});
  final Mode mode;
  final ValueListenable<Duration> clock;
  final RoundState state;
  final Duration? best;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final clockColor = switch (state) {
      RoundState.playing => kMagenta,
      RoundState.won => kGood,
      RoundState.lost => kBad,
    };
    return Row(
      children: [
        IconButton(
          key: const Key('play-home'),
          onPressed: onHome,
          tooltip: 'Home',
          icon: Icon(Icons.home_rounded, color: kCyan, shadows: glow(kCyan, strength: 0.5)),
        ),
        Expanded(
          child: Text(
            '${mode.label.toUpperCase()} · ${mode.count}',
            style: body(size: 13, color: kMuted, weight: FontWeight.w900),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: clock,
          builder: (_, d, _) => Text(
            formatTime(d),
            key: const Key('clock'),
            style: display(size: 28, color: Color.lerp(clockColor, kText, 0.35)!, glowColor: clockColor),
          ),
        ),
        Expanded(
          child: Text(
            best == null ? 'Best —' : 'Best ${formatTime(best!)}',
            textAlign: TextAlign.right,
            style: body(size: 13, color: kMuted),
          ),
        ),
      ],
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.round, required this.onTap});
  final Round round;
  final void Function(int cell) onTap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: kBoard.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: kCyan.withValues(alpha: 0.8), width: 1.5),
      boxShadow: [...boxGlow(kCyan, strength: 0.7), ...boxGlow(kMagenta, strength: 0.4)],
    ),
    child: Padding(
      padding: const EdgeInsets.all(4.5),
      child: Column(
        children: [
          for (var r = 0; r < kRows; r++)
            Expanded(
              child: Row(
                children: [
                  for (var c = 0; c < kCols; c++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: _Cell(round: round, cell: r * kCols + c, onTap: onTap),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _Cell extends StatelessWidget {
  const _Cell({required this.round, required this.cell, required this.onTap});
  final Round round;
  final int cell;
  final void Function(int cell) onTap;

  @override
  Widget build(BuildContext context) {
    final n = round.numberAt(cell);
    final lost = round.state == RoundState.lost;
    var fill = kCell.withValues(alpha: 0.7);
    var edge = kViolet.withValues(alpha: 0.18);
    List<BoxShadow>? shadows;
    String? label;
    var labelColor = kText;
    Color? labelGlow;
    if (n != null) {
      final cleared = round.isCleared(n);
      if (lost && n == round.wrongNumber) {
        fill = kBad;
        edge = kBad;
        shadows = boxGlow(kBad, strength: 1.2);
        label = '$n';
        labelColor = kInk;
      } else if (lost && cell == round.neededCell) {
        fill = kGold;
        edge = kGold;
        shadows = boxGlow(kGold, strength: 1.2);
        label = '$n';
        labelColor = kInk;
      } else if (cleared) {
        fill = kGood.withValues(alpha: 0.10);
        edge = kGood.withValues(alpha: 0.45);
      } else if (round.hidden && !lost) {
        fill = kTile;
        edge = kCyan;
        shadows = boxGlow(kCyan, strength: 0.8);
      } else {
        fill = Colors.transparent;
        edge = kCyan.withValues(alpha: 0.35);
        label = '$n';
        labelColor = lost ? kMuted : const Color(0xFFDFFBFF);
        labelGlow = lost ? null : kCyan;
      }
    }
    return GestureDetector(
      key: Key('cell-$cell'),
      behavior: HitTestBehavior.opaque,
      // Down, not up: a speed game reacts on touch.
      onTapDown: (_) => onTap(cell),
      child: Semantics(
        button: n != null,
        label: n == null ? null : (round.hidden ? 'Tile' : 'Number $n'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: edge, width: 1),
            boxShadow: shadows,
          ),
          alignment: Alignment.center,
          child: label == null
              ? null
              : FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(label, style: display(size: 26, color: labelColor, spacing: 0, glowColor: labelGlow)),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Wrong tap: red scanline bands tear across the board and fade.
class _Glitch extends StatelessWidget {
  const _Glitch(this.t);
  final Animation<double> t;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: t,
    builder: (_, _) {
      final v = t.value;
      if (v == 0 || v == 1) return const SizedBox.shrink();
      return CustomPaint(painter: _GlitchPainter(v));
    },
  );
}

class _GlitchPainter extends CustomPainter {
  _GlitchPainter(this.v);
  final double v;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = 1 - v;
    final r = Random((v * 12).floor());
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      Paint()..color = kBad.withValues(alpha: 0.18 * fade),
    );
    for (var i = 0; i < 7; i++) {
      final y = r.nextDouble() * size.height;
      final hgt = 2 + r.nextDouble() * 10;
      final shift = (r.nextDouble() - 0.5) * 40 * fade;
      canvas.drawRect(
        Rect.fromLTWH(shift, y, size.width, hgt),
        Paint()..color = (i.isEven ? kBad : kCyan).withValues(alpha: 0.35 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(_GlitchPainter old) => old.v != v;
}

/// Finish: the board flashes white-cyan and fades.
class _Flash extends StatelessWidget {
  const _Flash(this.t);
  final Animation<double> t;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: t,
    builder: (_, _) {
      final v = t.value;
      if (v == 0 || v == 1) return const SizedBox.shrink();
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: RadialGradient(colors: [
            kTile.withValues(alpha: 0.55 * (1 - v)),
            kCyan.withValues(alpha: 0.25 * (1 - v)),
            Colors.transparent,
          ]),
        ),
      );
    },
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.children, required this.color});
  final List<Widget> children;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xE6080312),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color.withValues(alpha: 0.8), width: 1.5),
      boxShadow: boxGlow(color, strength: 0.6),
    ),
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    ),
  );
}

/// Neon sign flicker: a few quick dips while the tube "warms up", then on.
class Flicker extends StatefulWidget {
  const Flicker({super.key, required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;

  @override
  State<Flicker> createState() => _FlickerState();
}

class _FlickerState extends State<Flicker> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  Timer? _wait;

  @override
  void initState() {
    super.initState();
    _wait = Timer(widget.delay, () {
      if (mounted) unawaited(_c.forward());
    });
  }

  @override
  void dispose() {
    _wait?.cancel();
    _c.dispose();
    super.dispose();
  }

  // Off/on steps of a tube catching: mostly on, with a few dark beats.
  static const _dark = [(0.0, 0.12), (0.22, 0.30), (0.38, 0.42), (0.55, 0.58)];

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final v = _c.value;
        final off = _c.status == AnimationStatus.dismissed || _dark.any((d) => v >= d.$1 && v < d.$2);
        return Opacity(opacity: off ? 0.15 : 1, child: child);
      },
      child: widget.child,
    );
  }
}

class _WinCard extends StatelessWidget {
  const _WinCard({
    required this.time,
    required this.best,
    required this.newBest,
    required this.rank,
    required this.rankInfo,
    required this.onAgain,
    required this.onShare,
    required this.onSignIn,
  });
  final Duration time;
  final Duration best;
  final bool newBest;
  final RankState rank;
  final RankInfo? rankInfo;
  final VoidCallback onAgain;
  final VoidCallback onShare;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) => _Card(
    color: newBest ? kGold : kCyan,
    children: [
      Flicker(
        child: Text(
          newBest ? 'NEW BEST' : 'CLEAR',
          key: const Key('win-title'),
          style: display(size: 24, color: newBest ? const Color(0xFFFFF6C2) : kText, glowColor: newBest ? kGold : kCyan),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '${formatTime(time)} s',
        key: const Key('win-time'),
        style: display(size: 42, spacing: 0, color: const Color(0xFFE6FFF3), glowColor: kGood, glowStrength: 1.2),
      ),
      if (!newBest) Text('Your best ${formatTime(best)} s', style: body(color: kMuted)),
      const SizedBox(height: 14),
      _RankChip(rank: rank, info: rankInfo, onSignIn: onSignIn),
      const SizedBox(height: 20),
      NeonButton(key: const Key('again'), label: 'Play again', onPressed: onAgain),
      const SizedBox(height: 8),
      TextButton.icon(
        key: const Key('share'),
        onPressed: onShare,
        icon: const Icon(Icons.ios_share_rounded, size: 18, color: kCyan),
        label: Text('Share', style: body(color: kCyan)),
      ),
    ],
  );
}

class _RankChip extends StatelessWidget {
  const _RankChip({required this.rank, required this.info, required this.onSignIn});
  final RankState rank;
  final RankInfo? info;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final Widget child = switch (rank) {
      RankState.loading => const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: kMagenta),
      ),
      RankState.ranked => Column(
        children: [
          Text('#${info!.rank}', key: const Key('rank'), style: display(size: 26, color: const Color(0xFFFFD6F5), spacing: 1, glowColor: kMagenta)),
          Text('IN THE WORLD · ALL TIME', style: body(size: 11, color: kMuted, weight: FontWeight.w900)),
        ],
      ),
      RankState.notSignedIn => TextButton(
        key: const Key('rank-sign-in'),
        onPressed: onSignIn,
        child: Text('Sign in to Play Games to get a world rank', textAlign: TextAlign.center, style: body(color: kCyan)),
      ),
      RankState.tooFast => Text(
        'Too fast to be real. Not sent to the leaderboard.',
        textAlign: TextAlign.center,
        style: body(size: 13, color: kMuted),
      ),
      RankState.failed => Text(
        'Couldn’t reach the leaderboard. Your best is saved.',
        textAlign: TextAlign.center,
        style: body(size: 13, color: kMuted),
      ),
      RankState.unavailable => const SizedBox.shrink(),
    };
    if (rank == RankState.unavailable) return child;
    return Container(
      constraints: const BoxConstraints(minWidth: 170, minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF12061F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kMagenta.withValues(alpha: 0.6)),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _LoseCard extends StatelessWidget {
  const _LoseCard({required this.round, required this.onAgain});
  final Round round;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) => _Card(
    color: kBad,
    children: [
      Flicker(
        child: Text('OOPS', key: const Key('lose-title'), style: display(size: 30, color: const Color(0xFFFFD0D8), glowColor: kBad)),
      ),
      const SizedBox(height: 10),
      Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'That was '),
            TextSpan(text: '${round.wrongNumber}', style: body(color: kBad, glowColor: kBad)),
            const TextSpan(text: '. You needed '),
            TextSpan(text: '${round.next}', style: body(color: kGold, glowColor: kGold)),
            const TextSpan(text: '.'),
          ],
        ),
        textAlign: TextAlign.center,
        style: body(size: 16, color: kMuted),
      ),
      const SizedBox(height: 20),
      NeonButton(key: const Key('again'), label: 'Try again', onPressed: onAgain),
    ],
  );
}
