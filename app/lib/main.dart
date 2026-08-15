import 'package:flutter/material.dart';

import 'app.dart';
import 'core/providers/ad_provider.dart';
import 'core/providers/image_edit_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/subscription_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/storage_service.dart';
import 'core/utils/error_handler.dart';
import 'platform/ad_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppErrorHandler.init();

  // sqflite init (File 47) — eagerly open/create the database so any
  // first-use failure surfaces here, wrapped in try/catch, rather than
  // silently on first export/history read.
  await StorageService.instance.initialize();

  // Providers are created here (not inside app.dart) so their async load
  // steps can complete before the first frame — avoids a flash of the
  // wrong theme or a moment where settings appear unset.
  final themeProvider = ThemeProvider();
  final settingsProvider = SettingsProvider();
  await themeProvider.load();
  await settingsProvider.load();

  // AdMob init.
  await AdService.instance.initialize();

  // ATT request (post-onboarding) — safety net for RETURNING users whose
  // onboarding completed in a prior session but the app was killed before
  // ATT could show. The immediate first-run case is handled directly in
  // onboarding_screen.dart's _finish(), at the exact moment onboarding
  // completes — main.dart's startup code here runs before onboarding UI
  // ever shows in a first-run session, so it can't catch that case itself.
  if (settingsProvider.value.hasCompletedOnboarding &&
      !settingsProvider.value.hasSeenAttPrompt) {
    await AdService.instance.requestTrackingAuthorization();
    await settingsProvider.markAttPromptSeen();
  }

  // IAP init — subscriptionProvider seeds its initial value from
  // settingsProvider's cached isAdFree (Gap 6 resolution) before the live
  // purchaseStream/restorePurchases calls resolve.
  final subscriptionProvider = SubscriptionProvider(settingsProvider);
  subscriptionProvider.initialize();

  final adProvider = AdProvider(subscriptionProvider);
  final imageEditProvider = ImageEditProvider();

  runApp(
    KatharEraseApp(
      themeProvider: themeProvider,
      settingsProvider: settingsProvider,
      subscriptionProvider: subscriptionProvider,
      adProvider: adProvider,
      imageEditProvider: imageEditProvider,
    ),
  );
}
