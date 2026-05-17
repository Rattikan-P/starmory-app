import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferenceService {
  static const String _onboardingKey = 'onboarding_completed';
  static const String _guestModeKey = 'is_guest_mode';
  static const String _languageLevelKey = 'guest_language_level';
  static const String _englishVariantKey = 'guest_english_variant';

  Box? _box;

  Future<void> init() async {
    // เช็คก่อนว่า Hive initialized แล้วหรือยัง
    if (!Hive.isBoxOpen('starmory_box')) {
      await Hive.initFlutter();
      _box = await Hive.openBox('starmory_box');
    } else {
      _box = Hive.box('starmory_box');
    }
  }

  // Onboarding
  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  Future<void> setOnboardingCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, completed);
  }

  // Guest Mode
  Future<bool> isGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_guestModeKey) ?? false;
  }

  Future<void> setGuestMode(bool isGuest) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestModeKey, isGuest);
  }

  // Language Level (for guest mode)
  Future<String?> getGuestLanguageLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageLevelKey); // null = ยังไม่ได้เลือก
  }

  Future<void> setGuestLanguageLevel(String level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageLevelKey, level);
  }

  // English Variant (for guest mode)
  Future<String?> getGuestEnglishVariant() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_englishVariantKey) ?? 'US'; // Default US
  }

  Future<void> setGuestEnglishVariant(String variant) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_englishVariantKey, variant);
  }

  // Guest data storage
  Future<void> saveGuestData(String key, dynamic value) async {
    await _box?.put(key, value);
  }

  Future<dynamic> getGuestData(String key) async {
    return _box?.get(key);
  }

  Future<void> clearGuestData() async {
    await _box?.clear();
  }

  Future<void> clearGuestPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_languageLevelKey);
    await prefs.remove(_englishVariantKey);
  }

  // Guest Quota Tracking
  // Terms Version
  static const String _termsVersionKey = 'terms_version';
  static const int _currentTermsVersion = 1;

  // Guest Quota Tracking
  static const String _guestLifetimeGenKey = 'guest_lifetime_gen_count';
  static const String _guestDailyPhotoCountKey = 'guest_daily_photo_count';
  static const String _guestDailyPhotoResetKey = 'guest_daily_photo_reset_date';

  Future<int?> getGuestLifetimeGenCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_guestLifetimeGenKey);
  }

  Future<void> incrementGuestLifetimeGenCount() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_guestLifetimeGenKey) ?? 0;
    await prefs.setInt(_guestLifetimeGenKey, current + 1);
  }

  Future<int?> getGuestDailyPhotoCount() async {
    final prefs = await SharedPreferences.getInstance();
    final lastReset = prefs.getString(_guestDailyPhotoResetKey);
    final today = DateTime.now().toIso8601String().split('T')[0];

    if (lastReset != today) {
      return 0; // New day, reset implicitly
    }
    return prefs.getInt(_guestDailyPhotoCountKey);
  }

  Future<void> incrementGuestDailyPhotoCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastReset = prefs.getString(_guestDailyPhotoResetKey);

    if (lastReset != today) {
      await prefs.setString(_guestDailyPhotoResetKey, today);
      await prefs.setInt(_guestDailyPhotoCountKey, 1);
    } else {
      final current = prefs.getInt(_guestDailyPhotoCountKey) ?? 0;
      await prefs.setInt(_guestDailyPhotoCountKey, current + 1);
    }
  }

  Future<String?> getGuestDailyPhotoResetDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_guestDailyPhotoResetKey);
  }

  Future<void> resetGuestDailyPhoto() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    await prefs.setString(_guestDailyPhotoResetKey, today);
    await prefs.setInt(_guestDailyPhotoCountKey, 0);
  }

  // Terms Version
  Future<int?> getTermsVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_termsVersionKey);
  }

  Future<void> setTermsVersion(int version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_termsVersionKey, version);
  }

  Future<bool> hasAcceptedCurrentTerms() async {
    final acceptedVersion = await getTermsVersion();
    return acceptedVersion != null && acceptedVersion >= _currentTermsVersion;
  }

  int getCurrentTermsVersion() => _currentTermsVersion;
}
