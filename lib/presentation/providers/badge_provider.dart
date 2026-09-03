import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/badge_unlock_dialog.dart';
import 'providers.dart';

/// Activity types for badge tracking
enum ActivityType {
  generateVocab,
  review,
}

/// Badge model representing an achievement badge
class Badge {
  final String id;
  final String name;
  final String titleTh;
  final String icon;
  final String description;
  final String descriptionTh;
  final bool isLocked;
  final int requiredStars;
  final String category; // 'Stars', 'Streak', 'Time', 'Special'
  final String tier; // 'Bronze', 'Silver', 'Gold', 'Nebula'
  final List<Color> gradientColors;

  Badge({
    required this.id,
    required this.name,
    this.titleTh = '',
    required this.icon,
    required this.description,
    this.descriptionTh = '',
    this.isLocked = true,
    required this.requiredStars,
    this.category = 'Stars',
    this.tier = 'Bronze',
    this.gradientColors = const [Color(0xFF8B5CF6), Color(0xFF6366F1)],
  });

  Color get tierColor {
    switch (tier.toLowerCase()) {
      case 'bronze':
        return const Color(0xFFCD7F32);
      case 'silver':
        return const Color(0xFFC0C0C0);
      case 'gold':
        return const Color(0xFFFFD700);
      case 'nebula':
        return const Color(0xFFC084FC);
      default:
        return const Color(0xFF8B5CF6);
    }
  }
}

/// Upcoming Badge Info for progress display
class UpcomingBadgeInfo {
  final Badge badge;
  final int currentProgress;
  final int targetProgress;
  final double progressPercentage;
  final String progressLabel;

  const UpcomingBadgeInfo({
    required this.badge,
    required this.currentProgress,
    required this.targetProgress,
    required this.progressPercentage,
    required this.progressLabel,
  });
}

/// Statistics model for tracking badge criteria
class BadgeStats {
  final int nightOwlCount;
  final int earlyBirdCount;
  final int shieldSavedCount;
  final int totalGenCount;
  final int totalReviewCount;

  const BadgeStats({
    this.nightOwlCount = 0,
    this.earlyBirdCount = 0,
    this.shieldSavedCount = 0,
    this.totalGenCount = 0,
    this.totalReviewCount = 0,
  });

  factory BadgeStats.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const BadgeStats();
    return BadgeStats(
      nightOwlCount: map['night_owl_count'] as int? ?? 0,
      earlyBirdCount: map['early_bird_count'] as int? ?? 0,
      shieldSavedCount: map['shield_saved_count'] as int? ?? 0,
      totalGenCount: map['total_gen_count'] as int? ?? 0,
      totalReviewCount: map['total_review_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'night_owl_count': nightOwlCount,
      'early_bird_count': earlyBirdCount,
      'shield_saved_count': shieldSavedCount,
      'total_gen_count': totalGenCount,
      'total_review_count': totalReviewCount,
    };
  }

  BadgeStats copyWith({
    int? nightOwlCount,
    int? earlyBirdCount,
    int? shieldSavedCount,
    int? totalGenCount,
    int? totalReviewCount,
  }) {
    return BadgeStats(
      nightOwlCount: nightOwlCount ?? this.nightOwlCount,
      earlyBirdCount: earlyBirdCount ?? this.earlyBirdCount,
      shieldSavedCount: shieldSavedCount ?? this.shieldSavedCount,
      totalGenCount: totalGenCount ?? this.totalGenCount,
      totalReviewCount: totalReviewCount ?? this.totalReviewCount,
    );
  }
}

/// Badge state holding badge list, unlocked count, and activity stats
class BadgeState {
  final List<Badge> badges;
  final int unlockedCount;
  final BadgeStats stats;
  final Badge? latestUnlockedBadge;

  BadgeState({
    required this.badges,
    required this.unlockedCount,
    this.stats = const BadgeStats(),
    this.latestUnlockedBadge,
  });

  factory BadgeState.initial() {
    return BadgeState(
      badges: [],
      unlockedCount: 0,
      stats: const BadgeStats(),
    );
  }

