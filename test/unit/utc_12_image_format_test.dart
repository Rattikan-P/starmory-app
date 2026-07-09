import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/core/utils/image_validator.dart';
import '../test_helpers.dart';

/// UTC-12: Validate Image Format
/// Test Function: ImageValidator.validateFromFile(String filePath)
///
/// Description: This test verifies that the system correctly validates
/// image file formats, accepting only .jpg, .jpeg, and .png files
/// before passing them to AI processing.
///
/// Test Data Location: test/test_data/images/
void main() {
  printTestHeader('UTC-12: Validate Image Format');

  // Get the test data directory
  final testDataDir = Directory('test/test_data/images');

  group('UTC-12: Validate Image Format', () {
    group('Valid formats', () {
      test('UT-12-TC01: Accept valid JPEG image (.jpg)', () {
        // Arrange
        final testFile = File('${testDataDir.path}/valid1.jpg');

        // Act
        final result = ImageValidator.validateFromFile(testFile.path);

        // Print output for Test Record
        printTestOutputSimple(
          testId: 'UT-12-TC01',
          description: 'Accept valid JPEG image (.jpg)',
          input: 'File = valid1.jpg',
          expectedOutput: {
            'valid': true,
            'format': '.jpg',
          },
          actualOutput: result.toJson(),
        );

        // Assert
        expect(result.valid, isTrue);
        expect(result.format, equals('.jpg'));
        expect(result.toJson(), equals({
          'valid': true,
          'format': '.jpg',
        }));
      });

      test('UT-12-TC02: Accept valid JPEG image (.jpeg)', () {
        // Arrange
        final testFile = File('${testDataDir.path}/valid2.jpeg');

        // Act
        final result = ImageValidator.validateFromFile(testFile.path);

        // Print output for Test Record
        printTestOutputSimple(
          testId: 'UT-12-TC02',
          description: 'Accept valid JPEG image (.jpeg)',
          input: 'File = valid2.jpeg',
          expectedOutput: {
            'valid': true,
            'format': '.jpeg',
          },
          actualOutput: result.toJson(),
        );

        // Assert
        expect(result.valid, isTrue);
        expect(result.format, equals('.jpeg'));
        expect(result.toJson(), equals({
          'valid': true,
          'format': '.jpeg',
        }));
      });

      test('UT-12-TC03: Accept valid PNG image', () {
        // Arrange
        final testFile = File('${testDataDir.path}/valid3.png');

        // Act
        final result = ImageValidator.validateFromFile(testFile.path);

        // Print output for Test Record
        printTestOutputSimple(
          testId: 'UT-12-TC03',
          description: 'Accept valid PNG image',
          input: 'File = valid3.png',
          expectedOutput: {
            'valid': true,
            'format': '.png',
          },
          actualOutput: result.toJson(),
        );

        // Assert
        expect(result.valid, isTrue);
        expect(result.format, equals('.png'));
        expect(result.toJson(), equals({
          'valid': true,
          'format': '.png',
        }));
      });
    });

    group('Unsupported formats', () {
      test('UT-12-TC04: Reject unsupported GIF format', () {
        // Arrange
        final testFile = File('${testDataDir.path}/invalid1.gif');

        // Act
        final result = ImageValidator.validateFromFile(testFile.path);

        // Print output for Test Record
        printTestOutputSimple(
          testId: 'UT-12-TC04',
          description: 'Reject unsupported GIF format',
          input: 'File = invalid1.gif',
          expectedOutput: {
            'valid': false,
            'error': 'Only JPEG and PNG images are supported.',
          },
          actualOutput: result.toJson(),
        );

        // Assert
        expect(result.valid, isFalse);
        expect(result.error, equals('Only JPEG and PNG images are supported.'));
        expect(result.toJson(), equals({
          'valid': false,
          'error': 'Only JPEG and PNG images are supported.',
        }));
      });

      test('UT-12-TC05: Reject unsupported WebP format', () {
        // Arrange
        final testFile = File('${testDataDir.path}/invalid2.webp');

        // Act
        final result = ImageValidator.validateFromFile(testFile.path);

        // Print output for Test Record
        printTestOutputSimple(
          testId: 'UT-12-TC05',
          description: 'Reject unsupported WebP format',
          input: 'File = invalid2.webp',
          expectedOutput: {
            'valid': false,
            'error': 'Only JPEG and PNG images are supported.',
          },
          actualOutput: result.toJson(),
        );

        // Assert
        expect(result.valid, isFalse);
        expect(result.error, equals('Only JPEG and PNG images are supported.'));
        expect(result.toJson(), equals({
          'valid': false,
          'error': 'Only JPEG and PNG images are supported.',
        }));
      });

      test('Reject WebP format', () {
        // Arrange
        const filePath = '/path/to/image.webp';

        // Act
        final result = ImageValidator.validateFromFile(filePath);

        // Assert
        expect(result.valid, isFalse);
        expect(result.error, equals('Only JPEG and PNG images are supported.'));
      });

      test('Reject file without extension', () {
        // Arrange
        const filePath = '/path/to/image';

        // Act
        final result = ImageValidator.validateFromFile(filePath);

        // Assert
        expect(result.valid, isFalse);
        expect(result.error, equals('No file extension found'));
      });
    });

    group('Validation from bytes', () {
      test('Validate PNG from bytes with magic number', () {
        // Arrange - PNG magic bytes: 89 50 4E 47
        final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x00]);
        const fileName = 'test.png';

        // Act
        final result = ImageValidator.validateFromBytes(bytes, fileName);

        // Assert
        expect(result.valid, isTrue);
        expect(result.format, equals('.png'));
      });

      test('Validate JPEG from bytes with magic number', () {
        // Arrange - JPEG magic bytes: FF D8 FF
        final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);
        const fileName = 'test.jpg';

        // Act
        final result = ImageValidator.validateFromBytes(bytes, fileName);

        // Assert
        expect(result.valid, isTrue);
        expect(result.format, equals('.jpg'));
      });

      test('Detect GIF from magic bytes (unsupported)', () {
        // Arrange - GIF magic bytes: 47 49 46 38
        final bytes = Uint8List.fromList([0x47, 0x49, 0x46, 0x38]);
        const fileName = 'test.gif';

        // Act
        final result = ImageValidator.validateFromBytes(bytes, fileName);

        // Assert
        expect(result.valid, isFalse);
        expect(result.error, equals('Only JPEG and PNG images are supported.'));
      });
    });

    group('Edge cases', () {
      test('Case insensitive extension handling', () {
        // Test various case combinations
        final testCases = [
          'image.JPG',
          'image.Jpg',
          'image.PNG',
          'image.Png',
          'image.JPEG',
          'image.Jpeg',
        ];

        for (final filePath in testCases) {
          final result = ImageValidator.validateFromFile('/path/to/$filePath');
          expect(result.valid, isTrue, reason: 'Should accept $filePath');
        }
      });

      test('Multiple dots in filename', () {
        // Arrange
        const filePath = '/path/to/image.backup.jpg';

        // Act
        final result = ImageValidator.validateFromFile(filePath);

        // Assert
        expect(result.valid, isTrue);
        expect(result.format, equals('.jpg'));
      });

      test('Empty file path', () {
        // Arrange
        const filePath = '';

        // Act
        final result = ImageValidator.validateFromFile(filePath);

        // Assert
        expect(result.valid, isFalse);
      });
    });
  });
}
