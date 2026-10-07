import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/streak_service.dart';
import '../../data/services/app_state_service.dart';
import 'providers.dart';

/// Streak service provider
final streakServiceProvider = Provider<StreakService>((ref) {
  return StreakService();
});

/// AppState service provider for guest streak migration
final appStateServiceProvider = Provider<AppStateService>((ref) {
  return AppStateService();
});

/// Streak data provider - fetches and caches streak data
/// Works for both registered (cloud) and guest (local) users
class StreakNotifier extends StateNotifier<StreakData?> {
  StreakNotifier(
      this._service, this._appStateService, this._userNotifier, this._ref)
      : super(null) {
    _init();
  }

  final StreakService _service;
  final AppStateService _appStateService;
  final UserNotifier _userNotifier;
  final Ref _ref;
  StreamSubscription<UserState>? _userStateSubscription;

  Future<void> _init() async {
    // Listen to user state changes via stream (only trigger refresh if streak-relevant fields changed)
    String? lastUserId;
    int? lastStreak;
    int? lastShields;
    DateTime? lastActivity;
    DateTime? lastStateUpdate;
    _userStateSubscription = _userNotifier.stream.listen((userState) async {
      final user = userState.user;
      final userId = user?.id;
      final streak = user?.currentStreak;
      final shields = user?.shields;
      final activity = user?.lastStreakActivityDate;
      final stateUpdate = user?.streakStateUpdatedAt;
      if (userId != lastUserId ||
          streak != lastStreak ||
          shields != lastShields ||
          activity != lastActivity ||
          stateUpdate != lastStateUpdate) {
        lastUserId = userId;
        lastStreak = streak;
        lastShields = shields;
        lastActivity = activity;
        lastStateUpdate = stateUpdate;
        if (!_userStateSubscription!.isPaused) {
          await refresh();
        }
      }
    }, onError: (error) {
      print('❌ Error in user state stream: $error');
    });
    await refresh();
  }

  @override
  void dispose() {
    _userStateSubscription?.cancel();
    super.dispose();
  }

  /// Refresh streak data from appropriate source (cloud or local) and check expiration
  Future<void> refresh() async {
    print('🔄 [Streak] refresh() called');

    // Read from UserModel (SSOT)
    final currentUser = _userNotifier.state.user;

    if (currentUser != null && currentUser.isGuest) {
      // Guest - load from UserModel
      print('🟢 [Streak] Loading guest streak from UserModel...');
      _loadFromUserModel(currentUser);
      print(
          '✅ [Streak] Guest streak loaded: streak=${state?.currentStreak ?? 0}');
      await checkAndResetStreakIfExpired();
      return;
    }

    // Fallback to check if registered user
    final supabaseUser = Supabase.instance.client.auth.currentUser;
    if (supabaseUser != null) {
      // Registered - load from cloud
      print('🔵 [Streak] Loading registered user streak from cloud...');
      try {
        final streakData = await _service.getStreakData();
        print(
            '✅ [Streak] Cloud streak loaded: streak=${streakData?.currentStreak ?? 0}');
        if (state != streakData) {
          state = streakData;
        }
        await checkAndResetStreakIfExpired();
      } catch (e) {
        print('⚠️ [Streak] Failed to load from cloud: $e');
        if (currentUser != null) {
          _loadFromUserModel(currentUser);
          await checkAndResetStreakIfExpired();
        } else {
          state = null;
        }
      }
    } else {
      // No user - null state
      print('⚠️ [Streak] No user found - setting streak to null');
      state = null;
    }
  }

  /// Load streak data from UserModel (SSOT - Single Source of Truth)
  void _loadFromUserModel(dynamic user) {
    final newData = StreakData(
      currentStreak: user.currentStreak,
      shieldsAvailable: user.shields,
      longestStreak: user.longestStreak,
      lastActivityDate: user.lastStreakActivityDate,
      streakStateUpdatedAt: user.streakStateUpdatedAt,
    );
    if (state != newData) {
      state = newData;
    }
  }

