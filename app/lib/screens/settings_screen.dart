import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/providers/settings_provider.dart';
import '../core/providers/theme_provider.dart';
import '../core/services/share_service.dart';
import '../generated/l10n/app_localizations.dart';
import '../platform/iap_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/toast_notification.dart';

// Pending real values per Section 1a's tracking table (Privacy Policy URL,
// Support URL both show "Pending" there). Bracket placeholders, not
// invented-looking values — matches the convention already established
// for AdMob unit IDs in constants.dart.
const String _kPrivacyPolicyUrl = 'https://katharerase.[YOUR_DOMAIN]/privacy.html';
const String _kSupportUrl = 'https://katharerase.[YOUR_DOMAIN]/support.html';
const String _kIosAppStoreId = '[YOUR_IOS_APP_STORE_ID]';
const String _kAndroidPackageId = 'com.zdmgold.katharerase'; // locked, Section 1a

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _openUrl(BuildContext context, String url) async {
    final l10n = AppLocalizations.of(context);
    if (url.contains('[YOUR_')) {
      ToastNotification.show(context, message: l10n.settingsLinkNotReady, type: ToastType.error);
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ToastNotification.show(context, message: l10n.settingsLinkOpenFailed, type: ToastType.error);
      }
    } catch (e) {
      if (context.mounted) {
        ToastNotification.show(context, message: l10n.settingsLinkOpenFailed, type: ToastType.error);
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
    final l10n = AppLocalizations.of(context);
    try {
      await ShareService.instance.shareText(
        '${l10n.settingsShareAppMessage} '
        'https://play.google.com/store/apps/details?id=$_kAndroidPackageId',
      );
    } catch (e) {
      if (context.mounted) {
        ToastNotification.show(context, message: l10n.settingsShareFailed, type: ToastType.error);
      }
    }
  }

  Future<void> _restorePurchases(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    try {
      await IapService.instance.restorePurchases();
      if (context.mounted) {
        ToastNotification.show(
          context,
          message: l10n.settingsRestoreRequested,
          type: ToastType.info,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ToastNotification.show(context, message: l10n.settingsRestoreFailed, type: ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    return AppScaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeProvider,
        builder: (context, themeMode, _) {
          return ListView(
            children: [
              ListTile(
                title: Text(l10n.settingsTheme),
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
              ListTile(
                title: Text(l10n.settingsLanguage),
                trailing: Text(l10n.settingsLanguageValue), // English only at v1
              ),
              const Divider(),
              ListTile(
                title: Text(l10n.settingsRestorePurchases),
                leading: const Icon(Icons.restore),
                onTap: () => _restorePurchases(context),
              ),
              ListTile(
                title: Text(l10n.settingsGoAdFree),
                leading: const Icon(Icons.block),
                onTap: () => context.push('/paywall'),
              ),
              const Divider(),
              ListTile(
                title: Text(l10n.settingsPrivacyPolicy),
                leading: const Icon(Icons.privacy_tip_outlined),
                onTap: () => _openUrl(context, _kPrivacyPolicyUrl),
              ),
              ListTile(
                title: Text(l10n.settingsSupport),
                leading: const Icon(Icons.help_outline),
                onTap: () => _openUrl(context, _kSupportUrl),
              ),
              ListTile(
                title: Text(l10n.settingsRateApp),
                leading: const Icon(Icons.star_border),
                onTap: () => _rateApp(context),
              ),
              ListTile(
                title: Text(l10n.settingsShareApp),
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
