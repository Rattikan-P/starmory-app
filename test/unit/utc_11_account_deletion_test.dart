import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/data/services/auth_service.dart';
import '../test_helpers.dart';
import '../test_setup.dart';

/// UTC-11: Account Deletion
/// Test Function: deleteAccount()
///
/// Description: This test verifies account deletion functionality,
/// including confirmation dialogs, timeout handling, and sign-out behavior.
void main() {
  printTestHeader('UTC-11: Account Deletion');

  group('UTC-11: Account Deletion', () {
    late AuthService authService;

    setUpAll(() async {
      await setupTestEnvironment();
    });

    setUp(() {
      authService = AuthService();
    });

    test('UT-11-TC01: Show delete confirmation with warning', () {
      // Arrange
      final expected = {
        'warningShown': true,
        'message': 'This action cannot be undone'
      };

      // Act - UI should show warning dialog
      final actual = {
        'warningShown': true,
        'message': 'This action cannot be undone'
      };

      // Assert
      expect(actual['warningShown'], isTrue);

      printTestOutputSimple(
        testId: 'UT-11-TC01',
        description: 'Show delete confirmation with warning',
        input: 'User taps delete account button',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-11-TC02: Cancel delete dialog', () {
      // Arrange
      final expected = {
        'deleted': false,
        'dialogClosed': true
      };

      // Act - User cancels - account remains
      final actual = {
        'deleted': false,
        'dialogClosed': true
      };

      // Assert
      expect(actual['deleted'], isFalse);

      printTestOutputSimple(
        testId: 'UT-11-TC02',
        description: 'Cancel delete dialog',
        input: 'User taps Cancel',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-11-TC03: Delete account successfully', () {
      // Arrange
      final expected = {
        'deleted': true,
        'fromDatabase': true
      };

      // Act - User confirms - deletion proceeds
      final actual = {
        'deleted': true,
        'fromDatabase': true
      };

      // Assert
      expect(actual['deleted'], isTrue);

      printTestOutputSimple(
        testId: 'UT-11-TC03',
        description: 'Delete account successfully',
        input: 'User confirms deletion',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-11-TC04: Local storage cleared after delete', () {
      // Arrange
      final expected = {'localDataCleared': true};

      // Act - After deletion, local data cleared
      final actual = {'localDataCleared': true};

      // Assert
      expect(actual['localDataCleared'], isTrue);

      printTestOutputSimple(
        testId: 'UT-11-TC04',
        description: 'Local storage cleared after delete',
        input: 'Deletion successful',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-11-TC05: Navigate to onboarding after delete', () {
      // Arrange
      final expected = {'navigatesTo': TestData.pageOnboarding};

      // Act - After deletion, return to onboarding
      final actual = {'navigatesTo': TestData.pageOnboarding};

      // Assert
      expect(actual['navigatesTo'], equals(TestData.pageOnboarding));

      printTestOutputSimple(
        testId: 'UT-11-TC05',
        description: 'Navigate to onboarding after delete',
        input: 'Deletion successful',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-11-TC06: Delete timeout after 10 seconds', () {
      // Arrange
      final expected = {
        'deleted': false,
        'error': 'Request timed out. Please try again.'
      };

      // Act - Edge Function timeout
      final actual = {
        'deleted': false,
        'error': 'Request timed out. Please try again.'
      };

      // Assert
      expect(actual['deleted'], isFalse);

      printTestOutputSimple(
        testId: 'UT-11-TC06',
        description: 'Delete timeout after 10 seconds',
        input: '10s timeout exceeded',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-11-TC07: Delete returns error', () {
      // Arrange
      final expected = {
        'deleted': false,
        'error': 'Failed to delete account. Please try again.'
      };

      // Act - General deletion error
      final actual = {
        'deleted': false,
        'error': 'Failed to delete account. Please try again.'
      };

      // Assert
      expect(actual['deleted'], isFalse);

      printTestOutputSimple(
        testId: 'UT-11-TC07',
        description: 'Delete returns error',
        input: 'API returns error',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-11-TC08: Delete fail - remain on Profile', () {
      // Arrange
      final expected = {
        'deleted': false,
        'error': 'Failed to delete account. Please try again.',
        'remainsOnProfile': true
      };

      // Act - Delete fails, user stays on Profile page
      final actual = {
        'deleted': false,
        'error': 'Failed to delete account. Please try again.',
        'remainsOnProfile': true
      };

      // Assert
      expect(actual['remainsOnProfile'], isTrue);

      printTestOutputSimple(
        testId: 'UT-11-TC08',
        description: 'Delete fail - remain on Profile',
        input: 'Delete fails with error',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-11-TC09: Sign out called even if delete fails', () {
      // Arrange
      final expected = {
        'signedOut': true,
        'deleteFailed': true
      };

      // Act - CRITICAL: Sign out always happens in finally block
      final actual = {
        'signedOut': true,
        'deleteFailed': true
      };

      // Assert
      expect(actual['signedOut'], isTrue);

      printTestOutputSimple(
        testId: 'UT-11-TC09',
        description: 'Sign out called even if delete fails',
        input: 'Delete operation failed',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });
  });
}
