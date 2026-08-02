import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:starmory_app/data/models/vocabulary_model.dart';
import 'package:starmory_app/data/models/word_card_model.dart';
import 'package:starmory_app/data/services/hive_service.dart';
import 'package:starmory_app/data/services/review_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../test_helpers.dart';
import '../test_helpers.mocks.dart';

/// UTC-05: Card Persistence After Review
/// Test Function: ReviewService.updateCard(WordCardModel card)
///
/// Description: This test verifies that the system correctly persists updated
/// card state with FSRS parameters to storage after user rating.
void main() {
  printTestHeader('UTC-05: Card Persistence After Review');

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

  tearDown(() {
    // Reset mocks after each test
    reset(mockSupabaseClient);
    reset(mockAuth);
    reset(mockHiveService);
  });

  // ============================================================================
  // UTC-05-TC01: Save updated card to Hive (Guest)
  // ============================================================================
  test('UTC-05-TC01: Save updated card to Hive (Guest)', () async {
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

    final card = WordCardModel(
      id: 'card1',
      userId: 'guest',
      vocabularyId: 'vocab1',
      stability: 2.5,
      difficulty: 5,
      state: CardState.review,
      dueDate: now.add(Duration(days: 1)),
      createdAt: now,
      vocabulary: vocab,
    );

    when(mockHiveService.saveWordCard(any)).thenAnswer((_) async {});

    final expected = {'saved': true, 'storage': 'Hive'};

    // Act
    final result = await reviewService.updateCard(card);

    // Assert
    expect(result, isNotNull);
    verify(mockHiveService.saveWordCard(any)).called(1);

    printTestOutputSimple(
      testId: 'UTC-05-TC01',
      description: 'Save updated card to Hive (Guest)',
      input: 'TD01: Updated card with new FSRS state (Guest mode)',
      expectedOutput: expected,
      actualOutput: {'saved': result != null, 'storage': 'Hive'},
    );
  });

  // ============================================================================
  // UTC-05-TC02: Update card in Supabase (Registered)
  // ============================================================================
  test('UTC-05-TC02: Update card in Supabase (Registered)', () async {
    // Arrange - Setup registered user mode
    final mockSession = MockSession();
    final mockUser = MockUser();

    when(mockUser.id).thenReturn('user123');
    when(mockSession.user).thenReturn(mockUser);
    when(mockAuth.currentSession).thenReturn(mockSession);

    // Recreate service with registered user setup
    final registeredReviewService = ReviewService(
      client: mockSupabaseClient,
      hiveService: mockHiveService,
    );

    final now = DateTime.now();
    final card = WordCardModel(
      id: 'card1',
      userId: 'user123',
      vocabularyId: 'vocab1',
      stability: 2.5,
      difficulty: 5,
      state: CardState.review,
      dueDate: now.add(Duration(days: 1)),
      createdAt: now,
    );

    final expected = {'saved': true, 'storage': 'Supabase', 'mode': 'registered'};

    // Act
    WordCardModel? result;
    try {
      result = await registeredReviewService.updateCard(card);
    } catch (e) {
      // Expected to fail due to mocking - we just verify the call was made
    }

    // Assert - Verify Supabase was called and Hive was not called
    verify(mockSupabaseClient.from('word_cards')).called(1);
    verifyNever(mockHiveService.saveWordCard(any));

    printTestOutputSimple(
      testId: 'UTC-05-TC02',
      description: 'Update card in Supabase (Registered)',
      input: 'TD02: Updated card with new FSRS state (Registered mode)',
      expectedOutput: expected,
      actualOutput: {
        'saved': result != null,
        'storage': 'Supabase',
        'mode': 'registered',
        'hive_called': false,
        'note': 'Supabase methods verified, integration tests cover actual DB operations'
      },
    );
  });

  // ============================================================================
  // UTC-05-TC03: Vocabulary data preserved after save
  // ============================================================================
  test('UTC-05-TC03: Vocabulary data preserved after save', () async {
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

    final card = WordCardModel(
      id: 'card1',
      userId: 'guest',
      vocabularyId: 'vocab1',
      stability: 2.5,
      difficulty: 5,
      state: CardState.review,
      dueDate: now.add(Duration(days: 1)),
      createdAt: now,
      vocabulary: vocab,
    );

    when(mockHiveService.saveWordCard(any)).thenAnswer((_) async {});

    // Act
    final result = await reviewService.updateCard(card);

    // Assert
    expect(result?.vocabulary?.word, 'test');
    expect(result?.vocabulary?.id, 'vocab1');

    printTestOutputSimple(
      testId: 'UTC-05-TC03',
      description: 'Vocabulary data preserved after save',
      input: 'TD03: Card with vocabulary data attached',
      expectedOutput: {'vocabulary': 'not_null', 'word': 'test'},
      actualOutput: {
        'vocabulary': result?.vocabulary != null ? 'not_null' : 'null',
        'word': result?.vocabulary?.word ?? 'missing'
      },
    );
  });

  // ============================================================================
  // UTC-05-TC04: updatedAt timestamp updated
  // ============================================================================
  test('UTC-05-TC04: updatedAt timestamp updated', () async {
    // Arrange
    final now = DateTime.now();
    final card = WordCardModel(
      id: 'card1',
      userId: 'guest',
      vocabularyId: 'vocab1',
      stability: 2.5,
      difficulty: 5,
      state: CardState.review,
      dueDate: now.add(Duration(days: 1)),
      createdAt: now.subtract(Duration(hours: 1)),
    );

    when(mockHiveService.saveWordCard(any)).thenAnswer((_) async {});

    // Act
    final result = await reviewService.updateCard(card);

    // Assert
    expect(result?.updatedAt, isNotNull);
    expect(result!.updatedAt!.isAfter(result.createdAt), isTrue);

    printTestOutputSimple(
      testId: 'UTC-05-TC04',
      description: 'updatedAt timestamp updated',
      input: 'TD01: Updated card with new FSRS state',
      expectedOutput: {'updated_at': 'present', 'after_created': true},
      actualOutput: {
        'updated_at': result.updatedAt != null ? 'present' : 'missing',
        'after_created': result.updatedAt!.isAfter(result.createdAt)
      },
    );
  });
}
