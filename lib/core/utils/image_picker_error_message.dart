/// Converts low-level image picker failures into user-friendly messages.
class ImagePickerErrorMessage {
  ImagePickerErrorMessage._();

  static String failedToPick(Object error) {
    final rawMessage = error.toString();
    final normalized = rawMessage.toLowerCase();

    if (normalized.contains('request for permission is already running') ||
        normalized.contains('permission request is already running')) {
      return 'Failed to pick image: A permission request is already in progress. Please wait a moment, then try again.';
    }

    return 'Failed to pick image: $rawMessage';
  }

  static bool isPermissionRequestAlreadyRunning(Object error) {
    final normalized = error.toString().toLowerCase();
    return normalized.contains('request for permission is already running') ||
        normalized.contains('permission request is already running');
  }
}
