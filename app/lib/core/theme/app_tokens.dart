import 'package:flutter/material.dart';

/// Semantic color tokens. Every text/background pairing used by the app is
/// contrast-tested in test/design_tokens_test.dart (WCAG AA, 4.5:1).
@immutable
class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.muted,
    required this.separator,
    required this.text,
    required this.text2,
    required this.text3,
    required this.accent,
    required this.onAccent,
    required this.accentTint,
    required this.accentText,
    required this.danger,
  });

  /// Screen background (grouped-list grey in light mode).
  final Color background;

  /// Cards, sheets, panels.
  final Color surface;

  /// Fills for inactive controls and wells.
  final Color muted;

  /// Hairline dividers and borders (decorative, not text).
  final Color separator;

  final Color text;
  final Color text2;
  final Color text3;

  /// Brand emerald for fills (buttons, active slider track, switches).
  final Color accent;
  final Color onAccent;

  /// Soft emerald wash behind selected chips/tabs.
  final Color accentTint;

  /// Emerald used for text and icons on surfaces and on [accentTint].
  final Color accentText;
  final Color danger;

  static const AppPalette light = AppPalette(
    background: Color(0xFFF2F2F7),
    surface: Color(0xFFFFFFFF),
    muted: Color(0xFFEBEBF0),
    separator: Color(0xFFD9D9DE),
    text: Color(0xFF111114),
    text2: Color(0xFF55555C),
    text3: Color(0xFF6B6B73),
    accent: Color(0xFF047857),
    onAccent: Color(0xFFFFFFFF),
    accentTint: Color(0xFFDDF3E9),
    accentText: Color(0xFF036448),
    danger: Color(0xFFC9251B),
  );

  static const AppPalette dark = AppPalette(
    background: Color(0xFF0A0A0C),
    surface: Color(0xFF1C1C1F),
    muted: Color(0xFF2A2A2E),
    separator: Color(0xFF38383D),
    text: Color(0xFFF5F5F7),
    text2: Color(0xFFB0B0B8),
    text3: Color(0xFF9A9AA3),
    accent: Color(0xFF34D399),
    onAccent: Color(0xFF04271D),
    accentTint: Color(0xFF12372B),
    accentText: Color(0xFF6EE7B7),
    danger: Color(0xFFFF6B61),
  );
}

/// 4-point spacing scale.
abstract final class AppSpace {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii.
abstract final class AppRadius {
  static const double s = 10;
  static const double m = 14;
  static const double l = 20;
  static const double xl = 28;
}

/// Exposes the palette through Theme.of(context).extension<AppTokens>().
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens(this.palette);

  final AppPalette palette;

  @override
  AppTokens copyWith({AppPalette? palette}) =>
      AppTokens(palette ?? this.palette);

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) =>
      other is AppTokens && t >= 0.5 ? other : this;
}

extension AppTokensContext on BuildContext {
  /// The active palette (falls back to light if no theme extension is set,
  /// e.g. in a bare MaterialApp used by a test).
  AppPalette get palette =>
      (Theme.of(this).extension<AppTokens>() ?? const AppTokens(AppPalette.light))
          .palette;
}
