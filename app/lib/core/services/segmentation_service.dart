import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../utils/constants.dart';

/// Thrown when segmentation fails for any reason — model load failure,
/// unsupported device, inference error. Caught by image_edit_provider
/// (Phase 3) to trigger the manual-brush fallback per Feature 1's
/// acceptance criteria ("Falls back to manual message if model fails").
class SegmentationException implements Exception {
  const SegmentationException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'SegmentationException: $message'
      '${cause != null ? ' (cause: $cause)' : ''}';
}

/// Minimal seam covering only what SegmentationService actually needs
/// from tflite_flutter's Interpreter — added during Phase 8 so
/// test/segmentation_service_test.dart can inject a fake implementation
/// without loading a real .tflite model or touching native FFI code
/// (impossible in a standard `flutter test` unit test, and Section 14's
/// real model file doesn't exist yet regardless).
abstract class TfliteInterpreterAdapter {
  List<int> getInputShape();
  List<int> getOutputShape();
  void run(Object input, Object output);
  void close();
}

class _RealTfliteInterpreterAdapter implements TfliteInterpreterAdapter {
  _RealTfliteInterpreterAdapter(this._interpreter);
  final Interpreter _interpreter;

  @override
  List<int> getInputShape() => _interpreter.getInputTensor(0).shape;

  @override
  List<int> getOutputShape() => _interpreter.getOutputTensor(0).shape;

  @override
  void run(Object input, Object output) => _interpreter.run(input, output);

  @override
  void close() => _interpreter.close();
}

/// Path B (default): loads assets/models/segmentation.tflite via
/// tflite_flutter and runs inference on both iOS and Android.
///
/// *** OPEN BLOCKER — Section 14, not resolved by this file ***
/// This service is code-complete but its MODEL CHOICE is not verified.
/// The build plan corrected the model family to U2-Net (class-agnostic
/// salient object detection) based on research, but empirical quality
/// against real product photos (shoe, bag, bottle, food, electronics) on
/// a physical device has not been tested — it could not be tested during
/// build planning (no path to real product photos from that environment)
/// and cannot be tested here either. Do not treat this file as "done" in
/// the sense of validated — only in the sense of implementing Path B
/// correctly against whatever .tflite file is placed at
/// assets/models/segmentation.tflite. The developer must run the
/// Section 14 product-photo test before trusting this service's output
/// quality for Feature 1's non-person subjects.
///
/// This service intentionally queries the interpreter's actual input/
/// output tensor shapes at runtime (getInputShape/getOutputShape) rather
/// than hardcoding dimensions like 320x320 — the exact U2-Net export's
/// tensor shape is not yet known/committed, and hardcoding a guessed
/// shape would silently produce wrong results instead of a clear error
/// if the real model differs.
class SegmentationService {
  SegmentationService._({
    Future<TfliteInterpreterAdapter> Function(String assetPath)? loader,
  }) : _loader = loader ?? _defaultLoader;

  static final SegmentationService instance = SegmentationService._();

  /// Test-only constructor — injects a fake loader so unit tests can
  /// exercise loadModel()/runInference()'s logic (success path, failure
  /// path, exception wrapping, mask-length correctness) without a real
  /// model file or platform channel. See
  /// test/segmentation_service_test.dart.
  @visibleForTesting
  SegmentationService.forTesting(
    Future<TfliteInterpreterAdapter> Function(String assetPath) loader,
  ) : _loader = loader;

  static Future<TfliteInterpreterAdapter> _defaultLoader(
    String assetPath,
  ) async {
    final interpreter = await Interpreter.fromAsset(assetPath);
    return _RealTfliteInterpreterAdapter(interpreter);
  }

  final Future<TfliteInterpreterAdapter> Function(String assetPath) _loader;

  TfliteInterpreterAdapter? _interpreter;
  List<int>? _inputShape;
  List<int>? _outputShape;

  bool get isLoaded => _interpreter != null;

  /// Loads the bundled model. Call once (e.g. lazily on first use from
  /// image_edit_provider), not per-inference — model load is expensive.
  Future<void> loadModel() async {
    if (_interpreter != null) return;
    try {
      final interpreter = await _loader('assets/models/segmentation.tflite');
      _inputShape = interpreter.getInputShape();
      _outputShape = interpreter.getOutputShape();
      _interpreter = interpreter;
    } catch (e) {
      throw SegmentationException(
        'Failed to load segmentation model. Falling back to manual brush.',
        e,
      );
    }
  }

  /// Runs inference on a preprocessed input buffer and returns a raw mask
  /// buffer matching the model's output tensor shape. Preprocessing
  /// (resize to _inputShape, normalize to the model's expected range) and
  /// postprocessing (resize mask back to original image dimensions,
  /// threshold/alpha conversion) are the caller's responsibility
  /// (image_edit_provider, Phase 3) since they depend on export_service's
  /// image-handling utilities — kept out of this file to avoid a
  /// core/services -> core/services cross-dependency for something that's
  /// really image-processing, not segmentation.
  ///
  /// [inputBuffer] must already match the interpreter's expected input
  /// shape/type (query via [inputShape] before building it).
  Future<Uint8List> runInference(Float32List inputBuffer) async {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw const SegmentationException(
        'Segmentation model not loaded. Call loadModel() first.',
      );
    }
    try {
      final outputShape = _outputShape!;
      final outputLength = outputShape.reduce((a, b) => a * b);
      final output = Float32List(outputLength);
      interpreter.run(inputBuffer, output);
      // Convert float mask (typically 0.0-1.0 saliency) to 8-bit alpha
      // mask bytes. Real threshold/curve tuning happens once Section 14's
      // product-photo test results are in — using a straight linear scale
      // here as the honest starting point, not a tuned value.
      final maskBytes = Uint8List(outputLength);
      for (var i = 0; i < outputLength; i++) {
        maskBytes[i] = (output[i].clamp(0.0, 1.0) * 255).round();
      }
      return maskBytes;
    } catch (e) {
      throw SegmentationException('Inference failed.', e);
    }
  }

  List<int>? get inputShape => _inputShape;
  List<int>? get outputShape => _outputShape;

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _inputShape = null;
    _outputShape = null;
  }

  // Path A (Section 16): optional Android-only ML Kit enhancement.
  // Deliberately not implemented — kMlKitPathAEnabled stays false until
  // post-launch per the build plan. When enabled, this class gains an
  // Android-only branch that tries ML Kit first and falls back to the
  // TFLite path above. Not a v1 blocker.
  // ignore: unused_field
  static const bool _pathAReserved = kMlKitPathAEnabled;
}
