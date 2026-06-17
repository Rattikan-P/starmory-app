import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/utils/snackbar_helper.dart';
import 'test_helpers.dart';

void main() {
  group('UTC-01: Email Validation', () {
    test('UT-01-TC01: Valid standard email accepted', () {
      final actual = SnackBarHelper.isValidEmail(TestData.validEmail);
      printTestResult({'valid': actual});
      expect(actual, true);
    });

    test('UT-01-TC02: Valid email with subdomain accepted', () {
      final actual = SnackBarHelper.isValidEmail(TestData.validEmailSubdomain);
      printTestResult({'valid': actual});
      expect(actual, true);
    });

    test('UT-01-TC03: Reject email without @ symbol', () {
      final actual = SnackBarHelper.isValidEmail(TestData.invalidEmail);
      printTestResult({'valid': actual});
      expect(actual, false);
    });

    test('UT-01-TC04: Reject email without local part', () {
      final actual = SnackBarHelper.isValidEmail(TestData.emailWithoutAt);
      printTestResult({'valid': actual});
      expect(actual, false);
    });

    test('UT-01-TC05: Reject email with invalid domain', () {
      final actual = SnackBarHelper.isValidEmail(TestData.emailWithInvalidDomain);
      printTestResult({'valid': actual});
      expect(actual, false);
    });

    test('UT-01-TC06: Reject empty email', () {
      final actual = SnackBarHelper.isValidEmail(TestData.emptyEmail);
      printTestResult({'valid': actual});
      expect(actual, false);
    });

    test('UT-01-TC07: Reject email with spaces', () {
      final actual = SnackBarHelper.isValidEmail(TestData.emailWithSpace);
      printTestResult({'valid': actual});
      expect(actual, false);
    });

    test('UT-01-TC08: Reject email without domain', () {
      final actual = SnackBarHelper.isValidEmail(TestData.emailWithoutDomain);
      printTestResult({'valid': actual});
      expect(actual, false);
    });
  });
}