  BadgeState copyWith({
    List<Badge>? badges,
    int? unlockedCount,
    BadgeStats? stats,
    Badge? latestUnlockedBadge,
  }) {
    return BadgeState(
      badges: badges ?? this.badges,
      unlockedCount: unlockedCount ?? this.unlockedCount,
      stats: stats ?? this.stats,
      latestUnlockedBadge: latestUnlockedBadge ?? this.latestUnlockedBadge,
    );
  }

  bool isUnlocked(String badgeId) {
    try {
      final b = badges.firstWhere((element) => element.id == badgeId);
      return !b.isLocked;
    } catch (_) {
      return false;
    }
  }

  int get totalBadgesCount => badges.length;

  int getProgress(
    Badge badge, {
    int totalStars = 0,
    int streakDays = 0,
  }) {
    if (badge.category == 'Stars') {
      return totalStars;
    }
    if (badge.category == 'Streak') {
      return streakDays;
    }
    switch (badge.id) {
      case 'night_owl':
      case 'lord_of_dark_nebula':
        return stats.nightOwlCount;
      case 'morning_nova':
      case 'solar_pioneer':
        return stats.earlyBirdCount;
      case 'iron_shield':
        return stats.shieldSavedCount;
      default:
        return 0;
    }
  }

  double getProgressRatio(
    Badge badge, {
    int totalStars = 0,
    int streakDays = 0,
  }) {
    if (!badge.isLocked) return 1.0;
    final current = getProgress(
      badge,
      totalStars: totalStars,
      streakDays: streakDays,
    );
    if (badge.requiredStars <= 0) return 0.0;
    return (current / badge.requiredStars).clamp(0.0, 1.0);
  }

  /// Calculates the next closest badge to unlock based on user stars and streak
  UpcomingBadgeInfo? getNextUpcomingBadge(int totalStars, int streakDays, {String? category}) {
    var candidateBadges = badges.where((b) => b.isLocked).toList();
    if (category != null) {
      candidateBadges = candidateBadges.where((b) => b.category == category).toList();
    }
    if (candidateBadges.isEmpty) return null;

    // For Stars category, find the next star milestone badge (target > totalStars, smallest target)
    if (category == 'Stars' || (category == null && candidateBadges.any((b) => b.category == 'Stars' && b.requiredStars > totalStars))) {
      final starBadges = candidateBadges
          .where((b) => b.category == 'Stars' && b.requiredStars > totalStars)
          .toList();
      if (starBadges.isNotEmpty) {
        starBadges.sort((a, b) => a.requiredStars.compareTo(b.requiredStars));
        final nextBadge = starBadges.first;
        final target = nextBadge.requiredStars;
        final ratio = target > 0 ? (totalStars / target).clamp(0.0, 1.0) : 0.0;
        return UpcomingBadgeInfo(
          badge: nextBadge,
          currentProgress: totalStars,
          targetProgress: target,
          progressPercentage: ratio,
          progressLabel: '$totalStars / $target Stars',
        );
      }
    }

    UpcomingBadgeInfo? closest;
    double maxRatio = -1.0;
    int minRemaining = 999999;

    for (final badge in candidateBadges) {
      final isStreak = badge.category == 'Streak';
      final isStars = badge.category == 'Stars';

      int current;
      int target = badge.requiredStars;
      String unit;

      if (isStars) {
        current = totalStars;
        unit = 'Stars';
      } else if (isStreak) {
        current = streakDays;
        unit = 'Days';
      } else {
        // Special badges with numerical stats (night owl, early bird, etc.)
        current = getProgress(badge);
        unit = 'Actions';
      }

      // Skip badges that have already met requirements or have no target
      if (target <= 0 || current >= target) continue;

      final ratio = (current / target).clamp(0.0, 1.0);
      final remaining = (target - current).clamp(0, 999999);

      if (ratio > maxRatio || (ratio == maxRatio && remaining < minRemaining)) {
        maxRatio = ratio;
        minRemaining = remaining;
        closest = UpcomingBadgeInfo(
          badge: badge,
          currentProgress: current,
          targetProgress: target,
          progressPercentage: ratio,
          progressLabel: '$current / $target $unit',
        );
      }
    }

    return closest;
  }
}

