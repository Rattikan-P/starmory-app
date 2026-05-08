import 'package:intl/intl.dart';

/// Manages user quota for AI generations
class QuotaManager {
  final int totalLimit;
  final int dailyLimit;
  final List<QuotaEntry> usageHistory;

  QuotaManager({
    required this.totalLimit,
    required this.dailyLimit,
    List<QuotaEntry>? usageHistory,
  }) : usageHistory = usageHistory ?? [];

  /// Check if user can generate more content
  bool canGenerate() {
    return !isTotalLimitReached() && !isDailyLimitReached();
  }

  /// Check if total limit is reached
  bool isTotalLimitReached() {
    return usageHistory.length >= totalLimit;
  }

  /// Check if daily limit is reached
  bool isDailyLimitReached() {
    final todayUsage = getTodayUsage();
    return todayUsage >= dailyLimit;
  }

  /// Get today's usage count
  int getTodayUsage() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return usageHistory
        .where((entry) => DateFormat('yyyy-MM-dd').format(entry.timestamp) == today)
        .length;
  }

  /// Get remaining total quota
  int getRemainingTotal() {
    return (totalLimit - usageHistory.length).clamp(0, totalLimit);
  }

  /// Get remaining daily quota
  int getRemainingDaily() {
    final todayUsage = getTodayUsage();
    return (dailyLimit - todayUsage).clamp(0, dailyLimit);
  }

  /// Record a generation usage
  QuotaManager recordUsage({String? imageId, String? vocabularyId}) {
    final entry = QuotaEntry(
      timestamp: DateTime.now(),
      imageId: imageId,
      vocabularyId: vocabularyId,
    );

    return QuotaManager(
      totalLimit: totalLimit,
      dailyLimit: dailyLimit,
      usageHistory: [...usageHistory, entry],
    );
  }

  /// Get usage percentage (0-100)
  double getTotalUsagePercentage() {
    return (usageHistory.length / totalLimit * 100).clamp(0, 100);
  }

  double getDailyUsagePercentage() {
    final todayUsage = getTodayUsage();
    return (todayUsage / dailyLimit * 100).clamp(0, 100);
  }

  /// Get quota status message
  String getStatusMessage() {
    if (isTotalLimitReached()) {
      return 'Total limit reached ($totalLimit/$totalLimit)';
    } else if (isDailyLimitReached()) {
      return 'Daily limit reached ($dailyLimit/$dailyLimit)';
    } else {
      return 'Daily: ${getTodayUsage()}/$dailyLimit | Total: ${usageHistory.length}/$totalLimit';
    }
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'totalLimit': totalLimit,
      'dailyLimit': dailyLimit,
      'usageHistory': usageHistory.map((e) => e.toJson()).toList(),
    };
  }

  /// Create from JSON
  factory QuotaManager.fromJson(Map<String, dynamic> json) {
    return QuotaManager(
      totalLimit: json['totalLimit'] as int,
      dailyLimit: json['dailyLimit'] as int,
      usageHistory: (json['usageHistory'] as List<dynamic>?)
              ?.map((e) => QuotaEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Create guest mode quota manager
  factory QuotaManager.guestMode({List<QuotaEntry>? usageHistory}) {
    return QuotaManager(
      totalLimit: 10, // From AppConstants.guestTotalLimit
      dailyLimit: 3, // From AppConstants.guestDailyLimit
      usageHistory: usageHistory,
    );
  }

  /// Create registered user quota manager
  factory QuotaManager.registeredUser({List<QuotaEntry>? usageHistory}) {
    return QuotaManager(
      totalLimit: 999999, // Unlimited for registered users
      dailyLimit: 15, // From AppConstants.registeredDailyLimit
      usageHistory: usageHistory,
    );
  }
}

/// Represents a single quota usage entry
class QuotaEntry {
  final DateTime timestamp;
  final String? imageId;
  final String? vocabularyId;

  QuotaEntry({
    required this.timestamp,
    this.imageId,
    this.vocabularyId,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'imageId': imageId,
      'vocabularyId': vocabularyId,
    };
  }

  factory QuotaEntry.fromJson(Map<String, dynamic> json) {
    return QuotaEntry(
      timestamp: DateTime.parse(json['timestamp'] as String),
      imageId: json['imageId'] as String?,
      vocabularyId: json['vocabularyId'] as String?,
    );
  }
}
