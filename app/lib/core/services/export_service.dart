import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

import '../models/editable_image_state.dart';
import '../models/export_job.dart';
import '../utils/constants.dart';

class ExportException implements Exception {
  const ExportException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() => 'ExportException: $message'
      '${cause != null ? ' (cause: $cause)' : ''}';
}

/// Composites image + mask + background into final output and applies
/// resize (Feature 14) during compositing. All pixel work goes through
/// package:image; WEBP output is a secondary re-encode step through
/// flutter_image_compress, since package:image cannot encode WEBP at all
/// (confirmed live — it's decode-only for that format). See pubspec.yaml
/// comment on flutter_image_compress for why this dependency exists.
class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  /// Main entry point: takes the original image bytes, the mask produced
  /// by segmentation_service.dart / brush edits, and the current editor
  /// state, and produces final export bytes in the requested format.
  Future<Uint8List> compositeAndExport({
    required Uint8List originalBytes,
    required Uint8List maskBytes,
    required BackgroundType backgroundType,
    Color? bgColor,
    double blurRadius = 0.0,
    double edgeFeather = 0.0,
    required ExportFormat format,
    required int quality,
    required ResizeMode resizeMode,
    int? customWidth,
    int? customHeight,
  }) async {
    try {
      final original = img.decodeImage(originalBytes);
      if (original == null) {
        throw const ExportException('Could not decode source image.');
      }

      var composited = _applyMaskAndBackground(
        original: original,
        maskBytes: maskBytes,
        backgroundType: backgroundType,
        bgColor: bgColor,
        blurRadius: blurRadius,
        edgeFeather: edgeFeather,
      );

      composited = _applyResize(
        composited,
        resizeMode: resizeMode,
        customWidth: customWidth,
        customHeight: customHeight,
      );

      switch (format) {
        case ExportFormat.png:
          return Uint8List.fromList(img.encodePng(composited));
        case ExportFormat.jpg:
          // JPEG has no alpha channel — flatten onto white first if the
          // background choice was "transparent" (Feature 4 + Feature 5
          // interaction the build plan doesn't explicitly resolve; white
          // flatten is the least-surprising default rather than black).
          final flattened = backgroundType == BackgroundType.transparent
              ? _flattenOntoWhite(composited)
              : composited;
          return Uint8List.fromList(
            img.encodeJpg(flattened, quality: quality),
          );
        case ExportFormat.webp:
          return _encodeWebpWithFallback(composited, quality: quality);
      }
    } on ExportException {
      rethrow;
    } catch (e) {
      throw ExportException('Export failed.', e);
    }
  }

  img.Image _applyMaskAndBackground({
    required img.Image original,
    required Uint8List maskBytes,
    required BackgroundType backgroundType,
    Color? bgColor,
    required double blurRadius,
    required double edgeFeather,
  }) {
    final result = img.Image(
      width: original.width,
      height: original.height,
      numChannels: 4, // RGBA — needed for transparent/blur backgrounds
    );

    // Edge feather (Feature 11): soften the mask itself before compositing,
    // not the final image, so it only affects the subject/background
    // boundary rather than blurring the whole frame.
    final effectiveMask = edgeFeather > 0
        ? _featherMask(maskBytes, original.width, original.height, edgeFeather)
        : maskBytes;

    img.Image? backgroundLayer;
    switch (backgroundType) {
      case BackgroundType.white:
        backgroundLayer = img.Image(width: original.width, height: original.height)
          ..clear(img.ColorRgb8(255, 255, 255));
        break;
      case BackgroundType.black:
        backgroundLayer = img.Image(width: original.width, height: original.height)
          ..clear(img.ColorRgb8(0, 0, 0));
        break;
      case BackgroundType.solidColor:
        final c = bgColor ?? const Color(0xFFFFFFFF);
        backgroundLayer = img.Image(width: original.width, height: original.height)
          ..clear(img.ColorRgb8(
            (c.r * 255).round(),
            (c.g * 255).round(),
            (c.b * 255).round(),
          ));
        break;
      case BackgroundType.gaussianBlur:
        backgroundLayer = img.gaussianBlur(
          img.Image.from(original),
          radius: blurRadius.round().clamp(
                kBackgroundBlurMinPx.round(),
                kBackgroundBlurMaxPx.round(),
              ),
        );
        break;
      case BackgroundType.transparent:
        backgroundLayer = null; // leave alpha=0 where mask says background
        break;
    }

    for (var y = 0; y < original.height; y++) {
      for (var x = 0; x < original.width; x++) {
        final maskIdx = y * original.width + x;
        final alpha = maskIdx < effectiveMask.length ? effectiveMask[maskIdx] : 0;
        final srcPixel = original.getPixel(x, y);

        if (backgroundLayer != null) {
          final bgPixel = backgroundLayer.getPixel(x, y);
          final blended = _blend(srcPixel, bgPixel, alpha / 255.0);
          result.setPixelRgba(x, y, blended.r, blended.g, blended.b, 255);
        } else {
          result.setPixelRgba(
            x,
            y,
            srcPixel.r.toInt(),
            srcPixel.g.toInt(),
            srcPixel.b.toInt(),
            alpha,
          );
        }
      }
    }
    return result;
  }

  ({int r, int g, int b}) _blend(img.Pixel fg, img.Pixel bg, double alpha) {
    return (
      r: (fg.r * alpha + bg.r * (1 - alpha)).round(),
      g: (fg.g * alpha + bg.g * (1 - alpha)).round(),
      b: (fg.b * alpha + bg.b * (1 - alpha)).round(),
    );
  }

  Uint8List _featherMask(
    Uint8List mask,
    int width,
    int height,
    double radiusPx,
  ) {
    // Represent mask as a single-channel image so package:image's own
    // gaussianBlur can do the softening — avoids hand-rolling a separable
    // blur kernel for a byte buffer.
    final maskImage = img.Image(width: width, height: height, numChannels: 1);
    for (var i = 0; i < mask.length && i < width * height; i++) {
      maskImage.setPixelR(i % width, i ~/ width, mask[i]);
    }
    final blurred = img.gaussianBlur(
      maskImage,
      radius: radiusPx.round().clamp(
            kEdgeFeatherMinPx.round(),
            kEdgeFeatherMaxPx.round(),
          ),
    );
    final out = Uint8List(width * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        out[y * width + x] = blurred.getPixel(x, y).r.toInt();
      }
    }
    return out;
  }

  img.Image _flattenOntoWhite(img.Image withAlpha) {
    final flat = img.Image(width: withAlpha.width, height: withAlpha.height);
    for (var y = 0; y < withAlpha.height; y++) {
      for (var x = 0; x < withAlpha.width; x++) {
        final p = withAlpha.getPixel(x, y);
        final a = p.a / 255.0;
        flat.setPixelRgb(
          x,
          y,
          (p.r * a + 255 * (1 - a)).round(),
          (p.g * a + 255 * (1 - a)).round(),
          (p.b * a + 255 * (1 - a)).round(),
        );
      }
    }
    return flat;
  }

  img.Image _applyResize(
    img.Image source, {
    required ResizeMode resizeMode,
    int? customWidth,
    int? customHeight,
  }) {
    Size? target;
    switch (resizeMode) {
      case ResizeMode.original:
        return source;
      case ResizeMode.square1x1:
        target = kResizePreset1x1;
        break;
      case ResizeMode.portrait4x5:
        target = kResizePreset4x5;
        break;
      case ResizeMode.portrait9x16:
        target = kResizePreset9x16;
        break;
      case ResizeMode.custom:
        if (customWidth == null || customHeight == null) {
          throw const ExportException(
            'Custom resize selected but width/height not provided.',
          );
        }
        target = Size(customWidth.toDouble(), customHeight.toDouble());
        break;
    }
    return img.copyResize(
      source,
      width: target.width.round(),
      height: target.height.round(),
    );
  }

  /// WEBP has no encoder in package:image (confirmed decode-only). Route
  /// through flutter_image_compress instead, encoding the already-
  /// composited PNG bytes. Falls back to JPG on UnsupportedError per the
  /// package's own documented pattern — WEBP requires a working platform
  /// encoder, not guaranteed on every device.
  Future<Uint8List> _encodeWebpWithFallback(
    img.Image composited, {
    required int quality,
  }) async {
    final pngBytes = Uint8List.fromList(img.encodePng(composited));
    try {
      final webpBytes = await FlutterImageCompress.compressWithList(
        pngBytes,
        format: CompressFormat.webp,
        quality: quality,
      );
      if (webpBytes.isEmpty) {
        throw const ExportException(
          'WEBP encode returned empty result, falling back to JPG.',
        );
      }
      return webpBytes;
    } on UnsupportedError catch (_) {
      // Documented fallback pattern from flutter_image_compress's own
      // README — this device/platform combination can't produce WEBP.
      return Uint8List.fromList(img.encodeJpg(composited, quality: quality));
    } catch (e) {
      throw ExportException('WEBP export failed.', e);
    }
  }
}