/// Controller managing all badge evaluations, stats tracking, and unlocks
class BadgeController extends StateNotifier<BadgeState> {
  final Ref _ref;

  BadgeController(this._ref) : super(BadgeState.initial()) {
    _initializeBadges();
    _initUserListener();
  }

  void _initUserListener() {
    final user = _ref.read(userStateProvider).user;
    if (user != null) {
      _syncWithUser(user);
    }

    _ref.listen(userStateProvider, (previous, next) {
      final nextUser = next.user;
      if (nextUser != null) {
        _syncWithUser(nextUser);
      }
    });
  }

  void _syncWithUser(dynamic user) {
    final rawStats = user.preferences['badge_stats'] as Map<String, dynamic>?;
    final stats = BadgeStats.fromMap(rawStats);
    final userBadges = Set<String>.from(user.badges);

    final updatedBadges = state.badges.map((badge) {
      final shouldBeUnlocked = userBadges.contains(badge.id) || (badge.id == 'first_word' && user.isGuest);
      return Badge(
        id: badge.id,
        name: badge.name,
        titleTh: badge.titleTh,
        icon: badge.icon,
        description: badge.description,
        descriptionTh: badge.descriptionTh,
        isLocked: !shouldBeUnlocked,
        requiredStars: badge.requiredStars,
        category: badge.category,
        tier: badge.tier,
        gradientColors: badge.gradientColors,
      );
    }).toList();

    state = state.copyWith(
      badges: updatedBadges,
      unlockedCount: updatedBadges.where((b) => !b.isLocked).length,
      stats: stats,
    );
  }

