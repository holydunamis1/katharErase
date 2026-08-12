import 'package:intl/intl.dart';

/// Locale-aware date formatting helpers used by recent_export_tile.dart
/// (Phase 4) and settings/export history screens.
///
/// Pure Dart, no dart:io, no plugin imports besides intl — safe for
/// lib/core/ per the architecture rule (unit-testable without a device).
class DateFormatter {
  DateFormatter._();

  /// e.g. "Aug 12, 2026"
  static String short(DateTime date, {String locale = 'en'}) {
    return DateFormat.yMMMd(locale).format(date);
  }

  /// e.g. "Aug 12, 2026, 3:45 PM"
  static String shortWithTime(DateTime date, {String locale = 'en'}) {
    return DateFormat.yMMMd(locale).add_jm().format(date);
  }

  /// e.g. "3:45 PM"
  static String timeOnly(DateTime date, {String locale = 'en'}) {
    return DateFormat.jm(locale).format(date);
  }

  /// Relative label for recent exports: "Today", "Yesterday", or short date.
  static String relative(DateTime date, {DateTime? now, String locale = 'en'}) {
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat.EEEE(locale).format(date); // "Monday"
    return short(date, locale: locale);
  }
}
