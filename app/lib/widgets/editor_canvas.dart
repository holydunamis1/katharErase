import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/editable_image_state.dart';
import '../core/providers/image_edit_provider.dart';
import '../core/utils/constants.dart';

/// InteractiveViewer -> CustomPaint. Displays original image, mask
/// composite, background layer. Handles zoom/pan.
///
/// This is where image_edit_provider's deferred _recomputeMaskFromHistory
/// no-op actually gets resolved (see that file's doc comment) — brush
/// strokes are replayed onto a live alpha buffer here, where CustomPainter
/// access makes that possible.
///
/// Coordinate space note: this widget sizes its CustomPaint/GestureDetector
/// to exactly match the image's native pixel dimensions (state.imageSize)
/// and lets InteractiveViewer handle all zoom/pan scaling around that.
/// Flutter's hit-testing reports GestureDetector.localPosition already
/// relative to the transformed child's own untransformed coordinate space,
/// so no manual matrix inversion against the TransformationController is
/// needed for brush points to land in the correct image-pixel location.
class EditorCanvas extends StatefulWidget {
  const EditorCanvas({super.key});

  @override
  State<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends State<EditorCanvas> {
  late final ImageEditProvider _provider;
  final TransformationController _transformController =
      TransformationController();

  ui.Image? _originalImage;
  String? _decodedForPath;

  ui.Image? _maskImage;
  int _maskCacheHistoryLength = -1;
  int _maskCacheHistoryIndex = -2;
  Uint8List? _maskCacheBaseBytes;

  List<Offset> _activeStrokePoints = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = Provider.of<ImageEditProvider>(context, listen: false);
    _provider.addListener(_onStateChanged);
    _onStateChanged();
  }

  @override
  void dispose() {
    _provider.removeListener(_onStateChanged);
    _transformController.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    final state = _provider.value;
    if (state.originalPath != null && state.originalPath != _decodedForPath) {
      _decodeOriginalImage(state.originalPath!);
    }
    _maybeRebuildMask(state);
  }

