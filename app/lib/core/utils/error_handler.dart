import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Global error handling wired up in main.dart (Phase 6, File 47).
///
/// Architecture rule: every third-party call gets try/catch with a graceful
/// non-crashing fallback. This file is the last-resort net for anything
/// that slips through — it must never itself throw, and must never assume
/// a device debugger is attached (developer is phone-only, no DevTools).
class AppErrorHandler {
  AppErrorHandler._();

  /// Call once from main.dart before runApp().
  static void init() {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      // In debug builds this still prints to console (visible in CI debug
      // APK logcat). In release builds there is intentionally no crash
      // reporting SDK wired up per Section 1 (zero backend) — errors are
      // caught here purely to prevent a hard crash, not to phone home.
      if (kReleaseMode) {
        // Swallow in release: ErrorWidget.builder below shows the recovery UI.
      }
    };

    ErrorWidget.builder = (FlutterErrorDetails details) {
      return _FullScreenErrorRecovery(details: details);
    };
  }
}

class _FullScreenErrorRecovery extends StatelessWidget {
  const _FullScreenErrorRecovery({required this.details});

  final FlutterErrorDetails details;

  // Bracket placeholder, matching the convention already established in
  // Section 1a (e.g. [YOUR_ADMOB_BANNER_ANDROID]) — no support email exists
  // yet (Section 1a shows Support URL as Pending), so no plausible-looking
  // value is invented here.
  static const String _supportEmail = '[YOUR_SUPPORT_EMAIL]';

  @override
  Widget build(BuildContext context) {
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
              const Text(
                'Something went wrong',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Try again, or restart the app if this keeps happening.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  // Pop back to a known-good route rather than retrying the
                  // exact same broken build — matches "no feature blocked"
                  // philosophy: recovery, not a dead end.
                  Navigator.of(context).maybePop();
                },
                child: const Text('Go back'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  // Email report link — no in-app crash SDK per zero-backend
                  // rule. Actual mailto: launch wired in Phase 4/5 via
                  // url_launcher-equivalent once that dependency is added;
                  // left as a labeled action here since Phase 1 has no
                  // navigation/launch capability yet.
                },
                child: Text('Report via $_supportEmail'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
