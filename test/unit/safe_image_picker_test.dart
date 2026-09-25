import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:starmory_app/core/utils/safe_image_picker.dart';

class FakeImagePicker extends Fake implements ImagePicker {
  Completer<XFile?>? completer;
  int callCount = 0;
  PlatformException? exceptionToThrow;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    callCount++;
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    if (completer != null) {
      return completer!.future;
    }
    return XFile('test/path/image.jpg');
  }

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    callCount++;
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return [XFile('test/path/image1.jpg')];
  }
}

void main() {
  setUp(() {
    SafeImagePicker.reset();
    SafeImagePicker.debounceDuration = Duration.zero;
  });

  tearDown(() {
    SafeImagePicker.reset();
  });

  group('SafeImagePicker', () {
    test('successfully picks an image when picker returns a file', () async {
      final fake = FakeImagePicker();
      SafeImagePicker.picker = fake;

      final file = await SafeImagePicker.pickImage(source: ImageSource.gallery);

      expect(file, isNotNull);
      expect(file!.path, 'test/path/image.jpg');
      expect(fake.callCount, 1);
      expect(SafeImagePicker.isPicking, isFalse);
    });

    test('ignores concurrent pick calls while first call is in flight', () async {
      final fake = FakeImagePicker();
      final completer = Completer<XFile?>();
      fake.completer = completer;
      SafeImagePicker.picker = fake;

      // Start first pick
      final firstFuture = SafeImagePicker.pickImage(source: ImageSource.gallery);
      expect(SafeImagePicker.isPicking, isTrue);

      // Attempt second pick while first is still pending
      final secondResult = await SafeImagePicker.pickImage(source: ImageSource.camera);
      expect(secondResult, isNull);
      expect(fake.callCount, 1); // Second call never invoked underlying picker

      // Complete first call
      completer.complete(XFile('test/path/first.jpg'));
      final firstResult = await firstFuture;

      expect(firstResult?.path, 'test/path/first.jpg');
      expect(SafeImagePicker.isPicking, isFalse);
    });

    test('suppresses PlatformException with already_active code and returns null', () async {
      final fake = FakeImagePicker();
      fake.exceptionToThrow = PlatformException(
        code: 'already_active',
        message: 'Image picker is already active',
      );
      SafeImagePicker.picker = fake;

      final result = await SafeImagePicker.pickImage(source: ImageSource.gallery);

      expect(result, isNull);
      expect(SafeImagePicker.isPicking, isFalse);
    });

    test('rethrows non-already_active PlatformException', () async {
      final fake = FakeImagePicker();
      fake.exceptionToThrow = PlatformException(
        code: 'camera_access_denied',
        message: 'Camera permission denied',
      );
      SafeImagePicker.picker = fake;

      expect(
        () => SafeImagePicker.pickImage(source: ImageSource.camera),
        throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'camera_access_denied')),
      );
    });

    test('pickMultiImage suppresses already_active and returns empty list', () async {
      final fake = FakeImagePicker();
      fake.exceptionToThrow = PlatformException(
        code: 'already_active',
        message: 'Image picker is already active',
      );
      SafeImagePicker.picker = fake;

      final result = await SafeImagePicker.pickMultiImage();

      expect(result, isEmpty);
      expect(SafeImagePicker.isPicking, isFalse);
    });
  });
}
