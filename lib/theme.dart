/// Numory's look: a black board on a dusk-purple night, white tiles, the
/// NUMORY wordmark in Orbitron and Nunito for everything else.
library;

import 'package:flutter/material.dart';

const kInk = Color(0xFF0B0B0D);
const kBoard = Color(0xFF000000);
const kCell = Color(0xFF17171B);
const kTile = Color(0xFFF6F6F2);
const kText = Color(0xFFF2F2EE);
const kMuted = Color(0xFF8C8C96);
const kGood = Color(0xFF57D98A);
const kBad = Color(0xFFFF6B6B);
const kGold = Color(0xFFFFCB52);
const kDusk = Color(0xFF3A1C4A);
const kDuskGlow = Color(0xFFB4475E);

const _display = 'Orbitron';
const _body = 'Nunito';

TextStyle display({double size = 24, FontWeight weight = FontWeight.w900, Color color = kText, double spacing = 2}) =>
    TextStyle(
      fontFamily: _display,
      fontSize: size,
      fontWeight: weight,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
      color: color,
      letterSpacing: spacing,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

TextStyle body({double size = 15, FontWeight weight = FontWeight.w700, Color color = kText}) => TextStyle(
  fontFamily: _body,
  fontSize: size,
  fontWeight: weight,
  fontVariations: [FontVariation('wght', weight.value.toDouble())],
  color: color,
);

ThemeData numoryTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: _body,
    colorScheme: const ColorScheme.dark(
      primary: kTile,
      onPrimary: kInk,
      secondary: kGold,
      surface: kCell,
      onSurface: kText,
      error: kBad,
    ),
    scaffoldBackgroundColor: kInk,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: kText, displayColor: kText, fontFamily: _body),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Color(0xFF141217), showDragHandle: true),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kText,
        side: const BorderSide(color: Color(0xFF3A3A42)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: body(size: 16, weight: FontWeight.w800),
      ),
    ),
  );
}

/// The dusk background behind every screen.
class Dusk extends StatelessWidget {
  const Dusk({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: kInk,
      gradient: RadialGradient(center: Alignment(0, -1.1), radius: 1.3, colors: [kDusk, kInk], stops: [0, 0.75]),
    ),
    child: child,
  );
}
