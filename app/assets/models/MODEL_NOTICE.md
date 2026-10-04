# segmentation.tflite

U²-Netp ("u2netp") salient-object segmentation model.

- Source: U²-Net by Xuebin Qin et al., https://github.com/xuebinqin/U-2-Net (Apache License 2.0; full text in `assets/licenses/u2net_apache2.txt`).
- Weights obtained as `u2netp.onnx` from the rembg project's GitHub release (rembg is MIT licensed), SHA-256 `309c8469258dda742793dce0ebea8e6dd393174f89934733ecc8b14c76f4ddd8`.
- Changes made (Apache-2.0 §4b): converted ONNX -> TensorFlow Lite (float32) with onnx2tf, and trimmed to the single fused output (`1959`).
- Tensors: input `[1,320,320,3]` float32 (NHWC, image / max, then ImageNet mean/std), output `[1,320,320,1]` float32 (sigmoid).
- Verified against the original ONNX model on real photographs: max abs difference < 1e-4, identical masks.
