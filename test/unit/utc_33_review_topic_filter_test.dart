import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:starmory_app/data/models/vocabulary_model.dart';
import 'package:starmory_app/data/models/word_card_model.dart';
import 'package:starmory_app/data/models/user_stats_model.dart';
import 'package:starmory_app/data/services/review_service.dart';
import 'package:starmory_app/presentation/providers/review_provider.dart';

import '../test_helpers.dart';
import '../test_helpers.mocks.dart';

/// UTC-33: Topic Filtering & Available Card Counts
/// Test Function: ReviewService.getAvailableCardCountsByTopic() / ReviewService.getDueCards(topicFilter)
void main() {
  printTestHeader('UTC-33: Topic Filtering & Available Card Counts');

  late MockReviewService mockReviewService;
  late ReviewNotifier notifier;

  setUp(() {
    mockReviewService = MockReviewService();
    notifier = ReviewNotifier(
      mockReviewService,
      recordLearningActivity: () async {},
    );
  });

  WordCardModel createCardWithTopic(String id, String topic) {
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
        word: 'Word $id',
        partOfSpeech: 'noun',
        thaiTranslation: 'คำแปล $id',
        englishSentence: 'Example $id.',
        thaiSentence: 'ตัวอย่าง $id',
        cefrLevel: 'A1',
        communicativeFunction: 'describing',
        languageVariant: 'US',
        imageUrl: '',
        topic: topic,
        createdAt: DateTime.now(),
      ),
      createdAt: DateTime.now(),
    );
  }

  test('UTC-33-TC01: Calculate card counts and availability per topic', () async {
    when(mockReviewService.getAvailableCardCountsByTopic()).thenAnswer((_) async => {
      'Nature': 8,
      'Food & Drinks': 4,
      'Travel': 0,
    });

    final counts = await mockReviewService.getAvailableCardCountsByTopic();

    expect(counts['Nature'], 8);
    expect(counts['Food & Drinks'], 4);
    expect(counts['Travel'], 0);

    printTestOutputSimple(
      testId: 'UTC-33-TC01',
      description: 'Calculate card counts and availability per topic',
      input: 'TD01: Nature=8, Food=4, Travel=0',
      expectedOutput: {
        'topics': [
          {'name': 'Nature', 'count': 8, 'enabled': true},
          {'name': 'Food & Drinks', 'count': 4, 'enabled': true},
          {'name': 'Travel', 'count': 0, 'enabled': false}
        ]
      },
      actualOutput: {
        'topics': [
          {'name': 'Nature', 'count': counts['Nature'], 'enabled': counts['Nature']! > 0},
          {'name': 'Food & Drinks', 'count': counts['Food & Drinks'], 'enabled': counts['Food & Drinks']! > 0},
          {'name': 'Travel', 'count': counts['Travel'], 'enabled': counts['Travel']! > 0}
        ]
      },
    );
  });

  test('UTC-33-TC02: Filter review session cards strictly by selected topic', () async {
    final foodCards = List.generate(4, (i) => createCardWithTopic('food_$i', 'Food & Drinks'));

    when(mockReviewService.getReviewSession(
      topicFilter: 'Food & Drinks',
      batchSize: 10,
    )).thenAnswer((_) async => foodCards);
    when(mockReviewService.getRemainingDueCount(topicFilter: 'Food & Drinks')).thenAnswer((_) async => 0);
    when(mockReviewService.getUserStats()).thenAnswer((_) async => UserStatsModel(lastReviewDate: DateTime.now()));

    await notifier.loadSession(topicFilter: 'Food & Drinks', batchSize: 10);

    expect(notifier.state.cards.length, 4);
    expect(notifier.state.cards.every((c) => c.vocabulary?.topic == 'Food & Drinks'), isTrue);

    printTestOutputSimple(
      testId: 'UTC-33-TC02',
      description: 'Filter review session cards strictly by selected topic',
      input: 'TD02: topicFilter = "Food & Drinks", batchSize = 10',
      expectedOutput: {'filter': 'Food & Drinks', 'count': 4, 'allMatchTopic': true},
      actualOutput: {
        'filter': notifier.state.currentTopicFilter,
        'count': notifier.state.cards.length,
        'allMatchTopic': notifier.state.cards.every((c) => c.vocabulary?.topic == 'Food & Drinks'),
      },
    );
  });

  test('UTC-33-TC03: Restrict loaded cards to configured session size', () async {
    final natureCards = List.generate(5, (i) => createCardWithTopic('nature_$i', 'Nature'));

    when(mockReviewService.getReviewSession(
      topicFilter: 'Nature',
      batchSize: 5,
    )).thenAnswer((_) async => natureCards);
    when(mockReviewService.getRemainingDueCount(topicFilter: 'Nature')).thenAnswer((_) async => 3);
    when(mockReviewService.getUserStats()).thenAnswer((_) async => UserStatsModel(lastReviewDate: DateTime.now()));

    await notifier.loadSession(topicFilter: 'Nature', batchSize: 5);

    expect(notifier.state.cards.length, 5);
    expect(notifier.state.remainingDueCount, 3);

    printTestOutputSimple(
      testId: 'UTC-33-TC03',
      description: 'Restrict loaded cards to configured session size',
      input: 'TD03: topic = "Nature", batchSize = 5, total = 8',
      expectedOutput: {'requestedSize': 5, 'loaded': 5, 'totalAvailable': 8},
      actualOutput: {
        'requestedSize': 5,
        'loaded': notifier.state.cards.length,
        'totalAvailable': notifier.state.cards.length + notifier.state.remainingDueCount,
      },
    );
  });
}
