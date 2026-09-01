import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/data/models/user_model.dart';

void main() {
  group('Streak Logic Tests', () {
    test('First activity ever sets streak to 1', () {
      final user = UserModel.createGuest();
      expect(user.currentStreak, equals(0));
      expect(user.lastStreakActivityDate, isNull);

      final updated = user.incrementStreak();
      expect(updated.currentStreak, equals(1));
      expect(updated.longestStreak, equals(1));
      expect(updated.lastStreakActivityDate, isNotNull);
    });

    test('Same day activity does not increment streak again', () {
      final now = DateTime.now();
      final user = UserModel.createGuest().copyWith(
        currentStreak: 1,
        longestStreak: 1,
        lastStreakActivityDate: now,
      );

      final updated = user.incrementStreak();
      expect(updated.currentStreak, equals(1));
      expect(updated.longestStreak, equals(1));
    });

    test('Consecutive day activity increments streak', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final user = UserModel.createGuest().copyWith(
        currentStreak: 2,
        longestStreak: 2,
        lastStreakActivityDate: yesterday,
      );

      final updated = user.incrementStreak();
      expect(updated.currentStreak, equals(3));
      expect(updated.longestStreak, equals(3));
    });

    test('7-day streak awards 1 shield', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final user = UserModel.createGuest().copyWith(
        currentStreak: 6,
        longestStreak: 6,
        shields: 0,
        lastStreakActivityDate: yesterday,
      );

      final updated = user.incrementStreak();
      expect(updated.currentStreak, equals(7));
      expect(updated.shields, equals(1));
    });

    test('Missed 1 day with shield consumes shield and maintains streak increment', () {
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
      final user = UserModel.createGuest().copyWith(
        currentStreak: 5,
        longestStreak: 5,
        shields: 1,
        lastStreakActivityDate: twoDaysAgo,
      );

      final updated = user.incrementStreak();
      expect(updated.currentStreak, equals(6));
      expect(updated.shields, equals(0));
    });

    test('Missed 1 day without shield resets streak to 1', () {
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
      final user = UserModel.createGuest().copyWith(
        currentStreak: 5,
        longestStreak: 5,
        shields: 0,
        lastStreakActivityDate: twoDaysAgo,
      );

      final updated = user.incrementStreak();
      expect(updated.currentStreak, equals(1));
      expect(updated.longestStreak, equals(5)); // longest preserved
    });
  });
}
