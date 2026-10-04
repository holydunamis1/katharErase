import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/providers/ad_provider.dart';
import 'core/providers/image_edit_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/subscription_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/utils/constants.dart';
import 'generated/l10n/app_localizations.dart';
import 'router.dart';

/// MaterialApp, GoRouter, Directionality, theme injection, Provider.value
/// tree.
///
/// Provider.value note: all five providers here are plain classes (four
/// extend ValueNotifier, AdProvider holds ValueNotifiers directly) — not
/// ChangeNotifier — so this uses plain `Provider<T>.value` for DI lookup
/// only, never ChangeNotifierProvider. Reactivity for theme comes from
/// the `ValueListenableBuilder<ThemeMode>` wrapping MaterialApp.router
/// below, not from package:provider's own change-notification mechanism,
/// consistent with the "ValueNotifier + ListenableBuilder, provider is
/// DI-only" architecture rule.
class KatharEraseApp extends StatelessWidget {
  const KatharEraseApp({
    super.key,
    required this.themeProvider,
    required this.settingsProvider,
    required this.subscriptionProvider,
    required this.adProvider,
    required this.imageEditProvider,
  });

  final ThemeProvider themeProvider;
  final SettingsProvider settingsProvider;
  final SubscriptionProvider subscriptionProvider;
  final AdProvider adProvider;
  final ImageEditProvider imageEditProvider;

  @override
  Widget build(BuildContext context) {
    final router = buildRouter(settingsProvider);

    return MultiProvider(
      providers: [
        Provider<ThemeProvider>.value(value: themeProvider),
        Provider<SettingsProvider>.value(value: settingsProvider),
        Provider<SubscriptionProvider>.value(value: subscriptionProvider),
        Provider<AdProvider>.value(value: adProvider),
        Provider<ImageEditProvider>.value(value: imageEditProvider),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeProvider,
        builder: (context, themeMode, _) {
          // Explicit top-level Directionality per Section 5, File 48 —
          // MaterialApp.router already resolves directionality internally
          // via its own Localizations, so this is intentional redundancy/
          // future-proofing rather than load-bearing for the English-only
          // v1 locale (Section 5, File 50), kept per the manifest's
          // explicit listing rather than silently dropped as "unneeded."
          return Directionality(
            textDirection: TextDirection.ltr,
            child: MaterialApp.router(
              title: 'KatharErase',
              debugShowCheckedModeBanner: false,
              themeMode: themeMode,
              theme: _buildTheme(Brightness.light),
              darkTheme: _buildTheme(Brightness.dark),
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          );
        },
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final accent = isDark ? AppColors.accentDark : AppColors.accentLight;
    final bgPrimary = isDark ? AppColors.bgPrimaryDark : AppColors.bgPrimaryLight;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: bgPrimary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: brightness,
        primary: accent,
        surface: bgPrimary,
        onSurface: textPrimary,
        error: isDark ? AppColors.errorDark : AppColors.errorLight,
      ),
      textTheme: Typography.material2021(platform: TargetPlatform.android)
          .black
          .apply(bodyColor: textPrimary, displayColor: textPrimary),
    );
  }
}
