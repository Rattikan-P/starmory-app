import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mockito/annotations.dart';
import 'package:starmory_app/data/services/hive_service.dart';
import 'package:starmory_app/data/services/review_service.dart';
import 'package:starmory_app/data/repositories/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Generate mocks for all services used in tests
@GenerateMocks([
  // Supabase
  SupabaseClient,
  GoTrueClient,
  User,
  Session,
  SupabaseQueryBuilder,
  PostgrestFilterBuilder,
  PostgrestTransformBuilder,

  // Services
  HiveService,
  ReviewService,

  // Repositories
  ProfileRepository,
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
  static const String languageLevelA2 = "A2";
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

  // ============================================================================
  // DISPLAY NAME TEST DATA (UTC-20: Edit Display Name)
  // ============================================================================

  // Display name validation test data
  static const String displayNameSingleChar = "A"; // TD02: < 2 chars (fails)
  static const String displayNameEmpty = ""; // TD03: Empty (fails)
  static const String displayNameWhitespace = " "; // TD04: Whitespace only (fails)
  static const String displayNameTwoChars = "AB"; // TD07: Exactly 2 chars (passes)
  static const String displayName40Chars =
      "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"; // TD08: Exactly 40 chars (passes)
  static const String displayName41Chars =
      "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"; // TD09: 41 chars (fails)
  static const String displayNameLongName =
      "Nuanwan Starmory Very Long Name That Exceeds"; // TD09: 41 chars with text (fails)
  static const String displayNameTruncated =
      "Nuanwan Starmory Very Lo..."; // Truncated display text

  // ============================================================================
  // PROFILE PHOTO TEST DATA (UTC-21/22: Manage Profile Photo)
  // ============================================================================

  // Photo format test data (using real files from test/test_data/images/)
  static const String validJpegPhoto = "profile-valid.jpg"; // TD01: Valid JPEG
  static const String validJpegPhoto2 = "profile-valid.jpg"; // Alternative (same file)
  static const String validJpgPhoto = "profile-valid.jpg"; // Uppercase extension
  static const String validPngPhoto = "profile-valid.png"; // TD02: Valid PNG
  static const String validPngPhotoUpper = "profile-valid.png"; // Uppercase extension
  static const String invalidGifPhoto = "profile-invalid.gif"; // TD03: Invalid GIF
  static const String invalidWebpPhoto = "invalid2.webp"; // Invalid WebP (if needed)
  static const String blurryPhoto = "blurry.jpg"; // Low quality image (if needed)
  static const String lowResPhoto = "low_resolution.png"; // Low resolution image (if needed)

  // Photo URL test data
  static const String oldPhotoUrl =
      "https://storage.starmory.com/avatars/old_avatar.jpg"; // TD05: Existing photo URL

  // ============================================================================
  // START OVER TEST DATA (UTC-25/26: Start Over)
  // ============================================================================

  // Guest start over test data (TD01 UTC-25)
  static const int guestVocabularyForStartOver = 15; // Guest vocabulary count
  static const int guestStreakForStartOver = 7; // Guest streak
  static const int guestQuotaUsed = 2; // Guest quota used (2/10)
  static const int guestQuotaTotal = 10; // Guest quota total

  // Registered start over test data (TD01 UTC-26)
  static const int registeredVocabularyForStartOver = 20; // Registered vocabulary count
  static const int registeredStreakForStartOver = 10; // Registered streak

  // ============================================================================
  // EXPORT VOCABULARY TEST DATA (UTC-27/28: Export Vocabulary)
  // ============================================================================

  // Guest export test data (TD01 UTC-27)
  static const int guestVocabularyForExport = 5; // Guest vocabulary count

  // Registered export test data (TD01 UTC-28)
  static const int cloudVocabularyForExport = 10; // Cloud vocabulary count
  static const int localVocabularyForExport = 5; // Local vocabulary fallback count

  // CSV headers (TD04 UTC-27/28)
  static const List<String> csvHeaders = [
    "Word",
    "Part of Speech",
    "Thai Translation",
    "English Sentence",
    "Thai Sentence",
    "CEFR Level",
    "Communicative Function",
    "Language Variant",
    "Tags",
    "Created Date"
  ];

  // ============================================================================
  // SAMPLE VOCABULARY DATA (UTC-27/28: Export Vocabulary)
  // ============================================================================

  // Sample vocabulary words for export testing (Starmory themed)
  static const List<Map<String, dynamic>> sampleVocabularyData = [
    {
      'word': 'star',
      'partOfSpeech': 'noun',
      'thaiTranslation': 'ดาว',
      'englishSentence': 'The stars shine brightly in the night sky.',
      'thaiSentence': 'ดาวส่องแสงสว่างบนท้องฟ้ายามค่ำคืน',
      'cefrLevel': 'A1',
      'communicativeFunction': 'describing',
      'languageVariant': 'US',
      'tags': 'space,nature',
    },
    {
      'word': 'galaxy',
      'partOfSpeech': 'noun',
      'thaiTranslation': 'ดาราจักรวาล',
      'englishSentence': 'Our galaxy contains billions of stars.',
      'thaiSentence': 'ดาราจักรวาลของเรามีดาวหลายพันล้านดวง',
      'cefrLevel': 'B1',
      'communicativeFunction': 'describing',
      'languageVariant': 'US',
      'tags': 'space,science',
    },
    {
      'word': 'orbit',
      'partOfSpeech': 'noun',
      'thaiTranslation': 'วงโคจร',
      'englishSentence': 'The Earth orbits around the Sun.',
      'thaiSentence': 'โลกโคจรรอบดวงอาทิตย์',
      'cefrLevel': 'A2',
      'communicativeFunction': 'describing',
      'languageVariant': 'UK',
      'tags': 'space,astronomy',
    },
    {
      'word': 'launch',
      'partOfSpeech': 'verb',
      'thaiTranslation': 'ปล่อย',
      'englishSentence': 'They will launch the rocket tomorrow.',
      'thaiSentence': 'พวกเขาจะปล่อยจรวดในวันพรุ่งนี้',
      'cefrLevel': 'B1',
      'communicativeFunction': 'describing',
      'languageVariant': 'US',
      'tags': 'space,action',
    },
    {
      'word': 'astronaut',
      'partOfSpeech': 'noun',
      'thaiTranslation': 'นักบินอวกาศ',
      'englishSentence': 'She trained for years to become an astronaut.',
      'thaiSentence': 'เธอฝึกมาหลายปีเพื่อเป็นนักบินอวกาศ',
      'cefrLevel': 'B2',
      'communicativeFunction': 'describing',
      'languageVariant': 'UK',
      'tags': 'space,profession',
    },
  ];

  // Sample CSV output for verification (formatted as it would appear in export)
  static const String sampleCsvOutput = '''Word,Part of Speech,Thai Translation,English Sentence,Thai Sentence,CEFR Level,Communicative Function,Language Variant,Tags,Created Date
star,noun,ดาว,"The stars shine brightly in the night sky.","ดาวส่องแสงสว่างบนท้องฟ้ายามค่ำคืน",A1,describing,US,"space,nature",
galaxy,noun,ดาราจักรวาล,"Our galaxy contains billions of stars.","ดาราจักรวาลของเรามีดาวหลายพันล้านดวง",B1,describing,US,"space,science"
orbit,noun,วงโคจร,"The Earth orbits around the Sun.","โลกโคจรรอบดวงอาทิตย์",A2,describing,UK,"space,astronomy"
launch,verb,ปล่อย,"They will launch the rocket tomorrow.","พวกเขาจะปล่อยจรวดในวันพรุ่งนี้",B1,describing,US,"space,action"
astronaut,noun,นักบินอวกาศ,"She trained for years to become an astronaut.","เธอฝึกมาหลายปีเพื่อเป็นนักบินอวกาศ",B2,describing,UK,"space,profession"''';
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