  void _initializeBadges() {
    final badges = [
      Badge(
        id: 'first_word',
        name: 'First Star',
        titleTh: 'ดาวดวงแรก',
        icon: 'assets/images/badges/first_word.png',
        description: 'Learned your first word',
        descriptionTh: 'เรียนรู้คำศัพท์คำแรกของคุณ',
        isLocked: false,
        requiredStars: 1,
        category: 'Stars',
        tier: 'Bronze',
        gradientColors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
      ),
      Badge(
        id: 'streak_3',
        name: 'First Spark',
        titleTh: 'ประกายแสงแรก',
        icon: 'assets/images/badges/streak_3.png',
        description: '3 day learning streak',
        descriptionTh: 'รักษาสถิติการเรียนต่อเนื่อง 3 วัน',
        isLocked: true,
        requiredStars: 3,
        category: 'Streak',
        tier: 'Bronze',
        gradientColors: [Color(0xFFFF8E53), Color(0xFFFF6B6B)],
      ),
      Badge(
        id: 'streak_7',
        name: 'Week Warrior',
        titleTh: 'นักรบสัปดาห์',
        icon: 'assets/images/badges/streak_7.png',
        description: '7 day learning streak',
        descriptionTh: 'รักษาสถิติการเรียนต่อเนื่อง 7 วัน',
        isLocked: true,
        requiredStars: 7,
        category: 'Streak',
        tier: 'Silver',
        gradientColors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
      ),
      Badge(
        id: 'words_10',
        name: 'Starlight Seeker',
        titleTh: 'ผู้ตามหาแสงดาว',
        icon: 'assets/images/badges/words_10.png',
        description: 'Collected 10 stars',
        descriptionTh: 'สะสมคำศัพท์ครบ 10 คำ',
        isLocked: true,
        requiredStars: 10,
        category: 'Stars',
        tier: 'Bronze',
        gradientColors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
      ),
      Badge(
        id: 'streak_14',
        name: 'Orbit Pioneer',
        titleTh: 'ผู้บุกเบิกวงโคจร',
        icon: 'assets/images/badges/streak_14.png',
        description: '14 day learning streak',
        descriptionTh: 'รักษาสถิติการเรียนต่อเนื่อง 14 วัน',
        isLocked: true,
        requiredStars: 14,
        category: 'Streak',
        tier: 'Silver',
        gradientColors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
      ),
      Badge(
        id: 'perfect_review',
        name: 'Perfect Score',
        titleTh: 'ทบทวนสมบูรณ์แบบ',
        icon: 'assets/images/badges/perfect_review.png',
        description: 'Perfect review session',
        descriptionTh: 'ทบทวนคำศัพท์ได้คะแนนเต็ม',
        isLocked: true,
        requiredStars: 20,
        category: 'Special',
        tier: 'Gold',
        gradientColors: [Color(0xFFF59E0B), Color(0xFFFFD700)],
      ),
      Badge(
        id: 'streak_30',
        name: 'Month Master',
        titleTh: 'จ้าวแห่งเดือน',
        icon: 'assets/images/badges/streak_30.png',
        description: '30 day learning streak',
        descriptionTh: 'รักษาสถิติการเรียนต่อเนื่อง 30 วัน',
        isLocked: true,
        requiredStars: 30,
        category: 'Streak',
        tier: 'Gold',
        gradientColors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
      ),
      Badge(
        id: 'words_50',
        name: 'Galaxy Explorer',
        titleTh: 'นักสำรวจกาแล็กซี',
        icon: 'assets/images/badges/words_50.png',
        description: 'Collected 50 stars',
        descriptionTh: 'สะสมคำศัพท์ครบ 50 คำ',
        isLocked: true,
        requiredStars: 50,
        category: 'Stars',
        tier: 'Silver',
        gradientColors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
      ),
      Badge(
        id: 'streak_60',
        name: 'Deep Space Habit',
        titleTh: 'นิสัยห้วงอวกาศลึก',
        icon: 'assets/images/badges/streak_60.png',
        description: '60 day learning streak',
        descriptionTh: 'รักษาสถิติการเรียนต่อเนื่อง 60 วัน',
        isLocked: true,
        requiredStars: 60,
        category: 'Streak',
        tier: 'Gold',
        gradientColors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
      ),
      Badge(
        id: 'words_100',
        name: 'Star Collector',
        titleTh: 'นักสะสมดวงดาว',
        icon: 'assets/images/badges/words_100.png',
        description: 'Collected 100 stars',
        descriptionTh: 'สะสมคำศัพท์ครบ 100 คำ',
        isLocked: true,
        requiredStars: 100,
        category: 'Stars',
        tier: 'Gold',
        gradientColors: [Color(0xFFFFD700), Color(0xFFF59E0B)],
      ),
      Badge(
        id: 'streak_100',
        name: 'Century Voyager',
        titleTh: 'นักท่องร้อยวัน',
        icon: 'assets/images/badges/streak_100.png',
        description: '100 day learning streak',
        descriptionTh: 'รักษาสถิติการเรียนต่อเนื่อง 100 วัน',
        isLocked: true,
        requiredStars: 100,
        category: 'Streak',
        tier: 'Nebula',
        gradientColors: [Color(0xFF7C3AED), Color(0xFFC084FC)],
      ),
      Badge(
        id: 'words_250',
        name: 'Constellation King',
        titleTh: 'ราชันแห่งกลุ่มดาว',
        icon: 'assets/images/badges/words_250.png',
        description: 'Collected 250 stars',
        descriptionTh: 'สะสมคำศัพท์ครบ 250 คำ',
        isLocked: true,
        requiredStars: 250,
        category: 'Stars',
        tier: 'Nebula',
        gradientColors: [Color(0xFF312E81), Color(0xFF7C3AED)],
      ),
      Badge(
        id: 'words_500',
        name: 'Cosmic Legend',
        titleTh: 'ตำนานคอสมิก',
        icon: 'assets/images/badges/words_500.png',
        description: 'Collected 500 stars',
        descriptionTh: 'สะสมคำศัพท์ครบ 500 คำ',
        isLocked: true,
        requiredStars: 500,
        category: 'Stars',
        tier: 'Nebula',
        gradientColors: [Color(0xFF1E1B4B), Color(0xFF7C3AED), Color(0xFF06B6D4)],
      ),

      // 🌙 Night Owl: Active late night 22:00 - 04:00 (30 times)
      Badge(
        id: 'night_owl',
        name: 'Night Owl',
        titleTh: 'นกฮูกราตรี',
        icon: '🦉',
        description: 'Active learning late at night (22:00 - 04:00) 30 times',
        descriptionTh: 'เรียนรู้คำศัพท์หรือทบทวนรอบดึก (22:00 - 04:00) ครบ 30 ครั้ง',
        isLocked: true,
        requiredStars: 30,
        category: 'Special',
        tier: 'Silver',
        gradientColors: [Color(0xFF6B21A8), Color(0xFF3B82F6)],
      ),

      // 🪐 Lord of the Dark Nebula: Active late night 22:00 - 04:00 (50 times)
      Badge(
        id: 'lord_of_dark_nebula',
        name: 'Lord of the Dark Nebula',
        titleTh: 'เจ้าแห่งเนบิวลารามืด',
        icon: '🪐',
        description: 'Active learning late at night (22:00 - 04:00) 50 times',
        descriptionTh: 'เรียนรู้คำศัพท์หรือทบทวนรอบดึก (22:00 - 04:00) ครบ 50 ครั้ง',
        isLocked: true,
        requiredStars: 50,
        category: 'Special',
        tier: 'Nebula',
        gradientColors: [Color(0xFF312E81), Color(0xFF7C3AED), Color(0xFF06B6D4)],
      ),

      // 🌅 Morning Nova: Active early morning 05:00 - 08:00 (30 times)
      Badge(
        id: 'morning_nova',
        name: 'Morning Nova',
        titleTh: 'ซูเปอร์โนวารุ่งสาง',
        icon: '🌅',
        description: 'Active learning early morning (05:00 - 08:00) 30 times',
        descriptionTh: 'เรียนรู้คำศัพท์หรือทบทวนยามเช้าตรู่ (05:00 - 08:00) ครบ 30 ครั้ง',
        isLocked: true,
        requiredStars: 30,
        category: 'Special',
        tier: 'Silver',
        gradientColors: [Color(0xFFFF7A00), Color(0xFFFFB800)],
      ),

      // ☀️ Solar Pioneer: Active early morning 05:00 - 08:00 (50 times)
      Badge(
        id: 'solar_pioneer',
        name: 'Solar Pioneer',
        titleTh: 'ผู้บุกเบิกแสงตะวัน',
        icon: '☀️',
        description: 'Active learning early morning (05:00 - 08:00) 50 times',
        descriptionTh: 'เรียนรู้คำศัพท์หรือทบทวนยามเช้าตรู่ (05:00 - 08:00) ครบ 50 ครั้ง',
        isLocked: true,
        requiredStars: 50,
        category: 'Special',
        tier: 'Gold',
        gradientColors: [Color(0xFFEA580C), Color(0xFFF59E0B), Color(0xFFFEF08A)],
      ),

      // 🛡️ Iron Shield: Protect streak with Streak Shield 3 times
      Badge(
        id: 'iron_shield',
        name: 'Iron Shield',
        titleTh: 'โล่เหล็กพิทักษ์สตรีค',
        icon: '🛡️',
        description: 'Saved your streak with Streak Shield 3 times',
        descriptionTh: 'ใช้ Streak Shield ป้องกันสตรีคไม่ให้แตกสำเร็จ 3 ครั้ง',
        isLocked: true,
        requiredStars: 3,
        category: 'Special',
        tier: 'Silver',
        gradientColors: [Color(0xFF0284C7), Color(0xFF06B6D4), Color(0xFF38BDF8)],
      ),
    ];

    state = state.copyWith(
      badges: badges,
      unlockedCount: badges.where((b) => !b.isLocked).length,
    );
  }

