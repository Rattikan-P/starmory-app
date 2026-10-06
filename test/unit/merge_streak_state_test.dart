import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/data/services/merge_service.dart';

void main() {
  group('Streak merge state timestamps', () {
    test('newer reset to zero wins over older positive streak', () async {
      final merge = await MergeService().mergeUserData(
        {
          'currentStreak': 0,
          'longestStreak': 5,
          'shields': 0,
          'lastStreakActivityDate': '2026-09-25',
          'streakStateUpdatedAt': '2026-09-27T08:00:00.000Z',
        },
        {
          'current_streak': 10,
          'longest_streak': 10,
          'shields_available': 1,
          'last_activity_date': '2026-09-26',
          'streak_state_updated_at': '2026-09-26T08:00:00.000Z',
        },
      );

      expect(merge.mergedData['current_streak'], 0);
      expect(merge.mergedData['streak_state_updated_at'],
          DateTime.parse('2026-09-27T08:00:00.000Z'));
      expect(merge.mergedData['last_activity_date'], '2026-09-25');
      expect(merge.mergedData['longest_streak'], 10);
      expect(merge.mergedData['shields_available'], 1);
    });

    test('newer positive streak wins over older zero reset', () async {
      final merge = await MergeService().mergeUserData(
        {
          'currentStreak': 0,
          'longestStreak': 5,
          'shields': 0,
          'lastStreakActivityDate': '2026-09-25',
          'streakStateUpdatedAt': '2026-09-26T08:00:00.000Z',
        },
        {
          'current_streak': 1,
          'longest_streak': 10,
          'shields_available': 0,
          'last_activity_date': '2026-09-27',
          'streak_state_updated_at': '2026-09-27T08:00:00.000Z',
        },
      );

      expect(merge.mergedData['current_streak'], 1);
      expect(merge.mergedData['last_activity_date'], '2026-09-27');
    });

    test('guest and registered badges are both retained after merge', () async {
      final merge = await MergeService().mergeUserData(
        {'badges': ['first_word', 'streak_3']},
        {'badges': ['night_owl']},
      );

      expect(merge.mergedData['badges'],
          {'first_word', 'streak_3', 'night_owl'});
    });
  });
}
