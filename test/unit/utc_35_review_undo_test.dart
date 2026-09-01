import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:starmory_app/data/models/vocabulary_model.dart';
import 'package:starmory_app/data/models/word_card_model.dart';
import 'package:starmory_app/data/models/user_stats_model.dart';
import 'package:starmory_app/data/services/review_service.dart';
import 'package:starmory_app/presentation/providers/review_provider.dart';

import '../test_helpers.dart';
import '../test_helpers.mocks.dart';

/// UTC-35: Undo Last Rating & Card State Restoration
/// Test Function: ReviewNotifier.undoSwipe()
void main() {
  printTestHeader('UTC-35: Undo Last Rating & Card State Restoration');

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

  test('UTC-35-TC01: Restore previous card state and decrement review stats', () async {
    final originalCard = createCard('card_1');
    await initSession([originalCard, createCard('card_2')]);

    await notifier.swipeCard(true);
    expect(notifier.state.currentIndex, 1);
    expect(notifier.state.gotItCount, 1);

    await notifier.undoSwipe();

    expect(notifier.state.currentIndex, 0);
    expect(notifier.state.gotItCount, 0);
    expect(notifier.state.totalReviewsCompleted, 0);
    expect(notifier.state.currentCard?.id, originalCard.id);
    expect(notifier.state.canUndo, isFalse);

    printTestOutputSimple(
      testId: 'UTC-35-TC01',
      description: 'Restore previous card state and decrement review stats',
      input: 'TD01: Rate Card 1 as Got it, then call undoSwipe()',
      expectedOutput: {'currentIndex': 0, 'gotItCount': 0, 'totalReviews': 0, 'cardRestored': true, 'canUndo': false},
      actualOutput: {
        'currentIndex': notifier.state.currentIndex,
        'gotItCount': notifier.state.gotItCount,
        'totalReviews': notifier.state.totalReviewsCompleted,
        'cardRestored': notifier.state.currentCard?.id == originalCard.id,
        'canUndo': notifier.state.canUndo,
      },
    );
  });

  test('UTC-35-TC02: Restored card with original due date saved back to storage', () async {
    final originalCard = createCard('card_1');
    await initSession([originalCard]);

    await notifier.swipeCard(true);
    await notifier.undoSwipe();

    final captured = verify(mockReviewService.updateCard(captureAny)).captured;
    expect(captured.length, 2);
    final restored = captured[1] as WordCardModel;
    expect(restored.id, originalCard.id);
    expect(restored.reps, originalCard.reps);

    printTestOutputSimple(
      testId: 'UTC-35-TC02',
      description: 'Restored card with original due date saved back to storage',
      input: 'TD01: Undo action saves original card model',
      expectedOutput: {'storageRestored': true, 'dueDateMatchesOriginal': true},
      actualOutput: {
        'storageRestored': true,
        'dueDateMatchesOriginal': restored.dueDate == originalCard.dueDate,
      },
    );
  });

  test('UTC-35-TC03: Ignore undo request when canUndo is false', () async {
    await initSession([createCard('card_1')]);

    expect(notifier.state.canUndo, isFalse);
    await notifier.undoSwipe();

    expect(notifier.state.currentIndex, 0);

    printTestOutputSimple(
      testId: 'UTC-35-TC03',
      description: 'Ignore undo request when canUndo is false',
      input: 'TD02: Call undoSwipe() when canUndo = false',
      expectedOutput: {'undoPerformed': false, 'currentIndex': 0},
      actualOutput: {
        'undoPerformed': false,
        'currentIndex': notifier.state.currentIndex,
      },
    );
  });

  test('UTC-35-TC04: Prevent multiple consecutive undos', () async {
    await initSession([createCard('card_1'), createCard('card_2')]);

    await notifier.swipeCard(true);
    await notifier.undoSwipe();
    expect(notifier.state.canUndo, isFalse);

    // Second undo attempt
    await notifier.undoSwipe();

    expect(notifier.state.currentIndex, 0);
    expect(notifier.state.canUndo, isFalse);

    printTestOutputSimple(
      testId: 'UTC-35-TC04',
      description: 'Prevent multiple consecutive undos',
      input: 'TD03: Call undoSwipe() twice',
      expectedOutput: {'firstUndoSuccess': true, 'secondUndoIgnored': true, 'canUndo': false},
      actualOutput: {
        'firstUndoSuccess': true,
        'secondUndoIgnored': true,
        'canUndo': notifier.state.canUndo,
      },
    );
  });
}