  /// Record activity (vocabulary generation or review) and evaluate time-based badges
  Future<List<Badge>> recordActivity(
    ActivityType type, {
    BuildContext? context,
  }) async {
    final user = _ref.read(userStateProvider).user;
    if (user == null) return [];

    final now = DateTime.now();
    final hour = now.hour;

    bool isNightOwl = (hour >= 22 || hour < 4);
    bool isEarlyBird = (hour >= 5 && hour < 8);

    var newStats = state.stats;

    if (type == ActivityType.generateVocab) {
      newStats = newStats.copyWith(totalGenCount: newStats.totalGenCount + 1);
    } else if (type == ActivityType.review) {
      newStats = newStats.copyWith(totalReviewCount: newStats.totalReviewCount + 1);
    }

    if (isNightOwl) {
      newStats = newStats.copyWith(nightOwlCount: newStats.nightOwlCount + 1);
    } else if (isEarlyBird) {
      newStats = newStats.copyWith(earlyBirdCount: newStats.earlyBirdCount + 1);
    }

    return await _saveStatsAndCheckBadges(newStats, context: context);
  }

  /// Record when a streak shield is successfully used to save streak
  Future<List<Badge>> recordShieldUsed({BuildContext? context}) async {
    final user = _ref.read(userStateProvider).user;
    if (user == null) return [];

    final newStats = state.stats.copyWith(
      shieldSavedCount: state.stats.shieldSavedCount + 1,
    );

    return await _saveStatsAndCheckBadges(newStats, context: context);
  }

