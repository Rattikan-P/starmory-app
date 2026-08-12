import 'package:flutter_riverpod/flutter_riverpod.dart';

// Badge model
class Badge {
  final String id;
  final String name;
  final String icon;
  final String description;
  final bool isLocked;
  final int requiredStars;

  Badge({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    this.isLocked = true,
    required this.requiredStars,
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
}

// Badge controller
class BadgeController extends StateNotifier<BadgeState> {
  BadgeController() : super(BadgeState.initial()) {
    _initializeBadges();
  }

  void _initializeBadges() {
    // Mock badges - will be replaced with real data later
    final badges = [
      Badge(
        id: 'first_word',
        name: 'First Star',
        icon: '⭐',
        description: 'Learned your first word',
        isLocked: false,
        requiredStars: 1,
      ),
      Badge(
        id: 'streak_7',
        name: 'Week Warrior',
        icon: '🔥',
        description: '7 day learning streak',
        isLocked: false,
        requiredStars: 7,
      ),
      Badge(
        id: 'words_50',
        name: 'Galaxy Explorer',
        icon: '🌌',
        description: 'Collected 50 stars',
        isLocked: true,
        requiredStars: 50,
      ),
      Badge(
        id: 'streak_30',
        name: 'Month Master',
        icon: '🏆',
        description: '30 day learning streak',
        isLocked: true,
        requiredStars: 30,
      ),
      Badge(
        id: 'words_100',
        name: 'Star Collector',
        icon: '💫',
        description: 'Collected 100 stars',
        isLocked: true,
        requiredStars: 100,
      ),
      Badge(
        id: 'perfect_review',
        name: 'Perfect Score',
        icon: '🎯',
        description: 'Perfect review session',
        isLocked: true,
        requiredStars: 20,
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
      if (badge.id == 'words_50' && totalStars >= 50) shouldUnlock = true;
      if (badge.id == 'streak_30' && streakDays >= 30) shouldUnlock = true;
      if (badge.id == 'words_100' && totalStars >= 100) shouldUnlock = true;

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
