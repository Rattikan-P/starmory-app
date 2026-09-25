import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// A thread-safe / re-entrancy-safe wrapper around [ImagePicker] that:
/// 1. Prevents concurrent picking operations (debouncing / single-flight lock).
/// 2. Silently handles [PlatformException] with code 'already_active' to prevent error dialogs.
/// 3. Adds an optional cooldown after picking completes to prevent rapid double-taps.
class SafeImagePicker {
  SafeImagePicker._();

  @visibleForTesting
  static ImagePicker picker = ImagePicker();

  static bool _isPicking = false;

  /// Whether an image pick operation is currently in progress.
  static bool get isPicking => _isPicking;

  /// Duration to hold the lock after a pick call completes to prevent accidental double-taps.
  @visibleForTesting
  static Duration debounceDuration = const Duration(milliseconds: 300);

  /// Resets the picker state (useful in tests or app reset).
  @visibleForTesting
  static void reset() {
    _isPicking = false;
    picker = ImagePicker();
    debounceDuration = const Duration(milliseconds: 300);
  }

  /// Safely picks a single image from the specified [source].
  ///
  /// Returns `null` if picking is already in progress, cancelled by user,
  /// or if the platform reports that the picker is already active.
  static Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    if (_isPicking) {
      debugPrint('[SafeImagePicker] Pick image ignored: picker is already active');
      return null;
    }

    _isPicking = true;
    try {
      final image = await picker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
        preferredCameraDevice: preferredCameraDevice,
        requestFullMetadata: requestFullMetadata,
      );
      return image;
    } on PlatformException catch (e) {
      if (e.code == 'already_active') {
        debugPrint('[SafeImagePicker] Handled already_active platform exception: ${e.message}');
        return null;
      }
      rethrow;
    } finally {
      if (debounceDuration > Duration.zero) {
        await Future.delayed(debounceDuration);
      }
      _isPicking = false;
    }
  }

  /// Safely picks multiple images.
  ///
  /// Returns empty list if picking is already in progress or cancelled.
  static Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    if (_isPicking) {
      debugPrint('[SafeImagePicker] Pick multi-image ignored: picker is already active');
      return [];
    }

    _isPicking = true;
    try {
      final images = await picker.pickMultiImage(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
        limit: limit,
        requestFullMetadata: requestFullMetadata,
      );
      return images;
    } on PlatformException catch (e) {
      if (e.code == 'already_active') {
        debugPrint('[SafeImagePicker] Handled already_active platform exception: ${e.message}');
        return [];
      }
      rethrow;
    } finally {
      if (debounceDuration > Duration.zero) {
        await Future.delayed(debounceDuration);
      }
      _isPicking = false;
    }
  }
}
