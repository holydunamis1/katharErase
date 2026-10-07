import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/editable_image_state.dart';
import '../core/providers/image_edit_provider.dart';
import '../core/utils/constants.dart';
import '../generated/l10n/app_localizations.dart';
import 'labeled_slider.dart';

/// Cut-out tool: Edge Smoothness (0-20 px).
class EdgeFeatherSlider extends StatelessWidget {
  const EdgeFeatherSlider({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ImageEditProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context);

    return ValueListenableBuilder<EditableImageState>(
      valueListenable: provider,
      builder: (context, state, _) {
        return LabeledSlider(
          label: l10n.edgeFeatherLabel,
          value: state.edgeFeather,
          min: kEdgeFeatherMinPx,
          max: kEdgeFeatherMaxPx,
          onChanged: provider.setEdgeFeather,
          valueText: state.edgeFeather.round().toString(),
        );
      },
    );
  }
}
