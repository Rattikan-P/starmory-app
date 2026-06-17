import 'package:equatable/equatable.dart';
import '../../core/utils/quota_manager.dart';
import '../../constants/app_defaults.dart';

/// Represents user account information
class UserModel extends Equatable {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final bool isGuest;
  final DateTime createdAt;
  final DateTime? lastActiveAt;
  final int totalWordsLearned;
  final int currentStreak; // in days
  final int longestStreak;
  final int shields; // streak shields (freeze protection)
  final DateTime? lastStreakActivityDate; // last date user did streak activity
  final List<String> badges;
  final List<String> stickers;
  final QuotaManager quotaManager;
  final Map<String, dynamic> preferences;

  const UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.isGuest,
    required this.createdAt,
    this.lastActiveAt,
    this.totalWordsLearned = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.shields = 0,
    this.lastStreakActivityDate,
    this.badges = const [],
    this.stickers = const [],
    required this.quotaManager,
    this.preferences = const {},
  });

  /// Create guest user
  factory UserModel.createGuest() {
    return UserModel(
      id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      email: 'guest@starmory.com',
      isGuest: true,
      createdAt: DateTime.now(),
      quotaManager: QuotaManager.guestMode(),
      preferences: _defaultPreferences(),
    );
  }

  /// Create registered user
  factory UserModel.createRegisteredUser({
    required String id,
    required String email,
    String? displayName,
    String? photoUrl,
  }) {
    return UserModel(
      id: id,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      isGuest: false,
      createdAt: DateTime.now(),
      quotaManager: QuotaManager.registeredUser(),
      preferences: _defaultPreferences(),
    );
  }

  /// Default user preferences
  static Map<String, dynamic> _defaultPreferences() {
    return {
      'languageVariant': AppDefaults.defaultEnglishVariant, // US or UK
      'defaultCefrLevel': AppDefaults.defaultLanguageLevel,
      'notificationEnabled': true,
      'reviewReminderTime': '19:00',
      'soundEnabled': true,
      'vibrationEnabled': true,
      'autoPlayAudio': false,
      'showTranslations': true,
    };
  }

  /// Update last active timestamp
  UserModel updateLastActive() {
    return copyWith(lastActiveAt: DateTime.now());
  }

  /// Increment words learned count
  UserModel incrementWordsLearned() {
    final newTotal = totalWordsLearned + 1;
    return copyWith(totalWordsLearned: newTotal);
  }

  /// Update streak
  UserModel updateStreak(int newStreak) {
    final newLongestStreak = newStreak > longestStreak ? newStreak : longestStreak;
    return copyWith(
      currentStreak: newStreak,
      longestStreak: newLongestStreak,
    );
  }

  /// Increment streak after activity
  /// Returns updated user with incremented streak and potentially earned shields
  /// Logic matches database trigger: update_streak_after_activity()
  /// Grace Period: Allow 48 hours (2 days) gap without breaking streak
  UserModel incrementStreak() {
    final today = DateTime.now().toIso8601String().split('T')[0];

    print('🔥 [Guest Streak] incrementStreak() called');
    print('   Current: streak=$currentStreak, longest=$longestStreak, shields=$shields');
    print('   Last activity: ${lastStreakActivityDate?.toIso8601String().split('T')[0] ?? "null"}');

    // First activity ever
    if (lastStreakActivityDate == null) {
      print('   ✅ First activity ever → streak=1');
      return copyWith(
        currentStreak: 1,
        longestStreak: longestStreak < 1 ? 1 : longestStreak,
        lastStreakActivityDate: DateTime.now(),
      );
    }

    // Check if already did activity today
    final lastActivityStr = lastStreakActivityDate!.toIso8601String().split('T')[0];
    if (lastActivityStr == today) {
      print('   ℹ️ Already updated today → no change');
      return this; // Already updated today
    }

    // Check if within grace period (within 48 hours = 2 days)
    // This handles edge case: activity at 23:59 yesterday and 00:01 today
    final now = DateTime.now();
    final lastActivity = lastStreakActivityDate!;
    final hoursSince = now.difference(lastActivity).inHours;

    print('   Hours since last activity: $hoursSince');

    // Grace period: 48 hours (2 days)
    if (hoursSince <= 48) {
      // Within grace period - increment streak
      final newStreak = currentStreak + 1;
      final newLongestStreak = newStreak > longestStreak ? newStreak : longestStreak;

      // Earn shield every 7 days
      int newShields = shields;
      bool earnedShield = false;
      if (newStreak % 7 == 0 && newStreak > currentStreak) {
        newShields = shields + 1;
        earnedShield = true;
      }

      print('   ✅ Within grace period → streak=$newStreak (earnedShield=$earnedShield)');
      return copyWith(
        currentStreak: newStreak,
        longestStreak: newLongestStreak,
        shields: newShields,
        lastStreakActivityDate: DateTime.now(),
      );
    } else {
      // Outside grace period - use shield if available, otherwise reset
      int newShields = shields;
      int newStreak = currentStreak; // Keep streak if shield used

      if (shields > 0) {
        // Use one shield - protect streak
        newShields = shields - 1;
        print('   🛡️ Outside grace period → using shield (shields=$newShields)');
        // Don't reset streak - shield protects it
      } else {
        // No shields - reset streak to 1
        newStreak = 1;
        print('   💀 Outside grace period, no shields → streak reset to 1');
      }

      return copyWith(
        currentStreak: newStreak,
        shields: newShields,
        lastStreakActivityDate: DateTime.now(),
      );
    }
  }

  /// Use a shield (freeze streak for one missed day)
  UserModel useShield() {
    if (shields <= 0) return this;
    return copyWith(shields: shields - 1);
  }

  /// Add shields (for testing or rewards)
  UserModel addShields(int count) {
    return copyWith(shields: shields + count);
  }

  /// Check if already did streak activity today
  bool get hasDoneStreakActivityToday {
    if (lastStreakActivityDate == null) return false;
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastActivityStr = lastStreakActivityDate!.toIso8601String().split('T')[0];
    return lastActivityStr == today;
  }

  /// Add badge
  UserModel addBadge(String badgeId) {
    if (badges.contains(badgeId)) return this;
    return copyWith(badges: [...badges, badgeId]);
  }

  /// Add sticker
  UserModel addSticker(String stickerId) {
    if (stickers.contains(stickerId)) return this;
    return copyWith(stickers: [...stickers, stickerId]);
  }

  /// Update preference
  UserModel updatePreference(String key, dynamic value) {
    final newPrefs = Map<String, dynamic>.from(preferences);
    newPrefs[key] = value;
    return copyWith(preferences: newPrefs);
  }

  /// Update language level preference
  UserModel updateLanguageLevel(String level) {
    return updatePreference('defaultCefrLevel', level);
  }

  /// Update english variant preference
  UserModel updateEnglishVariant(String variant) {
    return updatePreference('languageVariant', variant);
  }

  /// Get preference value
  T? getPreference<T>(String key) {
    return preferences[key] as T?;
  }

  /// Get language level from preferences
  String get languageLevel =>
      getPreference<String>('defaultCefrLevel') ?? AppDefaults.defaultLanguageLevel;

  /// Get english variant from preferences
  String get englishVariant =>
      getPreference<String>('languageVariant') ?? AppDefaults.defaultEnglishVariant;

  /// Check if user can generate more content
  bool get canGenerate => quotaManager.canGenerate();

  /// Get display name (fallback to email if not set)
  String get displayNameOrEmail => displayName ?? email;

  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    bool? isGuest,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    int? totalWordsLearned,
    int? currentStreak,
    int? longestStreak,
    int? shields,
    DateTime? lastStreakActivityDate,
    List<String>? badges,
    List<String>? stickers,
    QuotaManager? quotaManager,
    Map<String, dynamic>? preferences,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      isGuest: isGuest ?? this.isGuest,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      totalWordsLearned: totalWordsLearned ?? this.totalWordsLearned,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      shields: shields ?? this.shields,
      lastStreakActivityDate: lastStreakActivityDate ?? this.lastStreakActivityDate,
      badges: badges ?? this.badges,
      stickers: stickers ?? this.stickers,
      quotaManager: quotaManager ?? this.quotaManager,
      preferences: preferences ?? this.preferences,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'isGuest': isGuest,
      'createdAt': createdAt.toIso8601String(),
      'lastActiveAt': lastActiveAt?.toIso8601String(),
      'totalWordsLearned': totalWordsLearned,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'shields': shields,
      'lastStreakActivityDate': lastStreakActivityDate?.toIso8601String(),
      'badges': badges,
      'stickers': stickers,
      'quotaManager': quotaManager.toJson(),
      'preferences': preferences,
    };
  }

  /// Create from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      isGuest: json['isGuest'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastActiveAt: json['lastActiveAt'] != null
          ? DateTime.parse(json['lastActiveAt'] as String)
          : null,
      totalWordsLearned: json['totalWordsLearned'] as int? ?? 0,
      currentStreak: json['currentStreak'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      shields: json['shields'] as int? ?? 0,
      lastStreakActivityDate: json['lastStreakActivityDate'] != null
          ? DateTime.parse(json['lastStreakActivityDate'] as String)
          : null,
      badges: (json['badges'] as List<dynamic>?)?.cast<String>() ?? [],
      stickers: (json['stickers'] as List<dynamic>?)?.cast<String>() ?? [],
      quotaManager: QuotaManager.fromJson(
          json['quotaManager'] as Map<String, dynamic>? ?? {}),
      preferences: (json['preferences'] as Map<String, dynamic>?) ?? {},
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        isGuest,
        totalWordsLearned,
        currentStreak,
        longestStreak,
      ];
}
