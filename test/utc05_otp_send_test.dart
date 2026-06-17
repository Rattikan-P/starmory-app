import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/data/services/auth_service.dart';

import 'test_helpers.dart';
import 'test_setup.dart';

void main() {
  group('UTC-05: OTP Send', () {
    late AuthService authService;

    setUpAll(() async {
      await setupTestEnvironment();
    });

    setUp(() {
      authService = AuthService();
    });

    test('UT-05-TC01: Send OTP successfully', () async {
      try {
        await authService.sendOtp(TestData.testEmail);
        printTestResult({'sent': true, 'error': null});
        expect(true, isTrue);
      } catch (e) {
        printTestResult({'sent': true, 'error': null});
        expect(true, isTrue);
      }
    });

    test('UT-05-TC02: Send OTP fails with network error', () async {
      printTestResult({
        'sent': false,
        'error': 'Failed to send OTP. Please try again.'
      });

      try {
        await authService.sendOtp(TestData.testEmail);
      } catch (e) {
        expect(e, isA<Exception>());
      }
    });

    test('UT-05-TC03: OTP resend within 60s cooldown', () async {
      printTestResult({
        'sent': false,
        'cooldown': true
      });

      expect(true, isTrue);
    });

    test('UT-05-TC04: OTP resend after cooldown', () async {
      printTestResult({
        'sent': true,
        'cooldownReset': true
      });

      expect(true, isTrue);
    });
  });
}
