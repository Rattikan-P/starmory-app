import 'dart:io';
import 'dart:typed_data';

/// Result of image format validation
class ImageFormatResult {
  final bool valid;
  final String? format;
  final String? error;

  const ImageFormatResult({
    required this.valid,
    this.format,
    this.error,
  });

  /// Valid image format
  factory ImageFormatResult.valid(String format) {
    return ImageFormatResult(
      valid: true,
      format: format,
    );
  }

  /// Invalid image format
  factory ImageFormatResult.invalid(String error) {
    return ImageFormatResult(
      valid: false,
      error: error,
    );
  }

  /// Convert to JSON matching test plan format
  Map<String, dynamic> toJson() {
    if (valid) {
      return {
        'valid': true,
        'format': format,
      };
    } else {
      return {
        'valid': false,
        'error': error,
      };
    }
  }
}

/// Validates image file formats
class ImageValidator {
  /// Supported image formats
  static const Set<String> supportedFormats = {
    '.jpg',
    '.jpeg',
    '.png',
  };

  /// MIME type mapping
  static const Map<String, String> mimeTypeToFormat = {
    'image/jpeg': '.jpg',
    'image/jpg': '.jpg',
    'image/png': '.png',
    'image/gif': '.gif',
    'image/bmp': '.bmp',
    'image/webp': '.webp',
  };

  /// Validate image format from file path
  static ImageFormatResult validateFromFile(String filePath) {
    final extension = _getExtension(filePath);
    return _validateFormat(extension);
  }

  /// Validate image format from file
  static Future<ImageFormatResult> validateFromFileEntity(File file) async {
    if (!await file.exists()) {
      return ImageFormatResult.invalid('File does not exist');
    }
    return validateFromFile(file.path);
  }

  /// Validate image format from bytes
  static ImageFormatResult validateFromBytes(Uint8List bytes, String fileName) {
    // Try to detect from file extension first
    final extension = _getExtension(fileName);
    final formatResult = _validateFormat(extension);

    // If extension validation passed, verify with magic bytes
    if (formatResult.valid) {
      final detectedFormat = _detectFormatFromBytes(bytes);
      if (detectedFormat != null && detectedFormat != formatResult.format) {
        // Extension says one thing, bytes say another
        // Trust the bytes
        return _validateFormat(detectedFormat);
      }
    }

    return formatResult;
  }

  /// Get file extension from path
  static String _getExtension(String filePath) {
    final lastDot = filePath.lastIndexOf('.');
    if (lastDot == -1) {
      return '';
    }
    final extension = filePath.substring(lastDot).toLowerCase();
    return extension;
  }

  /// Validate format extension
  static ImageFormatResult _validateFormat(String format) {
    if (format.isEmpty) {
      return ImageFormatResult.invalid('No file extension found');
    }

    if (supportedFormats.contains(format)) {
      return ImageFormatResult.valid(format);
    }

    return ImageFormatResult.invalid(
      'Only JPEG and PNG images are supported.',
    );
  }

  /// Detect image format from magic bytes
  static String? _detectFormatFromBytes(Uint8List bytes) {
    if (bytes.length < 4) return null;

    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return '.png';
    }

    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return '.jpg';
    }

    // GIF: 47 49 46 38
    if (bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return '.gif';
    }

    // BMP: 42 4D
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return '.bmp';
    }

    // WebP: 52 49 46 46 ... 57 45 42 50
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      return '.webp';
    }

    return null;
  }

  /// Check if format is supported
  static bool isSupported(String format) {
    return supportedFormats.contains(format.toLowerCase());
  }

  /// Get supported formats list
  static List<String> getSupportedFormats() {
    return supportedFormats.toList();
  }
}
