import 'package:flutter_riverpod/flutter_riverpod.dart';

// Sticker model
class Sticker {
  final String id;
  final String name;
  final String icon;
  final String description;
  final bool isLocked;
  final int requiredStars;

  Sticker({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    this.isLocked = true,
    required this.requiredStars,
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
    // Mock stickers - will be replaced with real data later
    final stickers = [
      Sticker(
        id: 'happy_face',
        name: 'Happy',
        icon: '😊',
        description: 'Keep smiling while learning!',
        isLocked: false,
        requiredStars: 5,
      ),
      Sticker(
        id: 'rocket',
        name: 'Rocket',
        icon: '🚀',
        description: 'Blast off to learning success!',
        isLocked: false,
        requiredStars: 10,
      ),
      Sticker(
        id: 'star_struck',
        name: 'Star Struck',
        icon: '🤩',
        description: 'Amazing progress!',
        isLocked: true,
        requiredStars: 25,
      ),
      Sticker(
        id: 'rainbow',
        name: 'Rainbow',
        icon: '🌈',
        description: 'Colorful vocabulary journey!',
        isLocked: true,
        requiredStars: 50,
      ),
      Sticker(
        id: 'sparkles',
        name: 'Sparkles',
        icon: '✨',
        description: 'Shining bright!',
        isLocked: true,
        requiredStars: 75,
      ),
      Sticker(
        id: 'trophy',
        name: 'Trophy',
        icon: '🏆',
        description: 'Champion learner!',
        isLocked: true,
        requiredStars: 100,
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
