import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../models/editable_image_state.dart';
import '../services/segmentation_service.dart';

class ImageEditProvider extends ValueNotifier<EditableImageState> {
  ImageEditProvider() : super(const EditableImageState());

  void loadImage(String path, Size imageSize) {
    value = EditableImageState(
      originalPath: path,
      imageSize: imageSize,
    );
  }

  Future<void> autoSegment(Uint8List preprocessedInput) async {
    value = value.copyWith(isProcessing: true, autoSegmentationFailed: false);
    try {
      await SegmentationService.instance.loadModel();
      final maskBytes = await SegmentationService.instance.runInference(
        Float32List.fromList(
          preprocessedInput.map((b) => b / 255.0).toList(),
        ),
      );
      value = value.copyWith(
        maskBytes: maskBytes,
        isProcessing: false,
        autoSegmentationFailed: false,
      );
    } on SegmentationException {
      value = value.copyWith(
        isProcessing: false,
        autoSegmentationFailed: true,
      );
    } catch (e) {
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

  void applyBrushStroke(List<Offset> points) {
    final stroke = BrushStrokeEvent(
      points: points,
      brushSizePx: value.currentBrushSizePx,
      isRestore: value.currentBrushIsRestore,
      opacity: value.currentBrushOpacity,
    );
    final truncated = value.historyIndex + 1 < value.brushHistory.length
        ? value.brushHistory.sublist(0, value.historyIndex + 1)
        : value.brushHistory;
    final newHistory = [...truncated, stroke];
    value = value.copyWith(
      brushHistory: newHistory,
      historyIndex: newHistory.length - 1,
    );
    _recomputeMaskFromHistory();
  }

  void undo() {
    if (value.historyIndex < 0) return;
    value = value.copyWith(historyIndex: value.historyIndex - 1);
    _recomputeMaskFromHistory();
  }

  void redo() {
    if (value.historyIndex + 1 >= value.brushHistory.length) return;
    value = value.copyWith(historyIndex: value.historyIndex + 1);
    _recomputeMaskFromHistory();
  }

  bool get canUndo => value.historyIndex >= 0;
  bool get canRedo => value.historyIndex + 1 < value.brushHistory.length;

  void resetMask() {
    value = value.copyWith(
      brushHistory: const [],
      historyIndex: -1,
    );
    _recomputeMaskFromHistory();
  }

  void _recomputeMaskFromHistory() {
    if (value.imageSize == null) return;
    final width = value.imageSize!.width.round();
    final height = value.imageSize!.height.round();
    final buffer = Uint8List(width * height);

    if (value.maskBytes != null && value.maskBytes!.length == buffer.length) {
      buffer.setAll(0, value.maskBytes!);
    } else {
      buffer.fillRange(0, buffer.length, 255);
    }

    for (var i = 0; i <= value.historyIndex && i < value.brushHistory.length; i++) {
      final stroke = value.brushHistory[i];
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
            buffer[idx] = stroke.isRestore
                ? (buffer[idx] + delta).clamp(0, 255)
                : (buffer[idx] - delta).clamp(0, 255);
          }
        }
      }
    }

    value = value.copyWith(maskBytes: Uint8List.fromList(buffer));
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
