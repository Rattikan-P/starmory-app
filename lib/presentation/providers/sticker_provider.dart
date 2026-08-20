import 'package:flutter_riverpod/flutter_riverpod.dart';

// Sticker model
class Sticker {
  final String id;
  final String name;
  final String icon;
  final String description;
  final bool isLocked;
  final int requiredStars;
  final String packName;

  Sticker({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    this.isLocked = true,
    required this.requiredStars,
    this.packName = 'Daily',
  });
}

// Sticker state
class StickerState {
  final List<Sticker> stickers;
  final int unlockedCount;

  StickerState({
    required this.stickers,
    required this.unlockedCount,
  });

  factory StickerState.initial() {
    return StickerState(
      stickers: [],
      unlockedCount: 0,
    );
  }

  /// Get distinct pack names
  List<String> get availablePacks {
    final packs = stickers.map((s) => s.packName).toSet().toList();
    packs.sort();
    return ['All', ...packs];
  }

  StickerState copyWith({
    List<Sticker>? stickers,
    int? unlockedCount,
  }) {
    return StickerState(
      stickers: stickers ?? this.stickers,
      unlockedCount: unlockedCount ?? this.unlockedCount,
    );
  }
}

// Sticker controller
class StickerController extends StateNotifier<StickerState> {
  StickerController() : super(StickerState.initial()) {
    _initializeStickers();
  }

  void _initializeStickers() {
    final stickers = [
      Sticker(
        id: 'happy_face',
        name: 'Happy',
        icon: '😊',
        description: 'Keep smiling while learning!',
        isLocked: false,
        requiredStars: 5,
        packName: 'Daily',
      ),
      Sticker(
        id: 'rocket',
        name: 'Rocket',
        icon: '🚀',
        description: 'Blast off to learning success!',
        isLocked: false,
        requiredStars: 10,
        packName: 'Space',
      ),
      Sticker(
        id: 'ufo',
        name: 'UFO',
        icon: '🛸',
        description: 'Exploring unknown vocabulary!',
        isLocked: true,
        requiredStars: 15,
        packName: 'Space',
      ),
      Sticker(
        id: 'star_struck',
        name: 'Star Struck',
        icon: '🤩',
        description: 'Amazing progress!',
        isLocked: true,
        requiredStars: 25,
        packName: 'Daily',
      ),
      Sticker(
        id: 'saturn',
        name: 'Saturn',
        icon: '🪐',
        description: 'Ring of knowledge!',
        isLocked: true,
        requiredStars: 35,
        packName: 'Space',
      ),
      Sticker(
        id: 'rainbow',
        name: 'Rainbow',
        icon: '🌈',
        description: 'Colorful vocabulary journey!',
        isLocked: true,
        requiredStars: 50,
        packName: 'Daily',
      ),
      Sticker(
        id: 'comet',
        name: 'Comet',
        icon: '☄️',
        description: 'Blazing through words fast!',
        isLocked: true,
        requiredStars: 60,
        packName: 'Space',
      ),
      Sticker(
        id: 'sparkles',
        name: 'Sparkles',
        icon: '✨',
        description: 'Shining bright!',
        isLocked: true,
        requiredStars: 75,
        packName: 'Daily',
      ),
      Sticker(
        id: 'astronaut',
        name: 'Astronaut',
        icon: '👨‍🚀',
        description: 'Cosmic language explorer!',
        isLocked: true,
        requiredStars: 90,
        packName: 'Space',
      ),
      Sticker(
        id: 'trophy',
        name: 'Trophy',
        icon: '🏆',
        description: 'Champion learner!',
        isLocked: true,
        requiredStars: 100,
        packName: 'Legend',
      ),
      Sticker(
        id: 'nebula',
        name: 'Nebula',
        icon: '🌌',
        description: 'Deep cosmic vocabulary master!',
        isLocked: true,
        requiredStars: 150,
        packName: 'Space',
      ),
      Sticker(
        id: 'crystal',
        name: 'Crystal',
        icon: '💎',
        description: 'Pure crystal-clear memory!',
        isLocked: true,
        requiredStars: 200,
        packName: 'Legend',
      ),
      Sticker(
        id: 'crown',
        name: 'Crown',
        icon: '👑',
        description: 'Ruler of the Starmory galaxy!',
        isLocked: true,
        requiredStars: 250,
        packName: 'Legend',
      ),
    ];

    state = state.copyWith(
      stickers: stickers,
      unlockedCount: stickers.where((s) => !s.isLocked).length,
    );
  }

  void unlockSticker(String stickerId) {
    final updatedStickers = state.stickers.map((sticker) {
      if (sticker.id == stickerId) {
        return Sticker(
          id: sticker.id,
          name: sticker.name,
          icon: sticker.icon,
          description: sticker.description,
          isLocked: false,
          requiredStars: sticker.requiredStars,
          packName: sticker.packName,
        );
      }
      return sticker;
    }).toList();

    state = state.copyWith(
      stickers: updatedStickers,
      unlockedCount: updatedStickers.where((s) => !s.isLocked).length,
    );
  }

  void checkAndUnlockStickers(int totalStars) {
    for (var sticker in state.stickers) {
      if (!sticker.isLocked) continue;

      if (totalStars >= sticker.requiredStars) {
        unlockSticker(sticker.id);
      }
    }
  }
}

// Provider
final stickerStateProvider = StateNotifierProvider<StickerController, StickerState>((ref) {
  return StickerController();
});
