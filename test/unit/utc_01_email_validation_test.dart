import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/utils/snackbar_helper.dart';
import '../test_helpers.dart';

/// UTC-01: Email Validation
/// Test Function: isValidEmail(String email)
///
/// Description: This test verifies that the system correctly validates
/// email addresses for user authentication.
void main() {
  printTestHeader('UTC-01: Email Validation');

  group('UTC-01: Email Validation', () {
    test('UT-01-TC01: Valid standard email accepted', () {
      // Arrange
      final expected = {'valid': true};

      // Act
      final actual = SnackBarHelper.isValidEmail(TestData.validEmail);

      // Assert
      expect(actual, isTrue);

      printTestOutputSimple(
        testId: 'UT-01-TC01',
        description: 'Valid standard email accepted',
        input: 'Email = ${TestData.validEmail}',
        expectedOutput: expected,
        actualOutput: {'valid': actual},
      );
    });

    test('UT-01-TC02: Valid email with subdomain accepted', () {
      // Arrange
      final expected = {'valid': true};

      // Act
      final actual = SnackBarHelper.isValidEmail(TestData.validEmailSubdomain);

      // Assert
      expect(actual, isTrue);

      printTestOutputSimple(
        testId: 'UT-01-TC02',
        description: 'Valid email with subdomain accepted',
        input: 'Email = ${TestData.validEmailSubdomain}',
        expectedOutput: expected,
        actualOutput: {'valid': actual},
      );
    });

    test('UT-01-TC03: Reject email without @ symbol', () {
      // Arrange
      final expected = {'valid': false};

      // Act
      final actual = SnackBarHelper.isValidEmail(TestData.invalidEmail);

      // Assert
      expect(actual, isFalse);

      printTestOutputSimple(
        testId: 'UT-01-TC03',
        description: 'Reject email without @ symbol',
        input: 'Email = ${TestData.invalidEmail}',
        expectedOutput: expected,
        actualOutput: {'valid': actual},
      );
    });

    test('UT-01-TC04: Reject email without local part', () {
      // Arrange
      final expected = {'valid': false};

      // Act
      final actual = SnackBarHelper.isValidEmail(TestData.emailWithoutAt);

      // Assert
      expect(actual, isFalse);

      printTestOutputSimple(
        testId: 'UT-01-TC04',
        description: 'Reject email without local part',
        input: 'Email = ${TestData.emailWithoutAt}',
        expectedOutput: expected,
        actualOutput: {'valid': actual},
      );
    });

    test('UT-01-TC05: Reject email with invalid domain', () {
      // Arrange
      final expected = {'valid': false};

      // Act
      final actual = SnackBarHelper.isValidEmail(TestData.emailWithInvalidDomain);

      // Assert
      expect(actual, isFalse);

      printTestOutputSimple(
        testId: 'UT-01-TC05',
        description: 'Reject email with invalid domain',
        input: 'Email = ${TestData.emailWithInvalidDomain}',
        expectedOutput: expected,
        actualOutput: {'valid': actual},
      );
    });

    test('UT-01-TC06: Reject empty email', () {
      // Arrange
      final expected = {'valid': false};

      // Act
      final actual = SnackBarHelper.isValidEmail(TestData.emptyEmail);

      // Assert
      expect(actual, isFalse);

      printTestOutputSimple(
        testId: 'UT-01-TC06',
        description: 'Reject empty email',
        input: 'Email = ${TestData.emptyEmail}',
        expectedOutput: expected,
        actualOutput: {'valid': actual},
      );
    });

    test('UT-01-TC07: Reject email with spaces', () {
      // Arrange
      final expected = {'valid': false};

      // Act
      final actual = SnackBarHelper.isValidEmail(TestData.emailWithSpace);

      // Assert
      expect(actual, isFalse);

      printTestOutputSimple(
        testId: 'UT-01-TC07',
        description: 'Reject email with spaces',
        input: 'Email = ${TestData.emailWithSpace}',
        expectedOutput: expected,
        actualOutput: {'valid': actual},
      );
    });

    test('UT-01-TC08: Reject email without domain', () {
      // Arrange
      final expected = {'valid': false};

      // Act
      final actual = SnackBarHelper.isValidEmail(TestData.emailWithoutDomain);

      // Assert
      expect(actual, isFalse);

      printTestOutputSimple(
        testId: 'UT-01-TC08',
        description: 'Reject email without domain',
        input: 'Email = ${TestData.emailWithoutDomain}',
        expectedOutput: expected,
        actualOutput: {'valid': actual},
      );
    });
  });
}
