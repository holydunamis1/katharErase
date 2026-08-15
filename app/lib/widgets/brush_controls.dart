import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/editable_image_state.dart';
import '../core/providers/image_edit_provider.dart';
import '../core/utils/constants.dart';
import '../generated/l10n/app_localizations.dart';

/// Brush size slider (1-50px), Erase/Restore toggle, opacity slider.
/// Controls image_edit_provider's currentBrushSizePx/currentBrushIsRestore/
/// currentBrushOpacity (Gap 7) — the settings baked into the NEXT stroke
/// drawn on editor_canvas.dart, not a history operation itself.
class BrushControls extends StatelessWidget {
  const BrushControls({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ImageEditProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context);

    return ValueListenableBuilder<EditableImageState>(
      valueListenable: provider,
      builder: (context, state, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          label: Text(l10n.brushErase),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text(l10n.brushRestore),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                      selected: {state.currentBrushIsRestore},
                      onSelectionChanged: (selected) {
                        provider.setBrushMode(isRestore: selected.first);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(l10n.brushSizeLabel, style: Theme.of(context).textTheme.labelMedium),
              Slider(
                value: state.currentBrushSizePx.clamp(
                  kBrushSizeMinPx,
                  kBrushSizeMaxPx,
                ),
                min: kBrushSizeMinPx,
                max: kBrushSizeMaxPx,
                onChanged: provider.setBrushSize,
              ),
              Text(l10n.brushOpacityLabel, style: Theme.of(context).textTheme.labelMedium),
              Slider(
                value: state.currentBrushOpacity.clamp(0.0, 1.0),
                min: 0.0,
                max: 1.0,
                onChanged: provider.setBrushOpacity,
              ),
            ],
          ),
        );
      },
    );
  }
}
