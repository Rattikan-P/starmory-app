import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:starmory_app/core/utils/fsrs_helper.dart';
import 'package:starmory_app/data/models/word_card_model.dart';
import '../test_helpers.dart';

/// UTC-04: FSRS Rating Calculation
void main() {
  printTestHeader('UTC-04: FSRS Rating Calculation');

  test('UTC-04-TC03: AGAIN on existing card decreases stability', () async {
    final now = DateTime.now();
    final card = WordCardModel(
      id: 'card_abc',
      userId: 'guest',
      vocabularyId: 'vocab1',
      stability: 2.5,
      difficulty: 5,
      state: CardState.review,
      dueDate: now,
      createdAt: now.subtract(Duration(days: 10)),
      lastReview: now.subtract(Duration(hours: 1)),
      reps: 1,
    );

    final result = await FsrSHelper.reviewCard(card, false);

    expect(result.stability, lessThan(2.5));
    expect(result.lapses, greaterThan(card.lapses));

    printTestOutputSimple(
      testId: 'UTC-04-TC03',
      description: 'AGAIN on existing card decreases stability',
      input: 'TD03: Existing card, stability=2.5, rating=AGAIN',
      expectedOutput: {'stability_decreased': true, 'lapses_increased': true},
      actualOutput: {'stability_decreased': result.stability < 2.5, 'lapses_increased': result.lapses > card.lapses},
    );
  });

  test('UTC-04-TC04: GOOD on existing card increases stability', () async {
    final now = DateTime.now();
    final card = WordCardModel(
      id: 'card_def',
      userId: 'guest',
      vocabularyId: 'vocab1',
      stability: 2.5,
      difficulty: 5,
      state: CardState.review,
      dueDate: now,
      createdAt: now.subtract(Duration(days: 10)),
      lastReview: now.subtract(Duration(hours: 1)),
      reps: 1,
    );

    final result = await FsrSHelper.reviewCard(card, true);

    expect(result.stability, greaterThan(2.5));
    expect(result.reps, greaterThan(card.reps));

    printTestOutputSimple(
      testId: 'UTC-04-TC04',
      description: 'GOOD on existing card increases stability',
      input: 'TD04: Existing card, stability=2.5, rating=GOOD',
      expectedOutput: {'stability_increased': true, 'reps_increased': true},
      actualOutput: {'stability_increased': result.stability > 2.5, 'reps_increased': result.reps > card.reps},
    );
  });

  test('UTC-04-TC05: GOOD rating on stable card extends interval', () async {
    final now = DateTime.now();
    final card = WordCardModel(
      id: 'card_ghi',
      userId: 'guest',
      vocabularyId: 'vocab1',
      stability: 8.0,
      difficulty: 4,
      state: CardState.review,
      dueDate: now,
      createdAt: now.subtract(Duration(days: 30)),
      lastReview: now.subtract(Duration(days: 1)),
      reps: 5,
    );

    final result = await FsrSHelper.reviewCard(card, true);

    final daysUntilDue = result.dueDate.difference(now).inDays;
    expect(result.stability, greaterThanOrEqualTo(8.0));
    expect(daysUntilDue, greaterThan(1));

    printTestOutputSimple(
      testId: 'UTC-04-TC05',
      description: 'GOOD rating on stable card extends interval',
      input: 'TD05: Stable card, stability=8.0, rating=GOOD',
      expectedOutput: {'stability_extended': true, 'due_days_extended': true},
      actualOutput: {'stability_extended': result.stability >= 8.0, 'due_days_extended': daysUntilDue > 1},
    );
  });

  test('UTC-04-TC06: Due date is always in the future', () async {
    final now = DateTime.now();
    final card = WordCardModel(
      id: 'card_jkl',
      userId: 'guest',
      vocabularyId: 'vocab1',
      stability: 2.5,
      difficulty: 5,
      state: CardState.review,
      dueDate: now,
      createdAt: now,
      lastReview: now.subtract(Duration(hours: 1)),
      reps: 1,
    );

    final result = await FsrSHelper.reviewCard(card, true);

    expect(result.dueDate.isAfter(now), isTrue);

    printTestOutputSimple(
      testId: 'UTC-04-TC06',
      description: 'Due date is always in the future',
      input: 'Any card with any rating',
      expectedOutput: {'is_future': true, 'valid': true},
      actualOutput: {'is_future': result.dueDate.isAfter(now), 'valid': true},
    );
  });
}
