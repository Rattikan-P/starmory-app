import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/streak_service.dart';
import '../../data/services/preference_service.dart';

/// Streak service provider
final streakServiceProvider = Provider<StreakService>((ref) {
  return StreakService();
});

/// Preference service provider for guest streak data
final preferenceServiceProvider = Provider<PreferenceService>((ref) {
  return PreferenceService();
});

/// Streak data provider - fetches and caches streak data
/// Works for both registered (cloud) and guest (local) users
class StreakNotifier extends StateNotifier<StreakData?> {
  StreakNotifier(this._service, this._prefService) : super(null) {
    _init();
  }

  final StreakService _service;
  final PreferenceService _prefService;

  Future<void> _init() async {
    await refresh();
  }

  /// Refresh streak data from appropriate source (cloud or local)
  Future<void> refresh() async {
    final isGuest = await _prefService.isGuestMode();

    if (isGuest) {
      // Guest - load from local storage
      await _loadGuestStreak();
    } else {
      // Registered - load from cloud
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await _service.getStreakData();
        state = data;
      } else {
        // Not logged in - try guest mode
        await _loadGuestStreak();
      }
    }
  }

  /// Load streak data from local storage (guest mode)
  Future<void> _loadGuestStreak() async {
    final currentStreak = await _prefService.getGuestCurrentStreak();
    final shields = await _prefService.getGuestShields();
    final longestStreak = await _prefService.getGuestLongestStreak();
    final lastActivityStr = await _prefService.getGuestLastActivityDate();

    DateTime? lastActivityDate;
    if (lastActivityStr != null) {
      try {
        lastActivityDate = DateTime.parse(lastActivityStr);
      } catch (e) {
        lastActivityDate = null;
      }
    }

    state = StreakData(
      currentStreak: currentStreak,
      shieldsAvailable: shields,
      longestStreak: longestStreak,
      lastActivityDate: lastActivityDate,
    );
  }

  /// Update streak after activity
  Future<bool> updateAfterActivity() async {
    final isGuest = await _prefService.isGuestMode();

    if (isGuest) {
      // Guest - update local
      await _prefService.updateGuestStreakAfterActivity();
      await _loadGuestStreak();
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
    final isGuest = await _prefService.isGuestMode();

    if (isGuest) {
      // Guest - update local
      if (currentStreak != null) {
        await _prefService.setGuestCurrentStreak(currentStreak);
      }
      if (shieldsAvailable != null) {
        await _prefService.setGuestShields(shieldsAvailable);
      }
      await _loadGuestStreak();
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
    final isGuest = await _prefService.isGuestMode();

    if (isGuest) {
      // Guest - update local
      final current = await _prefService.getGuestShields();
      await _prefService.setGuestShields(current + count);
      await _loadGuestStreak();
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
    final isGuest = await _prefService.isGuestMode();

    if (isGuest) {
      // Guest - update local
      final current = await _prefService.getGuestShields();
      if (current <= 0) return false;
      await _prefService.setGuestShields(current - 1);
      await _loadGuestStreak();
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
    final isGuest = await _prefService.isGuestMode();

    if (isGuest) {
      await _prefService.resetGuestStreak();
      await _loadGuestStreak();
      return true;
    } else {
      final success = await _service.resetStreak();
      if (success) await refresh();
      return success;
    }
  }

  /// Set streak for testing/demo
  /// Automatically calculates appropriate shields for the streak value
  /// 7 days = 1 shield, 14 days = 2 shields, etc.
  Future<bool> setStreak(int value, {int? shields}) async {
    final isGuest = await _prefService.isGuestMode();

    // Calculate appropriate shields if not explicitly provided
    final calculatedShields = shields ?? (value ~/ 7);

    if (isGuest) {
      await _prefService.setGuestCurrentStreak(value);
      await _prefService.setGuestLongestStreak(value);
      await _prefService.setGuestConsecutiveDays(value % 7);
      await _prefService.setGuestLastActivityDate(DateTime.now().toIso8601String().split('T')[0]);
      await _prefService.setGuestShields(calculatedShields);
      await _loadGuestStreak();
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
  Future<bool> migrateGuestStreakToCloud() async {
    final guestData = await _prefService.getGuestStreakDataForMigration();

    // Only migrate if there's actual data
    if (guestData['current_streak'] == 0 &&
        guestData['shields_available'] == 0) {
      return true; // Nothing to migrate
    }

    final success = await _service.updateStreakData(
      currentStreak: guestData['current_streak'] as int?,
      shieldsAvailable: guestData['shields_available'] as int?,
      lastActivityDate: guestData['last_activity_date'] != null
          ? DateTime.parse(guestData['last_activity_date'] as String)
          : null,
    );

    if (success) {
      // Clear local guest streak after successful migration
      await _prefService.resetGuestStreak();
      await refresh();
    }

    return success;
  }
}

/// Streak notifier provider
final streakProvider = StateNotifierProvider<StreakNotifier, StreakData?>((ref) {
  final service = ref.watch(streakServiceProvider);
  final prefService = ref.watch(preferenceServiceProvider);
  return StreakNotifier(service, prefService);
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
