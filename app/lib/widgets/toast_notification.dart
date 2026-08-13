import 'package:flutter/material.dart';

import '../core/utils/constants.dart';
import '../core/utils/extensions.dart';

enum ToastType { success, error, info }

/// Snackbar-style transient message for "Saved," "Exported," errors.
/// Static utility rather than a widget, since Snackbars are shown via
/// ScaffoldMessenger, not composed into the widget tree directly.
class ToastNotification {
  ToastNotification._();

  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
  }) {
    final isDark = context.isDarkMode;
    final Color background;
    final IconData icon;
    switch (type) {
      case ToastType.success:
        background = isDark ? AppColors.successDark : AppColors.successLight;
        icon = Icons.check_circle_outline;
        break;
      case ToastType.error:
        background = isDark ? AppColors.errorDark : AppColors.errorLight;
        icon = Icons.error_outline;
        break;
      case ToastType.info:
        background = context.colors.inverseSurface;
        icon = Icons.info_outline;
        break;
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
