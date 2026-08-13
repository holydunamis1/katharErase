import 'package:flutter/material.dart';

/// Blocks input during segmentation/export. Wrap the screen content in a
/// Stack with this as the top layer, controlled by isProcessing (usually
/// from EditableImageState.isProcessing via ValueListenableBuilder in the
/// screen that owns it — this widget itself is presentation-only, no
/// provider access, to keep it reusable).
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.visible,
    this.message,
  });

  final bool visible;
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return Positioned.fill(
      child: AbsorbPointer(
        absorbing: true,
        child: Container(
          color: Colors.black.withValues(alpha: 0.55),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                if (message != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    message!,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
