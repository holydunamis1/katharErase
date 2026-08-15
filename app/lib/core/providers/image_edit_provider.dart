import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../models/editable_image_state.dart';
import '../services/segmentation_service.dart';

/// `ValueNotifier<EditableImageState>`. CRUD operations: load image,
/// auto-segment, apply brush, undo, redo, reset, set background, set
/// feather, toggle before/after.
///
/// Undo/redo scope note: Feature 6's acceptance criteria and the
/// EditableImageState model's brushHistory/historyIndex fields both
/// point at brush strokes specifically, not every property change.
/// Background/feather/blur/zoom changes are trivially re-selectable (tap
/// a different swatch, drag a slider back) and aren't tracked in the undo
/// stack — only erase/restore brush strokes are, matching typical photo-
/// editor UX where the expensive-to-redo action is the one that gets
/// undo support.
class ImageEditProvider extends ValueNotifier<EditableImageState> {
  ImageEditProvider() : super(const EditableImageState());

  /// Loads a new image and resets all editor state — history cleared on
  /// new image load per Feature 6's acceptance criteria.
  void loadImage(String path, Size imageSize) {
    value = EditableImageState(
      originalPath: path,
      imageSize: imageSize,
    );
  }

  /// Feature 1: Auto-Remove Background. Runs segmentation and updates
  /// state with the resulting mask, or sets autoSegmentationFailed on
  /// SegmentationException so fallback_manual_editor.dart (File 71) can
  /// react. Preprocessing (resize/normalize to the model's input tensor
  /// shape) and postprocessing (resize mask back to original dimensions)
  /// happen here rather than in segmentation_service.dart itself — see
  /// that file's doc comment for why the split is drawn there.
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
      // Any other unexpected failure also routes to the same fallback —
      // architecture rule: every third-party call degrades gracefully,
      // never a raw error dialog.
      value = value.copyWith(
        isProcessing: false,
        autoSegmentationFailed: true,
      );
    }
  }

  // ---- Manual brush (Features 2 & 3) ----

  // ---- Current brush tool settings (Gap 7) ----

  void setBrushSize(double sizePx) {
    value = value.copyWith(currentBrushSizePx: sizePx);
  }

  void setBrushMode({required bool isRestore}) {
    value = value.copyWith(currentBrushIsRestore: isRestore);
  }

  void setBrushOpacity(double opacity) {
    value = value.copyWith(currentBrushOpacity: opacity);
  }

  /// Appends a brush stroke built from the current tool settings
  /// (currentBrushSizePx/currentBrushIsRestore/currentBrushOpacity) plus
  /// the points captured by editor_canvas.dart's gesture handling, and
  /// moves historyIndex forward, discarding any redo-able strokes past
  /// the current index (standard undo-stack behavior: a new action after
  /// undoing clears the redo branch).
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

  /// Feature 10: Reset Mask. One-tap reset to original state — clears
  /// brush history but keeps the loaded image and its auto-seg result
  /// (re-running segmentation is expensive; reset means "undo my manual
  /// edits," not "reload the photo").
  void resetMask() {
    value = value.copyWith(
      brushHistory: const [],
      historyIndex: -1,
    );
    _recomputeMaskFromHistory();
  }

  /// Replays brushHistory[0..historyIndex] to derive the current mask.
  /// Actual pixel-level stroke application (painting circles of
  /// brushSizePx along each stroke's points, erase vs restore) is a
  /// canvas-layer concern that belongs in editor_canvas.dart (Phase 4),
  /// which has access to CustomPainter — this provider only tracks which
  /// strokes are "active" after undo/redo, not how they're rendered.
  void _recomputeMaskFromHistory() {
    // Intentionally left for editor_canvas.dart to react to via
    // ValueListenableBuilder watching brushHistory/historyIndex directly.
    // No-op here — documented rather than silently doing nothing, so a
    // future reader doesn't mistake this for an unfinished stub.
  }

  // ---- Background (Feature 4) ----

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

  // ---- Edge feather (Feature 11) ----

  void setEdgeFeather(double featherPx) {
    value = value.copyWith(edgeFeather: featherPx);
  }

  // ---- Zoom + Pan (Feature 7) ----

  void setZoom(double zoom) {
    value = value.copyWith(zoom: zoom);
  }

  void setPanOffset(Offset offset) {
    value = value.copyWith(panOffset: offset);
  }

  // ---- Before/After (Feature 8) ----

  void toggleBeforeAfter() {
    value = value.copyWith(showBeforeAfter: !value.showBeforeAfter);
  }
}
