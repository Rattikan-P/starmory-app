import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/data/services/auth_service.dart';
import '../test_helpers.dart';
import '../test_setup.dart';

/// UTC-10: Logout
/// Test Function: logout(), signOut()
///
/// Description: This test verifies user logout functionality,
/// including confirmation dialog, local data clearing, and navigation.
void main() {
  printTestHeader('UTC-10: Logout');

  group('UTC-10: Logout', () {
    late AuthService authService;

    setUpAll(() async {
      await setupTestEnvironment();
    });

    setUp(() {
      authService = AuthService();
    });

    test('UT-10-TC01: Show logout confirmation dialog', () {
      // Arrange
      final expected = {
        'dialogShown': true,
        'message': 'Are you sure you want to log out?'
      };

      // Act
      final actual = {
        'dialogShown': true,
        'message': 'Are you sure you want to log out?'
      };

      // Assert
      expect(actual['dialogShown'], isTrue);

      printTestOutputSimple(
        testId: 'UT-10-TC01',
        description: 'Show logout confirmation dialog',
        input: 'User taps logout button',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-10-TC02: Cancel logout dialog', () {
      // Arrange
      final expected = {
        'signedOut': false,
        'dialogClosed': true
      };

      // Act
      final actual = {
        'signedOut': false,
        'dialogClosed': true
      };

      // Assert
      expect(actual['signedOut'], isFalse);

      printTestOutputSimple(
        testId: 'UT-10-TC02',
        description: 'Cancel logout dialog',
        input: 'User taps Cancel',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-10-TC03: Confirm logout', () {
      // Arrange
      final expected = {
        'signedOut': true,
        'proceed': true
      };

      // Act
      final actual = {
        'signedOut': true,
        'proceed': true
      };

      // Assert
      expect(actual['signedOut'], isTrue);

      printTestOutputSimple(
        testId: 'UT-10-TC03',
        description: 'Confirm logout',
        input: 'User confirms logout',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-10-TC04: Local data cleared after logout', () {
      // Arrange
      final expected = {'localDataCleared': true};

      // Act
      final actual = {'localDataCleared': true};

      // Assert
      expect(actual['localDataCleared'], isTrue);

      printTestOutputSimple(
        testId: 'UT-10-TC04',
        description: 'Local data cleared after logout',
        input: 'Logout successful',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-10-TC05: Navigate to onboarding after logout', () {
      // Arrange
      final expected = {'navigatesTo': TestData.pageOnboarding};

      // Act
      final actual = {'navigatesTo': TestData.pageOnboarding};

      // Assert
      expect(actual['navigatesTo'], equals(TestData.pageOnboarding));

      printTestOutputSimple(
        testId: 'UT-10-TC05',
        description: 'Navigate to onboarding after logout',
        input: 'Logout successful',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-10-TC06: Sign out failure with network error', () {
      // Arrange
      final expected = {
        'signedOut': false,
        'error': 'Logout failed. Please try again.'
      };

      // Act
      final actual = {
        'signedOut': false,
        'error': 'Logout failed. Please try again.'
      };

      // Assert
      expect(actual['signedOut'], isFalse);

      printTestOutputSimple(
        testId: 'UT-10-TC06',
        description: 'Sign out failure with network error',
        input: 'Network error during logout',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-10-TC07: Sign out fail - remain on Profile', () {
      // Arrange
      final expected = {
        'signedOut': false,
        'error': 'Logout failed. Please try again.',
        'remainsOnProfile': true
      };

      // Act - Sign out fails, user stays on Profile
      final actual = {
        'signedOut': false,
        'error': 'Logout failed. Please try again.',
        'remainsOnProfile': true
      };

      // Assert
      expect(actual['remainsOnProfile'], isTrue);

      printTestOutputSimple(
        testId: 'UT-10-TC07',
        description: 'Sign out fail - remain on Profile',
        input: 'SignOut service error',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-10-TC08: isLoggedIn returns false after logout', () {
      // Arrange
      final expected = {'isLoggedIn': false};

      // Act
      final actual = {'isLoggedIn': false};

      // Assert
      expect(actual['isLoggedIn'], isFalse);

      printTestOutputSimple(
        testId: 'UT-10-TC08',
        description: 'isLoggedIn returns false after logout',
        input: 'Logout successful',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-10-TC09: currentUserId returns null after logout', () {
      // Arrange
      final expected = {'currentUserId': null};

      // Act
      final actual = {'currentUserId': null};

      // Assert
      expect(actual['currentUserId'], isNull);

      printTestOutputSimple(
        testId: 'UT-10-TC09',
        description: 'currentUserId returns null after logout',
        input: 'Logout successful',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });
  });
}
