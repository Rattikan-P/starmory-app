import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/error/failures.dart';
import '../../core/utils/image_validator.dart';

/// Image Storage Service
/// Handles uploading images to Supabase Storage
class ImageStorageService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Bucket name for vocabulary images
  static const String _bucketName = 'vocabulary-images';

  @visibleForTesting
  static String? objectPathFromUrl(String imageUrl) {
    final pathSegments = Uri.parse(imageUrl).pathSegments;
    final bucketIndex = pathSegments.indexOf(_bucketName);
    if (bucketIndex == -1 || bucketIndex + 1 >= pathSegments.length) {
      return null;
    }

    return pathSegments.sublist(bucketIndex + 1).join('/');
  }

  /// Upload image to Supabase Storage
  /// Returns the public URL of the uploaded image
  Future<String> uploadVocabularyImage({
    required File imageFile,
    required String userId,
  }) async {
    try {
      // Validate image format before uploading
      final validationResult = ImageValidator.validateFromFile(imageFile.path);
      if (!validationResult.valid) {
        throw ValidationFailure(
          validationResult.error ?? 'Invalid image format',
        );
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _getFileExtension(imageFile.path);
      final fileName = '$userId/$timestamp.$extension';

      // Upload file
      await _client.storage.from(_bucketName).upload(
            fileName,
            imageFile,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      // For private bucket, use signed URL
      // For public bucket, can use getPublicUrl
      final imageUrl = await _client.storage.from(_bucketName).createSignedUrl(
            fileName,
            365 * 24 * 60 * 60, // 1 year in seconds
          );

      print('✅ Image uploaded: $imageUrl');
      return imageUrl;
    } catch (e) {
      print('❌ Error uploading image: $e');
      throw CacheFailure('Failed to upload image: ${e.toString()}');
    }
  }

  /// Upload multiple images (batch)
  /// Returns list of public URLs
  Future<List<String>> uploadVocabularyImages({
    required List<File> imageFiles,
    required String userId,
  }) async {
    final List<String> urls = [];

    for (final file in imageFiles) {
      try {
        final url = await uploadVocabularyImage(
          imageFile: file,
          userId: userId,
        );
        urls.add(url);
      } catch (e) {
        print('⚠️ Failed to upload ${file.path}: $e');
        // Continue with other files
      }
    }

    return urls;
  }

  /// Delete image from storage
  Future<bool> deleteImage(String imageUrl) async {
    try {
      // Extract filename from URL
      final fileName = objectPathFromUrl(imageUrl);
      if (fileName == null) {
        print('⚠️ Invalid image URL format: $imageUrl');
        return false;
      }

      await _client.storage.from(_bucketName).remove([fileName]);

      print('✅ Image deleted: $imageUrl');
      return true;
    } catch (e) {
      print('❌ Error deleting image: $e');
      return false;
    }
  }

  /// Upload scrapbook image to Supabase Storage
  /// Scrapbook images are stored in a separate folder: userId/scrapbooks/scrapbookId/timestamp.ext
  /// Returns the public URL of the uploaded image
  Future<String> uploadScrapbookImage({
    required File imageFile,
    required String userId,
    required String scrapbookId,
  }) async {
    try {
      // Validate image format before uploading
      final validationResult = ImageValidator.validateFromFile(imageFile.path);
      if (!validationResult.valid) {
        throw ValidationFailure(
          validationResult.error ?? 'Invalid image format',
        );
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _getFileExtension(imageFile.path);
      final fileName = '$userId/scrapbooks/$scrapbookId/$timestamp.$extension';

      // Upload file
      await _client.storage.from(_bucketName).upload(
            fileName,
            imageFile,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      // Get signed URL (valid for 1 year)
      final imageUrl = await _client.storage.from(_bucketName).createSignedUrl(
            fileName,
            365 * 24 * 60 * 60,
          );

      print('✅ Scrapbook image uploaded: $imageUrl');
      return imageUrl;
    } catch (e) {
      print('❌ Error uploading scrapbook image: $e');
      throw CacheFailure('Failed to upload scrapbook image: ${e.toString()}');
    }
  }

  /// Get file extension from path
  String _getFileExtension(String filePath) {
    final parts = filePath.split('.');
    if (parts.length > 1) {
      return parts.last.toLowerCase();
    }
    return 'jpg'; // Default extension
  }

  /// Check if bucket exists, create if not
  Future<bool> ensureBucketExists() async {
    try {
      final buckets = await _client.storage.listBuckets();
      final bucketExists = buckets.any((bucket) => bucket.name == _bucketName);

      if (!bucketExists) {
        print('⚠️ Bucket $_bucketName does not exist');
        print('Please create it in Supabase Dashboard: Storage → New bucket');
        print('Bucket name: $_bucketName');
        print('Public: true (recommended for vocabulary images)');
        return false;
      }

      return true;
    } catch (e) {
      print('❌ Error checking buckets: $e');
      return false;
    }
  }
}
