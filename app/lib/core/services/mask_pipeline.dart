import 'dart:math' as math;
import 'dart:typed_data';

/// Pure-Dart pre/post-processing for the U2-Netp segmentation model.
///
/// No plugins, no dart:io, no dart:ui — fully unit-testable without a
/// device. Every function here is mirrored one-to-one by a float64 Python
/// reference; test/mask_pipeline_test.dart checks against values produced
/// by that reference.

/// ImageNet statistics used by U2-Net's training pipeline.
const List<double> kImagenetMean = [0.485, 0.456, 0.406];
const List<double> kImagenetStd = [0.229, 0.224, 0.225];

/// If the model's output range (max - min) is below this, it found no
/// salient subject; min-max normalisation would only amplify noise, so the
/// mask is left fully opaque instead.
const double kMinMaskRange = 0.05;

/// Edge contrast curve applied after upscaling (smoothstep over this band).
/// Tightens the soft halo of a coarse 320x320 mask without eating fine
/// detail such as whiskers.
const double kMaskCurveLow = 0.15;
const double kMaskCurveHigh = 0.85;

/// Bilinear sample of [src] (interleaved, [channels] per pixel) at the
/// fractional coordinates xs[i], ys[j]. Half-pixel-centre convention,
/// edge-clamped.
void _accumulateBilinear({
  required List<double> src,
  required int srcW,
  required int srcH,
  required int channels,
  required Float64List xs,
  required Float64List ys,
  required Float64List out,
  required int dstW,
  required int dstH,
}) {
  final x0s = Int32List(dstW);
  final x1s = Int32List(dstW);
  final fxs = Float64List(dstW);
  for (var i = 0; i < dstW; i++) {
    final x = math.max(0.0, math.min(xs[i], (srcW - 1).toDouble()));
    final x0 = x.floor();
    x0s[i] = x0;
    x1s[i] = math.min(x0 + 1, srcW - 1);
    fxs[i] = x - x0;
  }
  for (var j = 0; j < dstH; j++) {
    final y = math.max(0.0, math.min(ys[j], (srcH - 1).toDouble()));
    final y0 = y.floor();
    final y1 = math.min(y0 + 1, srcH - 1);
    final fy = y - y0;
    for (var i = 0; i < dstW; i++) {
      final fx = fxs[i];
      final a = (y0 * srcW + x0s[i]) * channels;
      final b = (y0 * srcW + x1s[i]) * channels;
      final c = (y1 * srcW + x0s[i]) * channels;
      final d = (y1 * srcW + x1s[i]) * channels;
      final o = (j * dstW + i) * channels;
      for (var ch = 0; ch < channels; ch++) {
        final top = src[a + ch] * (1 - fx) + src[b + ch] * fx;
        final bottom = src[c + ch] * (1 - fx) + src[d + ch] * fx;
        out[o + ch] += top * (1 - fy) + bottom * fy;
      }
    }
  }
}

/// Resizes [src] to [dstW] x [dstH] with supersampled bilinear filtering
/// (up to 4x4 taps per output pixel, which suppresses aliasing when
/// shrinking a large photo down to model size). Scale <= 1 reduces to
/// ordinary bilinear interpolation.
Float64List resizeInterleaved(
  List<double> src,
  int srcW,
  int srcH,
  int channels,
  int dstW,
  int dstH,
) {
  final sx = srcW / dstW;
  final sy = srcH / dstH;
  final kx = math.min(4, math.max(1, sx.ceil()));
  final ky = math.min(4, math.max(1, sy.ceil()));
  final out = Float64List(dstW * dstH * channels);
  final xs = Float64List(dstW);
  final ys = Float64List(dstH);
  for (var j = 0; j < ky; j++) {
    for (var jj = 0; jj < dstH; jj++) {
      ys[jj] = (jj + (j + 0.5) / ky) * sy - 0.5;
    }
    for (var i = 0; i < kx; i++) {
      for (var ii = 0; ii < dstW; ii++) {
        xs[ii] = (ii + (i + 0.5) / kx) * sx - 0.5;
      }
      _accumulateBilinear(
        src: src,
        srcW: srcW,
        srcH: srcH,
        channels: channels,
        xs: xs,
        ys: ys,
        out: out,
        dstW: dstW,
        dstH: dstH,
      );
    }
  }
  final scale = 1.0 / (kx * ky);
  for (var n = 0; n < out.length; n++) {
    out[n] *= scale;
  }
  return out;
}

/// Converts interleaved 8-bit RGB ([rgb].length == srcW*srcH*3) into the
/// model's input tensor: size x size x 3, NHWC order, divided by the image
/// maximum then normalised with ImageNet mean/std.
Float32List preprocessRgb(
  Uint8List rgb,
  int srcW,
  int srcH, {
  int size = 320,
}) {
  if (rgb.length != srcW * srcH * 3) {
    throw ArgumentError(
      'rgb length ${rgb.length} does not match ${srcW}x$srcH x3',
    );
  }
  final asDouble = Float64List(rgb.length);
  for (var i = 0; i < rgb.length; i++) {
    asDouble[i] = rgb[i].toDouble();
  }
  final resized = resizeInterleaved(asDouble, srcW, srcH, 3, size, size);
  var maxVal = 1e-6;
  for (final v in resized) {
    if (v > maxVal) maxVal = v;
  }
  final out = Float32List(size * size * 3);
  for (var i = 0; i < resized.length; i++) {
    final ch = i % 3;
    out[i] = ((resized[i] / maxVal - kImagenetMean[ch]) / kImagenetStd[ch]);
  }
  return out;
}

double _smoothstep(double x, double a, double b) {
  final t = math.max(0.0, math.min((x - a) / (b - a), 1.0));
  return t * t * (3 - 2 * t);
}

/// Turns the model's raw [probs] (modelSize x modelSize sigmoid output)
/// into an 8-bit alpha mask of [outW] x [outH]: min-max normalise, bilinear
/// upscale, edge curve. Returns an all-255 mask when no subject is found.
Uint8List postprocessMask(
  Float32List probs,
  int outW,
  int outH, {
  int modelSize = 320,
}) {
  if (probs.length != modelSize * modelSize) {
    throw ArgumentError(
      'probs length ${probs.length} does not match ${modelSize}x$modelSize',
    );
  }
  var lo = double.infinity;
  var hi = double.negativeInfinity;
  for (final v in probs) {
    if (v < lo) lo = v;
    if (v > hi) hi = v;
  }
  final out = Uint8List(outW * outH);
  if (hi - lo < kMinMaskRange) {
    out.fillRange(0, out.length, 255);
    return out;
  }
  final range = hi - lo;
  final normalised = List<double>.generate(
    probs.length,
    (i) => (probs[i] - lo) / range,
  );
  final up = resizeInterleaved(normalised, modelSize, modelSize, 1, outW, outH);
  for (var i = 0; i < up.length; i++) {
    final v = _smoothstep(up[i], kMaskCurveLow, kMaskCurveHigh);
    out[i] = (math.max(0.0, math.min(v, 1.0)) * 255 + 0.5).floor();
  }
  return out;
}
