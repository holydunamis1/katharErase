import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../utils/constants.dart';

class SegmentationException implements Exception {
  const SegmentationException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'SegmentationException: $message'
      '${cause != null ? ' (cause: $cause)' : ''}';
}

/// Runs the model: takes the preprocessed input tensor (320x320x3 floats)
/// and returns the raw output tensor (320x320 floats).
typedef SegmentationRunner = Future<Float32List> Function(Float32List input);

/// On-device salient-object segmentation (U2-Netp, class-agnostic).
///
/// Inference runs in a background isolate so a slow phone never freezes the
/// UI. Pre/post-processing lives in mask_pipeline.dart.
class SegmentationService {
  SegmentationService._() : _runner = _defaultRunner;

  static final SegmentationService instance = SegmentationService._();

  /// Test-only constructor — injects a fake runner so the error-handling
  /// contract can be tested without a native TFLite library.
  @visibleForTesting
  SegmentationService.forTesting(SegmentationRunner runner) : _runner = runner;

  final SegmentationRunner _runner;
  String? _lastError;

  String? get lastError => _lastError;

  /// Returns the raw model output (kModelInputSize x kModelInputSize floats).
  /// Any failure is wrapped in [SegmentationException] so callers can fall
  /// back to the manual brush.
  Future<Float32List> infer(Float32List input) async {
    const expectedIn = kModelInputSize * kModelInputSize * 3;
    const expectedOut = kModelInputSize * kModelInputSize;
    if (input.length != expectedIn) {
      final err = 'Input has ${input.length} values, expected $expectedIn.';
      _lastError = err;
      throw SegmentationException(err);
    }
    try {
      final output = await _runner(input);
      if (output.length != expectedOut) {
        throw StateError(
          'Model returned ${output.length} values, expected $expectedOut.',
        );
      }
      _lastError = null;
      return output;
    } catch (e, stack) {
      _lastError = 'INFERENCE FAILURE: $e\n$stack';
      throw SegmentationException(
        'Background removal failed. Falling back to manual brush.',
        e,
      );
    }
  }

  static Future<Float32List> _defaultRunner(Float32List input) async {
    final data = await rootBundle.load(kSegmentationModelAsset);
    final modelBytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    return Isolate.run(() => _inferInIsolate(modelBytes, input));
  }
}

bool _sameShape(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Float32List _inferInIsolate(Uint8List modelBytes, Float32List input) {
  final options = InterpreterOptions()..threads = 4;
  final interpreter = Interpreter.fromBuffer(modelBytes, options: options);
  try {
    final inputShape = interpreter.getInputTensor(0).shape;
    final outputShape = interpreter.getOutputTensor(0).shape;
    const expectedIn = [1, kModelInputSize, kModelInputSize, 3];
    const expectedOut = [1, kModelInputSize, kModelInputSize, 1];
    if (!_sameShape(inputShape, expectedIn) ||
        !_sameShape(outputShape, expectedOut)) {
      throw StateError(
        'Unexpected model tensor shapes: input $inputShape, '
        'output $outputShape.',
      );
    }

    final outputLength = outputShape.reduce((a, b) => a * b);
    final reshapedInput = input.reshape<dynamic>(inputShape);
    final reshapedOutput =
        List<double>.filled(outputLength, 0.0).reshape<dynamic>(outputShape);

    interpreter.run(reshapedInput, reshapedOutput);

    final result = Float32List(outputLength);
    var index = 0;
    void flatten(dynamic element) {
      if (element is List) {
        for (final sub in element) {
          flatten(sub);
        }
      } else if (element is num && index < outputLength) {
        result[index] = element.toDouble();
        index++;
      }
    }

    flatten(reshapedOutput);
    return result;
  } finally {
    interpreter.close();
  }
}
