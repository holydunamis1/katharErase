import 'package:flutter/material.dart';

import '../core/utils/extensions.dart';
import '../generated/l10n/app_localizations.dart';

/// First launch: "Tap Camera or Gallery to start." Shown on home_screen
/// (Phase 5) when there are no recent exports yet.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_camera_back_outlined,
              size: 64,
              color: context.colors.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.homeEmptyStateMessage,
              style: context.textStyles.bodyLarge?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
