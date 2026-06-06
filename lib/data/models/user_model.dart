import 'package:equatable/equatable.dart';
import '../../core/utils/quota_manager.dart';

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
    this.badges = const [],
    this.stickers = const [],
    required this.quotaManager,
    this.preferences = const {},
  });

  /// Create guest user
  factory UserModel.createGuest() {
    return UserModel(
      id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      email: 'guest@starmory.app',
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
      'languageVariant': 'US', // US or UK
      'defaultCefrLevel': 'A1',
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

  /// Get preference value
  T? getPreference<T>(String key) {
    return preferences[key] as T?;
  }

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
