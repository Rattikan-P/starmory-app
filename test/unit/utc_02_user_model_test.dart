import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/data/models/user_model.dart';
import '../test_helpers.dart';

/// UTC-02: User Model Creation
/// Test Function: UserModel.createGuest(), UserModel.createRegisteredUser()
///
/// Description: This test verifies that the system correctly creates
/// guest and registered user models with proper default values.
void main() {
  printTestHeader('UTC-02: User Model Creation');

  group('UTC-02: User Model Creation', () {
    test('UT-02-TC01: Create guest user', () {
      // Arrange
      final expected = {
        'isGuest': true,
        'email': 'guest@starmory.com',
        'quota': 10
      };

      // Act
      final guest = UserModel.createGuest();

      // Assert
      expect(guest.isGuest, isTrue);
      expect(guest.email, equals('guest@starmory.com'));
      expect(guest.quotaManager.getRemainingTotal(), equals(10));

      printTestOutputSimple(
        testId: 'UT-02-TC01',
        description: 'Create guest user',
        input: 'Operation = createGuest',
        expectedOutput: expected,
        actualOutput: {
          'isGuest': guest.isGuest,
          'email': guest.email,
          'quota': guest.quotaManager.getRemainingTotal()
        },
      );
    });

    test('UT-02-TC02: Create registered user', () {
      // Arrange
      final expected = {
        'isGuest': false,
        'id': TestData.testUserId,
        'email': TestData.testEmail
      };

      // Act
      final user = UserModel.createRegisteredUser(
        id: TestData.testUserId,
        email: TestData.testEmail,
      );

      // Assert
      expect(user.isGuest, isFalse);
      expect(user.id, equals(TestData.testUserId));
      expect(user.email, equals(TestData.testEmail));

      printTestOutputSimple(
        testId: 'UT-02-TC02',
        description: 'Create registered user',
        input: 'ID = ${TestData.testUserId}, Email = ${TestData.testEmail}',
        expectedOutput: expected,
        actualOutput: {
          'isGuest': user.isGuest,
          'id': user.id,
          'email': user.email
        },
      );
    });

    test('UT-02-TC03: Guest has default quota (10)', () {
      // Arrange
      final expected = {'quota': 10};

      // Act
      final guest = UserModel.createGuest();

      // Assert
      expect(guest.quotaManager.getRemainingTotal(), equals(10));

      printTestOutputSimple(
        testId: 'UT-02-TC03',
        description: 'Guest has default quota (10)',
        input: 'Operation = createGuest',
        expectedOutput: expected,
        actualOutput: {'quota': guest.quotaManager.getRemainingTotal()},
      );
    });

    test('UT-02-TC04: Guest has default preferences (B1, US)', () {
      // Arrange
      final expected = {
        'defaultCefrLevel': TestData.languageLevelB1,
        'languageVariant': TestData.englishVariantUS
      };

      // Act
      final guest = UserModel.createGuest();

      // Assert
      expect(guest.languageLevel, equals(TestData.languageLevelB1));
      expect(guest.englishVariant, equals(TestData.englishVariantUS));

      printTestOutputSimple(
        testId: 'UT-02-TC04',
        description: 'Guest has default preferences (B1, US)',
        input: 'Operation = createGuest',
        expectedOutput: expected,
        actualOutput: {
          'defaultCefrLevel': guest.languageLevel,
          'languageVariant': guest.englishVariant
        },
      );
    });

    test('UT-02-TC05: Update language level to A1', () {
      // Arrange
      final expected = {'defaultCefrLevel': TestData.languageLevelA1};

      // Act
      final userModel = UserModel.createGuest().updateLanguageLevel(TestData.languageLevelA1);

      // Assert
      expect(userModel.languageLevel, equals(TestData.languageLevelA1));

      printTestOutputSimple(
        testId: 'UT-02-TC05',
        description: 'Update language level to A1',
        input: 'Language Level = ${TestData.languageLevelA1}',
        expectedOutput: expected,
        actualOutput: {'defaultCefrLevel': userModel.languageLevel},
      );
    });

    test('UT-02-TC06: Update language level to B2', () {
      // Arrange
      final expected = {'defaultCefrLevel': TestData.languageLevelB2};

      // Act
      final userModel = UserModel.createGuest().updateLanguageLevel(TestData.languageLevelB2);

      // Assert
      expect(userModel.languageLevel, equals(TestData.languageLevelB2));

      printTestOutputSimple(
        testId: 'UT-02-TC06',
        description: 'Update language level to B2',
        input: 'Language Level = ${TestData.languageLevelB2}',
        expectedOutput: expected,
        actualOutput: {'defaultCefrLevel': userModel.languageLevel},
      );
    });

    test('UT-02-TC07: Update English variant to UK', () {
      // Arrange
      final expected = {'languageVariant': TestData.englishVariantUK};

      // Act
      final userModel = UserModel.createGuest().updateEnglishVariant(TestData.englishVariantUK);

      // Assert
      expect(userModel.englishVariant, equals(TestData.englishVariantUK));

      printTestOutputSimple(
        testId: 'UT-02-TC07',
        description: 'Update English variant to UK',
        input: 'English Variant = ${TestData.englishVariantUK}',
        expectedOutput: expected,
        actualOutput: {'languageVariant': userModel.englishVariant},
      );
    });

    test('UT-02-TC08: Get language level getter', () {
      // Arrange
      final expected = {'languageLevel': TestData.languageLevelB1};

      // Act
      final userModel = UserModel.createGuest().updateLanguageLevel(TestData.languageLevelB1);

      // Assert
      expect(userModel.languageLevel, equals(TestData.languageLevelB1));

      printTestOutputSimple(
        testId: 'UT-02-TC08',
        description: 'Get language level getter',
        input: 'Language Level = ${TestData.languageLevelB1}',
        expectedOutput: expected,
        actualOutput: {'languageLevel': userModel.languageLevel},
      );
    });

    test('UT-02-TC09: Get English variant getter', () {
      // Arrange
      final expected = {'englishVariant': TestData.englishVariantUS};

      // Act
      final userModel = UserModel.createGuest().updateEnglishVariant(TestData.englishVariantUS);

      // Assert
      expect(userModel.englishVariant, equals(TestData.englishVariantUS));

      printTestOutputSimple(
        testId: 'UT-02-TC09',
        description: 'Get English variant getter',
        input: 'English Variant = ${TestData.englishVariantUS}',
        expectedOutput: expected,
        actualOutput: {'englishVariant': userModel.englishVariant},
      );
    });
  });
}
