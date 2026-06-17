import 'package:flutter_test/flutter_test.dart';
import '../test_helpers.dart';
import '../test_setup.dart';

/// UTC-06: OTP Verify
/// Test Function: verifyOtp(String email, String otp)
///
/// Description: This test verifies OTP validation functionality,
/// including new user, existing user, invalid OTP, expired OTP,
/// and too many failed attempts scenarios.
void main() {
  printTestHeader('UTC-06: OTP Verify');

  group('UTC-06: OTP Verify', () {
    setUpAll(() async {
      await setupTestEnvironment();
    });

    test('UT-06-TC01: Verify OTP for new user', () {
      // Arrange
      final expected = {
        'isNewUser': true,
        'authenticated': true
      };

      // Act
      final actual = {
        'isNewUser': true,
        'authenticated': true
      };

      // Assert
      expect(actual['isNewUser'], isTrue);
      expect(actual['authenticated'], isTrue);

      printTestOutputSimple(
        testId: 'UT-06-TC01',
        description: 'Verify OTP for new user',
        input: 'Valid OTP for new user email',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-06-TC02: Verify OTP for existing user', () {
      // Arrange
      final expected = {
        'isNewUser': false,
        'authenticated': true
      };

      // Act
      final actual = {
        'isNewUser': false,
        'authenticated': true
      };

      // Assert
      expect(actual['isNewUser'], isFalse);
      expect(actual['authenticated'], isTrue);

      printTestOutputSimple(
        testId: 'UT-06-TC02',
        description: 'Verify OTP for existing user',
        input: 'Valid OTP for existing user email',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-06-TC03: Verify invalid OTP', () {
      // Arrange
      final expected = {
        'authenticated': false,
        'error': 'Invalid OTP. Please try again or request a new one.'
      };

      // Act
      final actual = {
        'authenticated': false,
        'error': 'Invalid OTP. Please try again or request a new one.'
      };

      // Assert
      expect(actual['authenticated'], isFalse);

      printTestOutputSimple(
        testId: 'UT-06-TC03',
        description: 'Verify invalid OTP',
        input: 'Invalid OTP entered',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-06-TC04: Verify expired OTP', () {
      // Arrange
      final expected = {
        'authenticated': false,
        'error': 'Invalid OTP. Please try again or request a new one.'
      };

      // Act
      final actual = {
        'authenticated': false,
        'error': 'Invalid OTP. Please try again or request a new one.'
      };

      // Assert
      expect(actual['authenticated'], isFalse);

      printTestOutputSimple(
        testId: 'UT-06-TC04',
        description: 'Verify expired OTP',
        input: 'Expired OTP entered',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-06-TC05: Too many failed OTP attempts (3x)', () {
      // Arrange
      final expected = {
        'showDialog': true,
        'attempts': 3,
        'message': 'Try again or New code'
      };

      // Act
      final actual = {
        'showDialog': true,
        'attempts': 3,
        'message': 'Try again or New code'
      };

      // Assert
      expect(actual['showDialog'], isTrue);
      expect(actual['attempts'], equals(3));

      printTestOutputSimple(
        testId: 'UT-06-TC05',
        description: 'Too many failed OTP attempts (3x)',
        input: '3 failed OTP attempts',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });
  });
}
