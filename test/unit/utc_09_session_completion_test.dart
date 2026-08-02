import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:starmory_app/data/models/user_stats_model.dart';
import 'package:starmory_app/data/models/vocabulary_model.dart';
import 'package:starmory_app/data/models/word_card_model.dart';
import 'package:starmory_app/data/services/hive_service.dart';
import 'package:starmory_app/data/services/review_service.dart';
import 'package:starmory_app/presentation/providers/review_provider.dart';
import '../test_helpers.dart';
import '../test_helpers.mocks.dart';

/// UTC-09: Session Completion Logic
/// Test Function: ReviewNotifier.loadSession(), ReviewState.isComplete
///
/// Description: This test verifies that the review session correctly detects
/// completion and handles load more functionality.
void main() {
  printTestHeader('UTC-09: Session Completion Logic');

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
  // UTC-09-TC01: Session not complete when cards remain
  // ============================================================================
  test('UTC-09-TC01: Session not complete when cards remain', () async {
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

    // Act
    container = ProviderContainer(
      overrides: [
        reviewServiceProvider.overrideWithValue(mockReviewService),
      ],
    );
    notifier = container.read(reviewStateProvider.notifier);
    await Future.delayed(Duration(milliseconds: 100));

    // Assert
    final state = container.read(reviewStateProvider);
    expect(state.isComplete, isFalse);
    expect(state.currentIndex, 0);
    expect(state.remainingCards, 2);

    printTestOutputSimple(
      testId: 'UTC-09-TC01',
      description: 'Session not complete when cards remain',
      input: 'TD01: 2 cards loaded, index at 0',
      expectedOutput: {'is_complete': false, 'remaining': 2},
      actualOutput: {
        'is_complete': state.isComplete,
        'remaining': state.remainingCards
      },
    );
  });

  // ============================================================================
  // UTC-09-TC02: Session complete when all cards reviewed
  // ============================================================================
  test('UTC-09-TC02: Session complete when all cards reviewed', () async {
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
    ];

    when(mockReviewService.getReviewSession()).thenAnswer((_) async => cards);
    when(mockReviewService.getRemainingDueCount()).thenAnswer((_) async => 0);
    when(mockReviewService.updateCard(any)).thenAnswer((_) async => cards[0]);

    // Act
    container = ProviderContainer(
      overrides: [
        reviewServiceProvider.overrideWithValue(mockReviewService),
      ],
    );
    notifier = container.read(reviewStateProvider.notifier);
    await Future.delayed(Duration(milliseconds: 100));

    // Swipe card
    await notifier.swipeCard(true);
    notifier.nextCard();

    await Future.delayed(Duration(milliseconds: 50));

    // Assert
    final state = container.read(reviewStateProvider);
    expect(state.isComplete, isTrue);
    expect(state.currentIndex, 1); // Moved past last card

    printTestOutputSimple(
      testId: 'UTC-09-TC02',
      description: 'Session complete when all cards reviewed',
      input: 'TD02: 1 card, reviewed and moved past',
      expectedOutput: {'is_complete': true},
      actualOutput: {'is_complete': state.isComplete},
    );
  });

  // ============================================================================
  // UTC-09-TC03: Session complete immediately when no cards
  // ============================================================================
  test('UTC-09-TC03: Session complete immediately when no cards', () async {
    // Arrange
    when(mockReviewService.getReviewSession()).thenAnswer((_) async => []);
    when(mockReviewService.getRemainingDueCount()).thenAnswer((_) async => 0);

    // Act
    container = ProviderContainer(
      overrides: [
        reviewServiceProvider.overrideWithValue(mockReviewService),
      ],
    );
    notifier = container.read(reviewStateProvider.notifier);
    await Future.delayed(Duration(milliseconds: 100));

    // Assert
    final state = container.read(reviewStateProvider);
    expect(state.isComplete, isTrue);
    expect(state.cards.length, 0);

    printTestOutputSimple(
      testId: 'UTC-09-TC03',
      description: 'Session complete immediately when no cards',
      input: 'TD03: No cards available',
      expectedOutput: {'is_complete': true, 'card_count': 0},
      actualOutput: {
        'is_complete': state.isComplete,
        'card_count': state.cards.length
      },
    );
  });

  // ============================================================================
  // UTC-09-TC04: Load more adds cards to session
  // ============================================================================
  test('UTC-09-TC04: Load more adds cards to session', () async {
    // Arrange
    final now = DateTime.now();
    final initialCards = [
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
    ];

    final moreCards = [
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
      WordCardModel(
        id: 'card3',
        userId: 'guest',
        vocabularyId: 'vocab3',
        stability: 2.0,
        difficulty: 5,
        state: CardState.review,
        dueDate: now.add(Duration(days: 1)),
        createdAt: now,
      ),
    ];

    when(mockReviewService.getReviewSession()).thenAnswer((_) async => initialCards);
    when(mockReviewService.getRemainingDueCount()).thenAnswer((_) async => 5);
    when(mockReviewService.getMoreCards(excludeIds: anyNamed('excludeIds')))
        .thenAnswer((_) async => moreCards);

    // Act
    container = ProviderContainer(
      overrides: [
        reviewServiceProvider.overrideWithValue(mockReviewService),
      ],
    );
    notifier = container.read(reviewStateProvider.notifier);
    await Future.delayed(Duration(milliseconds: 100));

    final beforeLoad = container.read(reviewStateProvider).cards.length;

    await notifier.loadMore();
    await Future.delayed(Duration(milliseconds: 100));

    final afterLoad = container.read(reviewStateProvider).cards.length;

    // Assert
    expect(afterLoad, greaterThan(beforeLoad));
    expect(container.read(reviewStateProvider).remainingDueCount, 5);

    printTestOutputSimple(
      testId: 'UTC-09-TC04',
      description: 'Load more adds cards to session',
      input: 'TD04: Initial 1 card, load 2 more',
      expectedOutput: {
        'cards_added': true,
        'total_cards': 3
      },
      actualOutput: {
        'cards_added': afterLoad > beforeLoad,
        'total_cards': afterLoad
      },
    );
  });

  // ============================================================================
  // UTC-09-TC05: Load more excludes reviewed cards
  // ============================================================================
  test('UTC-09-TC05: Load more excludes reviewed cards', () async {
    // Arrange
    final now = DateTime.now();
    final initialCards = [
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
    ];

    final moreCards = [
      WordCardModel(
        id: 'card3',
        userId: 'guest',
        vocabularyId: 'vocab3',
        stability: 2.0,
        difficulty: 5,
        state: CardState.review,
        dueDate: now.add(Duration(days: 1)),
        createdAt: now,
      ),
    ];

    when(mockReviewService.getReviewSession()).thenAnswer((_) async => initialCards);
    when(mockReviewService.getRemainingDueCount()).thenAnswer((_) async => 5);
    when(mockReviewService.getMoreCards(excludeIds: ['card1']))
        .thenAnswer((_) async => moreCards);
    when(mockReviewService.updateCard(any)).thenAnswer((_) async => initialCards[0]);

    // Act
    container = ProviderContainer(
      overrides: [
        reviewServiceProvider.overrideWithValue(mockReviewService),
      ],
    );
    notifier = container.read(reviewStateProvider.notifier);
    await Future.delayed(Duration(milliseconds: 100));

    // Swipe first card
    await notifier.swipeCard(true);
    await Future.delayed(Duration(milliseconds: 50));

    final reviewedIds = container.read(reviewStateProvider).reviewedCardIds;
    expect(reviewedIds.contains('card1'), isTrue);

    // Load more (should exclude card1)
    await notifier.loadMore();
    await Future.delayed(Duration(milliseconds: 100));

    final loadedCards = container.read(reviewStateProvider).cards;

    // Assert
    expect(loadedCards.any((c) => c.id == 'card1'), isTrue); // Original card still there
    expect(loadedCards.any((c) => c.id == 'card3'), isTrue); // New card added

    printTestOutputSimple(
      testId: 'UTC-09-TC05',
      description: 'Load more excludes reviewed cards',
      input: 'TD05: Reviewed card1, load more excludes it',
      expectedOutput: {
        'reviewed_tracked': true,
        'new_cards_loaded': true
      },
      actualOutput: {
        'reviewed_tracked': reviewedIds.contains('card1'),
        'new_cards_loaded': loadedCards.any((c) => c.id == 'card3')
      },
    );
  });

  // ============================================================================
  // UTC-09-TC06: Load more when no cards returns empty
  // ============================================================================
  test('UTC-09-TC06: Load more when no cards returns empty', () async {
    // Arrange
    when(mockReviewService.getReviewSession()).thenAnswer((_) async => []);
    when(mockReviewService.getRemainingDueCount()).thenAnswer((_) async => 0);
    when(mockReviewService.getMoreCards(excludeIds: anyNamed('excludeIds')))
        .thenAnswer((_) async => []);

    // Act
    container = ProviderContainer(
      overrides: [
        reviewServiceProvider.overrideWithValue(mockReviewService),
      ],
    );
    notifier = container.read(reviewStateProvider.notifier);
    await Future.delayed(Duration(milliseconds: 100));

    await notifier.loadMore();
    await Future.delayed(Duration(milliseconds: 100));

    // Assert
    final state = container.read(reviewStateProvider);
    expect(state.cards.length, 0);
    expect(state.remainingDueCount, 0);
    expect(state.isComplete, isTrue);

    printTestOutputSimple(
      testId: 'UTC-09-TC06',
      description: 'Load more when no cards returns empty',
      input: 'TD06: No cards available',
      expectedOutput: {'cards_loaded': 0, 'is_complete': true},
      actualOutput: {
        'cards_loaded': state.cards.length,
        'is_complete': state.isComplete
      },
    );
  });
}
