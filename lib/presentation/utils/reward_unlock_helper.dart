import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../providers/badge_provider.dart';
import '../providers/sticker_provider.dart';

/// Helper utility for evaluating and displaying reward unlock animations
class RewardUnlockHelper {
  /// Check all badges and sticker packs against user milestones (stars, streak, activity),
  /// persist unlocked rewards to UserModel, and display animated congratulatory dialogs.
  static Future<void> checkAndShowUnlocks(
    BuildContext context,
    WidgetRef ref, {
    int additionalWords = 0,
    int additionalNatureWords = 0,
  }) async {
    if (!context.mounted) return;

    final allVocabularies = ref.read(vocabularyStateProvider).vocabularies;
    final streakState = ref.read(streakProvider);
    final totalStars = allVocabularies.length + additionalWords;
    final streakDays = streakState?.currentStreak ?? 0;
    final natureVocabCount = allVocabularies
            .where((v) => v.topic.toLowerCase() == 'nature')
            .length +
        additionalNatureWords;

    // 1. Check and display unlocked badges
    await ref.read(badgeStateProvider.notifier).checkAndUnlockBadges(
          totalStars,
          streakDays,
          context: context,
        );

    if (!context.mounted) return;

    // 2. Check and display unlocked sticker packs
    await ref.read(stickerStateProvider.notifier).checkAndUnlockPacks(
          totalStars: totalStars,
          streakDays: streakDays,
          natureVocabCount: natureVocabCount,
          context: context,
        );
  }
}
