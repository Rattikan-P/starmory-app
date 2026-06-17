import 'package:permission_handler/permission_handler.dart';

/// Permission types for camera and gallery
enum PermissionType {
  camera,
  gallery,
}

/// Result of permission check and request
class PermissionResult {
  final bool permissionGranted;
  final String? action;
  final PermissionDialog? dialog;

  const PermissionResult({
    required this.permissionGranted,
    this.action,
    this.dialog,
  });

  /// Permission granted with action
  factory PermissionResult.granted(String action) {
    return PermissionResult(
      permissionGranted: true,
      action: action,
    );
  }

  /// Permission denied with dialog
  factory PermissionResult.denied(PermissionDialog dialog) {
    return PermissionResult(
      permissionGranted: false,
      dialog: dialog,
    );
  }

  /// Convert to JSON matching test plan format
  Map<String, dynamic> toJson() {
    if (permissionGranted) {
      return {
        'permissionGranted': true,
        'action': action,
      };
    } else {
      return {
        'permissionGranted': false,
        'dialog': dialog?.toJson(),
      };
    }
  }
}

/// Dialog shown when permission is denied
class PermissionDialog {
  final String message;
  final List<String> options;

  const PermissionDialog({
    required this.message,
    required this.options,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'options': options,
    };
  }

  /// Create default permission dialog
  factory PermissionDialog.defaultDenied() {
    return const PermissionDialog(
      message: 'Permission Required. Please grant permission to continue.',
      options: ['Cancel', 'Settings'],
    );
  }
}

/// Handles camera and gallery permissions
class AppPermissionHandler {
  /// Check and request permission
  static Future<PermissionResult> checkAndRequestPermission(
    PermissionType type,
  ) async {
    Permission permission;

    switch (type) {
      case PermissionType.camera:
        permission = Permission.camera;
        break;
      case PermissionType.gallery:
        // For gallery, we need photos permission on iOS
        // and storage permission on Android
        permission = Permission.photos;
        break;
    }

    // Check current permission status
    final status = await permission.status;

    // If already granted, return success
    if (status.isGranted) {
      final action = type == PermissionType.camera ? 'open_camera' : 'open_gallery';
      return PermissionResult.granted(action);
    }

    // If permanently denied, show dialog with settings option
    if (status.isPermanentlyDenied) {
      return PermissionResult.denied(PermissionDialog.defaultDenied());
    }

    // Request permission
    final result = await permission.request();

    if (result.isGranted) {
      final action = type == PermissionType.camera ? 'open_camera' : 'open_gallery';
      return PermissionResult.granted(action);
    }

    // Permission denied
    return PermissionResult.denied(PermissionDialog.defaultDenied());
  }

  /// Check if permission is granted without requesting
  static Future<bool> checkPermission(PermissionType type) async {
    Permission permission;

    switch (type) {
      case PermissionType.camera:
        permission = Permission.camera;
        break;
      case PermissionType.gallery:
        permission = Permission.photos;
        break;
    }

    final status = await permission.status;
    return status.isGranted;
  }

  /// Open app settings
  static Future<bool> openSettings() async {
    return await openAppSettings();
  }
}
