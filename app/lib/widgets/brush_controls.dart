import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/models/editable_image_state.dart';
import '../core/providers/image_edit_provider.dart';
import '../core/utils/constants.dart';
import '../generated/l10n/app_localizations.dart';
import 'labeled_slider.dart';
import 'reset_mask_dialog.dart';

/// Brush tool: Erase/Restore, size, opacity, and Reset. These settings are
/// baked into the NEXT stroke drawn on the canvas.
class BrushControls extends StatelessWidget {
  const BrushControls({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ImageEditProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context);

    return ValueListenableBuilder<EditableImageState>(
      valueListenable: provider,
      builder: (context, state, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: false, label: Text(l10n.brushErase)),
                      ButtonSegment(value: true, label: Text(l10n.brushRestore)),
                    ],
                    selected: {state.currentBrushIsRestore},
                    onSelectionChanged: (selected) {
                      HapticFeedback.selectionClick();
                      provider.setBrushMode(isRestore: selected.first);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => confirmResetMask(context, provider),
                  child: Text(l10n.toolbarReset),
                ),
              ],
            ),
            LabeledSlider(
              label: l10n.brushSizeLabel,
              value: state.currentBrushSizePx,
              min: kBrushSizeMinPx,
              max: kBrushSizeMaxPx,
              onChanged: provider.setBrushSize,
              valueText: state.currentBrushSizePx.round().toString(),
            ),
            LabeledSlider(
              label: l10n.brushOpacityLabel,
              value: state.currentBrushOpacity,
              min: 0.0,
              max: 1.0,
              onChanged: provider.setBrushOpacity,
              valueText: '${(state.currentBrushOpacity * 100).round()}%',
            ),
          ],
        );
      },
    );
  }
}
