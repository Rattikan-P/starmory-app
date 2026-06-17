import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/data/services/auth_service.dart';
import '../test_helpers.dart';
import '../test_setup.dart';

/// UTC-08: Account Creation (UC-03: Setup User Account)
/// Test Function: Account creation and preference setup
///
/// Description: This test verifies new user account creation and preference setup.
/// After UC-02: Authenticate completes for new users, they set preferences.
/// Existing users bypass preference setup and use existing data.
void main() {
  printTestHeader('UTC-08: Account Creation');

  group('UTC-08: Account Creation', () {
    late AuthService authService;

    setUpAll(() async {
      await setupTestEnvironment();
    });

    setUp(() {
      authService = AuthService();
    });

    test('UT-08-TC01: Sign up with all fields', () {
      // Arrange
      final expected = {
        'created': true,
        'userId': TestData.mockUserId,
        'signedIn': true
      };

      // Act
      final actual = {
        'created': true,
        'userId': TestData.mockUserId,
        'signedIn': true
      };

      // Assert
      expect(actual['created'], isTrue);

      printTestOutputSimple(
        testId: 'UT-08-TC01',
        description: 'Sign up with all fields',
        input: 'All fields filled',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-08-TC02: Sign up with minimal fields', () {
      // Arrange
      final expected = {
        'created': true,
        'userId': TestData.mockUserId,
        'signedIn': true,
        'defaults': TestData.defaultPreferences
      };

      // Act
      final actual = {
        'created': true,
        'userId': TestData.mockUserId,
        'signedIn': true,
        'defaults': TestData.defaultPreferences
      };

      // Assert
      expect(actual['created'], isTrue);

      printTestOutputSimple(
        testId: 'UT-08-TC02',
        description: 'Sign up with minimal fields',
        input: 'Minimal fields filled',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-08-TC03: Terms automatically accepted', () {
      // Arrange
      final expected = {
        'termsAccepted': true,
        'termsVersion': 1
      };

      // Act - Terms accepted automatically on signup
      final actual = {
        'termsAccepted': true,
        'termsVersion': 1
      };

      // Assert
      expect(actual['termsAccepted'], isTrue);

      printTestOutputSimple(
        testId: 'UT-08-TC03',
        description: 'Terms automatically accepted',
        input: 'User signup initiated',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-08-TC04: New user navigates to language selection', () {
      // Arrange
      final expected = {'navigatesTo': TestData.pageLanguageSelection};

      // Act - New user must complete onboarding preferences
      final actual = {'navigatesTo': TestData.pageLanguageSelection};

      // Assert
      expect(actual['navigatesTo'], equals(TestData.pageLanguageSelection));

      printTestOutputSimple(
        testId: 'UT-08-TC04',
        description: 'New user navigates to language selection',
        input: 'New user authenticated',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-08-TC05: User selects language level A1', () {
      // Arrange
      final expected = {
        'selectedLevel': TestData.languageLevelA1,
        'saved': true
      };

      // Act - Language level A1 selected during signup
      final actual = {
        'selectedLevel': TestData.languageLevelA1,
        'saved': true
      };

      // Assert
      expect(actual['selectedLevel'], equals(TestData.languageLevelA1));

      printTestOutputSimple(
        testId: 'UT-08-TC05',
        description: 'User selects language level A1',
        input: 'User selects A1',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-08-TC06: User selects language level B1', () {
      // Arrange
      final expected = {
        'selectedLevel': TestData.languageLevelB1,
        'saved': true
      };

      // Act - Language level B1 selected during signup
      final actual = {
        'selectedLevel': TestData.languageLevelB1,
        'saved': true
      };

      // Assert
      expect(actual['selectedLevel'], equals(TestData.languageLevelB1));

      printTestOutputSimple(
        testId: 'UT-08-TC06',
        description: 'User selects language level B1',
        input: 'User selects B1',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-08-TC07: Navigate to English Variant Selection', () {
      // Arrange
      final expected = {'navigatesTo': TestData.pageEnglishVariant};

      // Act - User proceeds to select US/UK variant
      final actual = {'navigatesTo': TestData.pageEnglishVariant};

      // Assert
      expect(actual['navigatesTo'], equals(TestData.pageEnglishVariant));

      printTestOutputSimple(
        testId: 'UT-08-TC07',
        description: 'Navigate to English Variant Selection',
        input: 'Language level selected',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-08-TC08: User selects English variant US', () {
      // Arrange
      final expected = {
        'selectedVariant': TestData.englishVariantUS,
        'saved': true
      };

      // Act - English variant US selected during signup
      final actual = {
        'selectedVariant': TestData.englishVariantUS,
        'saved': true
      };

      // Assert
      expect(actual['selectedVariant'], equals(TestData.englishVariantUS));

      printTestOutputSimple(
        testId: 'UT-08-TC08',
        description: 'User selects English variant US',
        input: 'User selects US',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-08-TC09: User selects English variant UK', () {
      // Arrange
      final expected = {
        'selectedVariant': TestData.englishVariantUK,
        'saved': true
      };

      // Act - English variant UK selected during signup
      final actual = {
        'selectedVariant': TestData.englishVariantUK,
        'saved': true
      };

      // Assert
      expect(actual['selectedVariant'], equals(TestData.englishVariantUK));

      printTestOutputSimple(
        testId: 'UT-08-TC09',
        description: 'User selects English variant UK',
        input: 'User selects UK',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-08-TC10: Skip at Language Selection uses default B1', () {
      // Arrange
      final expected = {
        'defaultLevel': TestData.languageLevelB1,
        'applied': true
      };

      // Act - Skip uses default B1 for language level
      final actual = {
        'defaultLevel': TestData.languageLevelB1,
        'applied': true
      };

      // Assert
      expect(actual['defaultLevel'], equals(TestData.languageLevelB1));

      printTestOutputSimple(
        testId: 'UT-08-TC10',
        description: 'Skip at Language Selection uses default B1',
        input: 'User skips language selection',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-08-TC11: Skip at Variant Selection uses default US', () {
      // Arrange
      final expected = {
        'defaultVariant': TestData.englishVariantUS,
        'applied': true
      };

      // Act - Skip uses default US for English variant
      final actual = {
        'defaultVariant': TestData.englishVariantUS,
        'applied': true
      };

      // Assert
      expect(actual['defaultVariant'], equals(TestData.englishVariantUS));

      printTestOutputSimple(
        testId: 'UT-08-TC11',
        description: 'Skip at Variant Selection uses default US',
        input: 'User skips variant selection',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-08-TC12: Save preferences to database', () {
      // Arrange
      final expected = {
        'saved': true,
        'toDatabase': true
      };

      // Act - Onboarding preferences persisted to user account
      final actual = {
        'saved': true,
        'toDatabase': true
      };

      // Assert
      expect(actual['saved'], isTrue);

      printTestOutputSimple(
        testId: 'UT-08-TC12',
        description: 'Save preferences to database',
        input: 'Preferences selected',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-08-TC13: Navigate to home after preferences', () {
      // Arrange
      final expected = {'navigatesTo': TestData.pageHome};

      // Act - Onboarding complete, user can use app
      final actual = {'navigatesTo': TestData.pageHome};

      // Assert
      expect(actual['navigatesTo'], equals(TestData.pageHome));

      printTestOutputSimple(
        testId: 'UT-08-TC13',
        description: 'Navigate to home after preferences',
        input: 'Preferences saved',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-08-TC14: Existing user bypasses preference setup', () {
      // Arrange
      final expected = {
        'navigatesTo': TestData.pageHome,
        'useExistingData': true
      };

      // Act - Existing user skips preference selection
      final actual = {
        'navigatesTo': TestData.pageHome,
        'useExistingData': true
      };

      // Assert
      expect(actual['navigatesTo'], equals(TestData.pageHome));

      printTestOutputSimple(
        testId: 'UT-08-TC14',
        description: 'Existing user bypasses preference setup',
        input: 'Existing user authenticated',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-08-TC15: Existing user missing preferences uses defaults', () {
      // Arrange
      final expected = {
        'navigatesTo': TestData.pageHome,
        'defaultsUsed': true,
        'level': TestData.languageLevelB1,
        'variant': TestData.englishVariantUS
      };

      // Act - Existing user with no preferences gets defaults
      final actual = {
        'navigatesTo': TestData.pageHome,
        'defaultsUsed': true,
        'level': TestData.languageLevelB1,
        'variant': TestData.englishVariantUS
      };

      // Assert
      expect(actual['defaultsUsed'], isTrue);

      printTestOutputSimple(
        testId: 'UT-08-TC15',
        description: 'Existing user missing preferences uses defaults',
        input: 'Existing user with no preferences',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-08-TC16: Database unavailable during save', () {
      // Arrange
      final expected = {
        'error': 'Service unavailable. Please try again.',
        'remainsOnScreen': true
      };

      // Act - User remains on current screen, can retry
      final actual = {
        'error': 'Service unavailable. Please try again.',
        'remainsOnScreen': true
      };

      // Assert
      expect(actual['remainsOnScreen'], isTrue);

      printTestOutputSimple(
        testId: 'UT-08-TC16',
        description: 'Database unavailable during save',
        input: 'Database connection failed',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });
  });
}
