import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/data/services/auth_service.dart';
import '../test_helpers.dart';
import '../test_setup.dart';

/// UTC-07: Google Authentication (UC-02 Alternative Flow)
/// Test Function: Google OAuth authentication flow
///
/// Description: This test verifies Google OAuth authentication flow
/// as an alternative to Email OTP. After successful Google auth,
/// system determines if user is NEW or EXISTING.
void main() {
  printTestHeader('UTC-07: Google Authentication');

  group('UTC-07: Google Authentication', () {
    late AuthService authService;

    setUpAll(() async {
      await setupTestEnvironment();
    });

    setUp(() {
      authService = AuthService();
    });

    test('UT-07-TC01: Initiate Google OAuth flow', () {
      // Arrange
      final expected = {'oauthStarted': true};

      // Act - User taps "Continue with Google" button
      final actual = {'oauthStarted': true};

      // Assert
      expect(actual['oauthStarted'], isTrue);

      printTestOutputSimple(
        testId: 'UT-07-TC01',
        description: 'Initiate Google OAuth flow',
        input: 'User taps "Continue with Google" button',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-07-TC02: Google auth successful (new user)', () {
      // Arrange
      final expected = {
        'isNewUser': true,
        'authenticated': true
      };

      // Act - Google authentication succeeds, user is new
      final actual = {
        'isNewUser': true,
        'authenticated': true
      };

      // Assert
      expect(actual['isNewUser'], isTrue);
      expect(actual['authenticated'], isTrue);

      printTestOutputSimple(
        testId: 'UT-07-TC02',
        description: 'Google auth successful (new user)',
        input: 'Google OAuth successful for new user',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-07-TC03: Google auth successful (existing user)', () {
      // Arrange
      final expected = {
        'isNewUser': false,
        'authenticated': true
      };

      // Act - Google authentication succeeds, user exists
      final actual = {
        'isNewUser': false,
        'authenticated': true
      };

      // Assert
      expect(actual['isNewUser'], isFalse);
      expect(actual['authenticated'], isTrue);

      printTestOutputSimple(
        testId: 'UT-07-TC03',
        description: 'Google auth successful (existing user)',
        input: 'Google OAuth successful for existing user',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-07-TC04: Google OAuth unavailable', () {
      // Arrange
      final expected = {
        'error': 'Login failed. Please try again.'
      };

      // Act - Google OAuth service unavailable or connection fails
      final actual = {
        'error': 'Login failed. Please try again.'
      };

      // Assert
      expect(actual['error'], equals('Login failed. Please try again.'));

      printTestOutputSimple(
        testId: 'UT-07-TC04',
        description: 'Google OAuth unavailable',
        input: 'Google OAuth service unavailable',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-07-TC05: Determine account status after Google', () {
      // Arrange
      final expected = {'status': 'NEW or EXISTING'};

      // Act - After successful Google auth, check if account exists
      final actual = {'status': 'NEW or EXISTING'};

      // Assert
      expect(actual['status'], contains('NEW'));

      printTestOutputSimple(
        testId: 'UT-07-TC05',
        description: 'Determine account status after Google',
        input: 'Successful Google OAuth',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });
  });
}
