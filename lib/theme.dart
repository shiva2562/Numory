/// Numory's look: neon on a synthwave night. A violet-black void, a magenta
/// horizon, a cyan grid floor rolling toward the player, and every light
/// source glowing. Orbitron for titles and the clock, Nunito for the rest,
/// board numbers included: Orbitron's square 1/7 and 2/8 blur together
/// when a player is memorising them.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// Base
const kInk = Color(0xFF07030F);
const kBoard = Color(0xFF05020B);
const kCell = Color(0xFF140B26);
const kTile = Color(0xFFF2FDFF);
const kText = Color(0xFFF4F0FF);
const kMuted = Color(0xFF9A8FB8);

// Neon
const kMagenta = Color(0xFFFF2BD6);
const kCyan = Color(0xFF19F0FF);
const kViolet = Color(0xFF8B3DFF);
const kGood = Color(0xFF3DFF9A);
const kBad = Color(0xFFFF3355);
const kGold = Color(0xFFFFE45C);

const _display = 'Orbitron';
const _body = 'Nunito';

/// Layered shadows that make text or a box read as lit tube light.
List<Shadow> glow(Color color, {double strength = 1}) => [
  Shadow(color: color.withValues(alpha: 0.9), blurRadius: 4 * strength),
  Shadow(color: color.withValues(alpha: 0.6), blurRadius: 12 * strength),
  Shadow(color: color.withValues(alpha: 0.35), blurRadius: 28 * strength),
];

List<BoxShadow> boxGlow(Color color, {double strength = 1}) => [
  BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 10 * strength),
  BoxShadow(
    color: color.withValues(alpha: 0.25),
    blurRadius: 30 * strength,
    spreadRadius: 2 * strength,
  ),
];

TextStyle display({
  double size = 24,
  FontWeight weight = FontWeight.w900,
  Color color = kText,
  double spacing = 2,
  Color? glowColor,
  double glowStrength = 1,
}) => TextStyle(
  fontFamily: _display,
  fontSize: size,
  fontWeight: weight,
  fontVariations: [FontVariation('wght', weight.value.toDouble())],
  color: color,
  letterSpacing: spacing,
  fontFeatures: const [FontFeature.tabularFigures()],
  shadows: glowColor == null ? null : glow(glowColor, strength: glowStrength),
);

/// A number on the board: heavy Nunito, so every digit reads at a glance.
TextStyle tile({double size = 26, Color color = kText, Color? glowColor}) => TextStyle(
  fontFamily: _body,
  fontSize: size,
  fontWeight: FontWeight.w900,
  fontVariations: const [FontVariation('wght', 900)],
  color: color,
  fontFeatures: const [FontFeature.tabularFigures()],
  shadows: glowColor == null ? null : glow(glowColor, strength: 0.8),
);

TextStyle body({
  double size = 15,
  FontWeight weight = FontWeight.w700,
  Color color = kText,
  Color? glowColor,
}) => TextStyle(
  fontFamily: _body,
  fontSize: size,
  fontWeight: weight,
  fontVariations: [FontVariation('wght', weight.value.toDouble())],
  color: color,
  shadows: glowColor == null ? null : glow(glowColor, strength: 0.6),
);

ThemeData numoryTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: _body,
    colorScheme: const ColorScheme.dark(
      primary: kMagenta,
      onPrimary: kInk,
      secondary: kCyan,
      surface: Color(0xFF110821),
      onSurface: kText,
      error: kBad,
    ),
    scaffoldBackgroundColor: kInk,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: kText,
      displayColor: kText,
      fontFamily: _body,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF0E061C),
      showDragHandle: true,
      dragHandleColor: kMagenta,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? kInk : kMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? kMagenta : kCell,
      ),
    ),
    listTileTheme: const ListTileThemeData(iconColor: kCyan),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kCyan,
        side: const BorderSide(color: kCyan, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: body(size: 16, weight: FontWeight.w800),
      ),
    ),
  );
}

/// The synthwave night behind every screen: violet sky, magenta horizon,
/// a cyan perspective grid rolling toward the player, faint scanlines.
/// [sun] adds the striped neon sun (home only). [calm] dims and slows the
/// floor so it never pulls the eye during a round.
class Backdrop extends StatefulWidget {
  const Backdrop({
    super.key,
    required this.child,
    this.sun = false,
    this.calm = false,
  });
  final Widget child;
  final bool sun;
  final bool calm;

  @override
  State<Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<Backdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // During a round the floor stands still: nothing moves behind the board
    // but the player's own taps, and no frame is spent repainting it.
    if (MediaQuery.disableAnimationsOf(context) || widget.calm) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      RepaintBoundary(
        child: CustomPaint(
          painter: _SynthwavePainter(_c, sun: widget.sun, calm: widget.calm),
        ),
      ),
      widget.child,
    ],
  );
}

class _SynthwavePainter extends CustomPainter {
  _SynthwavePainter(this.t, {required this.sun, required this.calm})
    : super(repaint: t);
  final Animation<double> t;
  final bool sun;
  final bool calm;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final horizon = h * (sun ? 0.50 : 0.70);
    final dim = calm ? 0.45 : 1.0;

