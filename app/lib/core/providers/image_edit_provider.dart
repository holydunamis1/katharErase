import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageEditProvider extends ChangeNotifier {
  img.Image? originalImage;
  img.Image? processedImage;
  bool isLoading = false;

  void setImage(img.Image image) {
    originalImage = image;
    processedImage = image;
    notifyListeners();
  }
}
