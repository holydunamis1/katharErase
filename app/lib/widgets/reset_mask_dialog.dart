import 'package:flutter/material.dart';

import '../core/providers/image_edit_provider.dart';
import '../generated/l10n/app_localizations.dart';

/// Feature 10: one-tap reset to the original AI result, behind a
/// confirmation dialog.
Future<void> confirmResetMask(
  BuildContext context,
  ImageEditProvider provider,
) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.resetConfirmTitle),
      content: Text(l10n.resetConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.resetConfirmCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.resetConfirmConfirm),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    provider.resetMask();
  }
}
