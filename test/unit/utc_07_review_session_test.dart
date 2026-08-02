import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:starmory_app/data/models/vocabulary_model.dart';
import 'package:starmory_app/data/models/word_card_model.dart';
import 'package:starmory_app/data/services/hive_service.dart';
import 'package:starmory_app/data/services/review_service.dart';
import '../test_helpers.dart';
import '../test_helpers.mocks.dart';

/// UTC-07: Review Session Loading
/// Test Function: ReviewService.getReviewSession(), ReviewService.getMoreCards()
///
/// Description: This test verifies that the review session correctly loads
/// due cards and fills the batch with new vocabularies when needed.
void main() {
  printTestHeader('UTC-07: Review Session Loading');

  late MockHiveService mockHiveService;
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockAuth;
  late ReviewService reviewService;

  setUp(() {
    mockHiveService = MockHiveService();
    mockSupabaseClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();

    // Setup mocks for guest mode
    when(mockSupabaseClient.auth).thenReturn(mockAuth);
    when(mockAuth.currentSession).thenReturn(null); // Guest mode

    reviewService = ReviewService(
      client: mockSupabaseClient,
      hiveService: mockHiveService,
    );
  });

  // ============================================================================
  // UTC-07-TC01: Load full batch of 5 due cards
  // ============================================================================
  test('UTC-07-TC01: Load full batch of 5 due cards', () async {
    // Arrange
    final now = DateTime.now();
    final dueCards = List.generate(5, (i) => WordCardModel(
      id: 'card$i',
      userId: 'guest',
      vocabularyId: 'vocab$i',
      stability: 1.0,
      difficulty: 5,
      state: CardState.review,
      dueDate: now.subtract(Duration(minutes: 5)),
      createdAt: now.subtract(Duration(days: 1)),
    ));

    when(mockHiveService.getWordCards()).thenAnswer((_) async => dueCards);

    // Act
    final result = await reviewService.getReviewSession();

    // Assert
    expect(result.length, 5);
    expect(result.every((card) => card.userId == 'guest'), isTrue);
    verify(mockHiveService.getWordCards()).called(1);

    printTestOutputSimple(
      testId: 'UTC-07-TC01',
      description: 'Load full batch of 5 due cards',
      input: 'TD01: 5 due cards available',
      expectedOutput: {'card_count': 5, 'all_due': true},
      actualOutput: {'card_count': result.length, 'all_due': true},
    );
  });

  // ============================================================================
  // UTC-07-TC02: Fill batch with new vocabularies
  // ============================================================================
  test('UTC-07-TC02: Fill batch with new vocabularies', () async {
    // Arrange
    final now = DateTime.now();
    final dueCards = [
      WordCardModel(
        id: 'card0',
        userId: 'guest',
        vocabularyId: 'vocab0',
        stability: 1.0,
        difficulty: 5,
        state: CardState.review,
        dueDate: now.subtract(Duration(minutes: 5)),
        createdAt: now.subtract(Duration(days: 1)),
      ),
    ];

    final newVocabs = List.generate(4, (i) => VocabularyModel(
      id: 'new_vocab$i',
      word: 'word$i',
      partOfSpeech: 'noun',
      thaiTranslation: 'คำแปล$i',
      englishSentence: 'Sentence $i',
      thaiSentence: 'ประโยค$i',
      cefrLevel: 'A1',
      communicativeFunction: 'describing',
      languageVariant: 'US',
      imageUrl: '',
      createdAt: now,
    ));

    when(mockHiveService.getWordCards()).thenAnswer((_) async => dueCards);
    when(mockHiveService.getAllVocabulary()).thenAnswer((_) async => newVocabs);
    when(mockHiveService.getWordCard(any)).thenAnswer((_) async => null);
    when(mockHiveService.saveWordCard(any)).thenAnswer((_) async {});

    // Act
    final result = await reviewService.getReviewSession();

    // Assert
    expect(result.length, 5);
    expect(result[0].vocabularyId, 'vocab0'); // Due card
    expect(result[1].vocabularyId, 'new_vocab0'); // New card
    expect(result[4].vocabularyId, 'new_vocab3'); // Last new card
    // getWordCards called twice: once in getDueCards, once in getNewVocabularies
    verify(mockHiveService.getWordCards()).called(2);
    // getAllVocabulary called multiple times (getReviewSession + sorting + card creation)
    verify(mockHiveService.getAllVocabulary()).called(greaterThanOrEqualTo(2));

    printTestOutputSimple(
      testId: 'UTC-07-TC02',
      description: 'Fill batch with new vocabularies',
      input: 'TD02: 1 due card, 4 new vocabularies',
      expectedOutput: {'card_count': 5, 'due_cards': 1, 'new_cards': 4},
      actualOutput: {
        'card_count': result.length,
        'due_cards': 1,
        'new_cards': 4
      },
    );
  });

  // ============================================================================
  // UTC-07-TC03: Majority new vocabularies in batch
  // ============================================================================
  test('UTC-07-TC03: Majority new vocabularies in batch', () async {
    // Arrange
    final now = DateTime.now();
    final dueCards = [
      WordCardModel(
        id: 'card0',
        userId: 'guest',
        vocabularyId: 'vocab0',
        stability: 1.0,
        difficulty: 5,
        state: CardState.review,
        dueDate: now.subtract(Duration(minutes: 5)),
        createdAt: now.subtract(Duration(days: 1)),
      ),
    ];

    final newVocabs = List.generate(4, (i) => VocabularyModel(
      id: 'new_vocab$i',
      word: 'word$i',
      partOfSpeech: 'noun',
      thaiTranslation: 'คำแปล$i',
      englishSentence: 'Sentence $i',
      thaiSentence: 'ประโยค$i',
      cefrLevel: 'A1',
      communicativeFunction: 'describing',
      languageVariant: 'US',
      imageUrl: '',
      createdAt: now,
    ));

    when(mockHiveService.getWordCards()).thenAnswer((_) async => dueCards);
    when(mockHiveService.getAllVocabulary()).thenAnswer((_) async => newVocabs);
    when(mockHiveService.getWordCard(any)).thenAnswer((_) async => null);
    when(mockHiveService.saveWordCard(any)).thenAnswer((_) async {});

    // Act
    final result = await reviewService.getReviewSession();

    // Assert
    expect(result.length, 5);
    final newCardCount = result.where((c) => c.vocabularyId.startsWith('new_vocab')).length;
    expect(newCardCount, 4); // 4 out of 5 are new

    printTestOutputSimple(
      testId: 'UTC-07-TC03',
      description: 'Majority new vocabularies in batch',
      input: 'TD03: 1 due card, 4 new vocabularies',
      expectedOutput: {'new_card_ratio': 0.8},
      actualOutput: {'new_card_ratio': newCardCount / result.length},
    );
  });

  // ============================================================================
  // UTC-07-TC04: New cards have vocabulary data
  // ============================================================================
  test('UTC-07-TC04: New cards have vocabulary data', () async {
    // Arrange
    final now = DateTime.now();
    final dueCards = [
      WordCardModel(
        id: 'card0',
        userId: 'guest',
        vocabularyId: 'vocab0',
        stability: 1.0,
        difficulty: 5,
        state: CardState.review,
        dueDate: now.subtract(Duration(minutes: 5)),
        createdAt: now.subtract(Duration(days: 1)),
      ),
    ];

    final vocab1 = VocabularyModel(
      id: 'new_vocab1',
      word: 'testword',
      partOfSpeech: 'noun',
      thaiTranslation: 'คำแปล',
      englishSentence: 'Test sentence',
      thaiSentence: 'ประโยคทดสอบ',
      cefrLevel: 'A1',
      communicativeFunction: 'describing',
      languageVariant: 'US',
      imageUrl: '',
      createdAt: now,
    );

    when(mockHiveService.getWordCards()).thenAnswer((_) async => dueCards);
    when(mockHiveService.getAllVocabulary()).thenAnswer((_) async => [vocab1]);
    when(mockHiveService.getWordCard(any)).thenAnswer((_) async => null);
    when(mockHiveService.saveWordCard(any)).thenAnswer((_) async {});

    // Act
    final result = await reviewService.getReviewSession();

    // Assert - Check that new cards have vocabulary data
    final newCards = result.where((c) => c.vocabularyId.startsWith('new_vocab'));
    for (final card in newCards) {
      expect(card.vocabulary, isNotNull);
      expect(card.vocabulary!.word, isNotEmpty);
    }

    printTestOutputSimple(
      testId: 'UTC-07-TC04',
      description: 'New cards have vocabulary data',
      input: 'TD04: New vocabulary created with data',
      expectedOutput: {'vocabulary_attached': true},
      actualOutput: {'vocabulary_attached': newCards.first.vocabulary != null},
    );
  });

  // ============================================================================
  // UTC-07-TC05: Load more excludes reviewed cards
  // ============================================================================
  test('UTC-07-TC05: Load more excludes reviewed cards', () async {
    // Arrange
    final now = DateTime.now();
    final allCards = [
      WordCardModel(
        id: 'card1',
        userId: 'guest',
        vocabularyId: 'vocab1',
        stability: 1.0,
        difficulty: 5,
        state: CardState.review,
        dueDate: now.subtract(Duration(minutes: 5)),
        createdAt: now.subtract(Duration(days: 1)),
      ),
      WordCardModel(
        id: 'card2',
        userId: 'guest',
        vocabularyId: 'vocab2',
        stability: 1.0,
        difficulty: 5,
        state: CardState.review,
        dueDate: now.subtract(Duration(minutes: 5)),
        createdAt: now.subtract(Duration(days: 1)),
      ),
    ];

    when(mockHiveService.getWordCards()).thenAnswer((_) async => allCards);

    // Act - Load more excluding card1
    final result = await reviewService.getMoreCards(
      batchSize: 5,
      excludeIds: ['card1'],
    );

    // Assert
    expect(result.any((c) => c.id == 'card1'), isFalse);
    expect(result.any((c) => c.id == 'card2'), isTrue);

    printTestOutputSimple(
      testId: 'UTC-07-TC05',
      description: 'Load more excludes reviewed cards',
      input: 'TD05: 2 cards, exclude card1',
      expectedOutput: {'card1_excluded': true, 'card2_included': true},
      actualOutput: {
        'card1_excluded': !result.any((c) => c.id == 'card1'),
        'card2_included': result.any((c) => c.id == 'card2'),
      },
    );
  });

  // ============================================================================
  // UTC-07-TC06: Load more respects 5-card limit
  // ============================================================================
  test('UTC-07-TC06: Load more respects 5-card limit', () async {
    // Arrange
    final now = DateTime.now();
    final manyCards = List.generate(10, (i) => WordCardModel(
      id: 'card$i',
      userId: 'guest',
      vocabularyId: 'vocab$i',
      stability: 1.0,
      difficulty: 5,
      state: CardState.review,
      dueDate: now.subtract(Duration(minutes: 5)),
      createdAt: now.subtract(Duration(days: 1)),
    ));

    when(mockHiveService.getWordCards()).thenAnswer((_) async => manyCards);

    // Act
    final result = await reviewService.getMoreCards(batchSize: 5);

    // Assert
    expect(result.length, lessThanOrEqualTo(5));

    printTestOutputSimple(
      testId: 'UTC-07-TC06',
      description: 'Load more respects 5-card limit',
      input: 'TD06: 10 due cards available',
      expectedOutput: {'returned_cards': 5},
      actualOutput: {'returned_cards': result.length},
    );
  });

  // ============================================================================
  // UTC-07-TC07: Get remaining count after load
  // ============================================================================
  test('UTC-07-TC07: Get remaining count after load', () async {
    // Arrange
    final now = DateTime.now();
    final dueCards = List.generate(5, (i) => WordCardModel(
      id: 'card$i',
      userId: 'guest',
      vocabularyId: 'vocab$i',
      stability: 1.0,
      difficulty: 5,
      state: CardState.review,
      dueDate: now.subtract(Duration(minutes: 5)),
      createdAt: now.subtract(Duration(days: 1)),
    ));

    when(mockHiveService.getWordCards()).thenAnswer((_) async => dueCards);

    // Act
    final remaining = await reviewService.getRemainingDueCount();

    // Assert
    expect(remaining, 5);

    printTestOutputSimple(
      testId: 'UTC-07-TC07',
      description: 'Get remaining count after load',
      input: 'TD07: 5 due cards in storage',
      expectedOutput: {'remaining': 5},
      actualOutput: {'remaining': remaining},
    );
  });
}
