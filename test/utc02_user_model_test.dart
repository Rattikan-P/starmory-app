import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/data/models/user_model.dart';
import 'test_helpers.dart';

void main() {
  group('UTC-02: User Model Creation', () {
    test('UT-02-TC01: Create guest user', () {
      final guest = UserModel.createGuest();
      printTestResult({
        'isGuest': guest.isGuest,
        'email': guest.email,
        'quota': guest.quotaManager.getRemainingTotal()
      });
      expect(guest.isGuest, true);
      expect(guest.email, "guest@starmory.com");
      expect(guest.quotaManager.getRemainingTotal(), 10);
    });

    test('UT-02-TC02: Create registered user', () {
      final user = UserModel.createRegisteredUser(
        id: TestData.testUserId,
        email: TestData.testEmail,
      );
      printTestResult({
        'isGuest': user.isGuest,
        'id': user.id,
        'email': user.email
      });
      expect(user.isGuest, false);
      expect(user.id, TestData.testUserId);
      expect(user.email, TestData.testEmail);
    });

    test('UT-02-TC03: Guest has default quota (10)', () {
      final guest = UserModel.createGuest();
      printTestResult({
        'quota': guest.quotaManager.getRemainingTotal()
      });
      expect(guest.quotaManager.getRemainingTotal(), 10);
    });

    test('UT-02-TC04: Guest has default preferences (B1, US)', () {
      final guest = UserModel.createGuest();
      printTestResult({
        'defaultCefrLevel': guest.languageLevel,
        'languageVariant': guest.englishVariant
      });
      expect(guest.languageLevel, "B1");
      expect(guest.englishVariant, "US");
    });

    test('UT-02-TC05: Update language level to A1', () {
      final userModel = UserModel.createGuest().updateLanguageLevel(TestData.languageLevelA1);
      printTestResult({
        'defaultCefrLevel': userModel.languageLevel
      });
      expect(userModel.languageLevel, TestData.languageLevelA1);
    });

    test('UT-02-TC06: Update language level to B2', () {
      final userModel = UserModel.createGuest().updateLanguageLevel(TestData.languageLevelB2);
      printTestResult({
        'defaultCefrLevel': userModel.languageLevel
      });
      expect(userModel.languageLevel, TestData.languageLevelB2);
    });

    test('UT-02-TC07: Update English variant to UK', () {
      final userModel = UserModel.createGuest().updateEnglishVariant(TestData.englishVariantUK);
      printTestResult({
        'languageVariant': userModel.englishVariant
      });
      expect(userModel.englishVariant, TestData.englishVariantUK);
    });

    test('UT-02-TC08: Get language level getter', () {
      final userModel = UserModel.createGuest().updateLanguageLevel(TestData.languageLevelB1);
      printTestResult({
        'languageLevel': userModel.languageLevel
      });
      expect(userModel.languageLevel, TestData.languageLevelB1);
    });

    test('UT-02-TC09: Get English variant getter', () {
      final userModel = UserModel.createGuest().updateEnglishVariant(TestData.englishVariantUS);
      printTestResult({
        'englishVariant': userModel.englishVariant
      });
      expect(userModel.englishVariant, TestData.englishVariantUS);
    });
  });
}
