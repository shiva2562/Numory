import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_info.dart';
import '../../core/round.dart';
import '../../services/save.dart';
import '../../theme.dart';
import '../home/home_screen.dart';

/// Shares a picture and its text; tests record instead.
typedef Sharer = Future<void> Function(Uint8List png, String text);

Future<void> sharePng(Uint8List png, String text) async {
  await SharePlus.instance.share(
    ShareParams(
      text: text,
      files: [XFile.fromData(png, mimeType: 'image/png', name: 'numory.png')],
    ),
  );
}

/// The best to beat: the chosen mode's, else the first mode that has one.
(Mode, Duration)? bestToBeat(Profile profile) {
  for (final m in [profile.mode, ...Mode.values]) {
    if (profile.best(m) case final b?) return (m, b);
  }
  return null;
}

/// The invite's line: a hello, the best to beat, and every store link.
String inviteText((Mode, Duration)? best) => [
  switch (best) {
    (final m, final t)? => 'Come play $kAppName with me! My best on ${m.label} is ${formatTime(t)} s. Can you beat it?',
    null => 'Come play $kAppName with me! How fast is your memory?',
  },
  ...storeLinks,
].join('\n');

/// The picture of the invite, as a PNG (3x).
Future<Uint8List> renderInviteCard(InviteCard card) => ScreenshotController().captureFromWidget(
  MediaQuery(
    // The sign and the floor stand still: no flicker to catch half way.
    data: const MediaQueryData(disableAnimations: true),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Material(type: MaterialType.transparency, child: card),
    ),
  ),
  pixelRatio: 3,
  delay: Duration.zero,
  targetSize: const Size(360, 450),
);

/// Settings › Invite friends: the NUMORY sign above the striped sun, a slice
/// of the neon board with its numbers showing on the grid floor, and the
/// best to beat.
class InviteCard extends StatelessWidget {
  const InviteCard({super.key, this.best});

  final (Mode, Duration)? best;

  @override
  Widget build(BuildContext context) {
    final both = storeLinks.length > 1;
    return SizedBox(
      width: 360,
      height: 450,
      child: Backdrop(
        sun: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            children: [
              const SizedBox(height: 56, child: Wordmark()),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'REMEMBER · TAP IN ORDER · BEAT THE CLOCK',
                  style: body(size: 10, weight: FontWeight.w900, color: kCyan, glowColor: kCyan),
                ),
              ),
              // The sun fills the space between the sign and the board.
              const Spacer(),
              const _BoardSlice(key: Key('invite-picture')),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  switch (best) {
                    (_, final t)? => 'CAN YOU BEAT MY ${formatTime(t)} s?',
                    null => 'HOW FAST IS YOUR MEMORY?',
                  },
                  maxLines: 1,
                  style: display(size: 18, spacing: 1, color: kGold, glowColor: kGold, glowStrength: 0.6),
                ),
              ),
              const SizedBox(height: 4),
              // The links themselves go in the text; a URL doesn't fit here.
              Text(
                [
                  if (best case (final m, _)?) '${m.label.toUpperCase()} · ${m.count} NUMBERS',
                  both ? 'Free on Google Play and the App Store' : 'Free on Google Play',
                ].join('  ·  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: body(size: 11, color: kMuted, weight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three rows of the 5-wide board while the numbers show, the way a round
/// opens. Fixed squares, so the card always looks the same.
class _BoardSlice extends StatelessWidget {
  const _BoardSlice({super.key});

  static const _rows = 3;

  /// Square (row * 5 + column) to the number on it.
  static const _numbers = {1: 1, 4: 2, 5: 3, 8: 4, 11: 5, 14: 6};

  @override
  Widget build(BuildContext context) => Container(
    width: 210,
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: kBoard.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: kCyan.withValues(alpha: 0.55), width: 1.5),
      boxShadow: boxGlow(kCyan, strength: 0.5),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < _rows; r++)
          Row(
            children: [
              for (var c = 0; c < kCols; c++) Expanded(child: _cell(_numbers[r * kCols + c])),
            ],
          ),
      ],
    ),
  );

  Widget _cell(int? n) => AspectRatio(
    aspectRatio: 1,
    child: Container(
      margin: const EdgeInsets.all(2.5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: n == null ? kCell.withValues(alpha: 0.7) : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: n == null ? kViolet.withValues(alpha: 0.18) : kCyan.withValues(alpha: 0.35)),
      ),
      child: n == null ? null : Text('$n', style: tile(size: 22, color: const Color(0xFFDFFBFF), glowColor: kCyan)),
    ),
  );
}
