import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AppStateService - Manages application-wide state and cache
/// Previously PreferenceService - renamed to reflect actual purpose
class AppStateService {
  static const String _onboardingKey = 'onboarding_completed';
  // Note: _guestModeKey removed - use UserModel.isGuest instead

  // Note: language_level and english_variant keys removed
  // Preferences now stored in UserModel only
  // Note: Guest data storage (Hive box) removed - unused dead code

  Future<void> init() async {
    // No initialization needed anymore
    // Previously initialized Hive 'starmory_box' which was never used
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

  // Note: Guest mode methods removed - use UserModel.isGuest instead
  // UserModel.isGuest is the single source of truth for guest state

  // Note: Language level and English variant methods removed
  // Preferences now stored in UserModel only (via Hive)

  // Note: Guest data storage methods removed - unused dead code

  Future<void> clearLocalPreferences() async {
    // Note: language_level and english_variant no longer stored here
    // They are now in UserModel (Hive)
    // Note: guest_mode no longer stored here - use UserModel.isGuest
    // This method clears keys that are no longer used (legacy cleanup)
    final prefs = await SharedPreferences.getInstance();
    // Legacy cleanup - remove old keys if they exist
    await prefs.remove('is_guest_mode'); // Old guest mode key
  }

  // Terms Version
  static const String _termsVersionKey = 'terms_version';
  static const int _currentTermsVersion = 1;

  // Note: Guest quota tracking moved to UserModel (SSOT pattern)
  // - Use UserModel.quotaManager for all quota operations
  // - This prevents sync issues between SharedPreferences and UserModel

  // Guest Streak Tracking (for migration to cloud when user registers)
  // Note: These methods are used by streak_provider for migration only
  // Active guest streak tracking uses UserModel streak fields
  static const String _guestCurrentStreakKey = 'guest_current_streak';
  static const String _guestShieldsKey = 'guest_shields_available';
  static const String _guestLongestStreakKey = 'guest_longest_streak';
  static const String _guestLastActivityKey = 'guest_last_activity_date';

  /// Get guest streak data as map (for migration to cloud)
  /// Used by streak_provider when guest user registers
  Future<Map<String, dynamic>> getGuestStreakDataForMigration() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'current_streak': prefs.getInt(_guestCurrentStreakKey) ?? 0,
      'shields_available': prefs.getInt(_guestShieldsKey) ?? 0,
      'longest_streak': prefs.getInt(_guestLongestStreakKey) ?? 0,
      'last_activity_date': prefs.getString(_guestLastActivityKey),
    };
  }

  /// Reset guest streak (for testing or after migration)
  Future<void> resetGuestStreak() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestCurrentStreakKey);
    await prefs.remove(_guestShieldsKey);
    await prefs.remove(_guestLongestStreakKey);
    await prefs.remove(_guestLastActivityKey);
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

  // Note: Guest streak tracking moved to UserModel + StreakService
  // This prevents sync issues between SharedPreferences and UserModel
  // All streak operations now use UserModel streak fields

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
