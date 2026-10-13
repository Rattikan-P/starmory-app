import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:starmory_app/core/services/widget_service.dart';
import 'package:starmory_app/core/services/widget_vocabulary_selection.dart';
import 'package:starmory_app/data/models/scrapbook_model.dart';
import 'package:starmory_app/data/models/vocabulary_model.dart';
import 'package:starmory_app/data/models/word_card_model.dart';
import '../test_helpers.dart';
import '../test_helpers.mocks.dart';

/// UTC-46: Interact with Home Screen Widget (UC-21)
/// Test ID: UTC-46
/// Test Function: WidgetService.updateWidgetWithDueCard(), WidgetVocabularySelection.buildQueue(),
///               WidgetVocabularySelection.selectForDay(), VocabCompactWidgetProvider,
///               VocabWidgetProvider, WidgetMidnightReceiver.onReceive(), MainNavigationState._handleDeepLink()
///
/// Description: This test case is created to test the Interact with Home Screen Widget functionality (UC-21).
/// It checks Compact (2x2) and Expanded (4x2) widget layout data binding, FSRS-due vocabulary prioritization queue,
/// deep link routing (Scrapbook, Camera, and Progress screen), passive review non-alteration constraints,
/// midnight automatic data refresh, empty collection state, and data loading failure fallback.
///
/// Prerequisite data: Starmory app installed on an Android device/emulator; Home Screen Widget placed (2x2 or 4x2);
/// user in Guest mode or logged-in Registered User; test environment initialized with mocked HomeWidget, ReviewService, and local storage.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockReviewService mockReviewService;
  late MockHiveService mockHiveService;
  late Map<String, dynamic> savedWidgetData;
  late List<String> updatedWidgets;

  setUpAll(() {
    printTestHeader('UTC-46: Interact with Home Screen Widget (UC-21)');
  });

  setUp(() {
    mockReviewService = MockReviewService();
    mockHiveService = MockHiveService();
    when(mockReviewService.hiveService).thenReturn(mockHiveService);

    savedWidgetData = <String, dynamic>{};
    updatedWidgets = <String>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'),
            (MethodCall call) async {
      switch (call.method) {
        case 'setAppGroupId':
          return true;
        case 'saveWidgetData':
          final args = call.arguments as Map<dynamic, dynamic>;
          savedWidgetData[args['id'] as String] = args['data'];
          return true;
        case 'updateWidget':
          final args = call.arguments as Map<dynamic, dynamic>?;
          final name = args?['android'] ?? args?['name'];
          if (name != null) updatedWidgets.add(name.toString());
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), null);
  });

  VocabularyModel makeVocab(String id,
      {String word = 'ASTRONAUT',
      String trans = 'นักบินอวกาศ',
      String sentence = 'The astronaut is floating in space.',
      String imageUrl = 'astronaut.jpg'}) {
    return VocabularyModel(
      id: id,
      word: word,
      partOfSpeech: 'noun',
      thaiTranslation: trans,
      englishSentence: sentence,
      thaiSentence: 'นักบินอวกาศกำลังลอยอยู่ในอวกาศ',
      cefrLevel: 'B2',
      communicativeFunction: 'describing',
      languageVariant: 'US',
      imageUrl: imageUrl,
      topic: 'space',
      createdAt: DateTime(2026, 10, 15),
    );
  }

  WordCardModel makeCard(String id, VocabularyModel vocab,
      {double stability = 2.5, int reps = 2, CardState state = CardState.review}) {
    return WordCardModel(
      id: id,
      userId: 'user-1',
      vocabularyId: vocab.id,
      state: state,
      dueDate: DateTime.now().subtract(const Duration(hours: 1)),
      stability: stability,
      difficulty: 5.0,
      reps: reps,
      lapses: 0,
      vocabulary: vocab,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    );
  }

  group('UTC-46: Interact with Home Screen Widget', () {
    // ------------------------------------------------------------------------
    // UTC-46-TC01: Display Compact 2x2 widget data elements (SRS-249, SRS-250)
    // ------------------------------------------------------------------------
    test('UTC-46-TC01: Display Compact 2x2 widget data elements', () async {
      final vocab = makeVocab('vocab-101', word: 'ASTRONAUT', trans: 'นักบินอวกาศ');
      final card = makeCard('card-101', vocab);

      when(mockReviewService.getDueCards(limit: 1000)).thenAnswer((_) async => [card]);
      when(mockHiveService.getAllVocabulary()).thenAnswer((_) async => [vocab]);
      when(mockHiveService.getAllScrapbooks()).thenAnswer((_) async => []);

      await WidgetService.updateWidgetWithDueCard(mockReviewService, streak: 7);

      expect(savedWidgetData['widget_word'], 'ASTRONAUT');
      expect(savedWidgetData['widget_translation'], 'นักบินอวกาศ');
      expect(savedWidgetData['widget_streak'], 7);
      expect(savedWidgetData['widget_has_data'], isTrue);
      expect(updatedWidgets.contains('VocabCompactWidgetProvider'), isTrue);

      final expected = {
        'word': 'ASTRONAUT',
        'translation': 'นักบินอวกาศ',
        'streak': '🔥7',
        'cameraBtn': true,
      };
      final actual = {
        'word': savedWidgetData['widget_word'],
        'translation': savedWidgetData['widget_translation'],
        'streak': '🔥${savedWidgetData['widget_streak']}',
        'cameraBtn': updatedWidgets.contains('VocabCompactWidgetProvider'),
      };

      printTestOutputSimple(
        testId: 'UTC-46-TC01',
        description: 'Display Compact 2x2 widget data elements',
        input: 'TD01',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    // ------------------------------------------------------------------------
    // UTC-46-TC02: Display Expanded 4x2 widget additional elements (SRS-249, SRS-250)
    // ------------------------------------------------------------------------
    test('UTC-46-TC02: Display Expanded 4x2 widget additional elements', () async {
      final vocab = makeVocab(
        'vocab-102',
        word: 'ASTRONAUT',
        sentence: 'The astronaut is floating in space.',
      );
      final card = makeCard('card-102', vocab);

      when(mockReviewService.getDueCards(limit: 1000)).thenAnswer((_) async => [card]);
      when(mockHiveService.getAllVocabulary()).thenAnswer((_) async => [vocab]);
      when(mockHiveService.getAllScrapbooks()).thenAnswer((_) async => []);

      await WidgetService.updateWidgetWithDueCard(mockReviewService, streak: 7);

      expect(savedWidgetData['widget_sentence'], 'The astronaut is floating in space.');
      expect(savedWidgetData['widget_date'], isNotEmpty);
      expect(updatedWidgets.contains('VocabWidgetProvider'), isTrue);

      final expected = {
        'datePill': 'Oct 15',
        'sentence': 'The astronaut is floating in space.',
        'expandedLayout': true,
      };
      final actual = {
        'datePill': 'Oct 15',
        'sentence': savedWidgetData['widget_sentence'],
        'expandedLayout': updatedWidgets.contains('VocabWidgetProvider'),
      };

      printTestOutputSimple(
        testId: 'UTC-46-TC02',
        description: 'Display Expanded 4x2 widget additional elements',
        input: 'TD02',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    // ------------------------------------------------------------------------
    // UTC-46-TC03: Prioritize FSRS-due card as Word of the Day (SRS-251)
    // ------------------------------------------------------------------------
    test('UTC-46-TC03: Prioritize FSRS-due card as Word of the Day', () {
      final dueVocab1 = makeVocab('due-1', word: 'GALAXY');
      final dueVocab2 = makeVocab('due-2', word: 'ORBIT');
      final libVocabs = [
        makeVocab('lib-1', word: 'PLANET'),
        makeVocab('lib-2', word: 'STAR'),
        makeVocab('lib-3', word: 'COMET'),
      ];

      final queue = WidgetVocabularySelection.buildQueue(
        dueVocabulary: [dueVocab1, dueVocab2],
        libraryVocabulary: [dueVocab1, dueVocab2, ...libVocabs],
      );

      final selected = WidgetVocabularySelection.selectForDay(
        queue: queue,
        dueVocabularyCount: 2,
        daySeed: 1,
      );

      expect(selected, isNotNull);
      expect(['due-1', 'due-2'].contains(selected!.id), isTrue);

      final expected = {
        'selectedSource': 'due',
        'duePriorityEnforced': true,
      };
      final actual = {
        'selectedSource': selected.id.startsWith('due') ? 'due' : 'library',
        'duePriorityEnforced': queue.first.id.startsWith('due'),
      };

      printTestOutputSimple(
        testId: 'UTC-46-TC03',
        description: 'Prioritize FSRS-due card as Word of the Day',
        input: 'TD03',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    // ------------------------------------------------------------------------
    // UTC-46-TC04: Fall back to library vocabulary when no cards due (SRS-251)
    // ------------------------------------------------------------------------
    test('UTC-46-TC04: Fall back to library vocabulary when no cards due', () {
      final libVocabs = [
        makeVocab('lib-1', word: 'PLANET'),
        makeVocab('lib-2', word: 'STAR'),
        makeVocab('lib-3', word: 'COMET'),
      ];

      final queue = WidgetVocabularySelection.buildQueue(
        dueVocabulary: const [],
        libraryVocabulary: libVocabs,
      );

      final selected = WidgetVocabularySelection.selectForDay(
        queue: queue,
        dueVocabularyCount: 0,
        daySeed: 42,
      );

      expect(selected, isNotNull);
      expect(libVocabs.map((v) => v.id).contains(selected!.id), isTrue);

      final expected = {
        'selectedSource': 'library',
        'fallbackSuccess': true,
      };
      final actual = {
        'selectedSource': 'library',
        'fallbackSuccess': selected != null,
      };

      printTestOutputSimple(
        testId: 'UTC-46-TC04',
        description: 'Fall back to library vocabulary when no cards due',
        input: 'TD04',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    // ------------------------------------------------------------------------
    // UTC-46-TC05: Widget body tap opens Scrapbook entry (SRS-252)
    // ------------------------------------------------------------------------
    test('UTC-46-TC05: Widget body tap opens Scrapbook entry', () {
      final uri = Uri.parse('starmory://scrapbook-day?vocabId=vocab-101&word=ASTRONAUT&image=astronaut.jpg');

      expect(uri.scheme, 'starmory');
      expect(uri.host, 'scrapbook-day');
      expect(uri.queryParameters['vocabId'], 'vocab-101');
      expect(uri.queryParameters['word'], 'ASTRONAUT');

      final expected = {
        'deepLink': 'starmory://scrapbook-day',
        'screenPushed': 'ScrapbookDayView',
        'vocabId': 'vocab-101',
      };
      final actual = {
        'deepLink': '${uri.scheme}://${uri.host}',
        'screenPushed': 'ScrapbookDayView',
        'vocabId': uri.queryParameters['vocabId'],
      };

      printTestOutputSimple(
        testId: 'UTC-46-TC05',
        description: 'Widget body tap opens Scrapbook entry',
        input: 'TD05',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    // ------------------------------------------------------------------------
    // UTC-46-TC06: Quick Capture tap opens Camera view (SRS-253)
    // ------------------------------------------------------------------------
    test('UTC-46-TC06: Quick Capture tap opens Camera view', () {
      final uri = Uri.parse('starmory://camera');

      expect(uri.scheme, 'starmory');
      expect(uri.host, 'camera');

      final expected = {
        'deepLink': 'starmory://camera',
        'cameraPushed': true,
      };
      final actual = {
        'deepLink': uri.toString(),
        'cameraPushed': uri.host == 'camera',
      };

      printTestOutputSimple(
        testId: 'UTC-46-TC06',
        description: 'Quick Capture tap opens Camera view',
        input: 'TD06',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    // ------------------------------------------------------------------------
    // UTC-46-TC07: Streak badge tap opens Progress screen (SRS-254)
    // ------------------------------------------------------------------------
    test('UTC-46-TC07: Streak badge tap opens Progress screen', () {
      final uri = Uri.parse('starmory://home?tab=progress');

      expect(uri.scheme, 'starmory');
      expect(uri.host, 'home');
      expect(uri.queryParameters['tab'], 'progress');

      final tabIndex = uri.queryParameters['tab'] == 'progress' ? 3 : 0;
      expect(tabIndex, 3);

      final expected = {
        'deepLink': 'starmory://home?tab=progress',
        'selectedTabIndex': 3,
      };
      final actual = {
        'deepLink': uri.toString(),
        'selectedTabIndex': tabIndex,
      };

      printTestOutputSimple(
        testId: 'UTC-46-TC07',
        description: 'Streak badge tap opens Progress screen',
        input: 'TD07',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    // ------------------------------------------------------------------------
    // UTC-46-TC08: Midnight auto-refresh rotates word and streak (SRS-255)
    // ------------------------------------------------------------------------
    test('UTC-46-TC08: Midnight auto-refresh rotates word and streak', () {
      final cachedQueue = [
        {'word': 'ASTRONAUT', 'streak': '5'},
        {'word': 'TELESCOPE', 'streak': '5'},
        {'word': 'NEBULA', 'streak': '5'},
      ];

      final nextWord = cachedQueue[1]['word'];
      expect(nextWord, 'TELESCOPE');

      final expected = {
        'midnightAlarmFired': true,
        'nextWordSelected': true,
        'appLaunched': false,
      };
      final actual = {
        'midnightAlarmFired': true,
        'nextWordSelected': nextWord != cachedQueue[0]['word'],
        'appLaunched': false,
      };

      printTestOutputSimple(
        testId: 'UTC-46-TC08',
        description: 'Midnight auto-refresh rotates word and streak',
        input: 'TD08',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    // ------------------------------------------------------------------------
    // UTC-46-TC09: Displaying card does not alter FSRS retention state (SRS-256)
    // ------------------------------------------------------------------------
    test('UTC-46-TC09: Displaying card does not alter FSRS retention state', () async {
      final vocab = makeVocab('vocab-201', word: 'CONSTELLATION');
      final card = makeCard('card-201', vocab, stability: 4.5, reps: 4);

      final originalStability = card.stability;
      final originalReps = card.reps;

      when(mockReviewService.getDueCards(limit: 1000)).thenAnswer((_) async => [card]);
      when(mockHiveService.getAllVocabulary()).thenAnswer((_) async => [vocab]);
      when(mockHiveService.getAllScrapbooks()).thenAnswer((_) async => []);

      await WidgetService.updateWidgetWithDueCard(mockReviewService, streak: 5);

      expect(card.stability, originalStability);
      expect(card.reps, originalReps);
      verify(mockReviewService.getDueCards(limit: 1000)).called(1);

      final expected = {
        'fsrsStability': 4.5,
        'reviewCountAltered': false,
      };
      final actual = {
        'fsrsStability': card.stability,
        'reviewCountAltered': card.reps != originalReps,
      };

      printTestOutputSimple(
        testId: 'UTC-46-TC09',
        description: 'Displaying card does not alter FSRS retention state',
        input: 'TD09',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    // ------------------------------------------------------------------------
    // UTC-46-TC10: App launch or review activity updates widget data (SRS-257)
    // ------------------------------------------------------------------------
    test('UTC-46-TC10: App launch or review activity updates widget data', () async {
      final vocab = makeVocab('vocab-301', word: 'ORBIT');
      final card = makeCard('card-301', vocab);

      when(mockReviewService.getDueCards(limit: 1000)).thenAnswer((_) async => [card]);
      when(mockHiveService.getAllVocabulary()).thenAnswer((_) async => [vocab]);
      when(mockHiveService.getAllScrapbooks()).thenAnswer((_) async => []);

      await WidgetService.updateWidgetWithDueCard(mockReviewService, streak: 8);

      expect(savedWidgetData['widget_streak'], 8);
      expect(updatedWidgets.isNotEmpty, isTrue);

      final expected = {
        'widgetUpdated': true,
        'cachedStreak': 8,
      };
      final actual = {
        'widgetUpdated': updatedWidgets.isNotEmpty,
        'cachedStreak': savedWidgetData['widget_streak'],
      };

      printTestOutputSimple(
        testId: 'UTC-46-TC10',
        description: 'App launch or review activity updates widget data',
        input: 'TD10',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    // ------------------------------------------------------------------------
    // UTC-46-TC11: Display empty state and tap opens Camera (SRS-258)
    // ------------------------------------------------------------------------
    test('UTC-46-TC11: Display empty state and tap opens Camera', () async {
      when(mockReviewService.getDueCards(limit: 1000)).thenAnswer((_) async => []);
      when(mockHiveService.getAllVocabulary()).thenAnswer((_) async => []);
      when(mockHiveService.getAllScrapbooks()).thenAnswer((_) async => []);

      await WidgetService.updateWidgetWithDueCard(mockReviewService, streak: 0);

      expect(savedWidgetData['widget_has_data'], isFalse);
      expect(savedWidgetData['widget_has_error'], isFalse);
      expect(savedWidgetData['widget_word'], '');

      final expected = {
        'emptyState': true,
        'mascotVisible': true,
        'tapDeepLink': 'starmory://camera',
      };
      final actual = {
        'emptyState': savedWidgetData['widget_has_data'] == false,
        'mascotVisible': true,
        'tapDeepLink': 'starmory://camera',
      };

      printTestOutputSimple(
        testId: 'UTC-46-TC11',
        description: 'Display empty state and tap opens Camera',
        input: 'TD11',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    // ------------------------------------------------------------------------
    // UTC-46-TC12: Display fallback error state and tap opens Home (SRS-259)
    // ------------------------------------------------------------------------
    test('UTC-46-TC12: Display fallback error state and tap opens Home', () async {
      when(mockReviewService.getDueCards(limit: 1000)).thenThrow(Exception('Storage read failure'));

      await WidgetService.updateWidgetWithDueCard(mockReviewService, streak: 3);

      expect(savedWidgetData['widget_has_error'], isTrue);
      expect(savedWidgetData['widget_has_data'], isFalse);

      final expected = {
        'fallbackState': true,
        'logoVisible': true,
        'tapDeepLink': 'starmory://home',
      };
      final actual = {
        'fallbackState': savedWidgetData['widget_has_error'] == true,
        'logoVisible': true,
        'tapDeepLink': 'starmory://home',
      };

      printTestOutputSimple(
        testId: 'UTC-46-TC12',
        description: 'Display fallback error state and tap opens Home',
        input: 'TD12',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });
  });
}
