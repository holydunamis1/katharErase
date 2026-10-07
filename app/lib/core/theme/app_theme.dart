import 'package:flutter/material.dart';

import 'app_tokens.dart';

const String kFontFamily = 'Inter';

TextTheme _textTheme(AppPalette p) {
  TextStyle s(double size, FontWeight weight,
          {double height = 1.3, double spacing = 0}) =>
      TextStyle(
        fontFamily: kFontFamily,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: spacing,
        color: p.text,
      );
  return TextTheme(
    displaySmall: s(32, FontWeight.w600, height: 1.15, spacing: -0.8),
    headlineMedium: s(28, FontWeight.w600, height: 1.15, spacing: -0.6),
    headlineSmall: s(24, FontWeight.w600, height: 1.2, spacing: -0.5),
    titleLarge: s(20, FontWeight.w600, height: 1.25, spacing: -0.3),
    titleMedium: s(17, FontWeight.w600, height: 1.3, spacing: -0.2),
    titleSmall: s(15, FontWeight.w600, height: 1.3, spacing: -0.1),
    bodyLarge: s(17, FontWeight.w400, height: 1.35, spacing: -0.2),
    bodyMedium: s(15, FontWeight.w400, height: 1.35, spacing: -0.1),
    bodySmall: s(13, FontWeight.w400, height: 1.35).copyWith(color: p.text2),
    labelLarge: s(15, FontWeight.w600, height: 1.2),
    labelMedium: s(13, FontWeight.w500, height: 1.2).copyWith(color: p.text2),
    labelSmall: s(11, FontWeight.w500, height: 1.2).copyWith(color: p.text2),
  );
}

/// The single source of truth for look and feel. Standard controls (buttons,
/// chips, sliders, switches, sheets, dialogs, list tiles, segmented
/// controls) are styled here once so every screen matches.
ThemeData buildAppTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
  final text = _textTheme(p);

  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.accent,
    onPrimary: p.onAccent,
    primaryContainer: p.accentTint,
    onPrimaryContainer: p.accentText,
    secondary: p.accent,
    onSecondary: p.onAccent,
    secondaryContainer: p.accentTint,
    onSecondaryContainer: p.accentText,
    error: p.danger,
    onError: p.onAccent,
    surface: p.surface,
    onSurface: p.text,
    onSurfaceVariant: p.text2,
    surfaceContainerHighest: p.muted,
    surfaceContainerHigh: p.muted,
    surfaceContainer: p.surface,
    outline: p.separator,
    outlineVariant: p.separator,
  );

  final roundedM = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.m),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: kFontFamily,
    textTheme: text,
    scaffoldBackgroundColor: p.background,
    extensions: [AppTokens(p)],
    // iOS-style slide + swipe-back on every platform.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      iconTheme: IconThemeData(color: p.text),
      actionsIconTheme: IconThemeData(color: p.text),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.l),
        side: BorderSide(color: p.separator, width: 0.5),
      ),
    ),
    dividerTheme: DividerThemeData(color: p.separator, thickness: 0.5, space: 0.5),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: roundedM,
        textStyle: text.labelLarge,
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        disabledBackgroundColor: p.muted,
        disabledForegroundColor: p.text3,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(64, 52),
        elevation: 0,
        shape: roundedM,
        textStyle: text.labelLarge,
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        disabledBackgroundColor: p.muted,
        disabledForegroundColor: p.text3,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: roundedM,
        textStyle: text.labelLarge,
        foregroundColor: p.text,
        side: BorderSide(color: p.separator),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.accentText,
        textStyle: text.labelLarge,
        minimumSize: const Size(44, 44),
      ),
    ),
    chipTheme: ChipThemeData(
      showCheckmark: false,
      backgroundColor: p.surface,
      selectedColor: p.accentTint,
      disabledColor: p.muted,
      shape: StadiumBorder(side: BorderSide(color: p.separator)),
      side: BorderSide(color: p.separator),
      labelStyle: text.labelLarge?.copyWith(color: p.text),
      secondaryLabelStyle: text.labelLarge?.copyWith(color: p.accentText),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.standard,
        minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
        ),
        side: WidgetStatePropertyAll(BorderSide(color: p.separator)),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? p.accentTint : p.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? p.accentText : p.text,
        ),
      ),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      activeTrackColor: p.accent,
      inactiveTrackColor: p.separator,
      thumbColor: p.accent,
      overlayColor: p.accent.withValues(alpha: 0.12),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? p.onAccent : Colors.white,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? p.accent
            : p.text3.withValues(alpha: 0.5),
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      modalBackgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: p.text3.withValues(alpha: 0.5),
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.l),
      ),
      titleTextStyle: text.titleMedium,
      contentTextStyle: text.bodyMedium,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.text2,
      textColor: p.text,
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodySmall,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
      minVerticalPadding: AppSpace.s,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.text,
      contentTextStyle: text.bodyMedium?.copyWith(color: p.surface),
      shape: roundedM,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
  );
}
