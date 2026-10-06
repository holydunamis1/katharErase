import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../generated/l10n/app_localizations.dart';

/// Global error handling wired up in main.dart (Phase 6, File 47).
///
/// Architecture rule: every third-party call gets try/catch with a
/// graceful non-crashing fallback. This file is the last-resort net for
/// anything that slips through — it must never itself throw, and must
/// never assume a device debugger is attached (developer is phone-only,
/// no DevTools).
class AppErrorHandler {
  AppErrorHandler._();

  /// Call once from main.dart before runApp().
  static void init() {
    FlutterError.onError = (FlutterErrorDetails details) {
      // Always log a short, cheap summary first (no stack parsing).
      final message = details.exceptionAsString();
      final stackLines = (details.stack?.toString() ?? '').split('\n');
      debugPrint(
        'APPERR ${details.exception.runtimeType}: '
        '${message.length > 600 ? message.substring(0, 600) : message}',
      );
      debugPrint('APPERR stack lines=${stackLines.length}');
      for (final line in stackLines.take(25)) {
        debugPrint('APPERR   $line');
      }
      // A runaway stack (e.g. infinite recursion) makes Flutter's debug
      // inspector spend minutes parsing it line by line, which froze the
      // whole app before it could show anything. Skip presenting those.
      if (stackLines.length > 300) return;
      FlutterError.presentError(details);
    };

    ErrorWidget.builder = (FlutterErrorDetails details) {
      return _FullScreenErrorRecovery(details: details);
    };
  }
}

class _FullScreenErrorRecovery extends StatelessWidget {
  const _FullScreenErrorRecovery({required this.details});

  final FlutterErrorDetails details;

  static const String _supportEmail = 'stmakarios@gmail.com';

  /// Localization retrofit note: this widget can render before
  /// MaterialApp/Localizations is mounted (e.g. an error during app.dart's
  /// own build), in which case AppLocalizations.of(context) itself throws.
  /// Unlike every other retrofitted file, this is a legitimate case for a
  /// genuine hardcoded-English fallback — the alternative is the crash
  /// recovery UI itself crashing, which defeats its entire purpose.
  ({String title, String body, String goBack, String report}) _strings(
    BuildContext context,
  ) {
    try {
      final l10n = AppLocalizations.of(context);
      return (
        title: l10n.errorScreenTitle,
        body: l10n.errorScreenBody,
        goBack: l10n.errorScreenGoBack,
        report: l10n.errorScreenReportEmail(_supportEmail),
      );
    } catch (e) {
      return (
        title: 'Something went wrong',
        body: 'Try again, or restart the app if this keeps happening.',
        goBack: 'Go back',
        report: 'Report via $_supportEmail',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = _strings(context);
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text(
                strings.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(strings.body, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).maybePop();
                },
                child: Text(strings.goBack),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  // Email report link — no in-app crash SDK per zero-
                  // backend rule. Actual mailto: launch can be wired via
                  // url_launcher (added Phase 5, Gap 10) now that it's
                  // available — left as a labeled action here since this
                  // file predates that dependency; a small follow-up
                  // could call launchUrl(Uri(scheme: 'mailto', ...)).
                },
                child: Text(strings.report),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
