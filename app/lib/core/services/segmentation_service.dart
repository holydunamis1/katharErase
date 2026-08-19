import 'package:image/image.dart' as img;

class SegmentationService {
  static Future<img.Image> removeBackground(img.Image inputImage) async {
    return inputImage;
  }
}

class SegmentationException implements Exception {
  final String message;
  SegmentationException(this.message);
  @override
  String toString() => message;
}