  Future<List<Badge>> _saveStatsAndCheckBadges(
    BadgeStats newStats, {
    BuildContext? context,
  }) async {
    final user = _ref.read(userStateProvider).user;
    if (user == null) return [];

    final currentBadges = Set<String>.from(user.badges);
    final newlyUnlocked = <Badge>[];

    // 1. Night Owl (>= 30)
    if (newStats.nightOwlCount >= 30 && !currentBadges.contains('night_owl')) {
      final b = _findBadge('night_owl');
      if (b != null) {
        newlyUnlocked.add(b);
        currentBadges.add(b.id);
      }
    }

    // 2. Lord of the Dark Nebula (>= 50)
    if (newStats.nightOwlCount >= 50 && !currentBadges.contains('lord_of_dark_nebula')) {
      final b = _findBadge('lord_of_dark_nebula');
      if (b != null) {
        newlyUnlocked.add(b);
        currentBadges.add(b.id);
      }
    }

    // 3. Morning Nova (>= 30)
    if (newStats.earlyBirdCount >= 30 && !currentBadges.contains('morning_nova')) {
      final b = _findBadge('morning_nova');
      if (b != null) {
        newlyUnlocked.add(b);
        currentBadges.add(b.id);
      }
    }

    // 4. Solar Pioneer (>= 50)
    if (newStats.earlyBirdCount >= 50 && !currentBadges.contains('solar_pioneer')) {
      final b = _findBadge('solar_pioneer');
      if (b != null) {
        newlyUnlocked.add(b);
        currentBadges.add(b.id);
      }
    }

    // 5. Iron Shield (>= 3)
    if (newStats.shieldSavedCount >= 3 && !currentBadges.contains('iron_shield')) {
      final b = _findBadge('iron_shield');
      if (b != null) {
        newlyUnlocked.add(b);
        currentBadges.add(b.id);
      }
    }

    // Save to UserModel (SSOT)
    final updatedPrefs = Map<String, dynamic>.from(user.preferences);
    updatedPrefs['badge_stats'] = newStats.toMap();

    final updatedUser = user.copyWith(
      badges: currentBadges.toList(),
      preferences: updatedPrefs,
    );

    await _ref.read(userStateProvider.notifier).updateUser(updatedUser);

    final updatedBadges = state.badges.map((badge) {
      if (currentBadges.contains(badge.id) && badge.isLocked) {
        return Badge(
          id: badge.id,
          name: badge.name,
          titleTh: badge.titleTh,
          icon: badge.icon,
          description: badge.description,
          descriptionTh: badge.descriptionTh,
          isLocked: false,
          requiredStars: badge.requiredStars,
          category: badge.category,
          tier: badge.tier,
          gradientColors: badge.gradientColors,
        );
      }
      return badge;
    }).toList();

    state = state.copyWith(
      badges: updatedBadges,
      unlockedCount: updatedBadges.where((b) => !b.isLocked).length,
      stats: newStats,
      latestUnlockedBadge: newlyUnlocked.isNotEmpty ? newlyUnlocked.last : state.latestUnlockedBadge,
    );

    if (newlyUnlocked.isNotEmpty && context != null && context.mounted) {
      for (final badge in newlyUnlocked) {
        await BadgeUnlockDialog.show(context, badge: badge);
      }
    }

    return newlyUnlocked;
  }

