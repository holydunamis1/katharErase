import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'app.dart';
import 'core/providers/ad_provider.dart';
import 'core/providers/image_edit_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/subscription_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/storage_service.dart';
import 'core/utils/error_handler.dart';
import 'platform/ad_service.dart';
import 'core/utils/constants.dart';
import 'platform/notification_service.dart';

void _boot(String step) => debugPrint('BOOT $step');

Future<void> main() async {
  _boot('main start');
  WidgetsFlutterBinding.ensureInitialized();
  _boot('binding ready');
  AppErrorHandler.init();

  // Apache-2.0 attribution for the bundled segmentation model (U2-Netp),
  // shown on the in-app licenses page (Settings > Open-source licenses).
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/licenses/u2net_apache2.txt');
    yield LicenseEntryWithLineBreaks(
      ['U2-Net (u2netp) segmentation model'],
      'U2-Net: Going Deeper with Nested U-Structure for Salient Object '
      'Detection. Xuebin Qin, Zichen Zhang, Chenyang Huang, Masood Dehghan, '
      'Osmar R. Zaiane and Martin Jagersand. Pattern Recognition, 2020.\n'
      'https://github.com/xuebinqin/U-2-Net\n\n'
      'Changes: the pretrained u2netp weights were converted to TensorFlow '
      'Lite format and the model was trimmed to its single fused output.\n\n'
      '$text',
    );
  });

  // sqflite init (File 47) — eagerly open/create the database so any
  // first-use failure surfaces here, wrapped in try/catch, rather than
  // silently on first export/history read.
  await StorageService.instance.initialize();
  _boot('storage ready');

  // Providers are created here (not inside app.dart) so their async load
  // steps can complete before the first frame — avoids a flash of the
  // wrong theme or a moment where settings appear unset.
  final themeProvider = ThemeProvider();
  final settingsProvider = SettingsProvider();
  await themeProvider.load();
  await settingsProvider.load();
  _boot('theme+settings loaded');

  // AdMob init.
  await AdService.instance.initialize();
  _boot('ads initialized');

  // Local notifications (unfinished-edit reminders). Failure-safe.
  if (kNotificationsEnabled) {
    await NotificationService.instance.init();
  }
  _boot('notifications initialized');

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

  _boot('calling runApp');
  runApp(
    KatharEraseApp(
      themeProvider: themeProvider,
      settingsProvider: settingsProvider,
      subscriptionProvider: subscriptionProvider,
      adProvider: adProvider,
      imageEditProvider: imageEditProvider,
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => _boot('first frame drawn'));
}
