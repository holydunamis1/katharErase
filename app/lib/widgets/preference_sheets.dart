import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/user_settings.dart';
import '../core/providers/settings_provider.dart';
import '../core/providers/theme_provider.dart';
import '../generated/l10n/app_localizations.dart';

/// Stored value meaning "follow the device language".
const String kLanguageSystem = 'system';

/// Native names of the languages the app ships. Add an entry here whenever
/// a new lib/l10n/app_<code>.arb is added.
const Map<String, String> kLanguageNativeNames = {'en': 'English'};

String languageLabel(AppLocalizations l10n, String code) {
  if (code == kLanguageSystem) return l10n.languageSystemDefault;
  return kLanguageNativeNames[code] ?? code;
}

/// The Locale to force on MaterialApp, or null to follow the device.
Locale? localeForSetting(String code) {
  if (code == kLanguageSystem) return null;
  for (final locale in AppLocalizations.supportedLocales) {
    if (locale.languageCode == code) return locale;
  }
  return null;
}

String themeLabel(AppLocalizations l10n, ThemeMode mode) {
  switch (mode) {
    case ThemeMode.system:
      return l10n.themeOptionSystem;
    case ThemeMode.light:
      return l10n.themeOptionLight;
    case ThemeMode.dark:
      return l10n.themeOptionDark;
  }
}

Future<void> showLanguageSheet(BuildContext context) {
  final settings = Provider.of<SettingsProvider>(context, listen: false);
  final codes = <String>[
    kLanguageSystem,
    for (final locale in AppLocalizations.supportedLocales) locale.languageCode,
  ];
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext);
      return SafeArea(
        child: ValueListenableBuilder<UserSettings>(
          valueListenable: settings,
          builder: (context, current, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    l10n.languageSheetTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final code in codes)
                  ListTile(
                    title: Text(languageLabel(l10n, code)),
                    trailing: current.language == code
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () async {
                      await settings.setLanguage(code);
                      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                    },
                  ),
              ],
            );
          },
        ),
      );
    },
  );
}

Future<void> showThemeSheet(BuildContext context) {
  final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
  final settings = Provider.of<SettingsProvider>(context, listen: false);
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext);
      return SafeArea(
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: themeProvider,
          builder: (context, current, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    l10n.themeSheetTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final mode in ThemeMode.values)
                  ListTile(
                    title: Text(themeLabel(l10n, mode)),
                    trailing:
                        current == mode ? const Icon(Icons.check) : null,
                    onTap: () async {
                      await themeProvider.setThemeMode(mode);
                      await settings.syncThemeMode(mode);
                      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                    },
                  ),
              ],
            );
          },
        ),
      );
    },
  );
}
