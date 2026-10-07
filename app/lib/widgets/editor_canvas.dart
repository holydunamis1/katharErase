import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/editable_image_state.dart';
import '../core/providers/image_edit_provider.dart';
import '../core/utils/constants.dart';
import '../generated/l10n/app_localizations.dart';

/// Where a photo of [image] size sits inside [viewport]: scaled uniformly
/// (never stretched) and centered, so the picture keeps its true
/// proportions whatever space the tool panel leaves for the canvas.
Rect fitImageRect(Size image, Size viewport) {
  if (image.width <= 0 || image.height <= 0) return Offset.zero & viewport;
  final scale = math.min(
    viewport.width / image.width,
    viewport.height / image.height,
  );
  final w = image.width * scale;
  final h = image.height * scale;
  return Rect.fromLTWH(
    (viewport.width - w) / 2,
    (viewport.height - h) / 2,
    w,
    h,
  );
}

/// A brush stroke in progress: points in IMAGE pixels (for painting), and
/// the finger position in canvas units (for the brush-size circle).
class _LiveStroke {
  const _LiveStroke(this.imagePoints, this.cursor);

  final List<Offset> imagePoints;
  final Offset? cursor;

  static const _LiveStroke none = _LiveStroke(<Offset>[], null);
}

class EditorCanvas extends StatefulWidget {
  /// [brushEnabled]: one finger paints (Manual tool); two fingers still
  /// pinch-zoom. When false, one finger pans the zoomed photo instead.
  const EditorCanvas({super.key, this.brushEnabled = false});

  final bool brushEnabled;

  @override
  State<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends State<EditorCanvas> {
  late final ImageEditProvider _provider;
  final TransformationController _transformController = TransformationController();
  final ValueNotifier<_LiveStroke> _live = ValueNotifier(_LiveStroke.none);

  ui.Image? _originalImage;
  ui.Image? _maskImage;
  String? _decodedForPath;
  // The mask buffer _maskImage was built from, and a counter that lets a
  // slow build be discarded if a newer mask arrived meanwhile. Rebuilding
  // the full-size mask image is expensive, so it only happens when the
  // mask itself changed (not on zoom, pan or slider changes).
  Uint8List? _maskSource;
  int _maskGeneration = 0;

  // Brush gesture state (raw pointers, so brush and pinch never fight over
  // the gesture arena).
  int _pointers = 0;
  bool _strokeActive = false;
  List<Offset> _strokeImagePoints = [];
  bool _hintDismissed = false;

  // Layout of the photo inside the viewport, refreshed on every build.
  Rect _fit = Rect.zero;
  double _fitScale = 1.0;

  @override
  void initState() {
    super.initState();
    _provider = Provider.of<ImageEditProvider>(context, listen: false);
    _provider.addListener(_onStateChanged);
    _onStateChanged();
  }

  @override
  void dispose() {
    _provider.removeListener(_onStateChanged);
    _transformController.dispose();
    _live.dispose();
    _originalImage?.dispose();
    _maskImage?.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    final state = _provider.value;
    if (state.originalPath != null && state.originalPath != _decodedForPath) {
      _decodeOriginalImage(state.originalPath!);
    }
    if (!identical(state.maskBytes, _maskSource)) {
      _maskSource = state.maskBytes;
      if (state.maskBytes != null) {
        _updateMaskImage(state.maskBytes!);
      } else if (_maskImage != null) {
        _maskGeneration++;
        setState(() {
          _maskImage?.dispose();
          _maskImage = null;
        });
      }
    }
  }

  Future<void> _decodeOriginalImage(String path) async {
    _decodedForPath = path;
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      _transformController.value = Matrix4.identity();
      setState(() => _originalImage = frame.image);
    } catch (e) {
      debugPrint('Failed to decode original image: $e');
    }
  }

