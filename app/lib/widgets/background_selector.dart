import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/editable_image_state.dart';
import '../core/providers/image_edit_provider.dart';
import '../core/utils/constants.dart';

/// Grid: White, Transparent, Black, Color picker circle, Blur slider
/// (0-25px).
///
/// Color picker note: no color-picker package exists in Section 6's
/// dependency manifest. Rather than add one, this uses a preset swatch
/// grid built from Flutter's own widgets — a conservative scope choice,
/// not a full HSV-wheel picker. If the developer wants a true custom
/// color wheel later, that's a real scope addition to flag and decide on
/// its own, not something to add silently here.
const List<Color> _presetSwatches = [
  Color(0xFFEF4444),
  Color(0xFFF59E0B),
  Color(0xFFEAB308),
  Color(0xFF22C55E),
  Color(0xFF10B981),
  Color(0xFF06B6D4),
  Color(0xFF3B82F6),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFF6B7280),
];

class BackgroundSelector extends StatelessWidget {
  const BackgroundSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ImageEditProvider>(context, listen: false);

    return ValueListenableBuilder<EditableImageState>(
      valueListenable: provider,
      builder: (context, state, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _swatchButton(
                      label: 'White',
                      color: Colors.white,
                      selected: state.backgroundType == BackgroundType.white,
                      onTap: () => provider.setBackgroundType(BackgroundType.white),
                    ),
                    _swatchButton(
                      label: 'Transparent',
                      color: null,
                      selected:
                          state.backgroundType == BackgroundType.transparent,
                      onTap: () =>
                          provider.setBackgroundType(BackgroundType.transparent),
                    ),
                    _swatchButton(
                      label: 'Black',
                      color: Colors.black,
                      selected: state.backgroundType == BackgroundType.black,
                      onTap: () => provider.setBackgroundType(BackgroundType.black),
                    ),
                    for (final swatch in _presetSwatches)
                      _swatchButton(
                        label: null,
                        color: swatch,
                        selected: state.backgroundType == BackgroundType.solidColor &&
                            state.bgColor == swatch,
                        onTap: () => provider.setBgColor(swatch),
                      ),
                  ],
                ),
              ),
              if (state.backgroundType == BackgroundType.gaussianBlur ||
                  state.backgroundType == BackgroundType.solidColor) ...[
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Text('Blur', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: state.blurRadius.clamp(
                        kBackgroundBlurMinPx,
                        kBackgroundBlurMaxPx,
                      ),
                      min: kBackgroundBlurMinPx,
                      max: kBackgroundBlurMaxPx,
                      onChanged: provider.setBlurRadius,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _swatchButton({
    required String? label,
    required Color? color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? const Color(0xFF10B981) : const Color(0xFFE5E5EA),
                  width: selected ? 3 : 1,
                ),
              ),
              child: color == null
                  ? CustomPaint(painter: _CheckerboardIconPainter())
                  : null,
            ),
            if (label != null) ...[
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }
}

class _CheckerboardIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tile = 6.0;
    final light = Paint()..color = const Color(0xFFE0E0E0);
    final dark = Paint()..color = const Color(0xFFBDBDBD);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), light);
    for (var y = 0.0; y < size.height; y += tile) {
      for (var x = 0.0; x < size.width; x += tile) {
        if (((x ~/ tile) + (y ~/ tile)) % 2 == 0) {
          canvas.drawRect(Rect.fromLTWH(x, y, tile, tile), dark);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