  /// Update streak after activity
  Future<bool> updateAfterActivity() async {
    final currentUser = _userNotifier.state.user;

    if (currentUser == null) {
      print('❌ [Streak] No current user');
      return false;
    }

    print(
        '📝 [Streak] updateAfterActivity() called - isGuest=${currentUser.isGuest}');

    if (currentUser.isGuest) {
      // Guest - increment streak in UserModel (SSOT)
      print('🟢 [Guest Streak] Calling incrementStreak()...');
      final updatedUser = currentUser.incrementStreak();
      await _userNotifier.updateUser(updatedUser);
      _loadFromUserModel(updatedUser);
      print(
          '✅ [Guest Streak] Updated UserModel: streak=${updatedUser.currentStreak}, shields=${updatedUser.shields}');
      return true;
    } else {
      // Registered activity triggers update the streak in Supabase.
      // Refresh after the trigger instead of writing a second, potentially stale value.
      await refresh();
      return true;
    }
  }

  /// Update streak data (manual/admin/testing)
  Future<bool> updateStreak({
    int? currentStreak,
    int? shieldsAvailable,
  }) async {
    final currentUser = _userNotifier.state.user;

    if (currentUser == null) return false;

    if (currentUser.isGuest) {
      // Guest - update UserModel
      final updatedUser = currentUser.copyWith(
        currentStreak: currentStreak ?? currentUser.currentStreak,
        longestStreak:
            currentStreak != null && currentStreak > currentUser.longestStreak
                ? currentStreak
                : currentUser.longestStreak,
        shields: shieldsAvailable ?? currentUser.shields,
        streakStateUpdatedAt: DateTime.now(),
      );
      await _userNotifier.updateUser(updatedUser);
      _loadFromUserModel(updatedUser);
      return true;
    } else {
      // Registered - update cloud
      final success = await _service.updateStreakData(
        currentStreak: currentStreak,
        shieldsAvailable: shieldsAvailable,
        streakStateUpdatedAt: DateTime.now(),
      );
      if (success) await refresh();
      return success;
    }
  }

  /// Add shields
  Future<bool> addShields(int count) async {
    final currentUser = _userNotifier.state.user;

    if (currentUser == null) return false;

    if (currentUser.isGuest) {
      // Guest - update UserModel
      final updatedUser = currentUser.addShields(count);
      await _userNotifier.updateUser(updatedUser);
      _loadFromUserModel(updatedUser);
      return true;
    } else {
      // Registered - update cloud
      final success = await _service.addShields(count);
      if (success) await refresh();
      return success;
    }
  }

  /// Use a shield
  Future<bool> useShield() async {
    final currentUser = _userNotifier.state.user;

    if (currentUser == null) return false;

    if (currentUser.isGuest) {
      // Guest - update UserModel
      if (currentUser.shields <= 0) return false;
      final updatedUser = currentUser.useShield();
      await _userNotifier.updateUser(updatedUser);
      _loadFromUserModel(updatedUser);
      await _ref.read(badgeProvider.notifier).recordShieldUsed();
      return true;
    } else {
      // Registered - update cloud
      final success = await _service.useShield();
      if (success) {
        await refresh();
        await _ref.read(badgeProvider.notifier).recordShieldUsed();
      }
      return success;
    }
  }

  /// Reset streak (testing)
  Future<bool> reset() async {
    final currentUser = _userNotifier.state.user;

    if (currentUser == null) return false;

    if (currentUser.isGuest) {
      // Guest - reset UserModel
      final updatedUser = currentUser.copyWith(
        currentStreak: 0,
        longestStreak: 0,
        shields: 0,
        clearLastStreakActivityDate: true,
        streakStateUpdatedAt: DateTime.now(),
      );
      await _userNotifier.updateUser(updatedUser);
      _loadFromUserModel(updatedUser);
      return true;
    } else {
      final success = await _service.resetStreak();
      if (success) await refresh();
      return success;
    }
  }

  /// Clear local streak state without affecting cloud data
  /// Use this when logging out to ensure fresh reload on next login
  void clearLocalState() {
    state = null;
  }

