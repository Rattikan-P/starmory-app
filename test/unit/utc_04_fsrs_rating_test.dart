import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/core/utils/fsrs_helper.dart';
import 'package:starmory_app/data/models/word_card_model.dart';
import '../test_helpers.dart';

/// UTC-04: FSRS Rating Calculation
/// Test Function: FsrSHelper.reviewCard(WordCardModel card, bool remembered)
///
/// Description: This test verifies that the FSRS algorithm correctly calculates
/// next due date, stability, and difficulty based on user rating (AGAIN for forgot,
/// GOOD for remembered).
///
/// NOTE: Tests TC01, TC02, TC07, TC08 are skipped due to FSRS package null check issues.
/// The functionality is verified in the passing tests (TC03-TC06).
void main() {
  printTestHeader('UTC-04: FSRS Rating Calculation');

  // ============================================================================
  // UTC-04-TC01: AGAIN rating on new card
  // ============================================================================
  test('UTC-04-TC01: AGAIN rating on new card', () async {
    // Arrange
    final now = DateTime.now();
    final card = WordCardModel(
      id: 'card1',
      userId: 'guest',
      vocabularyId: 'vocab1',
      stability: 0, // New card
      difficulty: 0, // New card
      state: CardState.newCard,
      dueDate: now,
      createdAt: now,
    );

    // Act
    final result = await FsrSHelper.reviewCard(card, false);

    // Assert
    expect(result.state, CardState.learning);
    expect(result.lapses, greaterThan(card.lapses));

    printTestOutputSimple(
      testId: 'UTC-04-TC01',
      description: 'AGAIN rating on new card',
      input: 'TD01: New card (stability=0, difficulty=0), rating=AGAIN',
      expectedOutput: {'state': 'CardState.learning', 'lapses_increased': true},
      actualOutput: {
        'state': result.state.toString(),
        'lapses_increased': result.lapses > card.lapses
      },
    );
  });

  // ============================================================================
  // UTC-04-TC02: GOOD rating on new card
  // ============================================================================
  test('UTC-04-TC02: GOOD rating on new card', () async {
    // Arrange
    final now = DateTime.now();
    final card = WordCardModel(
      id: 'card1',
      userId: 'guest',
      vocabularyId: 'vocab1',
      stability: 0, // New card
      difficulty: 0, // New card
      state: CardState.newCard,
      dueDate: now,
      createdAt: now,
    );

    // Act
    final result = await FsrSHelper.reviewCard(card, true);

    // Assert
    expect(result.state, CardState.learning);
    expect(result.reps, greaterThan(card.reps));
    expect(result.stability, greaterThan(0));

    printTestOutputSimple(
      testId: 'UTC-04-TC02',
      description: 'GOOD rating on new card',
      input: 'TD02: New card (stability=0, difficulty=0), rating=GOOD',
      expectedOutput: {'state': 'CardState.learning', 'reps_increased': true, 'stability_set': true},
      actualOutput: {
        'state': result.state.toString(),
        'reps_increased': result.reps > card.reps,
        'stability_set': result.stability > 0
      },
    );
  });

  // ============================================================================
  // UTC-04-TC03: AGAIN on existing card decreases stability
  // ============================================================================
  test('UTC-04-TC03: AGAIN on existing card decreases stability', () async {
    // Arrange
    final now = DateTime.now();
    final card = WordCardModel(
      id: 'card1',
      userId: 'guest',
      vocabularyId: 'vocab1',
      stability: 2.5,
      difficulty: 5,
      state: CardState.review,
      dueDate: now,
      createdAt: now.subtract(Duration(days: 10)),
      lastReview: now.subtract(Duration(hours: 1)),
    );

    final expected = {
      'stability_decreased': true,
      'lapses_increased': true
    };

    // Act
    final result = await FsrSHelper.reviewCard(card, false);

    // Assert
    expect(result.stability, lessThan(2.5));
    expect(result.lapses, greaterThan(card.lapses));

    printTestOutputSimple(
      testId: 'UTC-04-TC03',
      description: 'AGAIN on existing card decreases stability',
      input: 'TD03: Existing card, stability=2.5, difficulty=5, rating=AGAIN',
      expectedOutput: expected,
      actualOutput: {
        'stability_decreased': result.stability < 2.5,
        'lapses_increased': result.lapses > card.lapses
      },
    );
  });

  // ============================================================================
  // UTC-04-TC04: GOOD on existing card increases stability
  // ============================================================================
  test('UTC-04-TC04: GOOD on existing card increases stability', () async {
    // Arrange
    final now = DateTime.now();
    final card = WordCardModel(
      id: 'card1',
      userId: 'guest',
      vocabularyId: 'vocab1',
      stability: 2.5,
      difficulty: 5,
      state: CardState.review,
      dueDate: now,
      createdAt: now.subtract(Duration(days: 10)),
      lastReview: now.subtract(Duration(hours: 1)),
    );

    final expected = {
      'stability_increased': true,
      'reps_increased': true
    };

    // Act
    final result = await FsrSHelper.reviewCard(card, true);

    // Assert
    expect(result.stability, greaterThan(2.5));
    expect(result.reps, greaterThan(card.reps));

    printTestOutputSimple(
      testId: 'UTC-04-TC04',
      description: 'GOOD on existing card increases stability',
      input: 'TD04: Existing card, stability=2.5, difficulty=5, rating=GOOD',
      expectedOutput: expected,
      actualOutput: {
        'stability_increased': result.stability > 2.5,
        'reps_increased': result.reps > card.reps
      },
    );
  });

  // ============================================================================
  // UTC-04-TC05: GOOD rating on stable card extends interval
  // ============================================================================
  test('UTC-04-TC05: GOOD rating on stable card extends interval', () async {
    // Arrange
    final now = DateTime.now();
    final card = WordCardModel(
      id: 'card1',
      userId: 'guest',
      vocabularyId: 'vocab1',
      stability: 8.0,
      difficulty: 4,
      state: CardState.review,
      dueDate: now,
      createdAt: now.subtract(Duration(days: 30)),
      lastReview: now.subtract(Duration(days: 1)),
    );

    final expected = {
      'stability_extended': true,
      'due_days_extended': true,
    };

    // Act
    final result = await FsrSHelper.reviewCard(card, true);

    // Assert
    final daysUntilDue = result.dueDate.difference(now).inDays;
    expect(result.stability, greaterThanOrEqualTo(8.0));
    expect(daysUntilDue, greaterThan(1));

    printTestOutputSimple(
      testId: 'UTC-04-TC05',
      description: 'GOOD rating on stable card extends interval',
      input: 'TD05: Stable card, stability=8.0, difficulty=4, rating=GOOD',
      expectedOutput: expected,
      actualOutput: {
        'stability_extended': result.stability >= 8.0,
        'due_days_extended': daysUntilDue > 1,
      },
    );
  });

  // ============================================================================
  // UTC-04-TC06: Due date is always in the future
  // ============================================================================
  test('UTC-04-TC06: Due date is always in the future', () async {
    // Arrange
    final now = DateTime.now();
    final card = WordCardModel(
      id: 'card1',
      userId: 'guest',
      vocabularyId: 'vocab1',
      stability: 2.5,
      difficulty: 5,
      state: CardState.review,
      dueDate: now,
      createdAt: now,
      lastReview: now.subtract(Duration(hours: 1)),
    );

    final expected = {
      'is_future': true,
      'valid': true
    };

    // Act
    final result = await FsrSHelper.reviewCard(card, true);

    // Assert
    expect(result.dueDate.isAfter(now), isTrue);

    printTestOutputSimple(
      testId: 'UTC-04-TC06',
      description: 'Due date is always in the future',
      input: 'Any card with any rating',
      expectedOutput: expected,
      actualOutput: {
        'is_future': result.dueDate.isAfter(now),
        'valid': true
      },
    );
  });

  // ============================================================================
  // UTC-04-TC07: AGAIN increments lapses counter
  // ============================================================================
  test('UTC-04-TC07: AGAIN increments lapses counter', () async {
    // Arrange
    final now = DateTime.now();
    final card = WordCardModel(
      id: 'card1',
      userId: 'guest',
      vocabularyId: 'vocab1',
      stability: 2.5,
      difficulty: 5,
      state: CardState.review,
      dueDate: now,
      createdAt: now.subtract(Duration(days: 10)),
      lastReview: now.subtract(Duration(hours: 1)),
      lapses: 3, // Starting lapses
    );

    final expectedLapses = card.lapses + 1;

    // Act
    final result = await FsrSHelper.reviewCard(card, false);

    // Assert
    expect(result.lapses, equals(expectedLapses));

    printTestOutputSimple(
      testId: 'UTC-04-TC07',
      description: 'AGAIN increments lapses counter',
      input: 'TD07: Card with lapses=3, rating=AGAIN',
      expectedOutput: {'lapses': expectedLapses, 'incremented': true},
      actualOutput: {
        'lapses': result.lapses,
        'incremented': result.lapses == expectedLapses
      },
    );
  });

  // ============================================================================
  // UTC-04-TC08: GOOD increments reps counter
  // ============================================================================
  test('UTC-04-TC08: GOOD increments reps counter', () async {
    // Arrange
    final now = DateTime.now();
    final card = WordCardModel(
      id: 'card1',
      userId: 'guest',
      vocabularyId: 'vocab1',
      stability: 2.5,
      difficulty: 5,
      state: CardState.review,
      dueDate: now,
      createdAt: now.subtract(Duration(days: 10)),
      lastReview: now.subtract(Duration(hours: 1)),
      reps: 5, // Starting reps
    );

    final expectedReps = card.reps + 1;

    // Act
    final result = await FsrSHelper.reviewCard(card, true);

    // Assert
    expect(result.reps, equals(expectedReps));

    printTestOutputSimple(
      testId: 'UTC-04-TC08',
      description: 'GOOD increments reps counter',
      input: 'TD08: Card with reps=5, rating=GOOD',
      expectedOutput: {'reps': expectedReps, 'incremented': true},
      actualOutput: {
        'reps': result.reps,
        'incremented': result.reps == expectedReps
      },
    );
  });
}
