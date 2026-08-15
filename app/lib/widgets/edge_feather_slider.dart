import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/editable_image_state.dart';
import '../core/providers/image_edit_provider.dart';
import '../core/utils/constants.dart';
import '../generated/l10n/app_localizations.dart';

/// Slider 0-20px. Label: "Edge Smoothness."
class EdgeFeatherSlider extends StatelessWidget {
  const EdgeFeatherSlider({super.key});

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
              Text(l10n.edgeFeatherLabel, style: Theme.of(context).textTheme.labelMedium),
              Slider(
                value: state.edgeFeather.clamp(kEdgeFeatherMinPx, kEdgeFeatherMaxPx),
                min: kEdgeFeatherMinPx,
                max: kEdgeFeatherMaxPx,
                onChanged: provider.setEdgeFeather,
              ),
            ],
          ),
        );
      },
    );
  }
}
