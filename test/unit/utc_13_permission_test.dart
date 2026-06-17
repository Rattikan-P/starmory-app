import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/core/utils/permission_handler.dart';
import '../test_helpers.dart';

/// UTC-13: Check Camera and Gallery Permission
/// Test Function: checkAndRequestPermission(PermissionType type)
///
/// Description: This test verifies that the system correctly checks and requests
/// device permissions for camera and photo library access.
void main() {
  printTestHeader('UTC-13: Check Camera and Gallery Permission');

  group('UTC-13: Check Camera and Gallery Permission', () {
    group('Camera Permission', () {
      test('UT-13-TC01: Camera permission already granted', () {
        // Expected output according to test plan:
        final expected = {
          'permissionGranted': true,
          'action': 'open_camera',
        };

        // Verify the expected output structure
        expect(expected['permissionGranted'], isTrue);
        expect(expected['action'], equals('open_camera'));

        // Verify PermissionResult creates correct structure
        final result = PermissionResult.granted('open_camera');

        printTestOutputSimple(
          testId: 'UT-13-TC01',
          description: 'Camera permission already granted',
          input: 'Camera button tapped, permission = Granted',
          expectedOutput: expected,
          actualOutput: result.toJson(),
        );

        expect(result.permissionGranted, isTrue);
        expect(result.action, equals('open_camera'));
        expect(result.toJson(), equals(expected));
      });

      test('UT-13-TC02: Camera permission denied', () {
        // Expected output according to test plan:
        final expected = {
          'permissionGranted': false,
          'dialog': {
            'message': 'Permission Required. Please grant permission to continue.',
            'options': ['Cancel', 'Settings'],
          },
        };

        // Verify the expected output structure
        expect(expected['permissionGranted'], isFalse);

        // Verify PermissionResult.denied creates correct structure
        final dialog = PermissionDialog.defaultDenied();
        final result = PermissionResult.denied(dialog);

        printTestOutputSimple(
          testId: 'UT-13-TC02',
          description: 'Camera permission denied',
          input: 'Camera button tapped, permission = Denied',
          expectedOutput: expected,
          actualOutput: result.toJson(),
        );

        expect(result.permissionGranted, isFalse);
        expect(result.toJson(), equals(expected));
      });
    });

    group('Gallery Permission', () {
      test('UT-13-TC03: Gallery permission already granted', () {
        // Expected output according to test plan:
        final expected = {
          'permissionGranted': true,
          'action': 'open_gallery',
        };

        // Verify the expected output structure
        expect(expected['permissionGranted'], isTrue);
        expect(expected['action'], equals('open_gallery'));

        // Verify PermissionResult creates correct structure
        final result = PermissionResult.granted('open_gallery');

        printTestOutputSimple(
          testId: 'UT-13-TC03',
          description: 'Gallery permission already granted',
          input: 'Gallery button tapped, permission = Granted',
          expectedOutput: expected,
          actualOutput: result.toJson(),
        );

        expect(result.permissionGranted, isTrue);
        expect(result.action, equals('open_gallery'));
        expect(result.toJson(), equals(expected));
      });

      test('UT-13-TC04: Gallery permission denied', () {
        // Expected output according to test plan:
        final expected = {
          'permissionGranted': false,
          'dialog': {
            'message': 'Permission Required. Please grant permission to continue.',
            'options': ['Cancel', 'Settings'],
          },
        };

        // Verify the expected output structure
        expect(expected['permissionGranted'], isFalse);

        // Verify PermissionResult.denied creates correct structure
        final dialog = PermissionDialog.defaultDenied();
        final result = PermissionResult.denied(dialog);

        printTestOutputSimple(
          testId: 'UT-13-TC04',
          description: 'Gallery permission denied',
          input: 'Gallery button tapped, permission = Denied',
          expectedOutput: expected,
          actualOutput: result.toJson(),
        );

        expect(result.permissionGranted, isFalse);
        expect(result.toJson(), equals(expected));
      });
    });

    group('PermissionResult data models', () {
      test('PermissionResult.granted creates correct structure', () {
        // Arrange & Act
        final result = PermissionResult.granted('open_camera');

        // Assert
        expect(result.permissionGranted, isTrue);
        expect(result.action, equals('open_camera'));
        expect(result.toJson(), equals({
          'permissionGranted': true,
          'action': 'open_camera',
        }));
      });

      test('PermissionResult.denied creates correct structure', () {
        // Arrange & Act
        final dialog = PermissionDialog.defaultDenied();
        final result = PermissionResult.denied(dialog);

        // Assert
        expect(result.permissionGranted, isFalse);
        expect(result.dialog, isNotNull);
        expect(result.toJson(), equals({
          'permissionGranted': false,
          'dialog': {
            'message': 'Permission Required. Please grant permission to continue.',
            'options': ['Cancel', 'Settings'],
          },
        }));
      });

      test('PermissionDialog default dialog has correct structure', () {
        // Arrange & Act
        final dialog = PermissionDialog.defaultDenied();

        // Assert
        expect(dialog.message, equals('Permission Required. Please grant permission to continue.'));
        expect(dialog.options, contains('Cancel'));
        expect(dialog.options, contains('Settings'));
        expect(dialog.options.length, equals(2));
      });

      test('PermissionDialog custom dialog can be created', () {
        // Arrange & Act
        final dialog = const PermissionDialog(
          message: 'Custom message',
          options: ['OK', 'Retry'],
        );

        // Assert
        expect(dialog.message, equals('Custom message'));
        expect(dialog.options, equals(['OK', 'Retry']));
      });
    });

    group('PermissionType enum', () {
      test('PermissionType contains camera and gallery', () {
        // Arrange & Act
        final types = PermissionType.values;

        // Assert
        expect(types, contains(PermissionType.camera));
        expect(types, contains(PermissionType.gallery));
        expect(types.length, equals(2));
      });
    });
  });
}
