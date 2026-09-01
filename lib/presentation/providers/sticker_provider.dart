import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/sticker_sets.dart';
import '../widgets/sticker_pack_unlock_dialog.dart';
import 'providers.dart';

/// Upcoming Sticker Pack Info for progress display
class UpcomingStickerPackInfo {
  final StickerSet pack;
  final int currentProgress;
  final int targetProgress;
  final double progressPercentage;
  final String progressLabel;

  const UpcomingStickerPackInfo({
    required this.pack,
    required this.currentProgress,
    required this.targetProgress,
    required this.progressPercentage,
    required this.progressLabel,
  });
}

/// Sticker state holding list of sticker packs and unlocked statistics
class StickerState {
  final List<StickerSet> packs;
  final int unlockedCount;
  final StickerSet? latestUnlockedPack;

  StickerState({
    required this.packs,
    required this.unlockedCount,
    this.latestUnlockedPack,
  });

  factory StickerState.initial() {
    return StickerState(
      packs: stickerSets,
      unlockedCount: stickerSets.where((p) => !p.isLocked).length,
    );
  }

  int get totalPacksCount => packs.length;

  /// Check if a specific pack is unlocked
  bool isPackUnlocked(String packId) {
    try {
      final pack = packs.firstWhere((p) => p.id == packId);
      return !pack.isLocked;
    } catch (_) {
      return false;
    }
  }

  /// Get current progress value for a pack
  int getProgress(
    StickerSet pack, {
    int totalStars = 0,
    int streakDays = 0,
    int natureVocabCount = 0,
  }) {
    switch (pack.unlockType) {
      case StickerUnlockType.free:
        return 1;
      case StickerUnlockType.streak:
        return streakDays;
      case StickerUnlockType.category:
        if (pack.requiredCategory?.toLowerCase() == 'nature') {
          return natureVocabCount;
        }
        return 0;
      case StickerUnlockType.stars:
        return totalStars;
    }
  }

  /// Get target value for a pack
  int getTarget(StickerSet pack) {
    switch (pack.unlockType) {
      case StickerUnlockType.free:
        return 1;
      case StickerUnlockType.streak:
        return pack.requiredStreakDays ?? 0;
      case StickerUnlockType.category:
        return pack.requiredCategoryCount ?? 0;
      case StickerUnlockType.stars:
        return pack.requiredStars ?? 0;
    }
  }

  /// Get progress ratio between 0.0 and 1.0
  double getProgressRatio(
    StickerSet pack, {
    int totalStars = 0,
    int streakDays = 0,
    int natureVocabCount = 0,
  }) {
    if (!pack.isLocked) return 1.0;
    final target = getTarget(pack);
    if (target <= 0) return 1.0;
    final current = getProgress(
      pack,
      totalStars: totalStars,
      streakDays: streakDays,
      natureVocabCount: natureVocabCount,
    );
    return (current / target).clamp(0.0, 1.0);
  }

  /// Get human-readable progress label
  String getProgressLabel(
    StickerSet pack, {
    int totalStars = 0,
    int streakDays = 0,
    int natureVocabCount = 0,
  }) {
    if (!pack.isLocked) return 'Unlocked';

    final current = getProgress(
      pack,
      totalStars: totalStars,
      streakDays: streakDays,
      natureVocabCount: natureVocabCount,
    );
    final target = getTarget(pack);

    switch (pack.unlockType) {
      case StickerUnlockType.free:
        return 'Free';
      case StickerUnlockType.streak:
        return '$current / $target Days';
      case StickerUnlockType.category:
        if (pack.requiredCategory?.toLowerCase() == 'nature') {
          return '$current / $target Nature words';
        }
        return '$current / $target words';
      case StickerUnlockType.stars:
        return '$current / $target Stars';
    }
  }

  StickerState copyWith({
    List<StickerSet>? packs,
    int? unlockedCount,
    StickerSet? latestUnlockedPack,
  }) {
    return StickerState(
      packs: packs ?? this.packs,
      unlockedCount: unlockedCount ?? this.unlockedCount,
      latestUnlockedPack: latestUnlockedPack ?? this.latestUnlockedPack,
    );
  }
}

