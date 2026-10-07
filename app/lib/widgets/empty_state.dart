import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';
import '../generated/l10n/app_localizations.dart';

/// First launch: "Tap Camera or Gallery to start." Shown on the home screen
/// when there are no recent exports yet.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: p.accentTint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_photo_alternate_rounded,
                size: 40,
                color: p.accentText,
              ),
            ),
            const SizedBox(height: AppSpace.l),
            Text(
              l10n.homeEmptyStateMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: p.text2,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
