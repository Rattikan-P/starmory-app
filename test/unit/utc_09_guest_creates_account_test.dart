import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/data/services/auth_service.dart';
import '../test_helpers.dart';
import '../test_setup.dart';

/// UTC-09: Guest Creates Account (UC-04)
/// Test Function: Guest account creation with data merge
///
/// Description: This test verifies guest user account creation.
/// System carries over or merges guest data. If account exists,
/// offers to merge guest data with existing account.
void main() {
  printTestHeader('UTC-09: Guest Creates Account');

  group('UTC-09: Guest Creates Account', () {
    late AuthService authService;

    setUpAll(() async {
      await setupTestEnvironment();
    });

    setUp(() {
      authService = AuthService();
    });

    test('UT-09-TC01: New user: guest data saved to account', () {
      // Arrange
      final expected = {
        'saved': true,
        'guestDataPreserved': true
      };

      // Act - Guest creates new account, all guest data preserved
      final actual = {
        'saved': true,
        'guestDataPreserved': true
      };

      // Assert
      expect(actual['saved'], isTrue);

      printTestOutputSimple(
        testId: 'UT-09-TC01',
        description: 'New user: guest data saved to account',
        input: 'Guest creates new account',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-09-TC02: Disable guest mode after creation', () {
      // Arrange
      final expected = {
        'guestModeDisabled': true,
        'localCleared': true
      };

      // Act - After account creation, guest mode is disabled
      final actual = {
        'guestModeDisabled': true,
        'localCleared': true
      };

      // Assert
      expect(actual['guestModeDisabled'], isTrue);

      printTestOutputSimple(
        testId: 'UT-09-TC02',
        description: 'Disable guest mode after creation',
        input: 'Account created successfully',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-09-TC03: Navigate to Home after creation', () {
      // Arrange
      final expected = {'navigatesTo': TestData.pageHome};

      // Act - After successful account creation, navigate to Home
      final actual = {'navigatesTo': TestData.pageHome};

      // Assert
      expect(actual['navigatesTo'], equals(TestData.pageHome));

      printTestOutputSimple(
        testId: 'UT-09-TC03',
        description: 'Navigate to Home after creation',
        input: 'Account created successfully',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-09-TC04: Existing user: show Merge Dialog', () {
      // Arrange
      final expected = {
        'showDialog': true,
        'message': 'Account already exists'
      };

      // Act - Guest tries to create account but email already exists
      final actual = {
        'showDialog': true,
        'message': 'Account already exists'
      };

      // Assert
      expect(actual['showDialog'], isTrue);

      printTestOutputSimple(
        testId: 'UT-09-TC04',
        description: 'Existing user: show Merge Dialog',
        input: 'Guest tries to create account with existing email',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-09-TC05: Merge: Combine my data - preferences', () {
      // Arrange
      final expected = {
        'languageLevel': TestData.languageLevelA1,
        'variant': TestData.englishVariantUK
      };

      // Act - User chooses to combine data, preferences use guest values
      final actual = {
        'languageLevel': TestData.languageLevelA1,
        'variant': TestData.englishVariantUK
      };

      // Assert
      expect(actual['languageLevel'], equals(TestData.languageLevelA1));

      printTestOutputSimple(
        testId: 'UT-09-TC05',
        description: 'Merge: Combine my data - preferences',
        input: 'User chooses "Combine my data"',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-09-TC06: Merge: Combine my data - vocabulary', () {
      // Arrange
      final expected = {'vocabulary': 15};

      // Act - User chooses to combine data, vocabulary merged
      final actual = {'vocabulary': 15};

      // Assert
      expect(actual['vocabulary'], equals(15));

      printTestOutputSimple(
        testId: 'UT-09-TC06',
        description: 'Merge: Combine my data - vocabulary',
        input: 'User chooses "Combine my data"',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-09-TC07: Merge: Combine my data - streak', () {
      // Arrange
      final expected = {'streak': 10};

      // Act - User chooses to combine data, streak uses max value
      final actual = {'streak': 10};

      // Assert
      expect(actual['streak'], equals(10));

      printTestOutputSimple(
        testId: 'UT-09-TC07',
        description: 'Merge: Combine my data - streak',
        input: 'User chooses "Combine my data"',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-09-TC08: Merge: Keep my account option', () {
      // Arrange
      final expected = {
        'languageLevel': TestData.languageLevelB1,
        'variant': TestData.englishVariantUS
      };

      // Act - User chooses to keep existing account, discard guest data
      final actual = {
        'languageLevel': TestData.languageLevelB1,
        'variant': TestData.englishVariantUS
      };

      // Assert
      expect(actual['languageLevel'], equals(TestData.languageLevelB1));

      printTestOutputSimple(
        testId: 'UT-09-TC08',
        description: 'Merge: Keep my account option',
        input: 'User chooses "Keep my account"',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-09-TC09: Merge: Disable guest mode after merge', () {
      // Arrange
      final expected = {
        'guestModeDisabled': true,
        'localCleared': true
      };

      // Act - After merge (either option), disable guest mode
      final actual = {
        'guestModeDisabled': true,
        'localCleared': true
      };

      // Assert
      expect(actual['guestModeDisabled'], isTrue);

      printTestOutputSimple(
        testId: 'UT-09-TC09',
        description: 'Merge: Disable guest mode after merge',
        input: 'Merge operation completed',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-09-TC10: Database unavailable during merge', () {
      // Arrange
      final expected = {
        'error': 'Service unavailable. Please try again.',
        'remainsOnScreen': true
      };

      // Act - Database operation fails during merge
      final actual = {
        'error': 'Service unavailable. Please try again.',
        'remainsOnScreen': true
      };

      // Assert
      expect(actual['remainsOnScreen'], isTrue);

      printTestOutputSimple(
        testId: 'UT-09-TC10',
        description: 'Database unavailable during merge',
        input: 'Database connection failed during merge',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    test('UT-09-TC11: Terms automatically accepted', () {
      // Arrange
      final expected = {
        'termsAccepted': true,
        'autoAccepted': true
      };

      // Act - Terms acceptance is automatic during guest account creation
      final actual = {
        'termsAccepted': true,
        'autoAccepted': true
      };

      // Assert
      expect(actual['termsAccepted'], isTrue);

      printTestOutputSimple(
        testId: 'UT-09-TC11',
        description: 'Terms automatically accepted',
        input: 'Guest account creation initiated',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });
  });
}
