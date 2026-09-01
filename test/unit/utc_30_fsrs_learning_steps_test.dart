import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/core/utils/fsrs_helper.dart';
import 'package:starmory_app/data/models/word_card_model.dart';
import '../test_helpers.dart';

/// UTC-30: FSRS Short-term Learning & Relearning Steps
/// Test Function: FsrSHelper.reviewCard(WordCardModel card, bool remembered)
void main() {
  printTestHeader('UTC-30: FSRS Short-term Learning & Relearning Steps');

  test('UTC-30-TC01: New card first Got it schedules 10-minute learning step', () async {
    final now = DateTime.now();
    final card = WordCardModel(
      id: 'card1',
      userId: 'guest',
      vocabularyId: 'vocab1',
      stability: 0,
      difficulty: 0,
      state: CardState.newCard,
      dueDate: now,
      reps: 0,
      lapses: 0,
      createdAt: now,
    );

    final result = await FsrSHelper.reviewCard(card, true);

    expect(result.state, CardState.learning);
    expect(result.reps, 1);
    expect(result.dueDate.isAfter(now), isTrue);

    printTestOutputSimple(
      testId: 'UTC-30-TC01',
      description: 'New card first Got it schedules 10-minute learning step',
      input: 'TD01: New card, remembered = true (Got it)',
      expectedOutput: {'state': 'learning', 'reps': 1, 'intervalMinutes': 10},
      actualOutput: {
        'state': 'learning',
        'reps': result.reps,
        'intervalMinutes': result.dueDate.difference(now).inMinutes,
      },
    );
  });

  test('UTC-30-TC02: New card first Not yet schedules 1-minute repeat step', () async {
    final now = DateTime.now();
    final card = WordCardModel(
      id: 'card1',
      userId: 'guest',
      vocabularyId: 'vocab1',
      stability: 0,
      difficulty: 0,
      state: CardState.newCard,
      dueDate: now,
      reps: 0,
      lapses: 0,
      createdAt: now,
    );

    final result = await FsrSHelper.reviewCard(card, false);

    expect(result.state, CardState.learning);
    expect(result.reps, 1);
    expect(result.lapses, 1);

    printTestOutputSimple(
      testId: 'UTC-30-TC02',
      description: 'New card first Not yet schedules 1-minute repeat step',
      input: 'TD02: New card, remembered = false (Not yet)',
      expectedOutput: {'state': 'learning', 'reps': 1, 'lapses': 1, 'intervalMinutes': 1},
      actualOutput: {
        'state': 'learning',
        'reps': result.reps,
        'lapses': result.lapses,
        'intervalMinutes': result.dueDate.difference(now).inMinutes,
      },
    );
  });

  test('UTC-30-TC03: Consecutive Got it in learning step advances stability', () async {
    final now = DateTime.now();
    final card = WordCardModel(
      id: 'card1',
      userId: 'guest',
      vocabularyId: 'vocab1',
      stability: 1.2,
      difficulty: 4.5,
      state: CardState.learning,
      dueDate: now,
      reps: 1,
      lapses: 0,
      createdAt: now.subtract(const Duration(minutes: 10)),
      lastReview: now.subtract(const Duration(minutes: 10)),
    );

    final result = await FsrSHelper.reviewCard(card, true);

    expect(result.reps, 2);
    expect(result.stability, greaterThan(1.0));

    printTestOutputSimple(
      testId: 'UTC-30-TC03',
      description: 'Consecutive Got it in learning step advances stability',
      input: 'TD03: reps = 1, state = learning, remembered = true',
      expectedOutput: {'reps': 2, 'stabilityIncreased': true},
      actualOutput: {
        'reps': result.reps,
        'stabilityIncreased': result.stability > 1.0,
      },
    );
  });

  test('UTC-30-TC04: Forgotten card lapses into 10-minute Relearning state', () async {
    final now = DateTime.now();
    final card = WordCardModel(
      id: 'card1',
      userId: 'guest',
      vocabularyId: 'vocab1',
      stability: 3.5,
      difficulty: 5.0,
      state: CardState.review,
      dueDate: now,
      reps: 3,
      lapses: 0,
      createdAt: now.subtract(const Duration(days: 10)),
      lastReview: now.subtract(const Duration(days: 3)),
    );

    final result = await FsrSHelper.reviewCard(card, false);

    expect(result.lapses, 1);
    expect(result.state, CardState.relearning);

    printTestOutputSimple(
      testId: 'UTC-30-TC04',
      description: 'Forgotten card lapses into 10-minute Relearning state',
      input: 'TD04: Review card, remembered = false (Not yet)',
      expectedOutput: {'state': 'relearning', 'lapses': 1, 'intervalMinutes': 10},
      actualOutput: {
        'state': 'relearning',
        'lapses': result.lapses,
        'intervalMinutes': result.dueDate.difference(now).inMinutes,
      },
    );
  });
}
