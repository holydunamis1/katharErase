import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/editable_image_state.dart';
import '../core/providers/image_edit_provider.dart';
import '../generated/l10n/app_localizations.dart';
import 'before_after_toggle.dart';
import 'icon_button_48.dart';

/// Row: Undo, Redo, Reset, Before/After, Export. All icon_button_48.
/// [onExport] is supplied by editor_screen.dart (Phase 5) — navigating to
/// export_bottom_sheet is a screen-level concern, kept out of this widget
/// to avoid widgets/ depending on screens/.
class BottomToolbar extends StatelessWidget {
  const BottomToolbar({super.key, required this.onExport});

  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ImageEditProvider>(context, listen: false);

    return ValueListenableBuilder<EditableImageState>(
      valueListenable: provider,
      builder: (context, state, _) {
        final l10n = AppLocalizations.of(context);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton48(
                icon: Icons.undo,
                tooltip: l10n.toolbarUndo,
                onPressed: provider.canUndo ? provider.undo : null,
              ),
              IconButton48(
                icon: Icons.redo,
                tooltip: l10n.toolbarRedo,
                onPressed: provider.canRedo ? provider.redo : null,
              ),
              IconButton48(
                icon: Icons.restart_alt,
                tooltip: l10n.toolbarReset,
                onPressed: () => _confirmReset(context, provider),
              ),
              const BeforeAfterToggle(),
              IconButton48(
                icon: Icons.ios_share,
                tooltip: l10n.toolbarExport,
                onPressed: onExport,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Feature 10 acceptance criteria: "One-tap reset to original state.
  /// Confirmation dialog."
  Future<void> _confirmReset(
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
}
