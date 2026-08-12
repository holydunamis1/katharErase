import 'dart:typed_data';
import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'editable_image_state.freezed.dart';

/// Background fill type for Feature 4 (Replace Background).
enum BackgroundType { white, transparent, black, solidColor, gaussianBlur }

/// A single brush stroke event, used to reconstruct undo/redo history
/// (Feature 6) without storing a full bitmap per step.
///
/// freezed ^3.2.5 syntax: classes using the factory constructor must be
/// declared `abstract class`, not plain `class` (breaking change from
/// freezed 2.x — see pubspec.yaml comment on the freezed pin).
@freezed
abstract class BrushStrokeEvent with _$BrushStrokeEvent {
  const factory BrushStrokeEvent({
    required List<Offset> points,
    required double brushSizePx,
    required bool isRestore, // false = erase, true = restore (Feature 3)
  }) = _BrushStrokeEvent;
}

/// Core editor state — drives editor_canvas.dart, brush_controls.dart,
/// background_selector.dart, and bottom_toolbar.dart (Phase 4).
///
/// NOTE: image bytes (processedBytes, maskBytes) are kept in memory only,
/// per Section 1's zero-backend / on-device-only architecture. History is
/// cleared on new image load per Feature 6's acceptance criteria.
@freezed
abstract class EditableImageState with _$EditableImageState {
  const factory EditableImageState({
    String? originalPath,
    Uint8List? processedBytes,
    Uint8List? maskBytes,
    @Default([]) List<BrushStrokeEvent> brushHistory,
    @Default(-1) int historyIndex,
    @Default(BackgroundType.transparent) BackgroundType backgroundType,
    Color? bgColor,
    @Default(0.0) double blurRadius,
    @Default(0.0) double edgeFeather,
    @Default(1.0) double zoom,
    @Default(Offset.zero) Offset panOffset,
    @Default(false) bool isProcessing,
    @Default(false) bool showBeforeAfter,
    Size? imageSize,
  }) = _EditableImageState;
}
