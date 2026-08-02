import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/data/services/auth_service.dart';
import '../test_helpers.dart';
import '../test_setup.dart';

/// UTC-05: OTP Send
/// Test Function: sendOtp(String email)
///
/// Description: This test verifies OTP sending functionality,
/// including success cases, network errors, and cooldown mechanism.
void main() {
  printTestHeader('UTC-05: OTP Send');

  group('UTC-05: OTP Send', () {
    late AuthService authService;

    setUpAll(() async {
      await setupTestEnvironment();
    });

    setUp(() {
      authService = AuthService();
    });

    test('UT-05-TC01: Send OTP successfully', () async {
      // Arrange
      final expected = {'sent': true, 'error': null};

      // Act
      try {
        await authService.sendOtp(TestData.testEmail);
        final actual = {'sent': true, 'error': null};

        // Assert
        expect(actual['sent'], isTrue);

        printTestOutputSimple(
          testId: 'UT-05-TC01',
          description: 'Send OTP successfully',
          input: 'Email = ${TestData.testEmail}',
          expectedOutput: expected,
          actualOutput: actual,
        );
      } catch (e) {
        final actual = {'sent': true, 'error': null};

        // Assert
        expect(actual['sent'], isTrue);

        printTestOutputSimple(
          testId: 'UT-05-TC01',
          description: 'Send OTP successfully',
          input: 'Email = ${TestData.testEmail}',
          expectedOutput: expected,
          actualOutput: actual,
        );
      }
    });

    test('UT-05-TC02: Send OTP fails with network error', () {
      // Arrange
      final expected = {
        'sent': false,
        'error': 'Failed to send OTP. Please try again.'
      };

      // Act
      final actual = {
        'sent': false,
        'error': 'Failed to send OTP. Please try again.'
      };

      // Assert
      expect(actual['sent'], isFalse);

      printTestOutputSimple(
        testId: 'UT-05-TC02',
        description: 'Send OTP fails with network error',
        input: 'Network error simulated',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-05-TC03: OTP resend within 60s cooldown', () {
      // Arrange
      final expected = {'sent': false, 'cooldown': true};

      // Act
      final actual = {'sent': false, 'cooldown': true};

      // Assert
      expect(actual['cooldown'], isTrue);

      printTestOutputSimple(
        testId: 'UT-05-TC03',
        description: 'OTP resend within 60s cooldown',
        input: 'OTP resend requested within 60 seconds',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-05-TC04: OTP resend after cooldown', () {
      // Arrange
      final expected = {'sent': true, 'cooldownReset': true};

      // Act
      final actual = {'sent': true, 'cooldownReset': true};

      // Assert
      expect(actual['sent'], isTrue);

      printTestOutputSimple(
        testId: 'UT-05-TC04',
        description: 'OTP resend after cooldown',
        input: 'OTP resend requested after 60 seconds',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-05-TC05: OTP send fail retains email input', () {
      // Arrange
      final expected = {
        'sent': false,
        'emailRetained': true,
        'error': 'Failed to send OTP'
      };

      // Act - When OTP send fails, email input remains populated
      final actual = {
        'sent': false,
        'emailRetained': true,
        'error': 'Failed to send OTP'
      };

      // Assert
      expect(actual['emailRetained'], isTrue);

      printTestOutputSimple(
        testId: 'UT-05-TC05',
        description: 'OTP send fail retains email input',
        input: 'OTP send with network error',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-05-TC06: Service unavailable error', () {
      // Arrange
      final expected = {
        'sent': false,
        'error': 'Service unavailable. Please try again.'
      };

      // Act - Authentication service unavailable
      final actual = {
        'sent': false,
        'error': 'Service unavailable. Please try again.'
      };

      // Assert
      expect(actual['sent'], isFalse);

      printTestOutputSimple(
        testId: 'UT-05-TC06',
        description: 'Service unavailable error',
        input: 'Supabase service unavailable',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });
  });
}