  Future<void> _updateMaskImage(Uint8List maskBytes) async {
    final generation = ++_maskGeneration;
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
      if (!mounted || generation != _maskGeneration) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _maskImage?.dispose();
        _maskImage = frame.image;
      });
    } catch (e) {
      debugPrint('Failed to create mask image: $e');
    }
  }

  Offset _toImage(Offset canvasPoint) => Offset(
        (canvasPoint.dx - _fit.left) / _fitScale,
        (canvasPoint.dy - _fit.top) / _fitScale,
      );

  double get _zoom => _transformController.value.getMaxScaleOnAxis();

  /// Brush diameter in image pixels. The slider is in on-screen pixels, so
  /// a stroke covers the same visible size whatever the photo's resolution,
  /// and zooming in gives finer control.
  double _brushImagePx(EditableImageState state) =>
      state.currentBrushSizePx / (_fitScale * _zoom);

  bool get _brushActive =>
      widget.brushEnabled && !_provider.value.showBeforeAfter;

  void _onPointerDown(PointerDownEvent e) {
    _pointers++;
    if (!_brushActive) return;
    if (_pointers == 1) {
      _strokeActive = true;
      _strokeImagePoints = [_toImage(e.localPosition)];
      _live.value = _LiveStroke(_strokeImagePoints, e.localPosition);
      if (!_hintDismissed) setState(() => _hintDismissed = true);
    } else {
      // A second finger means pinch-zoom: drop the stroke in progress.
      _cancelStroke();
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_strokeActive || _pointers != 1) return;
    _strokeImagePoints.add(_toImage(e.localPosition));
    _live.value = _LiveStroke(_strokeImagePoints, e.localPosition);
  }

  void _onPointerUp(PointerUpEvent e) {
    final wasSingle = _pointers == 1;
    _pointers = math.max(0, _pointers - 1);
    if (_strokeActive && wasSingle) {
      _commitStroke();
    } else {
      _cancelStroke();
    }
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _pointers = math.max(0, _pointers - 1);
    _cancelStroke();
  }

  void _cancelStroke() {
    _strokeActive = false;
    _strokeImagePoints = [];
    _live.value = _LiveStroke.none;
  }

  void _commitStroke() {
    final points = _strokeImagePoints;
    _strokeActive = false;
    _strokeImagePoints = [];
    _live.value = _LiveStroke.none;
    if (points.isEmpty) return;
    _provider.applyBrushStroke(
      points,
      sizeInImagePx: _brushImagePx(_provider.value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EditableImageState>(
      valueListenable: _provider,
      builder: (context, state, _) {
        if (_originalImage == null || state.imageSize == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final imageSize = state.imageSize!;

        return LayoutBuilder(
          builder: (context, constraints) {
            final viewport = constraints.biggest;
            _fit = fitImageRect(imageSize, viewport);
            _fitScale = imageSize.width > 0 ? _fit.width / imageSize.width : 1.0;

            return Stack(
              fit: StackFit.expand,
              children: [
                InteractiveViewer(
                  transformationController: _transformController,
                  minScale: kZoomMin,
                  maxScale: kZoomMax,
                  panEnabled: !widget.brushEnabled,
                  child: SizedBox(
                    width: viewport.width,
                    height: viewport.height,
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _onPointerDown,
                      onPointerMove: _onPointerMove,
                      onPointerUp: _onPointerUp,
                      onPointerCancel: _onPointerCancel,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CustomPaint(
                            painter: _EditorPainter(
                              original: _originalImage!,
                              maskImage: _maskImage,
                              showBeforeAfter: state.showBeforeAfter,
                              backgroundType: state.backgroundType,
                              bgColor: state.bgColor,
                              blurRadius: state.blurRadius,
                              edgeFeather: state.edgeFeather,
                              fit: _fit,
                              fitScale: _fitScale,
                            ),
                          ),
                          if (widget.brushEnabled)
                            CustomPaint(
                              painter: _BrushOverlayPainter(
                                live: _live,
                                transform: _transformController,
                                fit: _fit,
                                fitScale: _fitScale,
                                brushScreenPx: state.currentBrushSizePx,
                                isRestore: state.currentBrushIsRestore,
                                opacity: state.currentBrushOpacity,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.brushEnabled && !_hintDismissed)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 12,
                    child: IgnorePointer(
                      child: Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            child: Text(
                              AppLocalizations.of(context).editorBrushHint,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Live feedback while painting: the stroke so far, and a circle showing
/// the brush's real on-screen size under the finger.
class _BrushOverlayPainter extends CustomPainter {
  _BrushOverlayPainter({
    required this.live,
    required this.transform,
    required this.fit,
    required this.fitScale,
    required this.brushScreenPx,
    required this.isRestore,
    required this.opacity,
  }) : super(repaint: Listenable.merge([live, transform]));

  final ValueNotifier<_LiveStroke> live;
  final TransformationController transform;
  final Rect fit;
  final double fitScale;
  final double brushScreenPx;
  final bool isRestore;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = live.value;
    final cursor = stroke.cursor;
    if (cursor == null) return;

    final zoom = transform.value.getMaxScaleOnAxis();
    final brushCanvas = brushScreenPx / zoom;
    final color = isRestore ? const Color(0xFF34C759) : const Color(0xFFFF3B30);

    if (stroke.imagePoints.isNotEmpty) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: 0.25 + 0.4 * opacity),
      );
      final line = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = brushCanvas
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final first = _toCanvas(stroke.imagePoints.first);
      final path = Path()..moveTo(first.dx, first.dy);
      for (final p in stroke.imagePoints.skip(1)) {
        final c = _toCanvas(p);
        path.lineTo(c.dx, c.dy);
      }
      if (stroke.imagePoints.length == 1) {
        canvas.drawCircle(first, brushCanvas / 2, Paint()..color = color);
      } else {
        canvas.drawPath(path, line);
      }
      canvas.restore();
    }

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / zoom;
    canvas.drawCircle(cursor, brushCanvas / 2, ring..color = Colors.black54);
    canvas.drawCircle(
      cursor,
      brushCanvas / 2 - 1.5 / zoom,
      ring..color = Colors.white,
    );
  }

  Offset _toCanvas(Offset imagePoint) => Offset(
        imagePoint.dx * fitScale + fit.left,
        imagePoint.dy * fitScale + fit.top,
      );

  @override
  bool shouldRepaint(covariant _BrushOverlayPainter old) =>
      old.fit != fit ||
      old.fitScale != fitScale ||
      old.brushScreenPx != brushScreenPx ||
      old.isRestore != isRestore ||
      old.opacity != opacity;
}

class _EditorPainter extends CustomPainter {
  _EditorPainter({
    required this.original,
    this.maskImage,
    required this.showBeforeAfter,
    required this.backgroundType,
    required this.bgColor,
    required this.blurRadius,
    required this.edgeFeather,
    required this.fit,
    required this.fitScale,
  });

  final ui.Image original;
  final ui.Image? maskImage;
  final bool showBeforeAfter;
  final BackgroundType backgroundType;
  final Color? bgColor;
  final double blurRadius;
  final double edgeFeather;
  final Rect fit;
  final double fitScale;

  Rect get _src =>
      Rect.fromLTWH(0, 0, original.width.toDouble(), original.height.toDouble());

  @override
  void paint(Canvas canvas, Size size) {
    final rect = fit;
    canvas.save();
    canvas.clipRect(rect);

    if (showBeforeAfter) {
      // "Before": the untouched original.
      canvas.drawImageRect(original, _src, rect, Paint());
      canvas.restore();
      return;
    }

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
      canvas.drawImageRect(original, _src, rect, Paint());
      final maskPaint = Paint()..blendMode = BlendMode.dstIn;
      // Feather is specified in image pixels; scale it to what's on screen.
      final sigma = edgeFeather * fitScale;
      if (sigma > 0) {
        maskPaint.imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
      }
      canvas.drawImageRect(
        maskImage!,
        Rect.fromLTWH(0, 0, maskImage!.width.toDouble(), maskImage!.height.toDouble()),
        rect,
        maskPaint,
      );
      canvas.restore();
    } else {
      canvas.drawImageRect(original, _src, rect, Paint());
    }
    canvas.restore();
  }

  void _drawBlurredBackground(Canvas canvas, Rect rect) {
    final sigma = blurRadius * fitScale;
    canvas.saveLayer(
      rect,
      Paint()
        ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    );
    canvas.drawImageRect(original, _src, rect, Paint());
    canvas.restore();
  }

  void _drawTransparencyCheckerboard(Canvas canvas, Rect rect) {
    const tile = 12.0;
    final light = Paint()..color = const Color(0xFFE0E0E0);
    final dark = Paint()..color = const Color(0xFFBDBDBD);
    canvas.drawRect(rect, light);
    for (var y = rect.top; y < rect.bottom; y += tile) {
      for (var x = rect.left; x < rect.right; x += tile) {
        final isDark = (((x - rect.left) ~/ tile) + ((y - rect.top) ~/ tile)) % 2 == 0;
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
        oldDelegate.showBeforeAfter != showBeforeAfter ||
        oldDelegate.backgroundType != backgroundType ||
        oldDelegate.bgColor != bgColor ||
        oldDelegate.blurRadius != blurRadius ||
        oldDelegate.edgeFeather != edgeFeather ||
        oldDelegate.fit != fit ||
        oldDelegate.fitScale != fitScale;
  }
}
