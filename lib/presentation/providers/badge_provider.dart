import 'package:flutter_riverpod/flutter_riverpod.dart';

// Badge model
class Badge {
  final String id;
  final String name;
  final String icon;
  final String description;
  final bool isLocked;
  final int requiredStars;
  final String category; // 'Stars', 'Streak', 'Special'

  Badge({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    this.isLocked = true,
    required this.requiredStars,
    this.category = 'Stars',
  });
}

// Upcoming Badge Info for progress display
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

// Badge state
class BadgeState {
  final List<Badge> badges;
  final int unlockedCount;

  BadgeState({
    required this.badges,
    required this.unlockedCount,
  });

  factory BadgeState.initial() {
    return BadgeState(
      badges: [],
      unlockedCount: 0,
    );
  }

  BadgeState copyWith({
    List<Badge>? badges,
    int? unlockedCount,
  }) {
    return BadgeState(
      badges: badges ?? this.badges,
      unlockedCount: unlockedCount ?? this.unlockedCount,
    );
  }

  /// Calculates the next closest badge to unlock based on user stars and streak
  UpcomingBadgeInfo? getNextUpcomingBadge(int totalStars, int streakDays) {
    final lockedBadges = badges.where((b) => b.isLocked).toList();
    if (lockedBadges.isEmpty) return null;

    UpcomingBadgeInfo? closest;
    double maxRatio = -1.0;
    int minRemaining = 999999;

    for (final badge in lockedBadges) {
      final isStreak = badge.category == 'Streak';
      final current = isStreak ? streakDays : totalStars;
      final target = badge.requiredStars;
      final ratio = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
      final remaining = (target - current).clamp(0, 999999);

      // Prioritize badge with highest percentage progress, or smallest remaining count
      if (ratio > maxRatio || (ratio == maxRatio && remaining < minRemaining)) {
        maxRatio = ratio;
        minRemaining = remaining;
        closest = UpcomingBadgeInfo(
          badge: badge,
          currentProgress: current,
          targetProgress: target,
          progressPercentage: ratio,
          progressLabel: isStreak
              ? '$current / $target Days'
              : '$current / $target Stars',
        );
      }
    }

    return closest;
  }
}

// Badge controller
class BadgeController extends StateNotifier<BadgeState> {
  BadgeController() : super(BadgeState.initial()) {
    _initializeBadges();
  }

  void _initializeBadges() {
    final badges = [
      Badge(
        id: 'first_word',
        name: 'First Star',
        icon: 'assets/images/badges/first_word.png',
        description: 'Learned your first word',
        isLocked: false,
        requiredStars: 1,
        category: 'Stars',
      ),
      Badge(
        id: 'streak_3',
        name: 'First Spark',
        icon: 'assets/images/badges/streak_3.png',
        description: '3 day learning streak',
        isLocked: true,
        requiredStars: 3,
        category: 'Streak',
      ),
      Badge(
        id: 'streak_7',
        name: 'Week Warrior',
        icon: 'assets/images/badges/streak_7.png',
        description: '7 day learning streak',
        isLocked: false,
        requiredStars: 7,
        category: 'Streak',
      ),
      Badge(
        id: 'words_10',
        name: 'Starlight Seeker',
        icon: 'assets/images/badges/words_10.png',
        description: 'Collected 10 stars',
        isLocked: true,
        requiredStars: 10,
        category: 'Stars',
      ),
      Badge(
        id: 'streak_14',
        name: 'Orbit Pioneer',
        icon: 'assets/images/badges/streak_14.png',
        description: '14 day learning streak',
        isLocked: true,
        requiredStars: 14,
        category: 'Streak',
      ),
      Badge(
        id: 'perfect_review',
        name: 'Perfect Score',
        icon: 'assets/images/badges/perfect_review.png',
        description: 'Perfect review session',
        isLocked: true,
        requiredStars: 20,
        category: 'Special',
      ),
      Badge(
        id: 'streak_30',
        name: 'Month Master',
        icon: 'assets/images/badges/streak_30.png',
        description: '30 day learning streak',
        isLocked: true,
        requiredStars: 30,
        category: 'Streak',
      ),
      Badge(
        id: 'words_50',
        name: 'Galaxy Explorer',
        icon: 'assets/images/badges/words_50.png',
        description: 'Collected 50 stars',
        isLocked: true,
        requiredStars: 50,
        category: 'Stars',
      ),
      Badge(
        id: 'streak_60',
        name: 'Deep Space Habit',
        icon: 'assets/images/badges/streak_60.png',
        description: '60 day learning streak',
        isLocked: true,
        requiredStars: 60,
        category: 'Streak',
      ),
      Badge(
        id: 'words_100',
        name: 'Star Collector',
        icon: 'assets/images/badges/words_100.png',
        description: 'Collected 100 stars',
        isLocked: true,
        requiredStars: 100,
        category: 'Stars',
      ),
      Badge(
        id: 'streak_100',
        name: 'Century Voyager',
        icon: 'assets/images/badges/streak_100.png',
        description: '100 day learning streak',
        isLocked: true,
        requiredStars: 100,
        category: 'Streak',
      ),
      Badge(
        id: 'words_250',
        name: 'Constellation King',
        icon: 'assets/images/badges/words_250.png',
        description: 'Collected 250 stars',
        isLocked: true,
        requiredStars: 250,
        category: 'Stars',
      ),
      Badge(
        id: 'words_500',
        name: 'Cosmic Legend',
        icon: 'assets/images/badges/words_500.png',
        description: 'Collected 500 stars',
        isLocked: true,
        requiredStars: 500,
        category: 'Stars',
      ),
    ];

    state = state.copyWith(
      badges: badges,
      unlockedCount: badges.where((b) => !b.isLocked).length,
    );
  }

  void unlockBadge(String badgeId) {
    final updatedBadges = state.badges.map((badge) {
      if (badge.id == badgeId) {
        return Badge(
          id: badge.id,
          name: badge.name,
          icon: badge.icon,
          description: badge.description,
          isLocked: false,
          requiredStars: badge.requiredStars,
          category: badge.category,
        );
      }
      return badge;
    }).toList();

    state = state.copyWith(
      badges: updatedBadges,
      unlockedCount: updatedBadges.where((b) => !b.isLocked).length,
    );
  }

  void checkAndUnlockBadges(int totalStars, int streakDays) {
    for (var badge in state.badges) {
      if (!badge.isLocked) continue;

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
        unlockBadge(badge.id);
      }
    }
  }
}

// Provider
final badgeStateProvider = StateNotifierProvider<BadgeController, BadgeState>((ref) {
  return BadgeController();
});
