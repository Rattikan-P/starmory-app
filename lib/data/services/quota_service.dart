import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'hive_service.dart';
import '../../core/config/app_constants.dart';
import '../../core/utils/quota_manager.dart';

class QuotaService {
  final SupabaseClient _client = Supabase.instance.client;
  final HiveService _hiveService;

  QuotaService() : _hiveService = HiveService();

  // Note: Using AppConstants for quota limits (single source of truth)
  // AppConstants.guestDailyLimit → AppConstants.guestDailyLimit
  // AppConstants.registeredDailyLimit → AppConstants.registeredDailyLimit
  static const String _quotasTable = 'user_quotas';

  Future<QuotaStatus> getStatus() async {
    final isGuest = _client.auth.currentUser == null;
    return isGuest ? await _getGuestStatus() : await _getRegisteredStatus();
  }

  Future<QuotaStatus> _getGuestStatus() async {
    // Get guest user from Hive (SSOT for quota data)
    final user = await _hiveService.getCurrentUser();

    if (user == null || !user.isGuest) {
      // No guest user exists - return default status
      return QuotaStatus(
        generationsRemaining: 10, // guest total limit
        photoUploadsRemaining: AppConstants.guestDailyLimit,
        isGuest: true,
        lifetimeLimit: 10,
        dailyPhotoLimit: AppConstants.guestDailyLimit,
      );
    }

    // Read quota from UserModel.quotaManager
    final quota = user.quotaManager;
    final totalUsed = quota.usageHistory.length;
    final guestTotalLimit = 10; // From AppConstants.guestTotalLimit
    final todayUsage = quota.getTodayUsage();

    return QuotaStatus(
      generationsRemaining: guestTotalLimit - totalUsed,
      photoUploadsRemaining: AppConstants.guestDailyLimit - todayUsage,
      isGuest: true,
      lifetimeLimit: guestTotalLimit,
      dailyPhotoLimit: AppConstants.guestDailyLimit,
      totalUsed: totalUsed,
    );
  }

  Future<QuotaStatus> _getRegisteredStatus() async {
    final user = _client.auth.currentUser;
    if (user == null) return await _getGuestStatus();

    final today = DateTime.now().toIso8601String().split('T')[0];

    final response = await _client
        .from(_quotasTable)
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    if (response == null) {
      // Create quota record if not exists
      await _client.from(_quotasTable).insert({'user_id': user.id});
      return QuotaStatus(
        generationsRemaining: AppConstants.registeredDailyLimit,
        photoUploadsRemaining: AppConstants.registeredDailyLimit,
        isGuest: false,
        dailyGenLimit: AppConstants.registeredDailyLimit,
      );
    }

    final lastReset = response['daily_gen_reset_date'] as String?;
    final genCount = response['daily_gen_count'] as int? ?? 0;
    final totalCount = response['total_gen_count'] as int? ?? 0;

    int currentCount = genCount;
    // Auto-reset if new day
    if (lastReset != today) {
      await _resetDailyQuota(user.id);
      currentCount = 0;
    }

    return QuotaStatus(
      generationsRemaining: AppConstants.registeredDailyLimit - currentCount,
      photoUploadsRemaining: AppConstants.registeredDailyLimit - currentCount,
      isGuest: false,
      dailyGenLimit: AppConstants.registeredDailyLimit,
      totalUsed: totalCount,
    );
  }

  Future<bool> canGenerate() async {
    final status = await getStatus();
    return status.generationsRemaining > 0 && status.photoUploadsRemaining > 0;
  }

  Future<bool> incrementGeneration() async {
    final isGuest = _client.auth.currentUser == null;
    return isGuest ? await _incrementGuestGen() : await _incrementRegisteredGen();
  }

  Future<bool> _incrementGuestGen() async {
    // Get guest user from Hive
    final user = await _hiveService.getCurrentUser();

    if (user == null || !user.isGuest) {
      return false;
    }

    final quota = user.quotaManager;
    final guestTotalLimit = 10;

    // Check if limit reached
    if (quota.usageHistory.length >= guestTotalLimit) {
      return false;
    }

    // Record usage in UserModel
    final updatedUser = user.copyWith(
      quotaManager: quota.recordUsage(),
    );

    // Save updated user back to Hive
    await _hiveService.saveUser(updatedUser);
    return true;
  }

  Future<bool> _incrementRegisteredGen() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final today = DateTime.now().toIso8601String().split('T')[0];

    // Get current quota
    final response = await _client
        .from(_quotasTable)
        .select()
        .eq('user_id', user.id)
        .single();

