import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
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

class SegmentationService {
  SegmentationService._({
    Future<TfliteInterpreterAdapter> Function(String assetPath)? loader,
  }) : _loader = loader ?? _defaultLoader;

  static final SegmentationService instance = SegmentationService._();

  @visibleForTesting
  SegmentationService.forTesting(
    Future<TfliteInterpreterAdapter> Function(String assetPath) loader,
  ) : _loader = loader;

  static Future<TfliteInterpreterAdapter> _defaultLoader(
    String assetPath,
  ) async {
    final options = InterpreterOptions()..threads = 4;
    final interpreter = await Interpreter.fromAsset(assetPath, options: options);
    return _RealTfliteInterpreterAdapter(interpreter);
  }

  final Future<TfliteInterpreterAdapter> Function(String assetPath) _loader;

  TfliteInterpreterAdapter? _interpreter;
  List<int>? _inputShape;
  List<int>? _outputShape;
  String? _lastError;

  bool get isLoaded => _interpreter != null;
  String? get lastError => _lastError;

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

      final reshapedInput = inputBuffer.reshape<dynamic>(inputShape);
      final reshapedOutput = List<double>.filled(outputLength, 0.0).reshape<dynamic>(outputShape);

      interpreter.run(reshapedInput, reshapedOutput);

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
