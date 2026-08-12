import 'package:permission_handler/permission_handler.dart';

/// Camera + photos permission request, rationale dialogs, and
/// permanently-denied deep-link to Settings.
///
/// Uses permission_handler (added to Section 6 during Phase 2 — see
/// pubspec.yaml comment for why camera/image_picker alone can't satisfy
/// File 18's acceptance criteria). Rationale dialog *content* belongs in
/// the UI layer (camera_screen.dart, Phase 5); this service only decides
/// *which* state you're in (grantable, needs rationale, permanently
/// denied) so the UI can react appropriately.
enum PermissionResult {
  granted,
  denied, // can ask again (show rationale, then re-request)
  permanentlyDenied, // OS won't prompt again — must deep-link to Settings
  restricted, // parental controls / MDM (iOS) — no path to grant at all
}

class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  Future<PermissionResult> checkCameraPermission() async {
    return _toResult(await Permission.camera.status);
  }

  Future<PermissionResult> requestCameraPermission() async {
    return _toResult(await Permission.camera.request());
  }

  /// Feature 5 (Save to Gallery) / gallery picker (Phase 5). On Android
  /// 13+, gal and image_picker handle the modern scoped-storage photo
  /// picker internally without a manifest permission prompt in most
  /// flows — this method is primarily relevant for iOS photo library
  /// access and pre-Android-13 devices.
  Future<PermissionResult> checkPhotosPermission() async {
    return _toResult(await Permission.photos.status);
  }

  Future<PermissionResult> requestPhotosPermission() async {
    return _toResult(await Permission.photos.request());
  }

  /// Deep-links to the OS Settings app for this app's permission page.
  /// Only meaningful after a PermissionResult.permanentlyDenied result —
  /// calling it otherwise just opens Settings without fixing anything,
  /// so callers should gate this behind that state (camera_screen.dart /
  /// crop_rotate_screen.dart, Phase 5).
  Future<bool> openSettings() => openAppSettings();

  PermissionResult _toResult(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
      case PermissionStatus.limited: // iOS partial photo library access
      case PermissionStatus.provisional:
        return PermissionResult.granted;
      case PermissionStatus.permanentlyDenied:
        return PermissionResult.permanentlyDenied;
      case PermissionStatus.restricted:
        return PermissionResult.restricted;
      case PermissionStatus.denied:
        return PermissionResult.denied;
    }
  }
}
