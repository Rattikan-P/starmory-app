import 'dart:convert';

import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Generate mocks for Supabase and related classes
@GenerateMocks([
  SupabaseClient,
  GoTrueClient,
  User,
])
import 'test_helpers.mocks.dart';

/// Print test result as JSON (without 'note' field)
/// This ensures output matches Expected Output in documentation
void printTestResult(Map<String, dynamic> data) {
  final output = Map<String, dynamic>.from(data);
  output.remove('note'); // Remove note field
  print(jsonEncode(output));
}

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
