import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application-wide constants
class AppConstants {
  // App Info
  static const String appName = 'Starmory';
  static const String appVersion = '1.0.0';

  // API Keys - Loaded from environment variables
  static String get geminiApiKey =>
      dotenv.env['GEMINI_API_KEY'] ?? 'YOUR_GEMINI_API_KEY_HERE';

  // Supabase Configuration - Loaded from environment variables
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? 'YOUR_SUPABASE_URL_HERE';

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? 'YOUR_SUPABASE_ANON_KEY_HERE';


  // Environment
  static String get env => dotenv.env['ENV'] ?? 'dev';

  // Quota Limits
  static const int guestTotalLimit = 10; // Total generations for guest mode
  static const int guestDailyLimit = 3; // Daily generations for guest mode
  static const int registeredDailyLimit = 15; // Daily generations for registered users

  // CEFR Levels
  static const List<String> cefrLevels = ['A1', 'A2', 'B1', 'B2'];

  // Communicative Functions
  static const List<String> communicativeFunctions = [
    'Indicative',
    'Imperative',
    'Subjunctive/Wish',
    'Conditionals',
  ];

  // Language Variants
  static const List<String> languageVariants = ['US', 'UK'];
  static const String defaultLanguageVariant = 'US';

  // Storage Keys
  static const String keyGuestMode = 'guest_mode';
  static const String keyUserSession = 'user_session';
  static const String keyVocabularyCache = 'vocabulary_cache';
  static const String keyCalendarData = 'calendar_data';
  static const String keyQuotaCount = 'quota_count';

  // Hive Box Names
  static const String boxVocabulary = 'vocabulary_box';
  static const String boxUser = 'user_box';
  static const String boxCalendar = 'calendar_box';

  /// Initialize environment variables 
  static Future<void> initialize() async {
    if (!kIsWeb) {
      try {
        await dotenv.load(fileName: ".env");
      } catch (e) {
        // Fallback to environment variables if .env fails to load
        debugPrint('Failed to load .env file: $e');
      }
    }
  }
}
