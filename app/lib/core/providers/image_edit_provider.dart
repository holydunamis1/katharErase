import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../models/editable_image_state.dart';
import '../services/mask_pipeline.dart';
import '../services/segmentation_service.dart';

/// Arguments for [_postprocessInIsolate] (kept sendable: only typed data).
class _PostprocessArgs {
  const _PostprocessArgs(this.probs, this.width, this.height);
  final Float32List probs;
  final int width;
  final int height;
}

Uint8List _postprocessInIsolate(_PostprocessArgs args) =>
    postprocessMask(args.probs, args.width, args.height);

class ImageEditProvider extends ValueNotifier<EditableImageState> {
  ImageEditProvider() : super(const EditableImageState());

  // Incremented on every loadImage so a late segmentation result for a
  // previous image can never overwrite the current one.
  int _loadToken = 0;

  void loadImage(String path, Size imageSize) {
    _loadToken++;
    value = EditableImageState(
      originalPath: path,
      imageSize: imageSize,
    );
  }

  /// Runs the model on [modelInput] (kModelInputSize x kModelInputSize x 3
  /// floats from preprocessRgb) and stores a full-size mask of
  /// [width] x [height] — the size of the image the editor is showing.
  Future<void> autoSegment(
    Float32List modelInput,
    int width,
    int height,
  ) async {
    final token = _loadToken;
    value = value.copyWith(isProcessing: true, autoSegmentationFailed: false);
    try {
      final probs = await SegmentationService.instance.infer(modelInput);
      final mask = await compute(
        _postprocessInIsolate,
        _PostprocessArgs(probs, width, height),
      );
      if (token != _loadToken) return;
      value = value.copyWith(
        baseMaskBytes: mask,
        maskBytes: mask,
        brushHistory: const [],
        historyIndex: -1,
        isProcessing: false,
        autoSegmentationFailed: false,
      );
    } catch (_) {
      if (token != _loadToken) return;
      value = value.copyWith(
        isProcessing: false,
        autoSegmentationFailed: true,
      );
    }
  }

  void setBrushSize(double sizePx) {
    value = value.copyWith(currentBrushSizePx: sizePx);
  }

  void setBrushMode({required bool isRestore}) {
    value = value.copyWith(currentBrushIsRestore: isRestore);
  }

  void setBrushOpacity(double opacity) {
    value = value.copyWith(currentBrushOpacity: opacity);
  }

  /// Fresh copy of the untouched base mask (or fully-opaque if there is none
  /// yet, e.g. when auto-segmentation failed and the user paints manually).
  Uint8List _baseMaskCopy(int length) {
    final base = value.baseMaskBytes;
    if (base != null && base.length == length) {
      return Uint8List.fromList(base);
    }
    return Uint8List(length)..fillRange(0, length, 255);
  }

  void applyBrushStroke(List<Offset> points) {
    final size = value.imageSize;
    if (size == null || points.isEmpty) return;
    final width = size.width.round();
    final height = size.height.round();

    final stroke = BrushStrokeEvent(
      points: points,
      brushSizePx: value.currentBrushSizePx,
      isRestore: value.currentBrushIsRestore,
      opacity: value.currentBrushOpacity,
    );
    final kept = value.brushHistory.sublist(0, value.historyIndex + 1);
    final newHistory = [...kept, stroke];

    // The current mask already reflects history[0..historyIndex], so the
    // new stroke can be painted on top of a copy — no full replay needed.
    final current = value.maskBytes;
    final mask = (current != null && current.length == width * height)
        ? Uint8List.fromList(current)
        : _baseMaskCopy(width * height);
    _paintStroke(mask, width, height, stroke);

    value = value.copyWith(
      brushHistory: newHistory,
      historyIndex: newHistory.length - 1,
      maskBytes: mask,
    );
  }

  void undo() {
    if (value.historyIndex < 0) return;
    _replayTo(value.historyIndex - 1);
  }

  void redo() {
    if (value.historyIndex + 1 >= value.brushHistory.length) return;
    _replayTo(value.historyIndex + 1);
  }

  bool get canUndo => value.historyIndex >= 0;
  bool get canRedo => value.historyIndex + 1 < value.brushHistory.length;

  /// Back to the untouched AI mask (or fully-opaque if none).
  void resetMask() {
    value = value.copyWith(brushHistory: const [], historyIndex: -1);
    _replayTo(-1);
  }

  /// Rebuilds maskBytes from the base mask plus history[0..index].
  void _replayTo(int index) {
    final size = value.imageSize;
    if (size == null) return;
    final width = size.width.round();
    final height = size.height.round();
    final mask = _baseMaskCopy(width * height);
    for (var i = 0; i <= index && i < value.brushHistory.length; i++) {
      _paintStroke(mask, width, height, value.brushHistory[i]);
    }
    value = value.copyWith(historyIndex: index, maskBytes: mask);
  }

  static void _paintStroke(
    Uint8List mask,
    int width,
    int height,
    BrushStrokeEvent stroke,
  ) {
    final radius = (stroke.brushSizePx / 2).round().clamp(1, 200);
    final delta = (255 * stroke.opacity).round().clamp(0, 255);
    for (final point in stroke.points) {
      final cx = point.dx.round();
      final cy = point.dy.round();
      for (var dy = -radius; dy <= radius; dy++) {
        final y = cy + dy;
        if (y < 0 || y >= height) continue;
        for (var dx = -radius; dx <= radius; dx++) {
          if (dx * dx + dy * dy > radius * radius) continue;
          final x = cx + dx;
          if (x < 0 || x >= width) continue;
          final idx = y * width + x;
          mask[idx] = stroke.isRestore
              ? (mask[idx] + delta).clamp(0, 255)
              : (mask[idx] - delta).clamp(0, 255);
        }
      }
    }
  }

  void setBackgroundType(BackgroundType type) {
    value = value.copyWith(backgroundType: type);
  }

  void setBgColor(Color color) {
    value = value.copyWith(backgroundType: BackgroundType.solidColor, bgColor: color);
  }

  void setBlurRadius(double radiusPx) {
    value = value.copyWith(
      backgroundType: BackgroundType.gaussianBlur,
      blurRadius: radiusPx,
    );
  }

  void setEdgeFeather(double featherPx) {
    value = value.copyWith(edgeFeather: featherPx);
  }

  void setZoom(double zoom) {
    value = value.copyWith(zoom: zoom);
  }

  void setPanOffset(Offset offset) {
    value = value.copyWith(panOffset: offset);
  }

  void toggleBeforeAfter() {
    value = value.copyWith(showBeforeAfter: !value.showBeforeAfter);
  }
}
