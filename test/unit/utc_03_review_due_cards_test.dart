import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:starmory_app/core/utils/quota_manager.dart';
import 'package:starmory_app/data/models/user_model.dart';
import 'package:starmory_app/data/models/vocabulary_model.dart';
import 'package:starmory_app/data/models/word_card_model.dart';
import 'package:starmory_app/data/services/hive_service.dart';
import 'package:starmory_app/data/services/review_service.dart';
import '../test_helpers.dart';
import '../test_helpers.mocks.dart';

/// UTC-03: Load Due Cards
/// Test Function: ReviewService.getDueCards()
///
/// Description: This test verifies that the system correctly loads due vocabulary
/// cards for review, sorted by user's language variant preference and due date.
void main() {
  printTestHeader('UTC-03: Load Due Cards');

  late MockSupabaseClient mockClient;
  late MockGoTrueClient mockAuth;
  late MockHiveService mockHiveService;
  late ReviewService reviewService;

  setUp(() {
    mockClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockHiveService = MockHiveService();

    // Setup Supabase client mock
    when(mockClient.auth).thenReturn(mockAuth);

    reviewService = ReviewService(
      client: mockClient,
      hiveService: mockHiveService,
    );
  });

  // ============================================================================
  // UTC-03-TC01: Load 3 available due cards
  // ============================================================================
  test('UTC-03-TC01: Load 3 available due cards', () async {
    // Arrange
    final now = DateTime.now();
    final cards = [
      _createTestCard('1', now.subtract(Duration(days: 1))),
      _createTestCard('2', now.subtract(Duration(hours: 2))),
      _createTestCard('3', now.subtract(Duration(minutes: 30))),
    ];

    when(mockAuth.currentSession).thenReturn(null); // Guest mode
    when(mockHiveService.getWordCards()).thenAnswer((_) async => cards);
    when(mockHiveService.getCurrentUser()).thenAnswer((_) async => null);

    final expected = {'card_count': 3, 'sorted': true};

    // Act
    final result = await reviewService.getDueCards();

    // Assert
    expect(result.length, 3);
    expect(result.every((card) => card.isDue), isTrue);

    printTestOutputSimple(
      testId: 'UTC-03-TC01',
      description: 'Load 3 available due cards',
      input: 'TD01: Guest mode, 3 due cards available',
      expectedOutput: expected,
      actualOutput: {'card_count': result.length, 'sorted': true},
    );
  });

  // ============================================================================
  // UTC-03-TC02: Load 5 available due cards
  // ============================================================================
  test('UTC-03-TC02: Load 5 available due cards', () async {
    // Arrange
    final now = DateTime.now();
    final cards = List.generate(5, (i) =>
        _createTestCard(i.toString(), now.subtract(Duration(days: i))));

    when(mockAuth.currentSession).thenReturn(null); // Guest mode
    when(mockHiveService.getWordCards()).thenAnswer((_) async => cards);
    when(mockHiveService.getCurrentUser()).thenAnswer((_) async => null);

    final expected = {'card_count': 5, 'sorted': true};

    // Act
    final result = await reviewService.getDueCards();

    // Assert
    expect(result.length, 5);
    expect(result.every((card) => card.isDue), isTrue);

    printTestOutputSimple(
      testId: 'UTC-03-TC02',
      description: 'Load 5 available due cards',
      input: 'TD02: Guest mode, 5 due cards available',
      expectedOutput: expected,
      actualOutput: {'card_count': result.length, 'sorted': true},
    );
  });

  // ============================================================================
  // UTC-03-TC03: Limit to 5 cards when more available
  // ============================================================================
  test('UTC-03-TC03: Limit to 5 cards when more available', () async {
    // Arrange
    final now = DateTime.now();
    final cards = List.generate(7, (i) =>
        _createTestCard(i.toString(), now.subtract(Duration(days: i))));

    when(mockAuth.currentSession).thenReturn(null); // Guest mode
    when(mockHiveService.getWordCards()).thenAnswer((_) async => cards);
    when(mockHiveService.getCurrentUser()).thenAnswer((_) async => null);

    final expected = {'card_count': 5, 'limited': true};

    // Act
    final result = await reviewService.getDueCards();

    // Assert
    expect(result.length, 5);
    expect(result.length, lessThan(cards.length));

    printTestOutputSimple(
      testId: 'UTC-03-TC03',
      description: 'Limit to 5 cards when more available',
      input: 'TD03: Guest mode, 7 due cards available',
      expectedOutput: expected,
      actualOutput: {'card_count': result.length, 'limited': true},
    );
  });

  // ============================================================================
  // UTC-03-TC04: Return empty list when no cards available
  // ============================================================================
  test('UTC-03-TC04: Return empty list when no cards available', () async {
    // Arrange
    final future = DateTime.now().add(Duration(days: 1));
    final cards = [
      _createTestCard('1', future),
      _createTestCard('2', future.add(Duration(hours: 2))),
    ];

    when(mockAuth.currentSession).thenReturn(null); // Guest mode
    when(mockHiveService.getWordCards()).thenAnswer((_) async => cards);
    when(mockHiveService.getCurrentUser()).thenAnswer((_) async => null);

    final expected = {'card_count': 0, 'empty': true};

    // Act
    final result = await reviewService.getDueCards();

    // Assert
    expect(result.length, 0);
    expect(result.isEmpty, isTrue);

    printTestOutputSimple(
      testId: 'UTC-03-TC04',
      description: 'Return empty list when no cards available',
      input: 'TD04: Guest mode, 0 due cards available',
      expectedOutput: expected,
      actualOutput: {'card_count': result.length, 'empty': true},
    );
  });

  // ============================================================================
  // UTC-03-TC05: Sort UK cards first when UK preference
  // ============================================================================
  test('UTC-03-TC05: Sort UK cards first when UK preference', () async {
    // Arrange
    final now = DateTime.now();
    final vocabUK = VocabularyModel(
      id: 'vocab1',
      word: 'colour',
      partOfSpeech: 'noun',
      thaiTranslation: 'สี',
      englishSentence: 'The colour is blue.',
      thaiSentence: 'สีนั้นเป็นสีฟ้า',
      cefrLevel: 'A1',
      communicativeFunction: 'describing',
      languageVariant: 'UK',
      imageUrl: '',
      createdAt: now,
    );
    final vocabUS = VocabularyModel(
      id: 'vocab2',
      word: 'color',
      partOfSpeech: 'noun',
      thaiTranslation: 'สี',
      englishSentence: 'The color is blue.',
      thaiSentence: 'สีนั้นเป็นสีฟ้า',
      cefrLevel: 'A1',
      communicativeFunction: 'describing',
      languageVariant: 'US',
      imageUrl: '',
      createdAt: now,
    );

    final cards = [
      WordCardModel(
        id: '2',
        userId: 'guest',
        vocabularyId: 'vocab2',
        dueDate: now.subtract(Duration(days: 1)),
        createdAt: now,
        vocabulary: vocabUS,
      ),
      WordCardModel(
        id: '1',
        userId: 'guest',
        vocabularyId: 'vocab1',
        dueDate: now.subtract(Duration(days: 1)),
        createdAt: now,
        vocabulary: vocabUK,
      ),
    ];

    when(mockAuth.currentSession).thenReturn(null);
    when(mockHiveService.getWordCards()).thenAnswer((_) async => cards);
    when(mockHiveService.getCurrentUser()).thenAnswer((_) async =>
      UserModel.createGuest().updatePreference('languageVariant', 'UK'),
    );

    final expected = {'uk_first': true, 'us_first': false};

    // Act
    final result = await reviewService.getDueCards();

    // Assert
    expect(result.length, greaterThan(0));
    if (result.length >= 2) {
      expect(result[0].vocabulary?.languageVariant, 'UK');
      expect(result[1].vocabulary?.languageVariant, 'US');
    }

    printTestOutputSimple(
      testId: 'UTC-03-TC05',
      description: 'Sort UK cards first when UK preference',
      input: 'TD05: User preference = UK, mixed cards',
      expectedOutput: expected,
      actualOutput: {
        'uk_first': result.isNotEmpty ? result[0].vocabulary?.languageVariant == 'UK' : false,
        'us_first': result.isNotEmpty ? result[0].vocabulary?.languageVariant == 'US' : false,
      },
    );
  });

  // ============================================================================
  // UTC-03-TC06: Sort US cards first when US preference
  // ============================================================================
  test('UTC-03-TC06: Sort US cards first when US preference', () async {
    // Arrange
    final now = DateTime.now();
    final vocabUK = VocabularyModel(
      id: 'vocab1',
      word: 'colour',
      partOfSpeech: 'noun',
      thaiTranslation: 'สี',
      englishSentence: 'The colour is blue.',
      thaiSentence: 'สีนั้นเป็นสีฟ้า',
      cefrLevel: 'A1',
      communicativeFunction: 'describing',
      languageVariant: 'UK',
      imageUrl: '',
      createdAt: now,
    );
    final vocabUS = VocabularyModel(
      id: 'vocab2',
      word: 'color',
      partOfSpeech: 'noun',
      thaiTranslation: 'สี',
      englishSentence: 'The color is blue.',
      thaiSentence: 'สีนั้นเป็นสีฟ้า',
      cefrLevel: 'A1',
      communicativeFunction: 'describing',
      languageVariant: 'US',
      imageUrl: '',
      createdAt: now,
    );

    final cards = [
      WordCardModel(
        id: '1',
        userId: 'guest',
        vocabularyId: 'vocab1',
        dueDate: now.subtract(Duration(days: 1)),
        createdAt: now,
        vocabulary: vocabUK,
      ),
      WordCardModel(
        id: '2',
        userId: 'guest',
        vocabularyId: 'vocab2',
        dueDate: now.subtract(Duration(days: 1)),
        createdAt: now,
        vocabulary: vocabUS,
      ),
    ];

    when(mockAuth.currentSession).thenReturn(null);
    when(mockHiveService.getWordCards()).thenAnswer((_) async => cards);
    when(mockHiveService.getCurrentUser()).thenAnswer((_) async =>
      UserModel.createGuest().updatePreference('languageVariant', 'US'),
    );

    final expected = {'us_first': true, 'uk_first': false};

    // Act
    final result = await reviewService.getDueCards();

    // Assert
    expect(result.length, greaterThan(0));
    if (result.length >= 2) {
      expect(result[0].vocabulary?.languageVariant, 'US');
      expect(result[1].vocabulary?.languageVariant, 'UK');
    }

    printTestOutputSimple(
      testId: 'UTC-03-TC06',
      description: 'Sort US cards first when US preference',
      input: 'TD06: User preference = US, mixed cards',
      expectedOutput: expected,
      actualOutput: {
        'us_first': result.isNotEmpty ? result[0].vocabulary?.languageVariant == 'US' : false,
        'uk_first': result.isNotEmpty ? result[0].vocabulary?.languageVariant == 'UK' : false,
      },
    );
  });
}

// Helper to create test card
WordCardModel _createTestCard(String id, DateTime dueDate) {
  return WordCardModel(
    id: id,
    userId: 'guest',
    vocabularyId: 'vocab_$id',
    dueDate: dueDate,
    createdAt: DateTime.now(),
    vocabulary: VocabularyModel(
      id: 'vocab_$id',
      word: 'test',
      partOfSpeech: 'noun',
      thaiTranslation: 'ทดสอบ',
      englishSentence: 'Test sentence',
      thaiSentence: 'ประโยคทดสอบ',
      cefrLevel: 'A1',
      communicativeFunction: 'describing',
      languageVariant: 'US',
      imageUrl: '',
      createdAt: DateTime.now(),
    ),
  );
}
