import 'package:flutter/material.dart';

import '../core/utils/extensions.dart';

/// Used for undo, redo, before/after, export, and anywhere else a
/// guaranteed 48x48dp touch target is required regardless of the icon's
/// visual size.
class IconButton48 extends StatelessWidget {
  const IconButton48({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: ThemeAccess.minTouchTarget,
      height: ThemeAccess.minTouchTarget,
      child: Material(
        color:
            isActive ? context.colors.primaryContainer : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Icon(
            icon,
            size: 24,
            color: onPressed == null
                ? context.colors.onSurface.withValues(alpha: 0.38)
                : context.colors.onSurface,
          ),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
