import 'package:flutter/material.dart';

/// Pure Dart + Flutter framework only — no dart:io, no plugin imports.
/// Safe for lib/core/ per the architecture rule.

extension StringFormatting on String {
  /// "background_removal" -> "Background Removal"
  String get toTitleCase {
    if (isEmpty) return this;
    return split(RegExp(r'[_\s]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  /// Truncate with ellipsis, used for filenames in recent_export_tile.dart.
  String truncateMiddle(int maxLength) {
    if (length <= maxLength) return this;
    final keep = (maxLength - 1) ~/ 2;
    return '${substring(0, keep)}…${substring(length - keep)}';
  }
}

extension FileSizeFormatting on int {
  /// Bytes -> human-readable string, e.g. 2_400_000 -> "2.3 MB".
  /// Used for export size display and the U2-Net model asset size check
  /// (Section 14 pre-build checklist references 5-25MB expected range).
  String get toHumanFileSize {
    if (this < 1024) return '$this B';
    if (this < 1024 * 1024) return '${(this / 1024).toStringAsFixed(1)} KB';
    if (this < 1024 * 1024 * 1024) {
      return '${(this / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(this / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

extension ThemeAccess on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get textStyles => Theme.of(this).textTheme;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Shorthand for the 48dp minimum touch target used across
  /// icon_button_48.dart and primary_button.dart (Phase 4).
  static const double minTouchTarget = 48.0;
}