    // Sky
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, horizon),
          [
            kInk,
            const Color(0xFF1A0733),
            Color.lerp(const Color(0xFF4A0E5C), kInk, calm ? 0.5 : 0)!,
          ],
          [0, 0.6, 1],
        ),
    );

    // Sun: stripes cut out of its lower half, like an 80s poster.
    if (sun) {
      final r = math.min(w * 0.24, h * 0.13);
      final c = Offset(w / 2, horizon - r * 0.35);
      final sunRect = Rect.fromCircle(center: c, radius: r);
      canvas.drawCircle(
        c,
        r * 1.5,
        Paint()
          ..color = kMagenta.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50),
      );
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, 0, w, horizon));
      final stripes = Path()
        ..addRect(Rect.fromLTRB(c.dx - r, c.dy - r, c.dx + r, c.dy + r));
      for (var i = 0; i < 6; i++) {
        final y = c.dy + r * (0.05 + i * 0.16);
        stripes.addRect(
          Rect.fromLTRB(c.dx - r, y, c.dx + r, y + r * (0.025 + i * 0.012)),
        );
      }
      stripes.fillType = PathFillType.evenOdd;
      canvas.clipPath(stripes);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = ui.Gradient.linear(
            sunRect.topCenter,
            sunRect.bottomCenter,
            [kGold, const Color(0xFFFF7A3D), kMagenta],
            [0, 0.5, 1],
          ),
      );
      canvas.restore();
    }

    // Horizon line
    canvas.drawRect(
      Rect.fromLTRB(0, horizon - 1, w, horizon + 1),
      Paint()
        ..color = kMagenta.withValues(alpha: 0.9 * dim)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawRect(
      Rect.fromLTRB(0, horizon - 30, w, horizon + 30),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, horizon - 30),
          Offset(0, horizon + 30),
          [
            Colors.transparent,
            kMagenta.withValues(alpha: 0.22 * dim),
            Colors.transparent,
          ],
          [0, 0.5, 1],
        ),
    );

    // Floor
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, horizon, w, h));
    canvas.drawRect(
      Rect.fromLTRB(0, horizon, w, h),
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, horizon), Offset(0, h), [
          const Color(0xFF12052A),
          kInk,
        ]),
    );
    final line = Paint()
      ..color = kCyan.withValues(alpha: 0.55 * dim)
      ..strokeWidth = 1.2;
    // A wide faint stroke under a thin bright one reads as glow without the
    // cost of a blur on every line, every frame.
    final glowLine = Paint()
      ..color = kCyan.withValues(alpha: 0.18 * dim)
      ..strokeWidth = 5;
    final depth = h - horizon;
    // Rows rush toward the viewer: spacing grows with the square of distance.
    for (var i = 0; i < 14; i++) {
      final p = (i + t.value) / 14;
      final y = horizon + depth * p * p;
      final fade = (p * 1.6).clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(0, y),
        Offset(w, y),
        glowLine..color = kCyan.withValues(alpha: 0.14 * dim * fade),
      );
      canvas.drawLine(
        Offset(0, y),
        Offset(w, y),
        line..color = kCyan.withValues(alpha: 0.55 * dim * fade),
      );
    }
    final vp = Offset(w / 2, horizon);
    for (var i = -10; i <= 10; i++) {
      final x = w / 2 + i * w * 0.16;
      canvas.drawLine(
        vp,
        Offset(w / 2 + (x - w / 2) * 6, h),
        glowLine..color = kCyan.withValues(alpha: 0.12 * dim),
      );
      canvas.drawLine(
        vp,
        Offset(w / 2 + (x - w / 2) * 6, h),
        line..color = kCyan.withValues(alpha: 0.45 * dim),
      );
    }
    canvas.restore();

    // Scanlines
    final scan = Paint()..color = Colors.black.withValues(alpha: 0.18);
    for (var y = 0.0; y < h; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, w, 1), scan);
    }
  }

  @override
  bool shouldRepaint(_SynthwavePainter old) =>
      old.sun != sun || old.calm != calm;
}

/// A neon button: dark glass, a magenta-to-cyan tube around it, glowing
/// label. [pulse] makes it breathe (the one action to press on a screen).
class NeonButton extends StatefulWidget {
  const NeonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.pulse = true,
    this.big = true,
  });
  final String label;
  final VoidCallback onPressed;
  final bool pulse;
  final bool big;

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  bool _down = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (widget.pulse && !still && !_c.isAnimating) {
      _c.repeat();
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
  Widget build(BuildContext context) {
    final h = widget.big ? 58.0 : 46.0;
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            final wave = math.sin(_c.value * 2 * math.pi) * 0.5 + 0.5;
            final scale = (_down ? 0.95 : 1.0) * (1 + 0.04 * wave);
            return Transform.scale(
              scale: scale,
              child: IntrinsicWidth(
                child: Container(
                  height: h,
                  constraints: BoxConstraints(minWidth: widget.big ? 200 : 140),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(h / 2),
                    gradient: const LinearGradient(
                      colors: [kMagenta, kViolet, kCyan],
                    ),
                    boxShadow: [
                      ...boxGlow(kMagenta, strength: 0.6 + 0.5 * wave),
                      BoxShadow(
                        color: kCyan.withValues(alpha: 0.25 + 0.2 * wave),
                        blurRadius: 22,
                        offset: const Offset(8, 0),
                      ),
                    ],
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        const Color(0xFF12051F),
                        kMagenta,
                        _down ? 0.35 : 0.06 * wave,
                      ),
                      borderRadius: BorderRadius.circular(h / 2),
                    ),
                    child: Text(
                      widget.label.toUpperCase(),
                      style: display(
                        size: widget.big ? 18 : 14,
                        spacing: 3,
                        glowColor: kMagenta,
                        glowStrength: 0.7,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