    final lastReset = response['daily_gen_reset_date'] as String?;
    final genCount = response['daily_gen_count'] as int? ?? 0;
    final totalCount = response['total_gen_count'] as int? ?? 0;

    // Check if needs reset first (before increment)
    int newDailyCount;
    if (lastReset == today) {
      // Same day - just increment
      newDailyCount = genCount + 1;
    } else {
      // New day - reset first, then increment to 1
      await _resetDailyQuota(user.id);
      newDailyCount = 1;
    }

    if (newDailyCount > AppConstants.registeredDailyLimit) return false;

    // Update quota
    await _client
        .from(_quotasTable)
        .update({
          'daily_gen_count': newDailyCount,
          'daily_gen_reset_date': today,
          'total_gen_count': totalCount + 1,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', user.id);

    return true;
  }

  Future<bool> incrementPhotoUpload() async {
    final isGuest = _client.auth.currentUser == null;
    return isGuest ? await _incrementGuestPhoto() : await _incrementRegisteredGen();
  }

  Future<bool> _incrementGuestPhoto() async {
    // For guests, photo upload counts as generation
    // Reuse the same quota tracking
    return await _incrementGuestGen();
  }

  Future<void> _resetDailyQuota(String userId) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    await _client
        .from(_quotasTable)
        .update({
          'daily_gen_count': 0,
          'daily_gen_reset_date': today,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', userId);
  }

  /// Check and reset quota if new day (for registered users)
  /// Call this when app opens to ensure quota is up-to-date
  Future<bool> checkAndResetQuotaIfNeeded() async {
    final isGuest = _client.auth.currentUser == null;
    if (isGuest) return false; // Guests handled separately

    final user = _client.auth.currentUser;
    if (user == null) return false;

    final today = DateTime.now().toIso8601String().split('T')[0];

    try {
      final response = await _client
          .from(_quotasTable)
          .select('daily_gen_reset_date')
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) return false;

      final lastReset = response['daily_gen_reset_date'] as String?;

      // If new day, reset quota
      if (lastReset != today) {
        await _resetDailyQuota(user.id);
        return true; // Was reset
      }

      return false; // No reset needed
    } catch (e) {
      print('❌ [QuotaService] Error checking quota reset: $e');
      return false;
    }
  }

  /// Check and reset guest quota if new day
  /// Updates UserModel if reset is needed
  Future<bool> checkAndResetGuestQuotaIfNeeded() async {
    try {
      // Get guest user from Hive
      final user = await _hiveService.getCurrentUser();

      if (user == null || !user.isGuest) return false;

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final quota = user.quotaManager;

      // Check if any usage is from yesterday or older
      bool hasOldEntries = quota.usageHistory.any((entry) {
        final entryDate = DateFormat('yyyy-MM-dd').format(entry.timestamp);
        return entryDate != today;
      });

      if (hasOldEntries) {
        // Filter out old entries, keep only today's
        final todayEntries = quota.usageHistory.where((entry) {
          final entryDate = DateFormat('yyyy-MM-dd').format(entry.timestamp);
          return entryDate == today;
        }).toList();

        // Update UserModel with filtered history
        final updatedQuota = QuotaManager(
          totalLimit: quota.totalLimit,
          dailyLimit: quota.dailyLimit,
          usageHistory: todayEntries,
        );

        final updatedUser = user.copyWith(quotaManager: updatedQuota);
        await _hiveService.saveUser(updatedUser);

        print('✅ [QuotaService] Guest quota reset - cleared old entries');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ [QuotaService] Error checking guest quota reset: $e');
      return false;
    }
  }
}

class QuotaStatus {
  final int generationsRemaining;
  final int photoUploadsRemaining;
  final bool isGuest;
  final int? lifetimeLimit;
  final int? dailyPhotoLimit;
  final int? dailyGenLimit;
  final int? totalUsed;

  QuotaStatus({
    required this.generationsRemaining,
    required this.photoUploadsRemaining,
    required this.isGuest,
    this.lifetimeLimit,
    this.dailyPhotoLimit,
    this.dailyGenLimit,
    this.totalUsed,
  });

  bool get isLow => generationsRemaining <= 3 && generationsRemaining > 0;
  bool get isExhausted => generationsRemaining <= 0;

  String get warningMessage {
    if (isExhausted) {
      return isGuest
          ? 'Free trials used up. Sign up for 15 daily generations!'
          : 'Daily limit reached. Come back tomorrow!';
    }
    if (isLow) {
      return isGuest
          ? '$generationsRemaining of $lifetimeLimit free left'
          : '$generationsRemaining left today';
    }
    return '';
  }
}
