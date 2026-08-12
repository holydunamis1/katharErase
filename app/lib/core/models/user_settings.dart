import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_settings.freezed.dart';
part 'user_settings.g.dart';

/// Persisted via SharedPreferences (storage_service.dart Phase 2,
/// settings_provider.dart Phase 3). Drives theme_provider and the
/// onboarding gate in main.dart/router.dart.
///
/// Section 1: single language at v1 ("English only at v1", File 50), so
/// `language` is stored now for forward compatibility but only 'en' ships.
///
/// freezed ^3.2.5 syntax: `abstract class`, not plain `class` (breaking
/// change from freezed 2.x — see pubspec.yaml comment on the freezed pin).
@freezed
abstract class UserSettings with _$UserSettings {
  const factory UserSettings({
    @Default(ThemeMode.system) ThemeMode themeMode,
    @Default('en') String language,
    @Default(false) bool isAdFree,
    @Default(false) bool hasCompletedOnboarding,
    @Default(false) bool hasSeenAttPrompt,
  }) = _UserSettings;

  factory UserSettings.fromJson(Map<String, dynamic> json) =>
      _$UserSettingsFromJson(json);
}