  /// Set streak for testing/demo
  /// Automatically calculates appropriate shields for the streak value
  /// 7 days = 1 shield, 14 days = 2 shields, etc.
  Future<bool> setStreak(int value, {int? shields}) async {
    final currentUser = _userNotifier.state.user;

    if (currentUser == null) return false;

    // Calculate appropriate shields if not explicitly provided
    final calculatedShields = shields ?? (value ~/ 7);

    if (currentUser.isGuest) {
      // Guest - update UserModel
      final today = DateTime.now();
      final updatedUser = currentUser.copyWith(
        currentStreak: value,
        longestStreak: value > currentUser.longestStreak
            ? value
            : currentUser.longestStreak,
        shields: calculatedShields,
        lastStreakActivityDate: today,
        streakStateUpdatedAt: today,
      );
      await _userNotifier.updateUser(updatedUser);
      _loadFromUserModel(updatedUser);
      return true;
    } else {
      // For registered users, use updateStreakData
      final success = await _service.updateStreakData(
        currentStreak: value,
        shieldsAvailable: calculatedShields,
        lastActivityDate: DateTime.now(),
        streakStateUpdatedAt: DateTime.now(),
      );
      if (success) await refresh();
      return success;
    }
  }

  /// Migrate guest streak to cloud (when user registers)
  /// Keeps the streak from the most recently active side; same-day ties use max.
  Future<bool> migrateGuestStreakToCloud({
    Map<String, dynamic>? guestStreakSnapshot,
  }) async {
    final legacyGuestData =
        await _appStateService.getGuestStreakDataForMigration();
    final guestStreak = guestStreakSnapshot?['currentStreak'] as int? ??
        legacyGuestData['current_streak'] as int? ??
        0;
    final guestLongest = guestStreakSnapshot?['longestStreak'] as int? ??
        legacyGuestData['longest_streak'] as int? ??
        0;
    final guestShields = guestStreakSnapshot?['shields'] as int? ??
        legacyGuestData['shields_available'] as int? ??
        0;
    final snapshotDate = guestStreakSnapshot?['lastStreakActivityDate'];
    final guestLastDate = snapshotDate is DateTime
        ? snapshotDate
        : snapshotDate is String
            ? DateTime.tryParse(snapshotDate)
            : legacyGuestData['last_activity_date'] is String
                ? DateTime.tryParse(
                    legacyGuestData['last_activity_date'] as String)
                : null;
    final snapshotStateTime = guestStreakSnapshot?['streakStateUpdatedAt'];
    final guestStateUpdatedAt = guestStreak == 0 && guestLastDate == null
        ? null
        : _parseDateTime(snapshotStateTime) ?? guestLastDate;

    // Only migrate if there's actual data
    if (guestStreak == 0 &&
        guestLongest == 0 &&
        guestShields == 0 &&
        guestLastDate == null &&
        guestStateUpdatedAt == null) {
      return true; // Nothing to migrate
    }

    // Get existing streak from cloud to compare
    final existingStreak = await _service.getStreakData();

    int finalStreak = guestStreak;
    int finalLongest = guestLongest;
    int finalShields = guestShields;
    DateTime? finalLastDate = guestLastDate;
    DateTime? finalStateUpdatedAt = guestStateUpdatedAt;

    if (existingStreak != null) {
      final guestStateTime = guestStateUpdatedAt ?? _activityDay(guestLastDate);
      final serverStateTime = existingStreak.streakStateUpdatedAt ??
          _activityDay(existingStreak.lastActivityDate);

      if (guestStateTime == null && serverStateTime == null) {
        finalStreak = guestStreak > existingStreak.currentStreak
            ? guestStreak
            : existingStreak.currentStreak;
      } else if (serverStateTime == null ||
          (guestStateTime != null && guestStateTime.isAfter(serverStateTime))) {
        finalStreak = guestStreak;
        finalLastDate = guestLastDate;
        finalStateUpdatedAt = guestStateTime;
      } else if (guestStateTime == null ||
          serverStateTime.isAfter(guestStateTime)) {
        finalStreak = existingStreak.currentStreak;
        finalLastDate = existingStreak.lastActivityDate;
        finalStateUpdatedAt = serverStateTime;
      } else {
        finalStreak = guestStreak > existingStreak.currentStreak
            ? guestStreak
            : existingStreak.currentStreak;
        finalStateUpdatedAt = guestStateTime;
        finalLastDate = guestLastDate ?? existingStreak.lastActivityDate;
      }

      // Longest streak and shields are non-additive records/resources.
      finalShields = guestShields > existingStreak.shieldsAvailable
          ? guestShields
          : existingStreak.shieldsAvailable;
      finalLongest = guestLongest > existingStreak.longestStreak
          ? guestLongest
          : existingStreak.longestStreak;

      print(
          '🔄 [Streak Migration] Guest: streak=$guestStreak, shields=$guestShields');
      print(
          '🔄 [Streak Migration] Existing: streak=${existingStreak.currentStreak}, shields=${existingStreak.shieldsAvailable}');
      print(
          '✅ [Streak Migration] Final: streak=$finalStreak, shields=$finalShields');
    }

    final success = await _service.updateStreakData(
      currentStreak: finalStreak,
      longestStreak: finalLongest,
      shieldsAvailable: finalShields,
      lastActivityDate: finalLastDate,
      streakStateUpdatedAt: finalStateUpdatedAt ?? DateTime.now(),
      clearLastActivityDate: finalLastDate == null,
    );

    if (success) {
      // Clear local guest streak after successful migration
      await _appStateService.resetGuestStreak();
      await refresh();
    }

    return success;
  }

