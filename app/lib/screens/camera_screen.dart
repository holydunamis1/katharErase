import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../generated/l10n/app_localizations.dart';
import '../platform/permission_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/icon_button_48.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/toast_notification.dart';

/// CameraPreview + white overlay guide rectangle + capture button + flash
/// toggle + gallery shortcut.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _flashOn = false;
  bool _initializing = true;
  // Stores which localized message to show, resolved at build time via
  // AppLocalizations rather than storing the resolved String directly —
  // this state is set from initState/async callbacks that may run before
  // a BuildContext with a resolved locale is guaranteed usable.
  _CameraErrorType? _errorType;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    final result = await PermissionService.instance.requestCameraPermission();
    switch (result) {
      case PermissionResult.granted:
        await _initCamera();
        break;
      case PermissionResult.denied:
        setState(() {
          _initializing = false;
          _errorType = _CameraErrorType.permissionDenied;
        });
        break;
      case PermissionResult.permanentlyDenied:
        setState(() {
          _initializing = false;
          _errorType = _CameraErrorType.permissionPermanentlyDenied;
        });
        break;
      case PermissionResult.restricted:
        setState(() {
          _initializing = false;
          _errorType = _CameraErrorType.permissionRestricted;
        });
        break;
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _initializing = false;
          _errorType = _CameraErrorType.noCameraFound;
        });
        return;
      }
      final controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _errorType = _CameraErrorType.startFailed;
      });
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final newMode = _flashOn ? FlashMode.off : FlashMode.torch;
      await controller.setFlashMode(newMode);
      setState(() => _flashOn = !_flashOn);
    } catch (e) {
      // Flash unsupported on this device/camera — silently no-op rather
      // than crash, matches the graceful-degradation architecture rule.
    }
  }

  Future<void> _capture(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final file = await controller.takePicture();
      if (!context.mounted) return;
      context.push('/crop', extra: file.path);
    } catch (e) {
      if (context.mounted) {
        ToastNotification.show(context, message: l10n.cameraCaptureFailed, type: ToastType.error);
      }
    }
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null || !context.mounted) return;
      context.push('/crop', extra: picked.path);
    } catch (e) {
      // ignore: avoid_print
      print('Gallery pick failed: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String? _errorMessage(AppLocalizations l10n) {
    return switch (_errorType) {
      null => null,
      _CameraErrorType.permissionDenied => l10n.cameraPermissionDenied,
      _CameraErrorType.permissionPermanentlyDenied =>
        l10n.cameraPermissionPermanentlyDenied,
      _CameraErrorType.permissionRestricted => l10n.cameraPermissionRestricted,
      _CameraErrorType.noCameraFound => l10n.cameraNoCameraFound,
      _CameraErrorType.startFailed => l10n.cameraStartFailed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final errorMessage = _errorMessage(l10n);

    return AppScaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l10n.cameraTitle),
      ),
      resizeToAvoidBottomInset: false,
      body: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_controller != null && _controller!.value.isInitialized)
              CameraPreview(_controller!)
            else if (errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            // White overlay guide rectangle — helps the user frame the
            // subject for background removal.
            if (_controller != null)
              IgnorePointer(
                child: Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.8,
                    heightFactor: 0.6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            if (_controller != null)
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton48(
                      icon: _flashOn ? Icons.flash_on : Icons.flash_off,
                      tooltip: l10n.cameraFlashTooltip,
                      onPressed: _toggleFlash,
                    ),
                    GestureDetector(
                      onTap: () => _capture(context),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                      ),
                    ),
                    IconButton48(
                      icon: Icons.photo_library_outlined,
                      tooltip: l10n.cameraGalleryTooltip,
                      onPressed: () => _pickFromGallery(context),
                    ),
                  ],
                ),
              ),
            if (_errorType == _CameraErrorType.permissionPermanentlyDenied)
              Positioned(
                bottom: 32,
                left: 24,
                right: 24,
                child: FilledButton(
                  onPressed: () => PermissionService.instance.openSettings(),
                  child: Text(l10n.cameraOpenSettings),
                ),
              ),
            LoadingOverlay(visible: _initializing),
          ],
        ),
      ),
    );
  }
}

enum _CameraErrorType {
  permissionDenied,
  permissionPermanentlyDenied,
  permissionRestricted,
  noCameraFound,
  startFailed,
}
