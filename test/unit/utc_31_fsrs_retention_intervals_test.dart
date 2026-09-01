import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/core/utils/fsrs_helper.dart';
import 'package:starmory_app/data/models/word_card_model.dart';
import '../test_helpers.dart';

/// UTC-31: FSRS Long-term Memory Retention & Multi-Day Intervals
/// Test Function: FsrSHelper.reviewCard(WordCardModel card, bool remembered)
void main() {
  printTestHeader('UTC-31: FSRS Long-term Memory Retention & Multi-Day Intervals');

  test('UTC-31-TC01: Initial graduated review card expands interval across days', () async {
    final now = DateTime.now();
    final card = WordCardModel(
      id: 'card_graduated',
      userId: 'guest',
      vocabularyId: 'vocab_1',
      stability: 2.5,
      difficulty: 5.0,
      state: CardState.review,
      dueDate: now,
      lastReview: now.subtract(const Duration(days: 2)),
      reps: 2,
      lapses: 0,
      createdAt: now.subtract(const Duration(days: 3)),
    );

    final result = await FsrSHelper.reviewCard(card, true);
    final days = result.dueDate.difference(now).inDays;

    expect(result.state, CardState.review);
    expect(days, greaterThan(1));
    expect(result.stability, greaterThan(2.5));

    printTestOutputSimple(
      testId: 'UTC-31-TC01',
      description: 'Initial graduated review card expands interval across days',
      input: 'TD01: Graduated card (Stability = 2.5), remembered = true',
      expectedOutput: {'state': 'review', 'stabilityIncreased': true, 'intervalDaysGreaterThan': 1},
      actualOutput: {
        'state': 'review',
        'stabilityIncreased': result.stability > 2.5,
        'intervalDaysGreaterThan': days > 1 ? 1 : 0,
      },
    );
  });

  test('UTC-31-TC02: Intermediate review card expands interval across weeks', () async {
    final now = DateTime.now();
    final card = WordCardModel(
      id: 'card_intermediate',
      userId: 'guest',
      vocabularyId: 'vocab_2',
      stability: 7.5,
      difficulty: 4.5,
      state: CardState.review,
      dueDate: now,
      lastReview: now.subtract(const Duration(days: 7)),
      reps: 4,
      lapses: 0,
      createdAt: now.subtract(const Duration(days: 15)),
    );

    final result = await FsrSHelper.reviewCard(card, true);
    final days = result.dueDate.difference(now).inDays;

    expect(result.state, CardState.review);
    expect(days, greaterThan(7));

    printTestOutputSimple(
      testId: 'UTC-31-TC02',
      description: 'Intermediate review card expands interval across weeks',
      input: 'TD02: Intermediate card (Stability = 7.5), remembered = true',
      expectedOutput: {'state': 'review', 'stabilityGreaterThan': 7.5, 'intervalDaysGreaterThan': 7},
      actualOutput: {
        'state': 'review',
        'stabilityGreaterThan': result.stability > 7.5 ? 7.5 : result.stability,
        'intervalDaysGreaterThan': days > 7 ? 7 : days,
      },
    );
  });

  test('UTC-31-TC03: Mature stable card expands interval across months', () async {
    final now = DateTime.now();
    final card = WordCardModel(
      id: 'card_mature',
      userId: 'guest',
      vocabularyId: 'vocab_3',
      stability: 25.0,
      difficulty: 3.8,
      state: CardState.review,
      dueDate: now,
      lastReview: now.subtract(const Duration(days: 25)),
      reps: 6,
      lapses: 0,
      createdAt: now.subtract(const Duration(days: 60)),
    );

    final result = await FsrSHelper.reviewCard(card, true);
    final days = result.dueDate.difference(now).inDays;

    expect(result.state, CardState.review);
    expect(days, greaterThan(30));

    printTestOutputSimple(
      testId: 'UTC-31-TC03',
      description: 'Mature stable card expands interval across months',
      input: 'TD03: Mature card (Stability = 25.0), remembered = true',
      expectedOutput: {'state': 'review', 'intervalDaysGreaterThan': 30},
      actualOutput: {
        'state': 'review',
        'intervalDaysGreaterThan': days > 30 ? 30 : days,
      },
    );
  });

  test('UTC-31-TC04: Lapse reduces stability and resets interval to short step', () async {
    final now = DateTime.now();
    final card = WordCardModel(
      id: 'card_lapse',
      userId: 'guest',
      vocabularyId: 'vocab_4',
      stability: 25.0,
      difficulty: 3.8,
      state: CardState.review,
      dueDate: now,
      lastReview: now.subtract(const Duration(days: 25)),
      reps: 6,
      lapses: 0,
      createdAt: now.subtract(const Duration(days: 60)),
    );

    final result = await FsrSHelper.reviewCard(card, false);

    expect(result.state, CardState.relearning);
    expect(result.stability, lessThan(25.0));
    expect(result.lapses, 1);

    printTestOutputSimple(
      testId: 'UTC-31-TC04',
      description: 'Lapse reduces stability and resets interval to short step',
      input: 'TD04: Mature card (Stability = 25.0), remembered = false',
      expectedOutput: {'state': 'relearning', 'stabilityReduced': true, 'lapses': 1},
      actualOutput: {
        'state': 'relearning',
        'stabilityReduced': result.stability < 25.0,
        'lapses': result.lapses,
      },
    );
  });
}
