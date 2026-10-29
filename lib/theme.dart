import 'package:flutter/material.dart';

/// Palette from the mockup: black and dark grey with the car's Ultimate Red.
abstract final class Palette {
  static const stage = Color(0xFF0B0B0C);
  static const glass = Color(0xFF151516);
  static const raise = Color(0xFF1C1C1E);
  static const unlit = Color(0xFF2C2C2E);
  static const line = Color(0xFF2A2A2C);
  static const ink = Color(0xFFF2F2F2);
  static const mute = Color(0xFF8E8E93);
  static const light = Color(0xFFC7C9CC);
  static const red = Color(0xFFE8333C);
  static const redDeep = Color(0xFF3A1517);
  static const amber = Color(0xFFFFB02E);
  static const ok = Color(0xFF7FD67A);
  static const okDeep = Color(0xFF18261A);
}

/// Variable fonts need the weight passed as an axis too.
TextStyle _font(String family, double size, int weight, {Color color = Palette.ink, double? height}) => TextStyle(
  fontFamily: family,
  fontSize: size,
  fontWeight: FontWeight.values[(weight ~/ 100) - 1],
  fontVariations: [FontVariation('wght', weight.toDouble())],
  color: color,
  height: height,
);

abstract final class Txt {
  static TextStyle display(double size, {int weight = 300, Color color = Palette.ink}) =>
      _font('Outfit', size, weight, color: color, height: 1.05);
  static TextStyle body(double size, {int weight = 400, Color color = Palette.ink}) =>
      _font('InstrumentSans', size, weight, color: color, height: 1.4);
  static TextStyle mono(double size, {int weight = 500, Color color = Palette.mute}) =>
      _font('JetBrainsMono', size, weight, color: color).copyWith(letterSpacing: size * 0.1);
  static TextStyle label() => mono(11);
  static TextStyle muted(double size) => body(size, color: Palette.mute);
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: Palette.glass,
    fontFamily: 'InstrumentSans',
    colorScheme: const ColorScheme.dark(
      primary: Palette.red,
      secondary: Palette.red,
      surface: Palette.raise,
      onSurface: Palette.ink,
      error: Palette.amber,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: Palette.ink, displayColor: Palette.ink),
    splashFactory: NoSplash.splashFactory,
    sliderTheme: const SliderThemeData(
      activeTrackColor: Palette.red,
      inactiveTrackColor: Palette.unlit,
      thumbColor: Palette.ink,
      trackHeight: 6,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Palette.ink : Palette.mute),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Palette.red : Palette.unlit,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.raise,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      labelStyle: const TextStyle(color: Palette.mute),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Palette.ink,
      contentTextStyle: Txt.body(13, color: const Color(0xFF0A0A0A)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(backgroundColor: Palette.glass),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(backgroundColor: Palette.glass),
      },
    ),
  );
}
