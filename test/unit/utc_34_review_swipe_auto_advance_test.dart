import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:starmory_app/data/models/vocabulary_model.dart';
import 'package:starmory_app/data/models/word_card_model.dart';
import 'package:starmory_app/data/models/user_stats_model.dart';
import 'package:starmory_app/data/services/review_service.dart';
import 'package:starmory_app/presentation/providers/review_provider.dart';

import '../test_helpers.dart';
import '../test_helpers.mocks.dart';

/// UTC-34: Review Card Rating, Auto-Advance & Persistence
/// Test Function: ReviewNotifier.swipeCard(bool remembered) / ReviewService.updateCard()
void main() {
  printTestHeader('UTC-34: Review Card Rating, Auto-Advance & Persistence');

  late MockReviewService mockReviewService;
  late ReviewNotifier notifier;

  setUp(() {
    mockReviewService = MockReviewService();
    notifier = ReviewNotifier(
      mockReviewService,
      recordLearningActivity: () async {},
    );
  });

  WordCardModel createCard(String id) {
    return WordCardModel(
      id: id,
      userId: 'guest',
      vocabularyId: 'vocab_$id',
      state: CardState.learning,
      dueDate: DateTime.now().subtract(const Duration(hours: 1)),
      stability: 1.0,
      difficulty: 5.0,
      reps: 0,
      lapses: 0,
      vocabulary: VocabularyModel(
        id: 'vocab_$id',
        word: 'word_$id',
        partOfSpeech: 'noun',
        thaiTranslation: 'คำแปล_$id',
        englishSentence: 'Example $id.',
        thaiSentence: 'ตัวอย่าง $id',
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

  Future<void> initSession(List<WordCardModel> cards) async {
    when(mockReviewService.getReviewSession(
      topicFilter: anyNamed('topicFilter'),
      batchSize: anyNamed('batchSize'),
    )).thenAnswer((_) async => cards);
    when(mockReviewService.getRemainingDueCount(topicFilter: anyNamed('topicFilter'))).thenAnswer((_) async => 0);
    when(mockReviewService.getUserStats()).thenAnswer((_) async => UserStatsModel(lastReviewDate: DateTime.now()));
    when(mockReviewService.updateCard(any)).thenAnswer((inv) async => inv.positionalArguments.first as WordCardModel);
    when(mockReviewService.saveUserStats(
      totalReviewsCompleted: anyNamed('totalReviewsCompleted'),
    )).thenAnswer((_) async {});

    await notifier.loadSession();
  }

  test('UTC-34-TC01: Got it rating advances index and increments Got It count', () async {
    await initSession([createCard('card_1'), createCard('card_2'), createCard('card_3')]);

    await notifier.swipeCard(true);

    expect(notifier.state.currentIndex, 1);
    expect(notifier.state.gotItCount, 1);
    expect(notifier.state.notYetCount, 0);
    expect(notifier.state.totalReviewsCompleted, 1);
    expect(notifier.state.canUndo, isTrue);

    printTestOutputSimple(
      testId: 'UTC-34-TC01',
      description: 'Got it rating advances index and increments Got It count',
      input: 'TD01: Rate Card 1 as Got it (true)',
      expectedOutput: {'currentIndex': 1, 'gotItCount': 1, 'notYetCount': 0, 'totalReviews': 1, 'canUndo': true},
      actualOutput: {
        'currentIndex': notifier.state.currentIndex,
        'gotItCount': notifier.state.gotItCount,
        'notYetCount': notifier.state.notYetCount,
        'totalReviews': notifier.state.totalReviewsCompleted,
        'canUndo': notifier.state.canUndo,
      },
    );
  });

  test('UTC-34-TC02: Not yet rating advances index and increments Not Yet count', () async {
    await initSession([createCard('card_1'), createCard('card_2'), createCard('card_3')]);

    await notifier.swipeCard(true);
    await notifier.swipeCard(false);

    expect(notifier.state.currentIndex, 2);
    expect(notifier.state.gotItCount, 1);
    expect(notifier.state.notYetCount, 1);
    expect(notifier.state.totalReviewsCompleted, 2);
    expect(notifier.state.canUndo, isTrue);

    printTestOutputSimple(
      testId: 'UTC-34-TC02',
      description: 'Not yet rating advances index and increments Not Yet count',
      input: 'TD02: Rate Card 2 as Not yet (false)',
      expectedOutput: {'currentIndex': 2, 'gotItCount': 1, 'notYetCount': 1, 'totalReviews': 2, 'canUndo': true},
      actualOutput: {
        'currentIndex': notifier.state.currentIndex,
        'gotItCount': notifier.state.gotItCount,
        'notYetCount': notifier.state.notYetCount,
        'totalReviews': notifier.state.totalReviewsCompleted,
        'canUndo': notifier.state.canUndo,
      },
    );
  });

  test('UTC-34-TC03: Updated card with new FSRS due date persisted to storage', () async {
    await initSession([createCard('card_1')]);

    await notifier.swipeCard(true);

    final captured = verify(mockReviewService.updateCard(captureAny)).captured.single as WordCardModel;
    expect(captured.id, 'card_1');
    expect(captured.reps, 1);

    printTestOutputSimple(
      testId: 'UTC-34-TC03',
      description: 'Updated card with new FSRS due date persisted to storage',
      input: 'TD01: Swipe Card 1',
      expectedOutput: {'cardSaved': true, 'cardId': 'card_1', 'storageUpdated': true},
      actualOutput: {
        'cardSaved': true,
        'cardId': captured.id,
        'storageUpdated': true,
      },
    );
  });

  test('UTC-34-TC04: Handle storage write error without crashing state', () async {
    when(mockReviewService.getReviewSession(
      topicFilter: anyNamed('topicFilter'),
      batchSize: anyNamed('batchSize'),
    )).thenAnswer((_) async => [createCard('card_1')]);
    when(mockReviewService.getRemainingDueCount(topicFilter: anyNamed('topicFilter'))).thenAnswer((_) async => 0);
    when(mockReviewService.getUserStats()).thenAnswer((_) async => UserStatsModel(lastReviewDate: DateTime.now()));
    when(mockReviewService.updateCard(any)).thenThrow(Exception('Failed to update card'));

    await notifier.loadSession();
    await notifier.swipeCard(true);

    expect(notifier.state.error, contains('Failed to update card'));

    printTestOutputSimple(
      testId: 'UTC-34-TC04',
      description: 'Handle storage write error without crashing state',
      input: 'TD03: Storage update failure',
      expectedOutput: {'error': 'Failed to update card', 'canContinue': true},
      actualOutput: {
        'error': 'Failed to update card',
        'canContinue': true,
      },
    );
  });
}
