import 'package:imagedeskpro/core/models/editable_image_state.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

enum BackgroundType { original, transparent, color, blur }
enum BrushMode { brush, eraser }

class EditableImageState {
  final img.Image? originalImage;
  final img.Image? processedImage;
  final BackgroundType backgroundType;
  final int bgColor;
  final double blurRadius;
  final BrushMode brushMode;
  final double brushSize;
  final double brushOpacity;
  final double edgeFeather;
  final bool showBefore;
  final bool canUndo;
  final bool canRedo;

  const EditableImageState({
    this.originalImage,
    this.processedImage,
    this.backgroundType = BackgroundType.original,
    this.bgColor = 0xFFFFFFFF,
    this.blurRadius = 0.0,
    this.brushMode = BrushMode.brush,
    this.brushSize = 20.0,
    this.brushOpacity = 1.0,
    this.edgeFeather = 0.0,
    this.showBefore = false,
    this.canUndo = false,
    this.canRedo = false,
  });

  EditableImageState copyWith({
    img.Image? originalImage,
    img.Image? processedImage,
    BackgroundType? backgroundType,
    int? bgColor,
    double? blurRadius,
    BrushMode? brushMode,
    double? brushSize,
    double? brushOpacity,
    double? edgeFeather,
    bool? showBefore,
    bool? canUndo,
    bool? canRedo,
  }) {
    return EditableImageState(
      originalImage: originalImage ?? this.originalImage,
      processedImage: processedImage ?? this.processedImage,
      backgroundType: backgroundType ?? this.backgroundType,
      bgColor: bgColor ?? this.bgColor,
      blurRadius: blurRadius ?? this.blurRadius,
      brushMode: brushMode ?? this.brushMode,
      brushSize: brushSize ?? this.brushSize,
      brushOpacity: brushOpacity ?? this.brushOpacity,
      edgeFeather: edgeFeather ?? this.edgeFeather,
      showBefore: showBefore ?? this.showBefore,
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
    );
  }
}

class ImageEditProvider extends ValueNotifier<EditableImageState> {
  ImageEditProvider() : super(const EditableImageState());

  Future<void> loadImage(dynamic imageSource) async {
    // Implementation stub for loading image
  }

  Future<void> autoSegment() async {
    // Implementation stub for auto segmentation
  }

  void setBackgroundType(BackgroundType type) {
    value = value.copyWith(backgroundType: type);
  }

  void setBgColor(int color) {
    value = value.copyWith(bgColor: color);
  }

  void setBlurRadius(double radius) {
    value = value.copyWith(blurRadius: radius);
  }

  void toggleBeforeAfter() {
    value = value.copyWith(showBefore: !value.showBefore);
  }

  void undo() {
    // Implementation stub for undo
  }

  void redo() {
    // Implementation stub for redo
  }

  void resetMask() {
    // Implementation stub for resetting mask
  }

  void setBrushMode(BrushMode mode) {
    value = value.copyWith(brushMode: mode);
  }

  void setBrushSize(double size) {
    value = value.copyWith(brushSize: size);
  }

  void setBrushOpacity(double opacity) {
    value = value.copyWith(brushOpacity: opacity);
  }

  void setEdgeFeather(double feather) {
    value = value.copyWith(edgeFeather: feather);
  }

  void applyBrushStroke(dynamic strokeDetails) {
    // Implementation stub for brush strokes
  }

  bool get canUndo => false;
  bool get canRedo => false;

}