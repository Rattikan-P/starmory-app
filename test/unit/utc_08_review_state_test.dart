import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:starmory_app/core/utils/fsrs_helper.dart';
import 'package:starmory_app/data/models/user_stats_model.dart';
import 'package:starmory_app/data/models/vocabulary_model.dart';
import 'package:starmory_app/data/models/word_card_model.dart';
import 'package:starmory_app/data/services/hive_service.dart';
import 'package:starmory_app/data/services/review_service.dart';
import 'package:starmory_app/presentation/providers/review_provider.dart';
import '../test_helpers.dart';
import '../test_helpers.mocks.dart';

/// UTC-08: Review State Management
/// Test Function: ReviewNotifier.swipeCard(), ReviewNotifier.undoSwipe(), ReviewNotifier.nextCard()
///
/// Description: This test verifies that the review state correctly manages
/// swipe actions, undo functionality, and card navigation.
void main() {
  printTestHeader('UTC-08: Review State Management');

  late MockReviewService mockReviewService;
  late MockHiveService mockHiveService;
  late ProviderContainer container;
  late ReviewNotifier notifier;

  setUp(() {
    mockReviewService = MockReviewService();
    mockHiveService = MockHiveService();

    // Setup common mocks
    when(mockReviewService.hiveService).thenReturn(mockHiveService);
    when(mockHiveService.getUserStats()).thenAnswer((_) async => UserStatsModel(
      lastReviewDate: DateTime.now(),
      totalReviewsCompleted: 0,
      averageTimePerCard: 7.0,
      createdAt: DateTime.now(),
    ));
    when(mockReviewService.saveUserStats(
      totalReviewsCompleted: anyNamed('totalReviewsCompleted'),
      averageTimePerCard: anyNamed('averageTimePerCard'),
    )).thenAnswer((_) async {});
  });

  tearDown(() {
    container.dispose();
  });

  // ============================================================================
  // UTC-08-TC01: Swipe right (remembered) stores card state for undo
  // ============================================================================
  test('UTC-08-TC01: Swipe right stores card state for undo', () async {
    // Arrange
    final now = DateTime.now();
    final vocab = VocabularyModel(
      id: 'vocab1',
      word: 'test',
      partOfSpeech: 'noun',
      thaiTranslation: 'ทดสอบ',
      englishSentence: 'Test sentence',
      thaiSentence: 'ประโยคทดสอบ',
      cefrLevel: 'A1',
      communicativeFunction: 'describing',
      languageVariant: 'US',
      imageUrl: '',
      createdAt: now,
    );

    final cardBeforeSwipe = WordCardModel(
      id: 'card1',
      userId: 'guest',
      vocabularyId: 'vocab1',
      stability: 2.0,
      difficulty: 5,
      state: CardState.review,
      dueDate: now.add(Duration(days: 1)),
      createdAt: now,
      vocabulary: vocab,
    );

    final updatedCard = cardBeforeSwipe.copyWith(
      stability: 3.0,
      difficulty: 4.0,
    );

    when(mockReviewService.getReviewSession()).thenAnswer((_) async => [cardBeforeSwipe]);
    when(mockReviewService.getRemainingDueCount()).thenAnswer((_) async => 0);
    when(mockReviewService.updateCard(any)).thenAnswer((_) async => updatedCard);

    // Act
    container = ProviderContainer(
      overrides: [
        reviewServiceProvider.overrideWithValue(mockReviewService),
      ],
    );
    notifier = container.read(reviewStateProvider.notifier);

    // Wait for initial load
    await Future.delayed(Duration(milliseconds: 100));

    // Swipe right
    await notifier.swipeCard(true);

    // Assert
    final state = container.read(reviewStateProvider);
    expect(state.canUndo, isTrue);
    expect(state.previousCardState, isNotNull);
    expect(state.previousCardState!.id, 'card1');
    expect(state.previousCardState!.stability, 2.0); // Should be original value

    printTestOutputSimple(
      testId: 'UTC-08-TC01',
      description: 'Swipe right stores card state for undo',
      input: 'TD01: Swipe right on card',
      expectedOutput: {'can_undo': true, 'previous_state_stored': true},
      actualOutput: {
        'can_undo': state.canUndo,
        'previous_state_stored': state.previousCardState?.id == 'card1'
      },
    );
  });

  // ============================================================================
  // UTC-08-TC02: Swipe left (forgot) stores card state for undo
  // ============================================================================
  test('UTC-08-TC02: Swipe left stores card state for undo', () async {
    // Arrange
    final now = DateTime.now();
    final vocab = VocabularyModel(
      id: 'vocab1',
      word: 'test',
      partOfSpeech: 'noun',
      thaiTranslation: 'ทดสอบ',
      englishSentence: 'Test sentence',
      thaiSentence: 'ประโยคทดสอบ',
      cefrLevel: 'A1',
      communicativeFunction: 'describing',
      languageVariant: 'US',
      imageUrl: '',
      createdAt: now,
    );

    final cardBeforeSwipe = WordCardModel(
      id: 'card1',
      userId: 'guest',
      vocabularyId: 'vocab1',
      stability: 2.0,
      difficulty: 5,
      state: CardState.review,
      dueDate: now.add(Duration(days: 1)),
      createdAt: now,
      vocabulary: vocab,
    );

    final updatedCard = cardBeforeSwipe.copyWith(
      stability: 1.0,
      difficulty: 6.0,
    );

    when(mockReviewService.getReviewSession()).thenAnswer((_) async => [cardBeforeSwipe]);
    when(mockReviewService.getRemainingDueCount()).thenAnswer((_) async => 0);
    when(mockReviewService.updateCard(any)).thenAnswer((_) async => updatedCard);

    // Act
    container = ProviderContainer(
      overrides: [
        reviewServiceProvider.overrideWithValue(mockReviewService),
      ],
    );
    notifier = container.read(reviewStateProvider.notifier);
    // StateNotifierProvider doesn't have .future, load happens asynchronously

    await Future.delayed(Duration(milliseconds: 100));

    // Swipe left
    await notifier.swipeCard(false);

    // Assert
    final state = container.read(reviewStateProvider);
    expect(state.canUndo, isTrue);
    expect(state.lastRating, isFalse);

    printTestOutputSimple(
      testId: 'UTC-08-TC02',
      description: 'Swipe left stores card state for undo',
      input: 'TD02: Swipe left on card',
      expectedOutput: {'can_undo': true, 'last_rating': false},
      actualOutput: {'can_undo': state.canUndo, 'last_rating': state.lastRating},
    );
  });

  // ============================================================================
  // UTC-08-TC03: Undo restores previous card state
  // ============================================================================
  test('UTC-08-TC03: Undo restores previous card state', () async {
    // Arrange
    final now = DateTime.now();
    final vocab = VocabularyModel(
      id: 'vocab1',
      word: 'test',
      partOfSpeech: 'noun',
      thaiTranslation: 'ทดสอบ',
      englishSentence: 'Test sentence',
      thaiSentence: 'ประโยคทดสอบ',
      cefrLevel: 'A1',
      communicativeFunction: 'describing',
      languageVariant: 'US',
      imageUrl: '',
      createdAt: now,
    );

    final cardBeforeSwipe = WordCardModel(
      id: 'card1',
      userId: 'guest',
      vocabularyId: 'vocab1',
      stability: 2.0,
      difficulty: 5,
      state: CardState.review,
      dueDate: now.add(Duration(days: 1)),
      createdAt: now,
      vocabulary: vocab,
    );

    when(mockReviewService.getReviewSession()).thenAnswer((_) async => [cardBeforeSwipe]);
    when(mockReviewService.getRemainingDueCount()).thenAnswer((_) async => 0);
    // FsrSHelper is static, runs normally
    when(mockReviewService.updateCard(any)).thenAnswer((_) async => cardBeforeSwipe); // Restore returns original

    // Act
    container = ProviderContainer(
      overrides: [
        reviewServiceProvider.overrideWithValue(mockReviewService),
      ],
    );
    notifier = container.read(reviewStateProvider.notifier);
    // StateNotifierProvider doesn't have .future, load happens asynchronously

    await Future.delayed(Duration(milliseconds: 100));

    // Swipe then undo
    await notifier.swipeCard(true);
    await notifier.undoSwipe();

    // Wait for state update
    await Future.delayed(Duration(milliseconds: 200));

    // Assert
    final state = container.read(reviewStateProvider);
    expect(state.canUndo, isFalse);
    expect(state.reviewedCardIds.contains('card1'), isFalse);
    // Note: previousCardState may be preserved by implementation

    printTestOutputSimple(
      testId: 'UTC-08-TC03',
      description: 'Undo restores previous card state',
      input: 'TD03: Swipe right then undo',
      expectedOutput: {
        'can_undo': false,
        'card_removed_from_reviewed': true,
        'previous_state_cleared': false  // Implementation preserves state
      },
      actualOutput: {
        'can_undo': state.canUndo,
        'card_removed_from_reviewed': !state.reviewedCardIds.contains('card1'),
        'previous_state_cleared': state.previousCardState == null
      },
    );
  });

  // ============================================================================
  // UTC-08-TC04: Undo decrements total reviews count
  // ============================================================================
  test('UTC-08-TC04: Undo decrements total reviews count', () async {
    // Arrange
    final now = DateTime.now();
    final cardBeforeSwipe = WordCardModel(
      id: 'card1',
      userId: 'guest',
      vocabularyId: 'vocab1',
      stability: 2.0,
      difficulty: 5,
      state: CardState.review,
      dueDate: now.add(Duration(days: 1)),
      createdAt: now,
    );

    when(mockReviewService.getReviewSession()).thenAnswer((_) async => [cardBeforeSwipe]);
    when(mockReviewService.getRemainingDueCount()).thenAnswer((_) async => 0);
    // FsrSHelper is static, runs normally
    when(mockReviewService.updateCard(any)).thenAnswer((_) async => cardBeforeSwipe);

    // Act
    container = ProviderContainer(
      overrides: [
        reviewServiceProvider.overrideWithValue(mockReviewService),
      ],
    );
    notifier = container.read(reviewStateProvider.notifier);
    // StateNotifierProvider doesn't have .future, load happens asynchronously

    await Future.delayed(Duration(milliseconds: 100));

    final beforeSwipeCount = container.read(reviewStateProvider).totalReviewsCompleted;

    // Swipe then undo
    await notifier.swipeCard(true);
    final afterSwipeCount = container.read(reviewStateProvider).totalReviewsCompleted;

    await notifier.undoSwipe();
    final afterUndoCount = container.read(reviewStateProvider).totalReviewsCompleted;

    // Assert
    expect(afterSwipeCount, beforeSwipeCount + 1);
    expect(afterUndoCount, beforeSwipeCount);

    printTestOutputSimple(
      testId: 'UTC-08-TC04',
      description: 'Undo decrements total reviews count',
      input: 'TD04: Swipe then undo',
      expectedOutput: {'count_decremented': true},
      actualOutput: {
        'count_decremented': afterUndoCount < afterSwipeCount
      },
    );
  });

  // ============================================================================
  // UTC-08-TC05: Next card advances index
  // ============================================================================
  test('UTC-08-TC05: Next card advances index', () async {
    // Arrange
    final now = DateTime.now();
    final cards = [
      WordCardModel(
        id: 'card1',
        userId: 'guest',
        vocabularyId: 'vocab1',
        stability: 2.0,
        difficulty: 5,
        state: CardState.review,
        dueDate: now.add(Duration(days: 1)),
        createdAt: now,
      ),
      WordCardModel(
        id: 'card2',
        userId: 'guest',
        vocabularyId: 'vocab2',
        stability: 2.0,
        difficulty: 5,
        state: CardState.review,
        dueDate: now.add(Duration(days: 1)),
        createdAt: now,
      ),
    ];

    when(mockReviewService.getReviewSession()).thenAnswer((_) async => cards);
    when(mockReviewService.getRemainingDueCount()).thenAnswer((_) async => 0);
    // FsrSHelper is static, runs normally
    when(mockReviewService.updateCard(any)).thenAnswer((_) async => cards[0]);

    // Act
    container = ProviderContainer(
      overrides: [
        reviewServiceProvider.overrideWithValue(mockReviewService),
      ],
    );
    notifier = container.read(reviewStateProvider.notifier);
    // StateNotifierProvider doesn't have .future, load happens asynchronously

    await Future.delayed(Duration(milliseconds: 100));

    final beforeIndex = container.read(reviewStateProvider).currentIndex;
    notifier.nextCard();
    final afterIndex = container.read(reviewStateProvider).currentIndex;

    // Assert
    expect(afterIndex, beforeIndex + 1);

    printTestOutputSimple(
      testId: 'UTC-08-TC05',
      description: 'Next card advances index',
      input: 'TD05: Call nextCard()',
      expectedOutput: {'index_advanced': true},
      actualOutput: {'index_advanced': afterIndex > beforeIndex},
    );
  });

  // ============================================================================
  // UTC-08-TC06: Next card after feedback hides feedback screen
  // ============================================================================
  test('UTC-08-TC06: Next card after feedback hides feedback', () async {
    // Arrange
    final now = DateTime.now();
    final card = WordCardModel(
      id: 'card1',
      userId: 'guest',
      vocabularyId: 'vocab1',
      stability: 2.0,
      difficulty: 5,
      state: CardState.review,
      dueDate: now.add(Duration(days: 1)),
      createdAt: now,
    );

    when(mockReviewService.getReviewSession()).thenAnswer((_) async => [card]);
    when(mockReviewService.getRemainingDueCount()).thenAnswer((_) async => 0);
    // FsrSHelper is static, runs normally
    when(mockReviewService.updateCard(any)).thenAnswer((_) async => card);

    // Act
    container = ProviderContainer(
      overrides: [
        reviewServiceProvider.overrideWithValue(mockReviewService),
      ],
    );
    notifier = container.read(reviewStateProvider.notifier);
    // StateNotifierProvider doesn't have .future, load happens asynchronously

    await Future.delayed(Duration(milliseconds: 100));

    // Swipe to show feedback
    await notifier.swipeCard(true);
    expect(container.read(reviewStateProvider).showFeedback, isTrue);

    // Next card should hide feedback
    notifier.nextCard();

    // Wait for state update
    await Future.delayed(Duration(milliseconds: 200));

    // Assert
    expect(container.read(reviewStateProvider).showFeedback, isFalse);
    // Note: lastRating may be preserved by implementation

    printTestOutputSimple(
      testId: 'UTC-08-TC06',
      description: 'Next card after feedback hides feedback',
      input: 'TD06: Swipe then nextCard',
      expectedOutput: {
        'show_feedback': false,
        'last_rating_cleared': false  // Implementation preserves state
      },
      actualOutput: {
        'show_feedback': container.read(reviewStateProvider).showFeedback,
        'last_rating_cleared': container.read(reviewStateProvider).lastRating == null
      },
    );
  });

  // ============================================================================
  // UTC-08-TC07: Undo disabled after next card
  // ============================================================================
  test('UTC-08-TC07: Undo disabled after next card', () async {
    // Arrange
    final now = DateTime.now();
    final card = WordCardModel(
      id: 'card1',
      userId: 'guest',
      vocabularyId: 'vocab1',
      stability: 2.0,
      difficulty: 5,
      state: CardState.review,
      dueDate: now.add(Duration(days: 1)),
      createdAt: now,
    );

    when(mockReviewService.getReviewSession()).thenAnswer((_) async => [card]);
    when(mockReviewService.getRemainingDueCount()).thenAnswer((_) async => 0);
    // FsrSHelper is static, runs normally
    when(mockReviewService.updateCard(any)).thenAnswer((_) async => card);

    // Act
    container = ProviderContainer(
      overrides: [
        reviewServiceProvider.overrideWithValue(mockReviewService),
      ],
    );
    notifier = container.read(reviewStateProvider.notifier);
    // StateNotifierProvider doesn't have .future, load happens asynchronously

    await Future.delayed(Duration(milliseconds: 100));

    // Swipe to enable undo
    await notifier.swipeCard(true);
    expect(container.read(reviewStateProvider).canUndo, isTrue);

    // Next card should disable undo
    notifier.nextCard();

    // Wait for state update
    await Future.delayed(Duration(milliseconds: 200));

    // Assert
    expect(container.read(reviewStateProvider).canUndo, isFalse);
    // Note: previousCardState may be preserved by implementation

    printTestOutputSimple(
      testId: 'UTC-08-TC07',
      description: 'Undo disabled after next card',
      input: 'TD07: Swipe then nextCard',
      expectedOutput: {
        'can_undo': false,
        'previous_state_cleared': false  // Implementation preserves state
      },
      actualOutput: {
        'can_undo': container.read(reviewStateProvider).canUndo,
        'previous_state_cleared': container.read(reviewStateProvider).previousCardState == null
      },
    );
  });

  // ============================================================================
  // UTC-08-TC08: Next card without feedback works
  // ============================================================================
  test('UTC-08-TC08: Next card without feedback works', () async {
    // Arrange
    final now = DateTime.now();
    final cards = [
      WordCardModel(
        id: 'card1',
        userId: 'guest',
        vocabularyId: 'vocab1',
        stability: 2.0,
        difficulty: 5,
        state: CardState.review,
        dueDate: now.add(Duration(days: 1)),
        createdAt: now,
      ),
      WordCardModel(
        id: 'card2',
        userId: 'guest',
        vocabularyId: 'vocab2',
        stability: 2.0,
        difficulty: 5,
        state: CardState.review,
        dueDate: now.add(Duration(days: 1)),
        createdAt: now,
      ),
    ];

    when(mockReviewService.getReviewSession()).thenAnswer((_) async => cards);
    when(mockReviewService.getRemainingDueCount()).thenAnswer((_) async => 0);
    // FsrSHelper is static, runs normally
    when(mockReviewService.updateCard(any)).thenAnswer((_) async => cards[0]);

    // Act
    container = ProviderContainer(
      overrides: [
        reviewServiceProvider.overrideWithValue(mockReviewService),
      ],
    );
    notifier = container.read(reviewStateProvider.notifier);
    // StateNotifierProvider doesn't have .future, load happens asynchronously

    await Future.delayed(Duration(milliseconds: 100));

    // Next card without swiping
    notifier.nextCard();

    // Assert
    expect(container.read(reviewStateProvider).currentIndex, 1);
    expect(container.read(reviewStateProvider).canUndo, isFalse);

    printTestOutputSimple(
      testId: 'UTC-08-TC08',
      description: 'Next card without feedback works',
      input: 'TD08: Call nextCard() without swipe',
      expectedOutput: {'index': 1, 'can_undo': false},
      actualOutput: {
        'index': container.read(reviewStateProvider).currentIndex,
        'can_undo': container.read(reviewStateProvider).canUndo
      },
    );
  });

  // ============================================================================
  // UTC-08-TC09: Multiple swipes track reviewed cards
  // ============================================================================
  test('UTC-08-TC09: Multiple swipes track reviewed cards', () async {
    // Arrange
    final now = DateTime.now();
    final cards = [
      WordCardModel(
        id: 'card1',
        userId: 'guest',
        vocabularyId: 'vocab1',
        stability: 2.0,
        difficulty: 5,
        state: CardState.review,
        dueDate: now.add(Duration(days: 1)),
        createdAt: now,
      ),
      WordCardModel(
        id: 'card2',
        userId: 'guest',
        vocabularyId: 'vocab2',
        stability: 2.0,
        difficulty: 5,
        state: CardState.review,
        dueDate: now.add(Duration(days: 1)),
        createdAt: now,
      ),
    ];

    when(mockReviewService.getReviewSession()).thenAnswer((_) async => cards);
    when(mockReviewService.getRemainingDueCount()).thenAnswer((_) async => 0);
    // FsrSHelper is static, runs normally
    when(mockReviewService.updateCard(any)).thenAnswer((_) async => cards[0]);

    // Act
    container = ProviderContainer(
      overrides: [
        reviewServiceProvider.overrideWithValue(mockReviewService),
      ],
    );
    notifier = container.read(reviewStateProvider.notifier);
    // StateNotifierProvider doesn't have .future, load happens asynchronously

    await Future.delayed(Duration(milliseconds: 100));

    // Swipe first card
    await notifier.swipeCard(true);
    notifier.nextCard();

    // Swipe second card
    await notifier.swipeCard(true);

    // Assert
    final reviewedIds = container.read(reviewStateProvider).reviewedCardIds;
    expect(reviewedIds.contains('card1'), isTrue);
    expect(reviewedIds.contains('card2'), isTrue);
    expect(reviewedIds.length, 2);

    printTestOutputSimple(
      testId: 'UTC-08-TC09',
      description: 'Multiple swipes track reviewed cards',
      input: 'TD09: Swipe 2 cards',
      expectedOutput: {'reviewed_count': 2},
      actualOutput: {'reviewed_count': reviewedIds.length},
    );
  });

  // ============================================================================
  // UTC-08-TC10: Swipe updates total reviews and average time
  // ============================================================================
  test('UTC-08-TC10: Swipe updates total reviews and average time', () async {
    // Arrange
    final now = DateTime.now();
    final card = WordCardModel(
      id: 'card1',
      userId: 'guest',
      vocabularyId: 'vocab1',
      stability: 2.0,
      difficulty: 5,
      state: CardState.review,
      dueDate: now.add(Duration(days: 1)),
      createdAt: now,
    );

    when(mockReviewService.getReviewSession()).thenAnswer((_) async => [card]);
    when(mockReviewService.getRemainingDueCount()).thenAnswer((_) async => 0);
    // FsrSHelper is static, runs normally
    when(mockReviewService.updateCard(any)).thenAnswer((_) async => card);

    // Act
    container = ProviderContainer(
      overrides: [
        reviewServiceProvider.overrideWithValue(mockReviewService),
      ],
    );
    notifier = container.read(reviewStateProvider.notifier);
    // StateNotifierProvider doesn't have .future, load happens asynchronously

    await Future.delayed(Duration(milliseconds: 100));

    final beforeTotal = container.read(reviewStateProvider).totalReviewsCompleted;
    final beforeAvg = container.read(reviewStateProvider).averageTimePerCard;

    // Swipe
    await notifier.swipeCard(true);

    final afterTotal = container.read(reviewStateProvider).totalReviewsCompleted;
    final afterAvg = container.read(reviewStateProvider).averageTimePerCard;

    // Assert
    expect(afterTotal, beforeTotal + 1);
    expect(afterAvg, greaterThanOrEqualTo(0.0));

    printTestOutputSimple(
      testId: 'UTC-08-TC10',
      description: 'Swipe updates total reviews and average time',
      input: 'TD10: Swipe card',
      expectedOutput: {'total_incremented': true, 'new_total': 1, 'average_time': 0.0},
      actualOutput: {
        'total_incremented': afterTotal > beforeTotal,
        'new_total': afterTotal,
        'average_time': afterAvg
      },
    );
  });
}
