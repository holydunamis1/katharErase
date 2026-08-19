import 'package:image/image.dart' as img;

class SegmentationService {
  SegmentationService._();
  static final SegmentationService instance = SegmentationService._();

  Future<img.Image> removeBackground(img.Image inputImage) async {
    return inputImage;
  }
}

class SegmentationException implements Exception {
  final String message;
  SegmentationException(this.message);
  @override
  String toString() => message;

  List<int>? get inputShape => _inputShape;
  List<int>? get outputShape => _outputShape;
  String? get lastError => _lastError;

}