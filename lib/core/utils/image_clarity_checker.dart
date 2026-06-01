import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Result of image clarity check
class ImageClarityResult {
  final bool isClear;
  final double clarityScore;
  final String message;

  const ImageClarityResult({
    required this.isClear,
    required this.clarityScore,
    required this.message,
  });

  /// Clear image with good clarity
  factory ImageClarityResult.clear(double score) {
    return ImageClarityResult(
      isClear: true,
      clarityScore: score,
      message: 'Image quality is good for AI processing.',
    );
  }

  /// Blurry image with low clarity
  factory ImageClarityResult.blurry(double score) {
    return ImageClarityResult(
      isClear: false,
      clarityScore: score,
      message: 'Image appears too blurry for accurate analysis.',
    );
  }

  /// Small image that may be too low resolution
  factory ImageClarityResult.small(int width, int height) {
    return ImageClarityResult(
      isClear: false,
      clarityScore: 0.0,
      message: 'Image resolution is too low ($width×$height). Minimum 480×480 recommended.',
    );
  }
}

/// Checks image clarity and blur detection
class ImageClarityChecker {
  /// Minimum image dimensions (width × height)
  static const int minImageDimension = 480;

  /// Laplacian variance threshold for blur detection
  /// Lower values indicate more blur
  static const double blurThreshold = 100.0;

  /// Check image clarity from file path
  static Future<ImageClarityResult> checkFromFile(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception('Image file does not exist: $imagePath');
    }

    final bytes = await file.readAsBytes();
    return checkFromBytes(bytes);
  }

  /// Check image clarity from bytes
  static Future<ImageClarityResult> checkFromBytes(Uint8List bytes) async {
    // Decode image
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Check image dimensions
    if (image.width < minImageDimension || image.height < minImageDimension) {
      return ImageClarityResult.small(image.width, image.height);
    }

    // Calculate clarity score using Laplacian variance
    final clarityScore = _calculateLaplacianVariance(image);

    // Determine if image is clear enough
    if (clarityScore < blurThreshold) {
      return ImageClarityResult.blurry(clarityScore);
    }

    return ImageClarityResult.clear(clarityScore);
  }

  /// Calculate Laplacian variance for blur detection
  /// Higher values indicate sharper images (more edges)
  /// Lower values indicate blurrier images (fewer edges)
  static double _calculateLaplacianVariance(img.Image image) {
    // Convert to grayscale for faster processing
    final grayscale = img.grayscale(image);

    // Resize for faster processing if image is large
    img.Image processedImage = grayscale;
    if (grayscale.width > 800 || grayscale.height > 800) {
      processedImage = img.copyResize(
        grayscale,
        width: 800,
        height: 800,
        interpolation: img.Interpolation.linear,
      );
    }

    // Apply Laplacian edge detection
    final edges = _laplacian(processedImage);

    // Calculate variance of the edge responses
    final mean = _calculateMean(edges);
    final variance = _calculateVariance(edges, mean);

    return variance;
  }

  /// Apply Laplacian edge detection kernel
  /// Returns edge strength for each pixel
  static List<double> _laplacian(img.Image image) {
    final edges = <double>[];
    final width = image.width;
    final height = image.height;

    // Laplacian kernel (3x3)
    //  0  1  0
    //  1 -4  1
    //  0  1  0

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        // Use getPixelSafe for safe access
        final center = image.getPixel(x, y);
        final top = image.getPixel(x, y - 1);
        final bottom = image.getPixel(x, y + 1);
        final left = image.getPixel(x - 1, y);
        final right = image.getPixel(x + 1, y);

        // Get the red channel for edge detection (grayscale equivalent)
        final centerVal = center.r.toInt();
        final topVal = top.r.toInt();
        final bottomVal = bottom.r.toInt();
        final leftVal = left.r.toInt();
        final rightVal = right.r.toInt();

        // Apply Laplacian operator
        final laplacian =
            (topVal + bottomVal + leftVal + rightVal - 4 * centerVal).abs();
        edges.add(laplacian.toDouble());
      }
    }

    return edges;
  }

  /// Calculate mean of values
  static double _calculateMean(List<double> values) {
    if (values.isEmpty) return 0.0;
    final sum = values.reduce((a, b) => a + b);
    return sum / values.length;
  }

  /// Calculate variance from values and mean
  static double _calculateVariance(List<double> values, double mean) {
    if (values.isEmpty) return 0.0;
    final sumSquaredDiff = values.fold<double>(
      0.0,
      (sum, value) => sum + (value - mean) * (value - mean),
    );
    return sumSquaredDiff / values.length;
  }

  /// Get quality description from clarity score
  static String getQualityDescription(double score) {
    if (score < 50) return 'Very Blurry';
    if (score < 100) return 'Blurry';
    if (score < 200) return 'Acceptable';
    if (score < 400) return 'Good';
    return 'Excellent';
  }
}
