import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/editable_image_state.dart';
import '../core/providers/image_edit_provider.dart';
import '../core/utils/constants.dart';

class EditorCanvas extends StatefulWidget {
  const EditorCanvas({super.key});

  @override
  State<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends State<EditorCanvas> {
  late final ImageEditProvider _provider;
  final TransformationController _transformController = TransformationController();

  ui.Image? _originalImage;
  ui.Image? _maskImage;
  String? _decodedForPath;

  List<Offset> _activeStrokePoints = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = Provider.of<ImageEditProvider>(context, listen: false);
    _provider.addListener(_onStateChanged);
    _onStateChanged();
  }

  @override
  void dispose() {
    _provider.removeListener(_onStateChanged);
    _transformController.dispose();
    _originalImage?.dispose();
    _maskImage?.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    final state = _provider.value;
    if (state.originalPath != null && state.originalPath != _decodedForPath) {
      _decodeOriginalImage(state.originalPath!);
    }
    if (state.maskBytes != null) {
      _updateMaskImage(state.maskBytes!);
    }
  }

  Future<void> _decodeOriginalImage(String path) async {
    _decodedForPath = path;
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() => _originalImage = frame.image);
    } catch (e) {
      debugPrint('Failed to decode original image: $e');
    }
  }

  Future<void> _updateMaskImage(Uint8List maskBytes) async {
    try {
      final width = _provider.value.imageSize?.width.round() ?? 0;
      final height = _provider.value.imageSize?.height.round() ?? 0;
      if (width <= 0 || height <= 0) return;
      if (maskBytes.length != width * height) {
        debugPrint(
          'Mask buffer size mismatch: expected ${width * height}, got ${maskBytes.length}',
        );
        return;
      }

      final rgba = Uint8List(width * height * 4);
      for (var i = 0; i < width * height; i++) {
        rgba[i * 4] = 255; // R
        rgba[i * 4 + 1] = 255; // G
        rgba[i * 4 + 2] = 255; // B
        rgba[i * 4 + 3] = maskBytes[i]; // A — the actual mask value
      }

      final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
      final descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: width,
        height: height,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      final codec = await descriptor.instantiateCodec();
      final frame = await codec.getNextFrame();
      buffer.dispose();
      if (!mounted) return;
      setState(() {
        _maskImage?.dispose();
        _maskImage = frame.image;
      });
    } catch (e) {
      debugPrint('Failed to create mask image: $e');
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (_provider.value.showBeforeAfter) return;
    _activeStrokePoints = [details.localPosition];
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_provider.value.showBeforeAfter) return;
    _activeStrokePoints = [..._activeStrokePoints, details.localPosition];
  }

  void _onPanEnd(DragEndDetails details) {
    if (_provider.value.showBeforeAfter || _activeStrokePoints.isEmpty) return;
    _provider.applyBrushStroke(_activeStrokePoints);
    _activeStrokePoints = [];
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EditableImageState>(
      valueListenable: _provider,
      builder: (context, state, _) {
        if (_originalImage == null || state.imageSize == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final size = state.imageSize!;

        return InteractiveViewer(
          transformationController: _transformController,
          minScale: kZoomMin,
          maxScale: kZoomMax,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: CustomPaint(
                painter: _EditorPainter(
                  original: _originalImage!,
                  maskImage: _maskImage,
                  backgroundType: state.backgroundType,
                  bgColor: state.bgColor,
                  blurRadius: state.blurRadius,
                  edgeFeather: state.edgeFeather,
                  imageSize: size,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EditorPainter extends CustomPainter {
  _EditorPainter({
    required this.original,
    this.maskImage,
    required this.backgroundType,
    required this.bgColor,
    required this.blurRadius,
    required this.edgeFeather,
    required this.imageSize,
  });

  final ui.Image original;
  final ui.Image? maskImage;
  final BackgroundType backgroundType;
  final Color? bgColor;
  final double blurRadius;
  final double edgeFeather;
  final Size imageSize;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    switch (backgroundType) {
      case BackgroundType.white:
        canvas.drawRect(rect, Paint()..color = Colors.white);
        break;
      case BackgroundType.black:
        canvas.drawRect(rect, Paint()..color = Colors.black);
        break;
      case BackgroundType.solidColor:
        canvas.drawRect(rect, Paint()..color = bgColor ?? Colors.white);
        break;
      case BackgroundType.gaussianBlur:
        _drawBlurredBackground(canvas, rect);
        break;
      case BackgroundType.transparent:
        _drawTransparencyCheckerboard(canvas, rect);
        break;
    }

    if (maskImage != null) {
      canvas.saveLayer(rect, Paint());
      canvas.drawImageRect(
        original,
        Rect.fromLTWH(0, 0, original.width.toDouble(), original.height.toDouble()),
        rect,
        Paint(),
      );
      final maskPaint = Paint()..blendMode = BlendMode.dstIn;
      if (edgeFeather > 0) {
        maskPaint.imageFilter = ui.ImageFilter.blur(
          sigmaX: edgeFeather,
          sigmaY: edgeFeather,
        );
      }
      canvas.drawImageRect(
        maskImage!,
        Rect.fromLTWH(0, 0, maskImage!.width.toDouble(), maskImage!.height.toDouble()),
        rect,
        maskPaint,
      );
      canvas.restore();
    } else {
      canvas.drawImageRect(
        original,
        Rect.fromLTWH(0, 0, original.width.toDouble(), original.height.toDouble()),
        rect,
        Paint(),
      );
    }
  }

  void _drawBlurredBackground(Canvas canvas, Rect rect) {
    canvas.saveLayer(
      rect,
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: blurRadius,
          sigmaY: blurRadius,
        ),
    );
    canvas.drawImageRect(
      original,
      Rect.fromLTWH(0, 0, original.width.toDouble(), original.height.toDouble()),
      rect,
      Paint(),
    );
    canvas.restore();
  }

  void _drawTransparencyCheckerboard(Canvas canvas, Rect rect) {
    const tile = 12.0;
    final light = Paint()..color = const Color(0xFFE0E0E0);
    final dark = Paint()..color = const Color(0xFFBDBDBD);
    canvas.drawRect(rect, light);
    for (var y = 0.0; y < rect.height; y += tile) {
      for (var x = 0.0; x < rect.width; x += tile) {
        final isDark = ((x ~/ tile) + (y ~/ tile)) % 2 == 0;
        if (isDark) {
          canvas.drawRect(Rect.fromLTWH(x, y, tile, tile), dark);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EditorPainter oldDelegate) {
    return oldDelegate.original != original ||
        oldDelegate.maskImage != maskImage ||
        oldDelegate.backgroundType != backgroundType ||
        oldDelegate.bgColor != bgColor ||
        oldDelegate.blurRadius != blurRadius ||
        oldDelegate.edgeFeather != edgeFeather;
  }
}