/// Controller managing Sticker Sets, unlocks, and sync with UserModel
class StickerController extends StateNotifier<StickerState> {
  final Ref _ref;

  StickerController(this._ref) : super(StickerState.initial()) {
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
    final userStickers = Set<String>.from(user.stickers);
    userStickers.add('doodle'); // Doodle is always free and unlocked

    final updatedPacks = state.packs.map((pack) {
      final shouldBeUnlocked = userStickers.contains(pack.id) || pack.unlockType == StickerUnlockType.free;
      return pack.copyWith(isLocked: !shouldBeUnlocked);
    }).toList();

    state = state.copyWith(
      packs: updatedPacks,
      unlockedCount: updatedPacks.where((p) => !p.isLocked).length,
    );
  }

  /// Check all locked packs and unlock if user meets criteria
  Future<List<StickerSet>> checkAndUnlockPacks({
    required int totalStars,
    required int streakDays,
    required int natureVocabCount,
    BuildContext? context,
  }) async {
    final user = _ref.read(userStateProvider).user;
    if (user == null) return [];

    final currentUnlocked = Set<String>.from(user.stickers);
    currentUnlocked.add('doodle');

    final newlyUnlocked = <StickerSet>[];

    for (final pack in state.packs) {
      if (!pack.isLocked || currentUnlocked.contains(pack.id)) continue;

      bool meetsCriteria = false;

      switch (pack.unlockType) {
        case StickerUnlockType.free:
          meetsCriteria = true;
          break;
        case StickerUnlockType.streak:
          final reqStreak = pack.requiredStreakDays ?? 0;
          if (reqStreak > 0 && streakDays >= reqStreak) {
            meetsCriteria = true;
          }
          break;
        case StickerUnlockType.category:
          if (pack.requiredCategory?.toLowerCase() == 'nature') {
            final reqCount = pack.requiredCategoryCount ?? 0;
            if (reqCount > 0 && natureVocabCount >= reqCount) {
              meetsCriteria = true;
            }
          }
          break;
        case StickerUnlockType.stars:
          final reqStars = pack.requiredStars ?? 0;
          if (reqStars > 0 && totalStars >= reqStars) {
            meetsCriteria = true;
          }
          break;
      }

      if (meetsCriteria) {
        newlyUnlocked.add(pack.copyWith(isLocked: false));
        currentUnlocked.add(pack.id);
      }
    }

    if (newlyUnlocked.isEmpty) return [];

    // Save to UserModel (SSOT)
    final updatedUser = user.copyWith(
      stickers: currentUnlocked.toList(),
    );
    await _ref.read(userStateProvider.notifier).updateUser(updatedUser);

    // Update local state
    final updatedPacks = state.packs.map((pack) {
      if (currentUnlocked.contains(pack.id)) {
        return pack.copyWith(isLocked: false);
      }
      return pack;
    }).toList();

    state = state.copyWith(
      packs: updatedPacks,
      unlockedCount: updatedPacks.where((p) => !p.isLocked).length,
      latestUnlockedPack: newlyUnlocked.last,
    );

    // Show celebration dialogs if context is mounted
    if (context != null && context.mounted) {
      for (final pack in newlyUnlocked) {
        await StickerPackUnlockDialog.show(context, stickerSet: pack);
      }
    }

    return newlyUnlocked;
  }

  /// Manually unlock a specific pack
  Future<void> unlockPack(String packId, {BuildContext? context}) async {
    final user = _ref.read(userStateProvider).user;
    if (user == null) return;

    final currentUnlocked = Set<String>.from(user.stickers);
    currentUnlocked.add(packId);

    final updatedUser = user.copyWith(stickers: currentUnlocked.toList());
    await _ref.read(userStateProvider.notifier).updateUser(updatedUser);

    final targetPack = state.packs.firstWhere((p) => p.id == packId);
    final unlockedPack = targetPack.copyWith(isLocked: false);

    if (context != null && context.mounted) {
      await StickerPackUnlockDialog.show(context, stickerSet: unlockedPack);
    }
  }
}

/// Provider for Sticker State and Controller
final stickerStateProvider = StateNotifierProvider<StickerController, StickerState>((ref) {
  return StickerController(ref);
});

/// Alias provider for convenience
final stickerProvider = stickerStateProvider;
