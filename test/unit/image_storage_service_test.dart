import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/data/services/image_storage_service.dart';

void main() {
  group('ImageStorageService.objectPathFromUrl', () {
    test('extracts a nested scrapbook path from a signed URL', () {
      const url = 'https://example.supabase.co/storage/v1/object/sign/'
          'vocabulary-images/user-id/scrapbooks/scrapbook-id/image.jpg?token=abc';

      expect(
        ImageStorageService.objectPathFromUrl(url),
        'user-id/scrapbooks/scrapbook-id/image.jpg',
      );
    });

    test('extracts an object path from a public URL', () {
      const url = 'https://example.supabase.co/storage/v1/object/public/'
          'vocabulary-images/user-id/image.jpg';

      expect(
        ImageStorageService.objectPathFromUrl(url),
        'user-id/image.jpg',
      );
    });

    test('returns null when the bucket or object path is missing', () {
      expect(
        ImageStorageService.objectPathFromUrl(
          'https://example.supabase.co/storage/v1/object/sign/other/image.jpg',
        ),
        isNull,
      );
      expect(
        ImageStorageService.objectPathFromUrl(
          'https://example.supabase.co/storage/v1/object/sign/vocabulary-images',
        ),
        isNull,
      );
    });
  });
}
