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

class _PlayScreenState extends State<PlayScreen> with SingleTickerProviderStateMixin {
  late Round _round;
  late final Ticker _ticker = createTicker((_) => _clock.value = _round.elapsed(widget.now()));
  final _clock = ValueNotifier(Duration.zero);
  bool _showResult = false;
  bool _newBest = false;
  RankState _rank = RankState.loading;
  RankInfo? _rankInfo;
  late final bool _firstRound = !widget.profile.hasFlag('played');

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _round = Round.random(widget.mode, start: widget.now(), random: widget.random);
    _clock.value = Duration.zero;
    _showResult = false;
    _newBest = false;
    _rank = RankState.loading;
    _rankInfo = null;
    widget.juice?.start();
    widget.interstitials?.levelOpened(widget.profile.rounds + 1);
    Analytics.instance.levelStart(widget.profile.rounds + 1);
    if (!_ticker.isActive) unawaited(_ticker.start());
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  void _tap(int cell) {
    final now = widget.now();
    final number = _round.numberAt(cell);
    final result = _round.tap(cell, now);
    switch (result) {
      case TapResult.ignored:
        return;
      case TapResult.correct:
        widget.juice?.correct(number!);
      case TapResult.finished:
        widget.juice?.correct(number!);
        _finish(won: true);
      case TapResult.wrong:
        widget.juice?.wrong();
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
      body: Dusk(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    _TopBar(mode: widget.mode, clock: _clock, best: widget.profile.best(widget.mode), onHome: _home),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: kCols / kRows,
                          child: Stack(
                            children: [
                              _Board(round: _round, onTap: _tap),
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
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 24,
                      child: Text(_showResult ? '' : _line, key: const Key('play-line'), style: body(color: kMuted)),
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
  const _TopBar({required this.mode, required this.clock, required this.best, required this.onHome});
  final Mode mode;
  final ValueListenable<Duration> clock;
  final Duration? best;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        key: const Key('play-home'),
        onPressed: onHome,
        tooltip: 'Home',
        icon: const Icon(Icons.home_rounded, color: kText),
      ),
      Expanded(
        child: Text(
          '${mode.label} · ${mode.count}',
          style: body(size: 14, color: kMuted, weight: FontWeight.w800),
        ),
      ),
      ValueListenableBuilder(
        valueListenable: clock,
        builder: (_, d, _) => Text(formatTime(d), key: const Key('clock'), style: display(size: 26, color: kBad)),
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

class _Board extends StatelessWidget {
  const _Board({required this.round, required this.onTap});
  final Round round;
  final void Function(int cell) onTap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: kBoard,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [BoxShadow(color: Color(0x66B4475E), blurRadius: 40, offset: Offset(0, 18), spreadRadius: -16)],
    ),
    child: Padding(
      padding: const EdgeInsets.all(6),
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
    var color = kCell;
    String? label;
    var labelColor = kText;
    if (n != null) {
      final cleared = round.isCleared(n);
      if (lost && n == round.wrongNumber) {
        color = kBad;
        label = '$n';
        labelColor = kInk;
      } else if (lost && cell == round.neededCell) {
        color = kGold;
        label = '$n';
        labelColor = kInk;
      } else if (cleared) {
        color = kCell;
      } else if (round.hidden && !lost) {
        color = kTile;
      } else {
        color = kBoard;
        label = '$n';
        if (lost) labelColor = kMuted;
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
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
          alignment: Alignment.center,
          child: label == null
              ? null
              : FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(label, style: body(size: 28, weight: FontWeight.w800, color: labelColor)),
                  ),
                ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: const Color(0xDB000000), borderRadius: BorderRadius.circular(18)),
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    ),
  );
}

class PrimaryButton extends StatefulWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.pulse = true});
  final String label;
  final VoidCallback onPressed;
  final bool pulse;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (widget.pulse && !still && !_c.isAnimating) {
      unawaited(_c.repeat());
    } else if (still) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) {
      final t = Curves.easeInOut.transform(_c.value < .5 ? _c.value * 2 : 2 - _c.value * 2);
      return Transform.scale(scale: 1 + 0.05 * t, child: child);
    },
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: kTile,
        foregroundColor: kInk,
        minimumSize: const Size(180, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: body(size: 18, weight: FontWeight.w900),
      ),
      onPressed: widget.onPressed,
      child: Text(widget.label),
    ),
  );
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
    children: [
      Text(
        newBest ? 'NEW BEST' : 'DONE',
        key: const Key('win-title'),
        style: display(size: 24, color: newBest ? kGold : kText),
      ),
      const SizedBox(height: 6),
      Text('${formatTime(time)} s', key: const Key('win-time'), style: display(size: 40, spacing: 0)),
      if (!newBest) Text('Your best ${formatTime(best)} s', style: body(color: kMuted)),
      const SizedBox(height: 12),
      _RankChip(rank: rank, info: rankInfo, onSignIn: onSignIn),
      const SizedBox(height: 18),
      PrimaryButton(key: const Key('again'), label: 'Play again', onPressed: onAgain),
      const SizedBox(height: 6),
      TextButton.icon(
        key: const Key('share'),
        onPressed: onShare,
        icon: const Icon(Icons.ios_share_rounded, size: 18, color: kMuted),
        label: Text('Share', style: body(color: kMuted)),
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
        child: CircularProgressIndicator(strokeWidth: 2.5, color: kMuted),
      ),
      RankState.ranked => Column(
        children: [
          Text('#${info!.rank}', key: const Key('rank'), style: display(size: 24, color: kGold, spacing: 1)),
          Text('in the world · all time', style: body(size: 12, color: kMuted)),
        ],
      ),
      RankState.notSignedIn => TextButton(
        key: const Key('rank-sign-in'),
        onPressed: onSignIn,
        child: Text('Sign in to Play Games to get a world rank', textAlign: TextAlign.center, style: body(color: kGold)),
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
      constraints: const BoxConstraints(minWidth: 160, minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: kCell, borderRadius: BorderRadius.circular(14)),
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
    children: [
      Text('OOPS', key: const Key('lose-title'), style: display(size: 26)),
      const SizedBox(height: 8),
      Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'That was '),
            TextSpan(text: '${round.wrongNumber}', style: body(color: kBad)),
            const TextSpan(text: '. You needed '),
            TextSpan(text: '${round.next}', style: body(color: kGold)),
            const TextSpan(text: '.'),
          ],
        ),
        textAlign: TextAlign.center,
        style: body(size: 16, color: kMuted),
      ),
      const SizedBox(height: 18),
      PrimaryButton(key: const Key('again'), label: 'Try again', onPressed: onAgain),
    ],
  );
}
