import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:katharerase/core/services/segmentation_service.dart';

/// Hand-written fake rather than a mockito-generated mock — avoids adding
/// mockito as a new dev_dependency (another version-verification cycle)
/// for a seam this simple. Implements the same TfliteInterpreterAdapter
/// abstraction segmentation_service.dart was refactored to depend on
/// during Phase 8, specifically so this test file could exist without a
/// real .tflite model file (which doesn't exist yet — Section 14's open
/// blocker) or native FFI.
class FakeTfliteInterpreterAdapter implements TfliteInterpreterAdapter {
  FakeTfliteInterpreterAdapter({
    required List<int> inputShape,
    required List<int> outputShape,
    this.outputFillValue = 0.5,
  })  : _inputShape = inputShape,
        _outputShape = outputShape;

  final List<int> _inputShape;
  final List<int> _outputShape;

  /// Value written to every element of the output buffer during run() —
  /// lets tests assert the mask-byte conversion math (0.0-1.0 -> 0-255)
  /// independent of any real model's actual output distribution.
  final double outputFillValue;

  bool closed = false;
  int runCallCount = 0;

  @override
  List<int> getInputShape() => _inputShape;

  @override
  List<int> getOutputShape() => _outputShape;

  @override
  void run(Object input, Object output) {
    runCallCount++;
    if (output is Float32List) {
      output.fillRange(0, output.length, outputFillValue);
    }
  }

  @override
  void close() => closed = true;
}

void main() {
  group('SegmentationService.loadModel', () {
    test('success: loads shapes from the adapter', () async {
      final fake = FakeTfliteInterpreterAdapter(
        inputShape: [1, 320, 320, 3],
        outputShape: [1, 320, 320, 1],
      );
      final service = SegmentationService.forTesting((_) async => fake);

      await service.loadModel();

      expect(service.isLoaded, isTrue);
      expect(service.inputShape, [1, 320, 320, 3]);
      expect(service.outputShape, [1, 320, 320, 1]);
    });

    test('failure: wraps any loader exception in SegmentationException', () async {
      final service = SegmentationService.forTesting(
        (_) async => throw Exception('simulated asset load failure'),
      );

      expect(
        () => service.loadModel(),
        throwsA(isA<SegmentationException>()),
      );
    });

    test('is idempotent — second call does not reload', () async {
      var loadCount = 0;
      final fake = FakeTfliteInterpreterAdapter(
        inputShape: [1, 4, 4, 3],
        outputShape: [1, 4, 4, 1],
      );
      final service = SegmentationService.forTesting((_) async {
        loadCount++;
        return fake;
      });

      await service.loadModel();
      await service.loadModel();

      expect(loadCount, 1);
    });
  });

  group('SegmentationService.runInference', () {
    test(
      'fallback exception thrown when inference attempted before loadModel()',
      () async {
        final service = SegmentationService.forTesting(
          (_) async => throw Exception('unused — loadModel never called'),
        );

        expect(
          () => service.runInference(Float32List(16)),
          throwsA(isA<SegmentationException>()),
        );
      },
    );

    test('returns a mask matching the output tensor\'s total element count', () async {
      // Output shape [1, 4, 4, 1] -> 16 total elements.
      final fake = FakeTfliteInterpreterAdapter(
        inputShape: [1, 4, 4, 3],
        outputShape: [1, 4, 4, 1],
      );
      final service = SegmentationService.forTesting((_) async => fake);
      await service.loadModel();

      final mask = await service.runInference(Float32List(48)); // 4*4*3

      expect(mask.length, 16);
      expect(fake.runCallCount, 1);
    });

    test('converts 0.0-1.0 float output to 0-255 mask bytes correctly', () async {
      final fake = FakeTfliteInterpreterAdapter(
        inputShape: [1, 2, 2, 3],
        outputShape: [1, 2, 2, 1],
        outputFillValue: 1.0, // every pixel fully "foreground"
      );
      final service = SegmentationService.forTesting((_) async => fake);
      await service.loadModel();

      final mask = await service.runInference(Float32List(12));

      expect(mask.every((byte) => byte == 255), isTrue);
    });

    test('inference failure is wrapped in SegmentationException', () async {
      final fake = FakeTfliteInterpreterAdapter(
        inputShape: [1, 2, 2, 3],
        outputShape: [1, 2, 2, 1],
      )..runCallCount = 0;
      final service = SegmentationService.forTesting((_) async => fake);
      await service.loadModel();

      // Wrong-length input won't itself throw in this fake (run() only
      // checks output type), so instead simulate a genuine inference
      // failure by passing a null-shaped scenario the fake can't handle
      // gracefully — here, an empty output shape causes reduce() to
      // throw inside runInference, which should be caught and wrapped.
      final brokenFake = FakeTfliteInterpreterAdapter(
        inputShape: [1, 2, 2, 3],
        outputShape: const [], // reduce() on empty list throws
      );
      final brokenService = SegmentationService.forTesting((_) async => brokenFake);
      await brokenService.loadModel();

      expect(
        () => brokenService.runInference(Float32List(12)),
        throwsA(isA<SegmentationException>()),
      );
    });
  });

  group('SegmentationService.dispose', () {
    test('closes the adapter and clears cached state', () async {
      final fake = FakeTfliteInterpreterAdapter(
        inputShape: [1, 2, 2, 3],
        outputShape: [1, 2, 2, 1],
      );
      final service = SegmentationService.forTesting((_) async => fake);
      await service.loadModel();

      service.dispose();

      expect(fake.closed, isTrue);
      expect(service.isLoaded, isFalse);
      expect(service.inputShape, isNull);
      expect(service.outputShape, isNull);
    });
  });
}
