import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/data/models/user_model.dart';
import 'package:starmory_app/data/services/streak_service.dart';

void main() {
  group('Streak Logic Tests', () {
    test('One missed day is not at risk and does not require a shield', () {
      final today = DateTime.now();
      final lastActivity = DateTime(today.year, today.month, today.day)
          .subtract(const Duration(days: 2));
      final streak = StreakData(
        currentStreak: 5,
        longestStreak: 5,
        shieldsAvailable: 0,
        lastActivityDate: lastActivity,
      );

      expect(streak.daysSinceLastActivity, equals(2));
      expect(streak.isAtRisk, isFalse);
      expect(streak.isBroken, isFalse);
    });

    test('One available shield protects a streak after a longer gap', () {
      final today = DateTime.now();
      final lastActivity = DateTime(today.year, today.month, today.day)
          .subtract(const Duration(days: 5));
      final streak = StreakData(
        currentStreak: 5,
        longestStreak: 5,
        shieldsAvailable: 1,
        lastActivityDate: lastActivity,
      );

      expect(streak.daysSinceLastActivity, equals(5));
      expect(streak.isAtRisk, isTrue);
      expect(streak.isBroken, isFalse);
    });

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

    test('Future activity date is clamped without changing streak state', () {
      final user = UserModel.createGuest().copyWith(
        currentStreak: 5,
        longestStreak: 7,
        shields: 2,
        lastStreakActivityDate: DateTime.now().add(const Duration(days: 1)),
      );

      final updated = user.incrementStreak();
      final today = DateTime.now();

      expect(updated.currentStreak, equals(5));
      expect(updated.longestStreak, equals(7));
      expect(updated.shields, equals(2));
      expect(
        updated.lastStreakActivityDate,
        DateTime(today.year, today.month, today.day),
      );
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

    test('Missed 1 day increments streak without consuming a shield', () {
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
      final user = UserModel.createGuest().copyWith(
        currentStreak: 5,
        longestStreak: 5,
        shields: 1,
        lastStreakActivityDate: twoDaysAgo,
      );

      final updated = user.incrementStreak();
      expect(updated.currentStreak, equals(6));
      expect(updated.shields, equals(1));
    });

    test('Missed 1 day still increments streak when no shield is available',
        () {
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
      final user = UserModel.createGuest().copyWith(
        currentStreak: 5,
        longestStreak: 5,
        shields: 0,
        lastStreakActivityDate: twoDaysAgo,
      );

      final updated = user.incrementStreak();
      expect(updated.currentStreak, equals(6));
      expect(updated.shields, equals(0));
    });

    test(
        'Missed multiple days without shield resets streak to 1 and preserves longest',
        () {
      final fiveDaysAgo = DateTime.now().subtract(const Duration(days: 5));
      final user = UserModel.createGuest().copyWith(
        currentStreak: 6,
        longestStreak: 6,
        shields: 0,
        lastStreakActivityDate: fiveDaysAgo,
      );

      final updated = user.incrementStreak();
      expect(updated.currentStreak, equals(1));
      expect(updated.longestStreak, equals(6));
      expect(updated.shields, equals(0));
    });

    test('Missed multiple days with a shield consumes one and preserves streak',
        () {
      final fiveDaysAgo = DateTime.now().subtract(const Duration(days: 5));
      final user = UserModel.createGuest().copyWith(
        currentStreak: 10,
        longestStreak: 10,
        shields: 2,
        lastStreakActivityDate: fiveDaysAgo,
      );

      final updated = user.incrementStreak();
      expect(updated.currentStreak, equals(10));
      expect(updated.longestStreak, equals(10));
      expect(updated.shields, equals(1));
    });
  });
}