  Future<void> _decodeOriginalImage(String path) async {
    _decodedForPath = path;
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() => _originalImage = frame.image);
    } catch (e) {
      // Decode failure: leave _originalImage null. editor_screen.dart
      // (Phase 5) is responsible for surfacing this via error_handler's
      // recovery UI if the image genuinely can't be loaded — this widget
      // just doesn't render a broken image rather than crashing.
      // ignore: avoid_print
      print('Failed to decode original image: $e');
    }
  }

  /// Rebuilds the live alpha-mask ui.Image only when the underlying
  /// buffer actually changed (base maskBytes identity, or brush history
  /// length/index) — avoids redundant async image decoding on every
  /// unrelated state change (e.g. zoom, background color).
  Future<void> _maybeRebuildMask(EditableImageState state) async {
    final baseChanged = !identical(state.maskBytes, _maskCacheBaseBytes);
    final historyChanged =
        state.brushHistory.length != _maskCacheHistoryLength ||
            state.historyIndex != _maskCacheHistoryIndex;
    if (!baseChanged && !historyChanged) return;
    if (state.imageSize == null) return;

    _maskCacheBaseBytes = state.maskBytes;
    _maskCacheHistoryLength = state.brushHistory.length;
    _maskCacheHistoryIndex = state.historyIndex;

    final width = state.imageSize!.width.round();
    final height = state.imageSize!.height.round();
    if (width <= 0 || height <= 0) return;

    final alpha = _buildAlphaBuffer(state, width, height);
    final rgba = Uint8List(width * height * 4);
    for (var i = 0; i < width * height; i++) {
      rgba[i * 4] = 255;
      rgba[i * 4 + 1] = 255;
      rgba[i * 4 + 2] = 255;
      rgba[i * 4 + 3] = alpha[i];
    }

    final descriptor = await ui.ImmutableBuffer.fromUint8List(rgba);
    final imgDescriptor = ui.ImageDescriptor.raw(
      descriptor,
      width: width,
      height: height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await imgDescriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    if (!mounted) return;
    setState(() => _maskImage = frame.image);
  }

  /// Base buffer: state.maskBytes if auto-segmentation has run, else
  /// fully-opaque (255 everywhere) so manual-only brushing (Feature 2
  /// without ever running Feature 1) still has a mask to paint into.
  /// Then replays brushHistory[0..historyIndex] on top — erase strokes
  /// subtract alpha scaled by stroke.opacity, restore strokes add it,
  /// both clamped to [0, 255].
  Uint8List _buildAlphaBuffer(EditableImageState state, int width, int height) {
    final buffer = Uint8List(width * height);
    if (state.maskBytes != null && state.maskBytes!.length == buffer.length) {
      buffer.setAll(0, state.maskBytes!);
    } else {
      buffer.fillRange(0, buffer.length, 255);
    }

    for (var i = 0; i <= state.historyIndex && i < state.brushHistory.length; i++) {
      final stroke = state.brushHistory[i];
      final radius = (stroke.brushSizePx / 2).round().clamp(1, 200);
      final delta = (255 * stroke.opacity).round().clamp(0, 255);
      for (final point in stroke.points) {
        final cx = point.dx.round();
        final cy = point.dy.round();
        for (var dy = -radius; dy <= radius; dy++) {
          final y = cy + dy;
          if (y < 0 || y >= height) continue;
          for (var dx = -radius; dx <= radius; dx++) {
            if (dx * dx + dy * dy > radius * radius) continue; // circle mask
            final x = cx + dx;
            if (x < 0 || x >= width) continue;
            final idx = y * width + x;
            final current = buffer[idx];
            buffer[idx] = stroke.isRestore
                ? (current + delta).clamp(0, 255)
                : (current - delta).clamp(0, 255);
          }
        }
      }
    }
    return buffer;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EditableImageState>(
      valueListenable: _provider,
      builder: (context, state, _) {
        if (_originalImage == null || state.imageSize == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final size = state.imageSize!;

        return InteractiveViewer(
          transformationController: _transformController,
          minScale: kZoomMin,
          maxScale: kZoomMax,
          child: GestureDetector(
            onPanStart: (details) {
              if (state.showBeforeAfter) return;
              _activeStrokePoints = [details.localPosition];
            },
            onPanUpdate: (details) {
              if (state.showBeforeAfter) return;
              _activeStrokePoints = [..._activeStrokePoints, details.localPosition];
            },
            onPanEnd: (_) {
              if (state.showBeforeAfter || _activeStrokePoints.isEmpty) return;
              _provider.applyBrushStroke(_activeStrokePoints);
              _activeStrokePoints = [];
            },
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: CustomPaint(
                painter: _EditorPainter(
                  original: _originalImage!,
                  mask: state.showBeforeAfter ? null : _maskImage,
                  backgroundType: state.backgroundType,
                  bgColor: state.bgColor,
                  blurRadius: state.blurRadius,
                  edgeFeather: state.edgeFeather,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EditorPainter extends CustomPainter {
  _EditorPainter({
    required this.original,
    required this.mask,
    required this.backgroundType,
    required this.bgColor,
    required this.blurRadius,
    required this.edgeFeather,
  });

  final ui.Image original;
  final ui.Image? mask;
  final BackgroundType backgroundType;
  final Color? bgColor;
  final double blurRadius;
  final double edgeFeather;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    if (mask == null) {
      // Before/After (showing original) or mask not built yet.
      canvas.drawImageRect(
        original,
        Rect.fromLTWH(0, 0, original.width.toDouble(), original.height.toDouble()),
        rect,
        Paint(),
      );
      return;
    }

    // Background layer, drawn first so the masked subject composites on
    // top of it.
    switch (backgroundType) {
      case BackgroundType.white:
        canvas.drawRect(rect, Paint()..color = Colors.white);
        break;
      case BackgroundType.black:
        canvas.drawRect(rect, Paint()..color = Colors.black);
        break;
      case BackgroundType.solidColor:
        canvas.drawRect(rect, Paint()..color = bgColor ?? Colors.white);
        break;
      case BackgroundType.gaussianBlur:
        canvas.saveLayer(
          rect,
          Paint()
            ..imageFilter = ui.ImageFilter.blur(
              sigmaX: blurRadius,
              sigmaY: blurRadius,
            ),
        );
        canvas.drawImageRect(
          original,
          Rect.fromLTWH(0, 0, original.width.toDouble(), original.height.toDouble()),
          rect,
          Paint(),
        );
        canvas.restore();
        break;
      case BackgroundType.transparent:
        _drawTransparencyCheckerboard(canvas, rect);
        break;
    }

    // Masked subject, composited via saveLayer + BlendMode.dstIn against
    // the mask image, with edge feather approximated by blurring the
    // mask itself during this blend (real-time preview, matching
    // Feature 11's "real-time preview" requirement — final export applies
    // the authoritative version via export_service.dart's package:image
    // gaussianBlur on the mask buffer, this is the fast live-preview
    // equivalent using Skia's native ImageFilter.blur instead).
    canvas.saveLayer(rect, Paint());
    canvas.drawImageRect(
      original,
      Rect.fromLTWH(0, 0, original.width.toDouble(), original.height.toDouble()),
      rect,
      Paint(),
    );
    final maskPaint = Paint()..blendMode = BlendMode.dstIn;
    if (edgeFeather > 0) {
      maskPaint.imageFilter = ui.ImageFilter.blur(
        sigmaX: edgeFeather,
        sigmaY: edgeFeather,
      );
    }
    canvas.drawImageRect(
      mask!,
      Rect.fromLTWH(0, 0, mask!.width.toDouble(), mask!.height.toDouble()),
      rect,
      maskPaint,
    );
    canvas.restore();
  }

  void _drawTransparencyCheckerboard(Canvas canvas, Rect rect) {
    const tile = 12.0;
    final light = Paint()..color = const Color(0xFFE0E0E0);
    final dark = Paint()..color = const Color(0xFFBDBDBD);
    canvas.drawRect(rect, light);
    for (var y = 0.0; y < rect.height; y += tile) {
      for (var x = 0.0; x < rect.width; x += tile) {
        final isDark = ((x ~/ tile) + (y ~/ tile)) % 2 == 0;
        if (isDark) {
          canvas.drawRect(Rect.fromLTWH(x, y, tile, tile), dark);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EditorPainter oldDelegate) {
    return oldDelegate.original != original ||
        oldDelegate.mask != mask ||
        oldDelegate.backgroundType != backgroundType ||
        oldDelegate.bgColor != bgColor ||
        oldDelegate.blurRadius != blurRadius ||
        oldDelegate.edgeFeather != edgeFeather;
  }
}
