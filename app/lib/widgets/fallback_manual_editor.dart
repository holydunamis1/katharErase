import 'package:flutter/material.dart';

import '../generated/l10n/app_localizations.dart';
import 'brush_controls.dart';
import 'editor_canvas.dart';

/// Shown when auto-seg unavailable: "Your device doesn't support
/// automatic background removal. Use the manual eraser below." Brush
/// canvas only — stricter than editor_screen.dart's normal tabbed view
/// (Auto/Manual/Background all available). This widget is what
/// editor_screen.dart renders INSTEAD of the normal tab switcher when
/// EditableImageState.autoSegmentationFailed is true, not an addition
/// alongside it — Feature 1's fallback message plus a UI that can't
/// accidentally lead the user back to a broken Auto tab.
class FallbackManualEditor extends StatelessWidget {
  const FallbackManualEditor({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Material(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.editorSegmentationFailedMessage,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Expanded(child: EditorCanvas()),
        const BrushControls(),
      ],
    );
  }
}
