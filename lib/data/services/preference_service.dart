import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/app_defaults.dart';

class PreferenceService {
  static const String _onboardingKey = 'onboarding_completed';
  static const String _guestModeKey = 'is_guest_mode';
  static const String _languageLevelKey = 'language_level';
  static const String _englishVariantKey = 'english_variant';

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

  // Language Level (local preferences for both guest and registered users)
  Future<String?> getLanguageLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageLevelKey); // null = ยังไม่ได้เลือก
  }

  Future<void> setLanguageLevel(String level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageLevelKey, level);
  }

  // English Variant (local preferences for both guest and registered users)
  Future<String?> getEnglishVariant() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_englishVariantKey) ?? AppDefaults.defaultEnglishVariant;
  }

  Future<void> setEnglishVariant(String variant) async {
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

  Future<void> clearLocalPreferences() async {
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

  // Guest Streak Tracking
  static const String _guestCurrentStreakKey = 'guest_current_streak';
  static const String _guestShieldsKey = 'guest_shields_available';
  static const String _guestLongestStreakKey = 'guest_longest_streak';
  static const String _guestLastActivityKey = 'guest_last_activity_date';
  static const String _guestConsecutiveDaysKey = 'guest_consecutive_days';

  // Get guest streak data
  Future<int> getGuestCurrentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_guestCurrentStreakKey) ?? 0;
  }

  Future<void> setGuestCurrentStreak(int streak) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_guestCurrentStreakKey, streak);
  }

  Future<int> getGuestShields() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_guestShieldsKey) ?? 0;
  }

  Future<void> setGuestShields(int shields) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_guestShieldsKey, shields);
  }

  Future<int> getGuestLongestStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_guestLongestStreakKey) ?? 0;
  }

  Future<void> setGuestLongestStreak(int streak) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_guestLongestStreakKey, streak);
  }

  Future<String?> getGuestLastActivityDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_guestLastActivityKey);
  }

  Future<void> setGuestLastActivityDate(String date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_guestLastActivityKey, date);
  }

  Future<int> getGuestConsecutiveDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_guestConsecutiveDaysKey) ?? 0;
  }

  Future<void> setGuestConsecutiveDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_guestConsecutiveDaysKey, days);
  }

  // Update guest streak after activity
  Future<void> updateGuestStreakAfterActivity() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastActivity = await getGuestLastActivityDate();

    int currentStreak = await getGuestCurrentStreak();
    int shields = await getGuestShields();
    int longestStreak = await getGuestLongestStreak();
    int consecutiveDays = await getGuestConsecutiveDays();

    // First activity ever
    if (lastActivity == null) {
      currentStreak = 1;
      consecutiveDays = 1;
    }
    // Same day - do nothing
    else if (lastActivity == today) {
      // Already updated today
    }
    // Consecutive day (yesterday)
    else if (_isYesterday(lastActivity)) {
      currentStreak++;
      consecutiveDays++;

      // Earn shield every 7 consecutive days
      if (consecutiveDays % 7 == 0) {
        shields++;
        consecutiveDays = 0; // Reset for next shield cycle
      }

      // Update longest streak
      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }
    }
    // Missed a day - use shield if available
    else {
      if (shields > 0) {
        shields--;
      } else {
        // No shields - reset streak
        currentStreak = 1;
        consecutiveDays = 1;
      }
    }

    // Save all values
    await setGuestCurrentStreak(currentStreak);
    await setGuestShields(shields);
    await setGuestLongestStreak(longestStreak);
    await setGuestConsecutiveDays(consecutiveDays);
    await setGuestLastActivityDate(today);
  }

  // Helper: Check if date string is yesterday
  bool _isYesterday(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      return date.year == yesterday.year &&
          date.month == yesterday.month &&
          date.day == yesterday.day;
    } catch (e) {
      return false;
    }
  }

  // Reset guest streak (for testing)
  Future<void> resetGuestStreak() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestCurrentStreakKey);
    await prefs.remove(_guestShieldsKey);
    await prefs.remove(_guestLongestStreakKey);
    await prefs.remove(_guestLastActivityKey);
    await prefs.remove(_guestConsecutiveDaysKey);
  }

  // Set guest streak for testing
  Future<void> setGuestStreakForTesting(int streak, {int shields = 0}) async {
    await setGuestCurrentStreak(streak);
    await setGuestShields(shields);
    await setGuestLongestStreak(streak);
    await setGuestConsecutiveDays(streak % 7);
    await setGuestLastActivityDate(DateTime.now().toIso8601String().split('T')[0]);
  }

  // Get all guest streak data as map (for migration to cloud)
  Future<Map<String, dynamic>> getGuestStreakDataForMigration() async {
    return {
      'current_streak': await getGuestCurrentStreak(),
      'shields_available': await getGuestShields(),
      'longest_streak': await getGuestLongestStreak(),
      'last_activity_date': await getGuestLastActivityDate(),
      'consecutive_days': await getGuestConsecutiveDays(),
    };
  }

  // Clear app cache (images, temporary data)
  // Does NOT delete: user settings, preferences, or learning data
  Future<void> clearCache() async {
    print('🧹 Clearing cache...');

    // Get cache info before clearing (for debug)
    final imageCountBefore = PaintingBinding.instance.imageCache.currentSize;
    final liveImageCountBefore = PaintingBinding.instance.imageCache.liveImageCount;

    print('  - Images in memory cache: $imageCountBefore');
    print('  - Live images: $liveImageCountBefore');

    // 1. Clear Flutter image cache (memory)
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    // 2. Clear CachedNetworkImage cache (disk - avatars, etc.)
    try {
      await DefaultCacheManager().emptyCache();
      print('  - Network image cache: cleared');
    } catch (e) {
      print('  - Network image cache: failed ($e)');
    }

    // 3. Clear temporary files
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final tempFiles = tempDir.listSync();
        final filesDeleted = tempFiles.length;
        for (var file in tempFiles) {
          try {
            if (file is File) {
              await file.delete();
            } else if (file is Directory) {
              await file.delete(recursive: true);
            }
          } catch (e) {
            // Skip files that can't be deleted
          }
        }
        print('  - Temporary files: $filesDeleted deleted');
      }
    } catch (e) {
      print('  - Temporary files: failed ($e)');
    }

    print('✅ Cache cleared successfully!');
  }
}
