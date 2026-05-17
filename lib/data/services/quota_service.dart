import 'package:supabase_flutter/supabase_flutter.dart';
import 'preference_service.dart';

class QuotaService {
  final SupabaseClient _client = Supabase.instance.client;
  final PreferenceService _preferenceService;

  QuotaService(this._preferenceService);

  static const int guestLifetimeLimit = 10;
  static const int guestDailyPhotoLimit = 3;
  static const int registeredDailyGenLimit = 15;
  static const String _quotasTable = 'user_quotas';

  Future<QuotaStatus> getStatus() async {
    final isGuest = _client.auth.currentUser == null;
    return isGuest ? await _getGuestStatus() : await _getRegisteredStatus();
  }

  Future<QuotaStatus> _getGuestStatus() async {
    final lifetimeUsed = (await _preferenceService.getGuestLifetimeGenCount()) ?? 0;
    final photoToday = (await _preferenceService.getGuestDailyPhotoCount()) ?? 0;

    return QuotaStatus(
      generationsRemaining: guestLifetimeLimit - lifetimeUsed,
      photoUploadsRemaining: guestDailyPhotoLimit - photoToday,
      isGuest: true,
      lifetimeLimit: guestLifetimeLimit,
      dailyPhotoLimit: guestDailyPhotoLimit,
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
        generationsRemaining: registeredDailyGenLimit,
        photoUploadsRemaining: registeredDailyGenLimit,
        isGuest: false,
        dailyGenLimit: registeredDailyGenLimit,
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
      generationsRemaining: registeredDailyGenLimit - currentCount,
      photoUploadsRemaining: registeredDailyGenLimit - currentCount,
      isGuest: false,
      dailyGenLimit: registeredDailyGenLimit,
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
    final current = (await _preferenceService.getGuestLifetimeGenCount()) ?? 0;
    if (current >= guestLifetimeLimit) return false;
    await _preferenceService.incrementGuestLifetimeGenCount();
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

    // Check if needs reset
    int newDailyCount = (lastReset == today) ? genCount + 1 : 1;

    if (newDailyCount > registeredDailyGenLimit) return false;

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
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastReset = await _preferenceService.getGuestDailyPhotoResetDate();

    if (lastReset != today) {
      await _preferenceService.resetGuestDailyPhoto();
    }

    final current = (await _preferenceService.getGuestDailyPhotoCount()) ?? 0;
    if (current >= guestDailyPhotoLimit) return false;

    await _preferenceService.incrementGuestDailyPhotoCount();
    return true;
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