  Badge? _findBadge(String id) {
    try {
      return state.badges.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  void unlockBadge(String badgeId, {BuildContext? context}) {
    final updatedBadges = state.badges.map((badge) {
      if (badge.id == badgeId) {
        final unlocked = Badge(
          id: badge.id,
          name: badge.name,
          titleTh: badge.titleTh,
          icon: badge.icon,
          description: badge.description,
          descriptionTh: badge.descriptionTh,
          isLocked: false,
          requiredStars: badge.requiredStars,
          category: badge.category,
          tier: badge.tier,
          gradientColors: badge.gradientColors,
        );
        if (context != null && context.mounted) {
          BadgeUnlockDialog.show(context, badge: unlocked);
        }
        return unlocked;
      }
      return badge;
    }).toList();

    state = state.copyWith(
      badges: updatedBadges,
      unlockedCount: updatedBadges.where((b) => !b.isLocked).length,
    );
  }

  Future<List<Badge>> checkAndUnlockBadges(
    int totalStars,
    int streakDays, {
    BuildContext? context,
  }) async {
    final user = _ref.read(userStateProvider).user;
    final currentBadges = user != null
        ? Set<String>.from(user.badges)
        : state.badges.where((b) => !b.isLocked).map((b) => b.id).toSet();

    final newlyUnlocked = <Badge>[];

    for (var badge in state.badges) {
      if (!badge.isLocked || currentBadges.contains(badge.id)) continue;

      bool shouldUnlock = false;

      // Word / Star Milestone badges
      if (badge.category == 'Stars' && totalStars >= badge.requiredStars) {
        shouldUnlock = true;
      }

      // Streak Milestone badges
      if (badge.category == 'Streak' && streakDays >= badge.requiredStars) {
        shouldUnlock = true;
      }

      if (shouldUnlock) {
        final unlocked = Badge(
          id: badge.id,
          name: badge.name,
          titleTh: badge.titleTh,
          icon: badge.icon,
          description: badge.description,
          descriptionTh: badge.descriptionTh,
          isLocked: false,
          requiredStars: badge.requiredStars,
          category: badge.category,
          tier: badge.tier,
          gradientColors: badge.gradientColors,
        );
        newlyUnlocked.add(unlocked);
        currentBadges.add(badge.id);
      }
    }

    if (newlyUnlocked.isEmpty) return [];

    // Save to UserModel (SSOT)
    if (user != null) {
      final updatedUser = user.copyWith(
        badges: currentBadges.toList(),
      );
      await _ref.read(userStateProvider.notifier).updateUser(updatedUser);
    }

    final updatedBadges = state.badges.map((badge) {
      if (currentBadges.contains(badge.id)) {
        return badge.isLocked
            ? Badge(
                id: badge.id,
                name: badge.name,
                titleTh: badge.titleTh,
                icon: badge.icon,
                description: badge.description,
                descriptionTh: badge.descriptionTh,
                isLocked: false,
                requiredStars: badge.requiredStars,
                category: badge.category,
                tier: badge.tier,
                gradientColors: badge.gradientColors,
              )
            : badge;
      }
      return badge;
    }).toList();

    state = state.copyWith(
      badges: updatedBadges,
      unlockedCount: updatedBadges.where((b) => !b.isLocked).length,
      latestUnlockedBadge: newlyUnlocked.last,
    );

    if (context != null && context.mounted) {
      for (final badge in newlyUnlocked) {
        await BadgeUnlockDialog.show(context, badge: badge);
      }
    }

    return newlyUnlocked;
  }
}

/// Provider for badge state and controller
final badgeStateProvider = StateNotifierProvider<BadgeController, BadgeState>((ref) {
  return BadgeController(ref);
});

/// Alias provider for convenience
final badgeProvider = badgeStateProvider;
