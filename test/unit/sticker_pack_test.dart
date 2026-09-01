import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/data/sticker_sets.dart';
import 'package:starmory_app/data/models/user_model.dart';
import 'package:starmory_app/presentation/providers/sticker_provider.dart';

void main() {
  group('Sticker Sets & Pack Unlock Tests', () {
    test('Sticker Sets initial configuration is correct', () {
      expect(stickerSets.length, 3);

      final doodle = stickerSets.firstWhere((s) => s.id == 'doodle');
      expect(doodle.unlockType, StickerUnlockType.free);
      expect(doodle.count, 20);

      final flower = stickerSets.firstWhere((s) => s.id == 'flower');
      expect(flower.unlockType, StickerUnlockType.category);
      expect(flower.requiredCategory, 'nature');
      expect(flower.requiredCategoryCount, 100);
      expect(flower.count, 16);

      final space = stickerSets.firstWhere((s) => s.id == 'space');
      expect(space.unlockType, StickerUnlockType.streak);
      expect(space.requiredStreakDays, 7);
      expect(space.count, 16);
    });

    test('StickerState calculates progress correctly for each pack', () {
      final state = StickerState.initial();
      final doodle = state.packs.firstWhere((p) => p.id == 'doodle');
      final flower = state.packs.firstWhere((p) => p.id == 'flower');
      final space = state.packs.firstWhere((p) => p.id == 'space');

      // Doodle (Free)
      expect(state.getProgressRatio(doodle), 1.0);

      // Flower (100 Nature Vocabs)
      expect(state.getProgress(flower, natureVocabCount: 25), 25);
      expect(state.getProgressRatio(flower, natureVocabCount: 25), 0.25);
      expect(state.getProgress(flower, natureVocabCount: 100), 100);
      expect(state.getProgressRatio(flower, natureVocabCount: 100), 1.0);

      // Space (7 Streak Days)
      expect(state.getProgress(space, streakDays: 3), 3);
      expect(state.getProgressRatio(space, streakDays: 3), closeTo(3 / 7, 0.01));
      expect(state.getProgress(space, streakDays: 7), 7);
      expect(state.getProgressRatio(space, streakDays: 7), 1.0);
    });

    test('UserModel defaults to unlocking Doodle pack', () {
      final user = UserModel.createGuest();
      expect(user.stickers.contains('doodle'), isTrue);
    });
  });
}