  DateTime? _activityDay(DateTime? date) =>
      date == null ? null : DateTime(date.year, date.month, date.day);

  DateTime? _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Check if user has already acquired vocabulary today
  /// Returns true if last activity date is today
  Future<bool> hasAcquiredVocabularyToday() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentUser = _userNotifier.state.user;
    final lastActivity =
        state?.lastActivityDate ?? currentUser?.lastStreakActivityDate;

    if (lastActivity == null) return false;

    final lastLocal = lastActivity.toLocal();
    final lastDay = DateTime(lastLocal.year, lastLocal.month, lastLocal.day);
    return today.difference(lastDay).inDays == 0;
  }

  /// Record vocabulary acquisition and update streak if not already done today
  /// Returns true if streak was updated (first vocabulary of the day)
  Future<bool> recordVocabularyAcquired() async {
    print('📝 [Streak] recordVocabularyAcquired() called');

    // Also record activity for Badge tracking (Night Owl / Morning Nova, etc.)
    await _ref
        .read(badgeProvider.notifier)
        .recordActivity(ActivityType.generateVocab);

    // Check if already acquired vocabulary today
    if (await hasAcquiredVocabularyToday()) {
      print('ℹ️ [Streak] Already acquired vocabulary today → skipping');
      // Already updated today, no need to update again
      return false;
    }

    print('✅ [Streak] First vocabulary of the day → updating streak');
    // First vocabulary of the day - update streak
    return await updateAfterActivity();
  }

  /// Record review activity - for future review feature
  /// This will update streak when user reviews vocabulary (not implemented yet)
  /// TODO: Implement when review feature is added
  Future<bool> recordReviewActivity() async {
    // Review will also count towards streak
    // Uses same logic as vocabulary acquisition
    return await recordVocabularyAcquired();
  }

  /// Record any learning activity (new word or review)
  /// This is a unified method that can be used for both activities
  Future<bool> recordLearningActivity() async {
    // Both new words and reviews count towards streak
    return await recordVocabularyAcquired();
  }

  /// Check if streak should be reset due to inactivity (called on app open or refresh)
  Future<void> checkAndResetStreakIfExpired() async {
    print('🔍 [Streak] checkAndResetStreakIfExpired() called');

    final currentUser = _userNotifier.state.user;

    if (currentUser == null) {
      print('⚠️ [Streak] No current user - skipping reset check');
      return;
    }

    final currentStreak = currentUser.isGuest
        ? currentUser.currentStreak
        : (state?.currentStreak ?? currentUser.currentStreak);

    // If streak is already 0, nothing to expire
    if (currentStreak <= 0) {
      print('ℹ️ [Streak] Current streak is already 0 - no reset needed');
      return;
    }

    final lastActivity = currentUser.isGuest
        ? currentUser.lastStreakActivityDate
        : (state?.lastActivityDate ?? currentUser.lastStreakActivityDate);

    if (lastActivity == null) {
      print('ℹ️ [Streak] No previous activity - nothing to check');
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastLocal = lastActivity.toLocal();
    final lastDay = DateTime(lastLocal.year, lastLocal.month, lastLocal.day);
    final daysDifference = today.difference(lastDay).inDays;

    print(
        '   [Streak] Days since last activity: $daysDifference (current: $currentStreak)');

    // daysDifference <= 1: active today or yesterday -> streak safe
    if (daysDifference <= 1) {
      print('✅ [Streak] Streak still active');
      return;
    }

    // daysDifference >= 2: user missed at least 1 day
    final missedDays = daysDifference - 1;
    final currentShields = currentUser.isGuest
        ? currentUser.shields
        : (state?.shieldsAvailable ?? currentUser.shields);

    if (currentShields >= missedDays) {
      print(
          '🛡️ [Streak] Inactivity protected by shields ($currentShields available, $missedDays needed)');
      return;
    }

    // Not enough shields -> streak expired (currentStreak becomes 0)
    // Note: NEVER reset longestStreak!
    print(
        '🔥 [Streak] Streak expired! Resetting current streak to 0 (was $currentStreak, longest: ${currentUser.longestStreak} preserved)...');
    final nowTime = DateTime.now();
    if (currentUser.isGuest) {
      final updatedUser = currentUser.copyWith(
        currentStreak: 0,
        shields: 0,
        streakStateUpdatedAt: nowTime,
      );
      await _userNotifier.updateUser(updatedUser);
      _loadFromUserModel(updatedUser);
    } else {
      await _service.updateStreakData(
        currentStreak: 0,
        shieldsAvailable: 0,
        streakStateUpdatedAt: nowTime,
      );
      final updatedUser = currentUser.copyWith(
        currentStreak: 0,
        shields: 0,
        streakStateUpdatedAt: nowTime,
      );
      await _userNotifier.updateUser(updatedUser);
      if (state != null) {
        state = state!.copyWith(
          currentStreak: 0,
          shieldsAvailable: 0,
          streakStateUpdatedAt: nowTime,
        );
      } else {
        _loadFromUserModel(updatedUser);
      }
    }
    print('✅ [Streak] Expiration reset complete: streak is now 0');
  }
}

