import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _themeModeKey = 'theme_mode';

/// `ValueNotifier<ThemeMode>`, own SharedPreferences key, persists on
/// change.
///
/// This is the single source of truth for theme — not UserSettings.
/// themeMode, even though that field also exists on the persisted
/// settings model. Reasoning (Gap 6, resolved during Phase 3 design):
/// MaterialApp (app.dart, Phase 6) needs theme available as early as
/// possible at boot, before the full async UserSettings load completes,
/// to avoid a flash of the wrong theme. settings_provider mirrors this
/// value into UserSettings.themeMode for display/schema completeness on
/// the settings screen, but never writes it independently — avoiding two
/// independent writers to the same conceptual state.
class ThemeProvider extends ValueNotifier<ThemeMode> {
  ThemeProvider() : super(ThemeMode.system);

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_themeModeKey);
      if (stored != null) {
        value = ThemeMode.values.firstWhere(
          (m) => m.name == stored,
          orElse: () => ThemeMode.system,
        );
      }
    } catch (e) {
      // Corrupt/missing prefs -> keep default ThemeMode.system rather
      // than crash app boot.
    } finally {
      _loaded = true;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode.name);
    } catch (e) {
      // Persist failure shouldn't revert the in-memory value — user still
      // sees the theme they picked for this session even if it won't
      // survive relaunch.
    }
  }
}
