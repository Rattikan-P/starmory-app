import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Generate mocks for Supabase and related classes
@GenerateMocks([
  SupabaseClient,
  GoTrueClient,
  User,
])
import 'test_helpers.mocks.dart';

// ============================================================================
// TEST DATA CONSTANTS
// ============================================================================

/// Test constants and utilities
class TestData {
  // Email validation test data (Starmory branded)
  static const String validEmail = "rattikan@starmory.com";
  static const String validEmailSubdomain = "rattikan.m@starmory.com";
  static const String invalidEmail = "rattikan_starmory";
  static const String emailWithoutAt = "@starmory.com";
  static const String emailWithInvalidDomain = "rattikan@.app";
  static const String emptyEmail = "";
  static const String emailWithSpace = "rattikan @starmory.com";
  static const String emailWithoutDomain = "rattikan@";

  // OTP test data
  static const String testEmail = "test@starmory.com";
  static const String existingEmail = "existing@starmory.com";
  static const String newEmail = "new@starmory.com";
  static const String validOtp = "123456";
  static const String invalidOtp = "000000";
  static const String expiredOtp = "111111";

  // User test data
  static const String testUserId = "user_starmory_123";
  static const String nonexistentUserId = "nonexistent_starmory";

  // Note: The app uses OTP-based authentication (sendOtp → verifyOtp)
  // Password-based methods (signUp, signIn) have been removed from AuthService

  static const String displayName = "Rattikan Starmory";

  // Preference test data
  static const String languageLevelA1 = "A1";
  static const String languageLevelB1 = "B1";
  static const String languageLevelB2 = "B2";
  static const String englishVariantUS = "US";
  static const String englishVariantUK = "UK";

  // Page routes/names
  static const String pageOnboarding = "OnboardingPage";
  static const String pageHome = "HomePage";
  static const String pageLanguageSelection = "LanguageSelectionPage";
  static const String pageEnglishVariant = "EnglishVariantPage";

  // Mock values
  static const String mockUserId = "uuid";

  // Default preferences combined
  static const String defaultPreferences = "B1, US";

  // Streak test data
  static const int guestStreak = 5;
  static const int cloudStreak = 3;

  // Vocabulary test data (Starmory themed)
  static const List<String> guestVocabulary = ["star", "galaxy"];
  static const List<String> cloudVocabulary = ["star"];
}

// ============================================================================
// SIMPLE JSON OUTPUT (For test documentation)
// ============================================================================

/// Print test result as JSON (without 'note' field)
/// This ensures output matches Expected Output in documentation
void printTestResult(Map<String, dynamic> data) {
  final output = Map<String, dynamic>.from(data);
  output.remove('note'); // Remove note field
  print(jsonEncode(output));
}

// ============================================================================
// IMAGE TEST HELPERS
// ============================================================================

/// Get the test data directory
Directory getTestDataDir() {
  final currentDir = Directory.current.path;
  return Directory('$currentDir/test/test_data/images');
}

/// Load a test image file by name
Future<Uint8List> loadTestImage(String filename) async {
  final testDataDir = getTestDataDir();
  final file = File('${testDataDir.path}/$filename');

  if (!await file.exists()) {
    throw FileSystemException('Test image not found', file.path);
  }

  return await file.readAsBytes();
}

/// Check if a test image exists
Future<bool> testImageExists(String filename) async {
  final testDataDir = getTestDataDir();
  final file = File('${testDataDir.path}/$filename');
  return await file.exists();
}

// ============================================================================
// DETAILED TEST OUTPUT (For test reports)
// ============================================================================

/// Test helper function to print formatted output for Test Record
void printTestOutput({
  required String testId,
  required String description,
  required Map<String, dynamic> input,
  required Map<String, dynamic> expectedOutput,
  required Map<String, dynamic> actualOutput,
}) {
  final separator = '=' * 60;
  print('');
  print(separator);
  print('TEST ID: $testId');
  print('Description: $description');
  print('-' * 60);
  print('Input:');
  input.forEach((key, value) {
    print('  $key: $value');
  });
  print('-' * 60);
  print('Expected Output:');
  print(const JsonEncoder.withIndent('  ').convert(expectedOutput));
  print('-' * 60);
  print('Actual Output:');
  print(const JsonEncoder.withIndent('  ').convert(actualOutput));
  print('-' * 60);
  print('Status: ${_compareJson(expectedOutput, actualOutput) ? "✓ PASS" : "✗ FAIL"}');
  print(separator);
  print('');
}

/// Test helper for simple input/output
void printTestOutputSimple({
  required String testId,
  required String description,
  required String input,
  required Map<String, dynamic> expectedOutput,
  required Map<String, dynamic> actualOutput,
}) {
  printTestOutput(
    testId: testId,
    description: description,
    input: {'input': input},
    expectedOutput: expectedOutput,
    actualOutput: actualOutput,
  );
}

/// Compare two JSON objects for equality
bool _compareJson(Map<String, dynamic> expected, Map<String, dynamic> actual) {
  try {
    return const JsonEncoder().convert(expected) ==
        const JsonEncoder().convert(actual);
  } catch (e) {
    return false;
  }
}

/// Print test header
void printTestHeader(String testName) {
  print('');
  print('╔${'═' * 58}╗');
  print('║ $testName${' ' * (58 - testName.length)}║');
  print('╚${'═' * 58}╝');
  print('');
}

/// Print test summary
void printTestSummary(Map<String, dynamic> results) {
  final separator = '=' * 60;
  print('');
  print(separator);
  print('TEST SUMMARY');
  print(separator);
  print('Total Tests: ${results['total']}');
  print('Passed: ${results['passed']}');
  print('Failed: ${results['failed']}');
  print('Pass Rate: ${results['passRate']}%');
  print(separator);
  print('');
}
