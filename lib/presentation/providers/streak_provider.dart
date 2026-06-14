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
  StreakNotifier(this._service, this._appStateService, this._userNotifier) : super(null) {
    _init();
  }

  final StreakService _service;
  final AppStateService _appStateService;
  final UserNotifier _userNotifier;
  StreamSubscription<UserState>? _userStateSubscription;

  Future<void> _init() async {
    // Listen to user state changes via stream
    _userStateSubscription = _userNotifier.stream.listen((userState) {
      // User changed - refresh streak data
      if (!_userStateSubscription!.isPaused) {
        refresh();
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

  /// Refresh streak data from appropriate source (cloud or local)
  Future<void> refresh() async {
    // Read from UserModel (SSOT)
    final currentUser = _userNotifier.state.user;

    if (currentUser != null && currentUser.isGuest) {
      // Guest - load from UserModel
      _loadFromUserModel(currentUser);
      return;
    }

    // Fallback to check if registered user
    final supabaseUser = Supabase.instance.client.auth.currentUser;
    if (supabaseUser != null) {
      // Registered - load from cloud
      final data = await _service.getStreakData();
      state = data;
    } else {
      // No user - null state
      state = null;
    }
  }

  /// Load streak data from UserModel (SSOT - Single Source of Truth)
  void _loadFromUserModel(dynamic user) {
    state = StreakData(
      currentStreak: user.currentStreak,
      shieldsAvailable: user.shields,
      longestStreak: user.longestStreak,
      lastActivityDate: user.lastStreakActivityDate,
    );
  }

  /// Update streak after activity
  Future<bool> updateAfterActivity() async {
    final currentUser = _userNotifier.state.user;

    if (currentUser == null) return false;

    if (currentUser.isGuest) {
      // Guest - increment streak in UserModel (SSOT)
      final updatedUser = currentUser.incrementStreak();
      await _userNotifier.updateUser(updatedUser);
      _loadFromUserModel(updatedUser);
      print('✅ [Guest Streak] Updated UserModel: streak=${updatedUser.currentStreak}, shields=${updatedUser.shields}');
      return true;
    } else {
      // Registered - manual update (until trigger is ready)
      final success = await _service.manualStreakUpdate();
      if (success) await refresh();
      return success;
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
        longestStreak: currentStreak != null && currentStreak > currentUser.longestStreak
            ? currentStreak
            : currentUser.longestStreak,
        shields: shieldsAvailable ?? currentUser.shields,
      );
      await _userNotifier.updateUser(updatedUser);
      _loadFromUserModel(updatedUser);
      return true;
    } else {
      // Registered - update cloud
      final success = await _service.updateStreakData(
        currentStreak: currentStreak,
        shieldsAvailable: shieldsAvailable,
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
      return true;
    } else {
      // Registered - update cloud
      final success = await _service.useShield();
      if (success) await refresh();
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
        lastStreakActivityDate: null,
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
        longestStreak: value > currentUser.longestStreak ? value : currentUser.longestStreak,
        shields: calculatedShields,
        lastStreakActivityDate: today,
      );
      await _userNotifier.updateUser(updatedUser);
      _loadFromUserModel(updatedUser);
      return true;
    } else {
      // For registered users, use updateStreakData
      final success = await _service.updateStreakData(
        currentStreak: value,
        shieldsAvailable: calculatedShields,
      );
      if (success) await refresh();
      return success;
    }
  }

  /// Migrate guest streak to cloud (when user registers)
  /// Uses MAX logic: keeps the better streak between guest and existing
  Future<bool> migrateGuestStreakToCloud() async {
    final guestData = await _appStateService.getGuestStreakDataForMigration();

    // Only migrate if there's actual data
    if (guestData['current_streak'] == 0 &&
        guestData['shields_available'] == 0) {
      return true; // Nothing to migrate
    }

    // Get existing streak from cloud to compare
    final existingStreak = await _service.getStreakData();

    // Use MAX logic: choose the better value between guest and existing
    final guestStreak = guestData['current_streak'] as int? ?? 0;
    final guestShields = guestData['shields_available'] as int? ?? 0;
    final guestLastDate = guestData['last_activity_date'] != null
        ? DateTime.parse(guestData['last_activity_date'] as String)
        : null;

    int finalStreak = guestStreak;
    int finalShields = guestShields;
    DateTime? finalLastDate = guestLastDate;

    if (existingStreak != null) {
      // Use MAX for streak (keep the better achievement)
      finalStreak = guestStreak > existingStreak.currentStreak
          ? guestStreak
          : existingStreak.currentStreak;

      // Use MAX for shields (keep more shields)
      finalShields = guestShields > existingStreak.shieldsAvailable
          ? guestShields
          : existingStreak.shieldsAvailable;

      // Use the most recent activity date
      if (existingStreak.lastActivityDate != null) {
        if (guestLastDate == null) {
          finalLastDate = existingStreak.lastActivityDate;
        } else {
          finalLastDate = guestLastDate.isAfter(existingStreak.lastActivityDate!)
              ? guestLastDate
              : existingStreak.lastActivityDate;
        }
      }

      print('🔄 [Streak Migration] Guest: streak=$guestStreak, shields=$guestShields');
      print('🔄 [Streak Migration] Existing: streak=${existingStreak.currentStreak}, shields=${existingStreak.shieldsAvailable}');
      print('✅ [Streak Migration] Final: streak=$finalStreak, shields=$finalShields');
    }

    final success = await _service.updateStreakData(
      currentStreak: finalStreak,
      shieldsAvailable: finalShields,
      lastActivityDate: finalLastDate,
    );

    if (success) {
      // Clear local guest streak after successful migration
      await _appStateService.resetGuestStreak();
      await refresh();
    }

    return success;
  }

  /// Check if user has already acquired vocabulary today
  /// Returns true if last activity date is today
  Future<bool> hasAcquiredVocabularyToday() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final streakData = state;

    if (streakData?.lastActivityDate == null) return false;

    final lastActivityStr = streakData!.lastActivityDate!.toIso8601String().split('T')[0];
    return lastActivityStr == today;
  }

  /// Record vocabulary acquisition and update streak if not already done today
  /// Returns true if streak was updated (first vocabulary of the day)
  Future<bool> recordVocabularyAcquired() async {
    // Check if already acquired vocabulary today
    if (await hasAcquiredVocabularyToday()) {
      // Already updated today, no need to update again
      return false;
    }

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
}

/// Streak notifier provider
final streakProvider = StateNotifierProvider<StreakNotifier, StreakData?>((ref) {
  final service = ref.watch(streakServiceProvider);
  final appStateService = ref.watch(appStateServiceProvider);
  final userNotifier = ref.watch(userStateProvider.notifier);
  return StreakNotifier(service, appStateService, userNotifier);
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
  unknown,    // Data not loaded
  inactive,   // No streak (0 days)
  active,     // Streak ongoing
  atRisk,     // Missed day but has shields
  broken,     // Streak broken
}

extension StreakStatusExtension on StreakStatus {
  String get label {
    switch (this) {
      case StreakStatus.unknown:
        return 'Loading...';
      case StreakStatus.inactive:
        return 'Start your streak!';
      case StreakStatus.active:
        return 'Keep going!';
      case StreakStatus.atRisk:
        return 'Shield protecting you';
      case StreakStatus.broken:
        return 'Streak lost';
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
        return '💔';
    }
  }
}