/// Streak notifier provider
final streakProvider =
    StateNotifierProvider<StreakNotifier, StreakData?>((ref) {
  final service = ref.watch(streakServiceProvider);
  final appStateService = ref.watch(appStateServiceProvider);
  final userNotifier = ref.watch(userStateProvider.notifier);
  return StreakNotifier(service, appStateService, userNotifier, ref);
});

/// Convenience provider for current streak value
final currentStreakProvider = Provider<int>((ref) {
  final streak = ref.watch(streakProvider);
  return streak?.currentStreak ?? 0;
});

/// Convenience provider for shields count
final shieldsProvider = Provider<int>((ref) {
  final streak = ref.watch(streakProvider);
  return streak?.shieldsAvailable ?? 0;
});

/// Provider for streak status (at risk, broken, etc.)
final streakStatusProvider = Provider<StreakStatus>((ref) {
  final streak = ref.watch(streakProvider);
  if (streak == null) return StreakStatus.unknown;

  if (streak.currentStreak == 0) return StreakStatus.inactive;
  if (streak.isAtRisk) return StreakStatus.atRisk;
  if (streak.isBroken) return StreakStatus.broken;
  return StreakStatus.active;
});

/// Streak status enum
enum StreakStatus {
  unknown, // Data not loaded
  inactive, // No streak (0 days)
  active, // Streak ongoing
  atRisk, // Missed day but has shields
  broken, // Streak broken
}

extension StreakStatusExtension on StreakStatus {
  String get label {
    switch (this) {
      case StreakStatus.unknown:
        return 'Loading...';
      case StreakStatus.inactive:
        return 'Start your streak today! 🌟';
      case StreakStatus.active:
        return 'Keep the streak alive! 🔥';
      case StreakStatus.atRisk:
        return 'Shield is protecting you 🛡️';
      case StreakStatus.broken:
        return 'Streak lost - Start fresh! 💪';
    }
  }

  String get message {
    switch (this) {
      case StreakStatus.unknown:
        return 'Loading your streak...';
      case StreakStatus.inactive:
        return 'Begin your learning journey today!';
      case StreakStatus.active:
        return 'You\'re on fire! Keep it up!';
      case StreakStatus.atRisk:
        return 'Your shield protected your streak!';
      case StreakStatus.broken:
        return 'No worries! Start a new streak today.';
    }
  }

  String get emoji {
    switch (this) {
      case StreakStatus.unknown:
        return '⏳';
      case StreakStatus.inactive:
        return '💫';
      case StreakStatus.active:
        return '🔥';
      case StreakStatus.atRisk:
        return '🛡️';
      case StreakStatus.broken:
        return '💪';
    }
  }
}
