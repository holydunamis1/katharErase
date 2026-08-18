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
/// without loading a real .tflite model or touching native FFI code.
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
class SegmentationService {
  SegmentationService._({
    Future<TfliteInterpreterAdapter> Function(String assetPath)? loader,
  }) : _loader = loader ?? _defaultLoader;

  static final SegmentationService instance = SegmentationService._();

  /// Test-only constructor — injects a fake loader so unit tests can
  /// exercise loadModel()/runInference()'s logic without a real model file.
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
  String? _lastError;

  bool get isLoaded => _interpreter != null;
  
  /// Public getter exposing the raw crash exception string for UI debugging.
  String? get lastError => _lastError;

  /// Loads the bundled model. Captures native exceptions into [_lastError].
  Future<void> loadModel() async {
    if (_interpreter != null) return;
    _lastError = null;
    try {
      final interpreter = await _loader('assets/models/segmentation.tflite');
      _inputShape = interpreter.getInputShape();
      _outputShape = interpreter.getOutputShape();
      _interpreter = interpreter;
    } catch (e, stack) {
      _lastError = 'LOAD FAILURE: $e\n$stack';
      throw SegmentationException(
        'Failed to load segmentation model. Falling back to manual brush.',
        e,
      );
    }
  }

  /// Runs inference on a preprocessed input buffer and returns a raw mask.
  Future<Uint8List> runInference(Float32List inputBuffer) async {
    final interpreter = _interpreter;
    if (interpreter == null || _inputShape == null || _outputShape == null) {
      const err = 'Segmentation model not loaded. Call loadModel() first.';
      _lastError = err;
      throw const SegmentationException(err);
    }
    try {
      final inputShape = _inputShape!;
      final outputShape = _outputShape!;
      final outputLength = outputShape.reduce((a, b) => a * b);

      // Reshape flat 1D input into the multi-dimensional structure required by the model
      // Added <dynamic> to satisfy the strict inference_failure_on_function_invocation lint
      final reshapedInput = inputBuffer.reshape<dynamic>(inputShape);

      // Initialize a multi-dimensional array to hold the model output
      // Added <double> and <dynamic> to explicitly define types for the analyzer
      final reshapedOutput = List<double>.filled(outputLength, 0.0).reshape<dynamic>(outputShape);

      // Run inference
      interpreter.run(reshapedInput, reshapedOutput);

      // Recursively flatten the nested list back into a 1D Uint8List and quantize
      final maskBytes = Uint8List(outputLength);
      int index = 0;

      void flattenAndQuantize(dynamic element) {
        if (element is List) {
          for (var subElement in element) {
            flattenAndQuantize(subElement);
          }
        } else if (element is num) {
          maskBytes[index] = (element.clamp(0.0, 1.0) * 255).round();
          index++;
        }
      }

      flattenAndQuantize(reshapedOutput);
      return maskBytes;
    } catch (e, stack) {
      _lastError = 'INFERENCE FAILURE: $e\n$stack';
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
    _lastError = null;
  }

  // ignore: unused_field
  static const bool _pathAReserved = kMlKitPathAEnabled;
}
