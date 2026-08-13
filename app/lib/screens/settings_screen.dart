import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/providers/settings_provider.dart';
import '../core/providers/theme_provider.dart';
import '../core/services/share_service.dart';
import '../platform/iap_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/toast_notification.dart';

// Pending real values per Section 1a's tracking table (Privacy Policy URL,
// Support URL both show "Pending" there). Bracket placeholders, not
// invented-looking values — matches the convention already established
// for AdMob unit IDs in constants.dart.
const String _kPrivacyPolicyUrl = 'https://katharerase.[YOUR_DOMAIN]/privacy.html';
const String _kSupportUrl = 'https://katharerase.[YOUR_DOMAIN]/support.html';
// iOS numeric App Store ID isn't assigned until App Store Connect
// registration (Section 14 pre-build checklist) — also a placeholder.
const String _kIosAppStoreId = '[YOUR_IOS_APP_STORE_ID]';
const String _kAndroidPackageId = 'com.zdmgold.katharerase'; // locked, Section 1a

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _openUrl(BuildContext context, String url) async {
    if (url.contains('[YOUR_')) {
      // Placeholder not yet filled in — don't attempt to launch a
      // literal bracket-string URL.
      ToastNotification.show(
        context,
        message: "This link isn't set up yet.",
        type: ToastType.error,
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ToastNotification.show(context, message: 'Could not open link.', type: ToastType.error);
      }
    } catch (e) {
      if (context.mounted) {
        ToastNotification.show(context, message: 'Could not open link.', type: ToastType.error);
      }
    }
  }

  Future<void> _rateApp(BuildContext context) async {
    final url = Theme.of(context).platform == TargetPlatform.iOS
        ? 'https://apps.apple.com/app/id$_kIosAppStoreId?action=write-review'
        : 'https://play.google.com/store/apps/details?id=$_kAndroidPackageId';
    await _openUrl(context, url);
  }

  Future<void> _shareApp(BuildContext context) async {
    try {
      await ShareService.instance.shareText(
        'Remove photo backgrounds instantly with KatharErase — free, no '
        'watermark. https://play.google.com/store/apps/details?id=$_kAndroidPackageId',
      );
    } catch (e) {
      if (context.mounted) {
        ToastNotification.show(context, message: 'Could not share.', type: ToastType.error);
      }
    }
  }

  Future<void> _restorePurchases(BuildContext context) async {
    try {
      await IapService.instance.restorePurchases();
      if (context.mounted) {
        ToastNotification.show(
          context,
          message: 'Restore requested — check back in a moment.',
          type: ToastType.info,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ToastNotification.show(context, message: 'Restore failed.', type: ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    return AppScaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeProvider,
        builder: (context, themeMode, _) {
          return ListView(
            children: [
              ListTile(
                title: const Text('Theme'),
                trailing: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode)),
                    ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto)),
                    ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode)),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (s) async {
                    await themeProvider.setThemeMode(s.first);
                    await settingsProvider.syncThemeMode(s.first);
                  },
                ),
              ),
              const ListTile(
                title: Text('Language'),
                trailing: Text('English'), // English only at v1, Section 5 File 50
              ),
              const Divider(),
              ListTile(
                title: const Text('Restore Purchases'),
                leading: const Icon(Icons.restore),
                onTap: () => _restorePurchases(context),
              ),
              ListTile(
                title: const Text('Go Ad-Free'),
                leading: const Icon(Icons.block),
                onTap: () => context.push('/paywall'),
              ),
              const Divider(),
              ListTile(
                title: const Text('Privacy Policy'),
                leading: const Icon(Icons.privacy_tip_outlined),
                onTap: () => _openUrl(context, _kPrivacyPolicyUrl),
              ),
              ListTile(
                title: const Text('Support'),
                leading: const Icon(Icons.help_outline),
                onTap: () => _openUrl(context, _kSupportUrl),
              ),
              ListTile(
                title: const Text('Rate App'),
                leading: const Icon(Icons.star_border),
                onTap: () => _rateApp(context),
              ),
              ListTile(
                title: const Text('Share App'),
                leading: const Icon(Icons.ios_share),
                onTap: () => _shareApp(context),
              ),
            ],
          );
        },
      ),
    );
  }
}
