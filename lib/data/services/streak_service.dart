import 'package:supabase_flutter/supabase_flutter.dart';

/// Streak data model
class StreakData {
  final int currentStreak;
  final int longestStreak;
  final int shieldsAvailable;
  final DateTime? lastActivityDate;

  StreakData({
    required this.currentStreak,
    required this.longestStreak,
    required this.shieldsAvailable,
    this.lastActivityDate,
  });

  factory StreakData.fromMap(Map<String, dynamic> map) {
    return StreakData(
      currentStreak: map['current_streak'] as int? ?? 0,
      longestStreak: map['longest_streak'] as int? ?? 0,
      shieldsAvailable: map['shields_available'] as int? ?? 0,
      lastActivityDate: map['last_activity_date'] != null
          ? DateTime.parse(map['last_activity_date'] as String)
          : null,
    );
  }

  /// Consecutive days since last shield (calculated)
  int get consecutiveDays => currentStreak % 7;

  /// Days since last activity
  int get daysSinceLastActivity {
    if (lastActivityDate == null) return 999;
    return DateTime.now().difference(lastActivityDate!).inDays;
  }

  /// Is streak at risk (missed 1 day, have shields)
  bool get isAtRisk {
    final missed = daysSinceLastActivity;
    return missed >= 1 && shieldsAvailable > 0;
  }

  /// Is streak broken (missed day, no shields)
  bool get isBroken {
    final missed = daysSinceLastActivity;
    return missed >= 2 && shieldsAvailable == 0;
  }

  /// Days until shield is earned (0-6, or null if not counting)
  int? get daysUntilNextShield {
    final consecutive = consecutiveDays;
    if (consecutive == 0) return 7;
    return 7 - consecutive;
  }

  Map<String, dynamic> toMap() {
    return {
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'shields_available': shieldsAvailable,
      'last_activity_date': lastActivityDate?.toIso8601String(),
    };
  }
}

/// Service for managing user streaks and shields
class StreakService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get current user's streak data
  Future<StreakData?> getStreakData() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final response = await _client
        .from('users')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) return null;

    return StreakData.fromMap(response);
  }

  /// Get streak data for a specific user (admin/debug use)
  Future<StreakData?> getStreakDataForUser(String userId) async {
    final response = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;

    return StreakData.fromMap(response);
  }

  /// Update streak data manually (testing/admin use)
  Future<bool> updateStreakData({
    int? currentStreak,
    int? longestStreak,
    int? shieldsAvailable,
    DateTime? lastActivityDate,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final updates = <String, dynamic>{};
    if (currentStreak != null) updates['current_streak'] = currentStreak;
    if (longestStreak != null) updates['longest_streak'] = longestStreak;
    if (shieldsAvailable != null) updates['shields_available'] = shieldsAvailable;
    if (lastActivityDate != null) {
      updates['last_activity_date'] = lastActivityDate.toIso8601String();
    }

    final error = await _client
        .from('users')
        .update(updates)
        .eq('id', user.id);

    return error == null;
  }

  /// Add shields to user (reward, testing)
  Future<bool> addShields(int count) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final current = await getStreakData();
    if (current == null) return false;

    return await updateStreakData(
      shieldsAvailable: current.shieldsAvailable + count,
    );
  }

  /// Use a shield manually (when user activates it)
  Future<bool> useShield() async {
    final current = await getStreakData();
    if (current == null || current.shieldsAvailable <= 0) return false;

    return await updateStreakData(
      shieldsAvailable: current.shieldsAvailable - 1,
    );
  }

  /// Call the database function to get full streak status
  Future<Map<String, dynamic>?> getStreakStatus() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final response = await _client.rpc('get_user_streak_status', params: {
      'user_uuid': user.id,
    });

    if (response == null) return null;

    return response as Map<String, dynamic>;
  }

  /// Manually trigger streak update (for testing)
  /// In production, this is triggered by activity completion
  Future<bool> manualStreakUpdate() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    // Update last activity date to today
    final today = DateTime.now().toIso8601String().split('T')[0];

    final error = await _client
        .from('users')
        .update({
          'last_activity_date': today,
        })
        .eq('id', user.id);

    return error == null;
  }

  /// Reset streak (for testing/admin)
  Future<bool> resetStreak() async {
    return await updateStreakData(
      currentStreak: 0,
      lastActivityDate: null,
    );
  }

  /// Check if streak should be reset due to inactivity
  /// Returns true if streak was reset, false otherwise
  Future<bool> checkAndResetStreakIfExpired() async {
    print('🔍 [StreakService] checkAndResetStreakIfExpired() called');

    final current = await getStreakData();
    if (current == null) {
      print('⚠️ [StreakService] No streak data found');
      return false;
    }

    print('   [StreakService] Current: streak=${current.currentStreak}, lastActivity=${current.lastActivityDate}');

    // No activity date - nothing to check
    if (current.lastActivityDate == null) {
      print('ℹ️ [StreakService] No previous activity - nothing to check');
      return false;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastLocal = current.lastActivityDate!.toLocal();
    final lastDay = DateTime(lastLocal.year, lastLocal.month, lastLocal.day);
    final daysDifference = today.difference(lastDay).inDays;

    print('   [StreakService] Days since last activity: $daysDifference');

    // daysDifference <= 1: active today or yesterday -> streak safe
    if (daysDifference <= 1) {
      print('✅ [StreakService] Streak still active');
      return false;
    }

    // Check if user has enough shields to cover missed days
    final missedDays = daysDifference - 1;
    if (current.shieldsAvailable >= missedDays) {
      print('🛡️ [StreakService] Protected by shields ($missedDays missed, ${current.shieldsAvailable} shields available)');
      return false;
    }

    print('🔥 [StreakService] Expired! Resetting streak...');
    return await updateStreakData(
      currentStreak: 0,
      shieldsAvailable: 0,
      lastActivityDate: null,
    );
  }

  /// Set streak to specific value (for testing/demo)
  Future<bool> setStreak(int streakValue, {int shields = 0}) async {
    return await updateStreakData(
      currentStreak: streakValue,
      longestStreak: streakValue,
      shieldsAvailable: shields,
      lastActivityDate: DateTime.now(),
    );
  }
}
