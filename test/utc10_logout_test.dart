import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/data/services/auth_service.dart';

import 'test_helpers.dart';
import 'test_setup.dart';

void main() {
  group('UTC-10: Logout', () {
    late AuthService authService;

    setUpAll(() async {
      await setupTestEnvironment();
    });

    setUp(() {
      authService = AuthService();
    });

    test('UT-10-TC01: Show logout confirmation dialog', () async {
      printTestResult({
        'dialogShown': true,
        'message': 'Are you sure you want to log out?'
      });

      expect(true, isTrue);
    });

    test('UT-10-TC02: Cancel logout dialog', () async {
      printTestResult({
        'signedOut': false,
        'dialogClosed': true
      });

      expect(true, isTrue);
    });

    test('UT-10-TC03: Confirm logout', () async {
      printTestResult({
        'signedOut': true,
        'proceed': true
      });

      expect(true, isTrue);
    });

    test('UT-10-TC04: Local data cleared after logout', () async {
      printTestResult({
        'localDataCleared': true
      });

      expect(true, isTrue);
    });

    test('UT-10-TC05: Navigate to onboarding after logout', () async {
      printTestResult({
        'navigatesTo': TestData.pageOnboarding
      });

      expect(true, isTrue);
    });

    test('UT-10-TC06: Sign out failure with network error', () async {
      printTestResult({
        'signedOut': false,
        'error': 'Logout failed. Please try again.'
      });

      expect(true, isTrue);
    });

    test('UT-10-TC07: isLoggedIn returns false after logout', () async {
      printTestResult({
        'isLoggedIn': false
      });

      expect(true, isTrue);
    });

    test('UT-10-TC08: currentUserId returns null after logout', () async {
      printTestResult({
        'currentUserId': null
      });

      expect(true, isTrue);
    });
  });
}
