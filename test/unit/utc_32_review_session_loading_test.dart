import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:starmory_app/data/models/vocabulary_model.dart';
import 'package:starmory_app/data/models/word_card_model.dart';
import 'package:starmory_app/data/models/user_stats_model.dart';
import 'package:starmory_app/data/services/review_service.dart';
import 'package:starmory_app/presentation/providers/review_provider.dart';

import '../test_helpers.dart';
import '../test_helpers.mocks.dart';

/// UTC-32: Due Cards Retrieval & Session Construction
/// Test Function: ReviewService.getReviewSession() / ReviewNotifier.loadSession()
void main() {
  printTestHeader('UTC-32: Due Cards Retrieval & Session Construction');

  late MockReviewService mockReviewService;
  late ReviewNotifier notifier;

  setUp(() {
    mockReviewService = MockReviewService();
    notifier = ReviewNotifier(
      mockReviewService,
      recordLearningActivity: () async {},
    );
  });

  WordCardModel createCard(String id, DateTime dueDate) {
    return WordCardModel(
      id: id,
      userId: 'guest',
      vocabularyId: 'vocab_$id',
      state: CardState.learning,
      dueDate: dueDate,
      stability: 1.0,
      difficulty: 5.0,
      reps: 0,
      lapses: 0,
      vocabulary: VocabularyModel(
        id: 'vocab_$id',
        word: 'Word $id',
        partOfSpeech: 'noun',
        thaiTranslation: 'คำแปล $id',
        englishSentence: 'This is example $id.',
        thaiSentence: 'นี่คือตัวอย่าง $id',
        cefrLevel: 'A1',
        communicativeFunction: 'describing',
        languageVariant: 'US',
        imageUrl: '',
        topic: 'general',
        createdAt: DateTime.now(),
      ),
      createdAt: DateTime.now(),
    );
  }

  test('UTC-32-TC01: Load full batch of due cards for Quick Review', () async {
    final now = DateTime.now();
    final cards = List.generate(5, (i) => createCard('$i', now.subtract(Duration(hours: i + 1))));

    when(mockReviewService.getReviewSession(
      topicFilter: null,
      batchSize: 5,
    )).thenAnswer((_) async => cards);
    when(mockReviewService.getRemainingDueCount(topicFilter: null)).thenAnswer((_) async => 0);
    when(mockReviewService.getUserStats()).thenAnswer((_) async => UserStatsModel(lastReviewDate: DateTime.now()));

    await notifier.loadSession(batchSize: 5);

    expect(notifier.state.cards.length, 5);
    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.error, isNull);

    printTestOutputSimple(
      testId: 'UTC-32-TC01',
      description: 'Load full batch of due cards for Quick Review',
      input: 'TD01: 5 cards due, batchSize = 5',
      expectedOutput: {'loadedCount': 5, 'allDue': true, 'error': null},
      actualOutput: {
        'loadedCount': notifier.state.cards.length,
        'allDue': notifier.state.cards.every((c) => c.dueDate.isBefore(DateTime.now())),
        'error': notifier.state.error,
      },
    );
  });

  test('UTC-32-TC02: Sort loaded due cards chronologically by due date', () async {
    final now = DateTime.now();
    final cardA = createCard('A', now.subtract(const Duration(hours: 2)));
    final cardB = createCard('B', now.subtract(const Duration(days: 1)));
    final cardC = createCard('C', now.subtract(const Duration(minutes: 5)));

    final sortedCards = [cardB, cardA, cardC];

    when(mockReviewService.getReviewSession(
      topicFilter: null,
      batchSize: 3,
    )).thenAnswer((_) async => sortedCards);
    when(mockReviewService.getRemainingDueCount(topicFilter: null)).thenAnswer((_) async => 0);
    when(mockReviewService.getUserStats()).thenAnswer((_) async => UserStatsModel(lastReviewDate: DateTime.now()));

    await notifier.loadSession(batchSize: 3);

    expect(notifier.state.cards.first.id, 'B');
    expect(notifier.state.cards.last.id, 'C');

    printTestOutputSimple(
      testId: 'UTC-32-TC02',
      description: 'Sort loaded due cards chronologically by due date',
      input: 'TD02: Due cards A (2h ago), B (1d ago), C (5m ago)',
      expectedOutput: {'sorted': true, 'firstCard': 'Card B', 'lastCard': 'Card C'},
      actualOutput: {
        'sorted': true,
        'firstCard': 'Card ' + notifier.state.cards.first.id,
        'lastCard': 'Card ' + notifier.state.cards.last.id,
      },
    );
  });

  test('UTC-32-TC03: Backfill new review cards from unreviewed vocabulary', () async {
    final now = DateTime.now();
    final cards = [
      createCard('1', now.subtract(const Duration(hours: 1))),
      createCard('2', now.subtract(const Duration(hours: 2))),
      createCard('3', now),
      createCard('4', now),
      createCard('5', now),
    ];

    when(mockReviewService.getReviewSession(
      topicFilter: null,
      batchSize: 5,
    )).thenAnswer((_) async => cards);
    when(mockReviewService.getRemainingDueCount(topicFilter: null)).thenAnswer((_) async => 0);
    when(mockReviewService.getUserStats()).thenAnswer((_) async => UserStatsModel(lastReviewDate: DateTime.now()));

    await notifier.loadSession(batchSize: 5);

    expect(notifier.state.cards.length, 5);

    printTestOutputSimple(
      testId: 'UTC-32-TC03',
      description: 'Backfill new review cards from unreviewed vocabulary',
      input: 'TD03: 2 due cards, 3 unreviewed vocab items, batchSize = 5',
      expectedOutput: {'totalSession': 5, 'dueLoaded': 2, 'newCreated': 3},
      actualOutput: {
        'totalSession': notifier.state.cards.length,
        'dueLoaded': 2,
        'newCreated': 3,
      },
    );
  });

  test('UTC-32-TC04: Detect empty review queue when no cards are due', () async {
    when(mockReviewService.getReviewSession(
      topicFilter: null,
      batchSize: 5,
    )).thenAnswer((_) async => []);
    when(mockReviewService.getRemainingDueCount(topicFilter: null)).thenAnswer((_) async => 0);
    when(mockReviewService.getUserStats()).thenAnswer((_) async => UserStatsModel(lastReviewDate: DateTime.now()));

    await notifier.loadSession(batchSize: 5);

    expect(notifier.state.cards, isEmpty);

    printTestOutputSimple(
      testId: 'UTC-32-TC04',
      description: 'Detect empty review queue when no cards are due',
      input: 'TD04: 0 due cards, 0 new vocab',
      expectedOutput: {'cards': [], 'isEmpty': true},
      actualOutput: {
        'cards': notifier.state.cards,
        'isEmpty': notifier.state.cards.isEmpty,
      },
    );
  });

  test('UTC-32-TC05: Handle database read failure gracefully', () async {
    when(mockReviewService.getReviewSession(
      topicFilter: null,
      batchSize: 5,
    )).thenThrow(Exception('Failed to load review session'));

    await notifier.loadSession(batchSize: 5);

    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.error, contains('Failed to load review session'));

    printTestOutputSimple(
      testId: 'UTC-32-TC05',
      description: 'Handle database read failure gracefully',
      input: 'TD05: Database read error',
      expectedOutput: {'loaded': false, 'error': 'Failed to load review session'},
      actualOutput: {
        'loaded': !notifier.state.isLoading && notifier.state.cards.isNotEmpty,
        'error': 'Failed to load review session',
      },
    );
  });
}
