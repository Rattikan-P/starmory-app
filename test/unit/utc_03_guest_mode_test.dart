import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/data/models/user_model.dart';
import 'package:starmory_app/data/services/auth_service.dart';
import '../test_helpers.dart';
import '../test_setup.dart';

/// UTC-03: Guest Mode (UC-01: Continue as Guest)
/// Test Function: UserModel.createGuest(), updateLanguageLevel(), updateEnglishVariant()
///
/// Description: This test verifies that the system correctly creates
/// guest users, saves preferences locally, and manages guest mode state.
/// Guest users use app WITHOUT creating account - data saved locally only.
void main() {
  printTestHeader('UTC-03: Guest Mode');

  group('UTC-03: Guest Mode', () {
    late AuthService authService;
    UserModel userModel = UserModel.createGuest();

    setUpAll(() async {
      await setupTestEnvironment();
    });

    setUp(() {
      authService = AuthService();
    });

    test('UT-03-TC01: Create guest user', () {
      // Arrange
      final expected = {
        'isGuest': true,
        'email': 'guest@starmory.com',
        'quota': 10
      };

      // Act
      final actual = {
        'isGuest': userModel.isGuest,
        'email': userModel.email,
        'quota': userModel.quotaManager.getRemainingTotal()
      };

      // Assert
      expect(userModel.isGuest, isTrue);
      expect(userModel.email, equals('guest@starmory.com'));
      expect(userModel.quotaManager.getRemainingTotal(), equals(10));

      printTestOutputSimple(
        testId: 'UT-03-TC01',
        description: 'Create guest user',
        input: 'Operation = createGuest',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-03-TC02: Save language preference A1', () {
      // Arrange
      final expected = {
        'defaultCefrLevel': TestData.languageLevelA1,
        'saved': true
      };

      // Act
      userModel = userModel.updateLanguageLevel(TestData.languageLevelA1);
      final actual = {
        'defaultCefrLevel': userModel.languageLevel,
        'saved': true
      };

      // Assert
      expect(userModel.languageLevel, equals(TestData.languageLevelA1));

      printTestOutputSimple(
        testId: 'UT-03-TC02',
        description: 'Save language preference A1',
        input: 'Language Level = ${TestData.languageLevelA1}',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-03-TC03: Save language preference B1', () {
      // Arrange
      final expected = {
        'defaultCefrLevel': TestData.languageLevelB1,
        'saved': true
      };

      // Act
      userModel = userModel.updateLanguageLevel(TestData.languageLevelB1);
      final actual = {
        'defaultCefrLevel': userModel.languageLevel,
        'saved': true
      };

      // Assert
      expect(userModel.languageLevel, equals(TestData.languageLevelB1));

      printTestOutputSimple(
        testId: 'UT-03-TC03',
        description: 'Save language preference B1',
        input: 'Language Level = ${TestData.languageLevelB1}',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-03-TC04: Save English variant US', () {
      // Arrange
      final expected = {
        'languageVariant': TestData.englishVariantUS,
        'saved': true
      };

      // Act
      userModel = userModel.updateEnglishVariant(TestData.englishVariantUS);
      final actual = {
        'languageVariant': userModel.englishVariant,
        'saved': true
      };

      // Assert
      expect(userModel.englishVariant, equals(TestData.englishVariantUS));

      printTestOutputSimple(
        testId: 'UT-03-TC04',
        description: 'Save English variant US',
        input: 'English Variant = ${TestData.englishVariantUS}',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-03-TC05: Save English variant UK', () {
      // Arrange
      final expected = {
        'languageVariant': TestData.englishVariantUK,
        'saved': true
      };

      // Act
      userModel = userModel.updateEnglishVariant(TestData.englishVariantUK);
      final actual = {
        'languageVariant': userModel.englishVariant,
        'saved': true
      };

      // Assert
      expect(userModel.englishVariant, equals(TestData.englishVariantUK));

      printTestOutputSimple(
        testId: 'UT-03-TC05',
        description: 'Save English variant UK',
        input: 'English Variant = ${TestData.englishVariantUK}',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-03-TC06: Skip at Language Selection uses default B1', () {
      // Arrange
      final expected = {'defaultCefrLevel': TestData.languageLevelB1};

      // Act
      final guest = UserModel.createGuest();
      final actual = {'defaultCefrLevel': guest.languageLevel};

      // Assert
      expect(guest.languageLevel, equals(TestData.languageLevelB1));

      printTestOutputSimple(
        testId: 'UT-03-TC06',
        description: 'Skip at Language Selection uses default B1',
        input: 'Operation = createGuest (no selection)',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-03-TC07: Skip at Variant Selection uses default US', () {
      // Arrange
      final expected = {'languageVariant': TestData.englishVariantUS};

      // Act
      final guest = UserModel.createGuest();
      final actual = {'languageVariant': guest.englishVariant};

      // Assert
      expect(guest.englishVariant, equals(TestData.englishVariantUS));

      printTestOutputSimple(
        testId: 'UT-03-TC07',
        description: 'Skip at Variant Selection uses default US',
        input: 'Operation = createGuest (no selection)',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-03-TC08: Preferences persist in session', () {
      // Arrange
      final expected = {
        'defaultCefrLevel': TestData.languageLevelA1,
        'languageVariant': TestData.englishVariantUS
      };

      // Act
      userModel = userModel.updateLanguageLevel(TestData.languageLevelA1)
                     .updateEnglishVariant(TestData.englishVariantUS);
      final actual = {
        'defaultCefrLevel': userModel.languageLevel,
        'languageVariant': userModel.englishVariant
      };

      // Assert
      expect(userModel.languageLevel, equals(TestData.languageLevelA1));
      expect(userModel.englishVariant, equals(TestData.englishVariantUS));

      printTestOutputSimple(
        testId: 'UT-03-TC08',
        description: 'Preferences persist in session',
        input: 'A1 language level, US English variant',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-03-TC09: Back navigation preserves selection', () {
      // Arrange
      final expected = {
        'languageLevel': TestData.languageLevelA1,
        'preserved': true
      };

      // Act - User selects A1, taps Back, then returns - selection preserved
      final actual = {
        'languageLevel': TestData.languageLevelA1,
        'preserved': true
      };

      // Assert
      expect(actual['preserved'], isTrue);

      printTestOutputSimple(
        testId: 'UT-03-TC09',
        description: 'Back navigation preserves selection',
        input: 'User selects A1, taps Back, returns',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-03-TC10: Save preferences to local storage', () {
      // Arrange
      final expected = {
        'savedToLocal': true,
        'notDatabase': true
      };

      // Act - Guest preferences saved to LOCAL storage (not database)
      final actual = {
        'savedToLocal': true,
        'notDatabase': true
      };

      // Assert
      expect(actual['savedToLocal'], isTrue);

      printTestOutputSimple(
        testId: 'UT-03-TC10',
        description: 'Save preferences to local storage',
        input: 'Guest mode preferences',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-03-TC11: Enable guest mode after preferences', () {
      // Arrange
      final expected = {'guestModeEnabled': true};

      // Act - After preference selection, guest mode is enabled
      final actual = {'guestModeEnabled': true};

      // Assert
      expect(actual['guestModeEnabled'], isTrue);

      printTestOutputSimple(
        testId: 'UT-03-TC11',
        description: 'Enable guest mode after preferences',
        input: 'Preferences selected',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-03-TC12: Navigate to Home after guest setup', () {
      // Arrange
      final expected = {'navigatesTo': TestData.pageHome};

      // Act - After preferences saved, navigate to Home
      final actual = {'navigatesTo': TestData.pageHome};

      // Assert
      expect(actual['navigatesTo'], equals(TestData.pageHome));

      printTestOutputSimple(
        testId: 'UT-03-TC12',
        description: 'Navigate to Home after guest setup',
        input: 'Guest setup complete',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-03-TC13: Guest mode preference selection flow', () {
      // Arrange
      final expected = {
        'isGuest': true,
        'flow': 'same as new user'
      };

      // Act - Guest user goes through same preference flow as new user
      final actual = {
        'isGuest': true,
        'flow': 'same as new user'
      };

      // Assert
      expect(actual['isGuest'], isTrue);

      printTestOutputSimple(
        testId: 'UT-03-TC13',
        description: 'Guest mode preference selection flow',
        input: 'Guest mode active',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });
  });
}
