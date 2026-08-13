import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/editable_image_state.dart';
import '../core/providers/image_edit_provider.dart';
import '../core/utils/extensions.dart';

/// Animated icon button. Toggles showBeforeAfter in provider.
class BeforeAfterToggle extends StatelessWidget {
  const BeforeAfterToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ImageEditProvider>(context, listen: false);

    return ValueListenableBuilder<EditableImageState>(
      valueListenable: provider,
      builder: (context, state, _) {
        return SizedBox(
          width: ThemeAccess.minTouchTarget,
          height: ThemeAccess.minTouchTarget,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: provider.toggleBeforeAfter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  state.showBeforeAfter
                      ? Icons.visibility
                      : Icons.visibility_outlined,
                  key: ValueKey(state.showBeforeAfter),
                  color: context.colors.onSurface,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
