import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/data/models/scrapbook_model.dart';
import 'package:starmory_app/presentation/pages/edit_scrapbook_screen.dart';
import 'package:starmory_app/presentation/pages/scrapbook_tab.dart';
import 'package:starmory_app/presentation/providers/scrapbook_provider.dart';
import 'package:starmory_app/presentation/widgets/scrapbook_detail_sheet.dart';
import 'package:starmory_app/presentation/widgets/scrapbook_polaroid.dart';
import 'package:starmory_app/presentation/widgets/vocabulary_detail_bottom_sheet.dart';

import '../scrapbook_widget_test_support.dart';
import '../test_helpers.dart';

/// UTC-27: View Scrapbook Archive (UC-11)
/// Function: `ScrapbookTab`, `ScrapbookState.getScrapbooksForDate()`, `showScrapbookDetailSheet()`
///
/// Description: This test case is created to test the View Scrapbook Archive functionality (UC-11).
/// It checks calendar date markers, date filtering, detail sheet rendering, empty day feedback,
/// month navigation, pull-to-refresh cloud merge, error state, and navigation interactions.
///
/// Prepared Data: ScrapbookState, ScrapbookModel list, selected date.
void main() {
  setUpAll(initializeScrapbookTestDependencies);

  printTestHeader('UTC-27: View Scrapbook Archive');

  group('UTC-27: View Scrapbook Archive', () {
    test('UT-27-TC01: Date range filtering and newest first sorting', () {
      final selectedDate = DateTime(2026, 8, 15);
      final state = ScrapbookState(scrapbooks: [
        scrapbook(id: 'old', date: selectedDate, createdAt: DateTime(2026, 8, 15, 9)),
        scrapbook(id: 'other-day', date: DateTime(2026, 8, 16)),
        scrapbook(id: 'new', date: selectedDate, createdAt: DateTime(2026, 8, 15, 12)),
      ]);

      final filteredIds = state.getScrapbooksForDate(selectedDate).map((item) => item.id).toList();

      expect(state.totalCount, 3);
      expect(filteredIds, ['new', 'old']);
      expect(state.getScrapbooksForDate(DateTime(2026, 8, 17)), isEmpty);

      printTestOutputSimple(
        testId: 'UT-27-TC01',
        description: 'Date range filtering and newest first sorting',
        input: 'Date = 2026-08-15, Scrapbooks = 3 items',
        expectedOutput: {'totalCount': 3, 'selectedIds': ['new', 'old']},
        actualOutput: {'totalCount': state.totalCount, 'selectedIds': filteredIds},
      );
    });

    testWidgets('UT-27-TC02: Calendar summary header and memory count',
        (tester) async {
      final day = DateTime.now();
      await tester.pumpWidget(scrapbookTestApp(
        child: const ScrapbookTab(),
        scrapbooks: [
          scrapbook(id: 'first', date: day),
          scrapbook(id: 'second', date: day, emoji: '🌟'),
        ],
      ));
      await tester.pump();

      expect(find.text('2 memories saved along the way'), findsOneWidget);
      expect(find.text('2 memories on this day'), findsOneWidget);

      printTestOutputSimple(
        testId: 'UT-27-TC02',
        description: 'Calendar summary header and memory count',
        input: 'Two memories on current date',
        expectedOutput: {
          'totalLabel': '2 memories saved along the way',
          'dayLabel': '2 memories on this day',
        },
        actualOutput: {
          'totalLabel': '2 memories saved along the way',
          'dayLabel': '2 memories on this day',
        },
      );
    });

    testWidgets('UT-27-TC03: Selecting a day with memories opens Detail Sheet',
        (tester) async {
      final now = DateTime.now();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final targetDay = now.day == 10 ? 12 : 10;
      final selectedDate = DateTime(now.year, now.month, targetDay);
      final expectedHeader = '$targetDay ${months[now.month - 1]} ${now.year}';

      await tester.pumpWidget(scrapbookTestApp(
        child: const ScrapbookTab(),
        scrapbooks: [
          scrapbook(id: 'memory-1', date: selectedDate, emoji: '🌟'),
        ],
      ));
      await tester.pump();

      await tester.tap(find.text('$targetDay').last);
      await tester.pumpAndSettle();

      expect(find.text(expectedHeader), findsOneWidget);
      expect(find.text('🌟'), findsWidgets);

      printTestOutputSimple(
        testId: 'UT-27-TC03',
        description: 'Selecting a day with memories opens Detail Sheet',
        input: 'Selected Date = $expectedHeader',
        expectedOutput: {'detailSheetVisible': true, 'dateHeader': expectedHeader, 'emoji': '🌟'},
        actualOutput: {'detailSheetVisible': true, 'dateHeader': expectedHeader, 'emoji': '🌟'},
      );
    });

    testWidgets('UT-27-TC04: Selecting an empty day shows SnackBar feedback',
        (tester) async {
      final now = DateTime.now();
      final emptyDay = now.day == 11 ? 13 : 11;
      final otherDay = emptyDay == 11 ? 10 : 12;
      final selectedDate = DateTime(now.year, now.month, otherDay);

      await tester.pumpWidget(scrapbookTestApp(
        child: const ScrapbookTab(),
        scrapbooks: [scrapbook(id: 'memory-1', date: selectedDate)],
      ));
      await tester.pump();

      await tester.tap(find.text('$emptyDay').last);
      await tester.pump();

      expect(find.text('No memories saved on this day'), findsOneWidget);
      expect(find.text('A fresh page waiting for a memory'), findsOneWidget);

      printTestOutputSimple(
        testId: 'UT-27-TC04',
        description: 'Selecting an empty day shows SnackBar feedback',
        input: 'Selected Empty Date = $emptyDay',
        expectedOutput: {'snackBar': 'No memories saved on this day'},
        actualOutput: {'snackBar': 'No memories saved on this day'},
      );
    });

    testWidgets('UT-27-TC05: Renders empty-state add-photo icon and guidance message',
        (tester) async {
      await tester.pumpWidget(scrapbookTestApp(child: const ScrapbookTab()));
      await tester.pump();

      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
      expect(
        find.text('Memories you create from Home will appear here.'),
        findsOneWidget,
      );

      printTestOutputSimple(
        testId: 'UT-27-TC05',
        description: 'Renders empty-state add-photo icon and guidance message',
        input: 'Empty ScrapbookState',
        expectedOutput: {
          'icon': 'add_photo_alternate_outlined',
          'message': 'Memories you create from Home will appear here.',
        },
        actualOutput: {
          'icon': 'add_photo_alternate_outlined',
          'message': 'Memories you create from Home will appear here.',
        },
      );
    });

    testWidgets('UT-27-TC06: Month navigation and Today button visibility',
        (tester) async {
      await tester.pumpWidget(scrapbookTestApp(child: const ScrapbookTab()));
      await tester.pump();

      expect(find.widgetWithText(TextButton, 'Today'), findsNothing);
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pump();
      expect(find.widgetWithText(TextButton, 'Today'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Today'));
      await tester.pump();
      expect(find.widgetWithText(TextButton, 'Today'), findsNothing);

      printTestOutputSimple(
        testId: 'UT-27-TC06',
        description: 'Month navigation and Today button visibility',
        input: 'User taps Previous month arrow then Today button',
        expectedOutput: {'afterPrevious': 'Today button visible', 'afterToday': 'Today button hidden'},
        actualOutput: {'afterPrevious': 'Today button visible', 'afterToday': 'Today button hidden'},
      );
    });

    testWidgets('UT-27-TC07: Detail Sheet displays date, count, emojis, and vocabulary UI',
        (tester) async {
      final memories = [
        scrapbook(id: 'one', date: DateTime(2026, 8, 15), emoji: '😊', imagePath: 'img1.jpg'),
        scrapbook(id: 'two', date: DateTime(2026, 8, 15), emoji: '🌟', imagePath: 'img2.jpg'),
      ];
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showScrapbookDetailSheet(context, scrapbooks: memories),
              child: const Text('Open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('15 Aug 2026'), findsOneWidget);
      expect(find.text('2 memories saved on this day'), findsOneWidget);
      expect(find.text('😊'), findsOneWidget);
      expect(find.text('🌟'), findsOneWidget);
      expect(find.text('Vocab'), findsOneWidget);

      printTestOutputSimple(
        testId: 'UT-27-TC07',
        description: 'Detail Sheet displays date, count, emojis, and vocabulary UI',
        input: 'Two memories on 15 Aug 2026 with emojis 😊 and 🌟',
        expectedOutput: {
          'date': '15 Aug 2026',
          'count': '2 memories saved on this day',
          'emojis': ['😊', '🌟'],
          'vocabSection': true,
        },
        actualOutput: {
          'date': '15 Aug 2026',
          'count': '2 memories saved on this day',
          'emojis': ['😊', '🌟'],
          'vocabSection': true,
        },
      );
    });

    test('UT-27-TC08: Pull-to-refresh merges cloud and local data with cloud priority',
        () {
      final time = DateTime(2026, 8, 15);
      final cloud = [
        scrapbook(id: 'shared', date: time, emoji: '🌟', createdAt: time),
      ];
      final local = [
        scrapbook(id: 'shared', date: time, emoji: '😊', createdAt: time),
        scrapbook(id: 'local-only', date: time, createdAt: time.subtract(const Duration(hours: 1))),
      ];

      final merged = ScrapbookNotifier.mergeCloudAndLocal(cloud, local);
      final mergedIds = merged.map((item) => item.id).toList();

      expect(mergedIds, ['shared', 'local-only']);
      expect(merged.first.selectedEmoji, '🌟');

      printTestOutputSimple(
        testId: 'UT-27-TC08',
        description: 'Pull-to-refresh merges cloud and local data with cloud priority',
        input: 'Cloud = ["shared"], Local = ["shared", "local-only"]',
        expectedOutput: {'mergedIds': ['shared', 'local-only'], 'sharedEmoji': '🌟'},
        actualOutput: {'mergedIds': mergedIds, 'sharedEmoji': merged.first.selectedEmoji},
      );
    });

    testWidgets('UT-27-TC09: Sync failure error state display and retry button',
        (tester) async {
      await tester.pumpWidget(scrapbookTestApp(
        child: const ScrapbookTab(),
        error: 'network failure',
      ));
      await tester.pump();

      expect(find.text('We couldn’t load your scrapbook.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      printTestOutputSimple(
        testId: 'UT-27-TC09',
        description: 'Sync failure error state display and retry button',
        input: 'Error = network failure',
        expectedOutput: {'errorMessage': 'We couldn’t load your scrapbook.', 'retryButton': true},
        actualOutput: {'errorMessage': 'We couldn’t load your scrapbook.', 'retryButton': true},
      );
    });

    testWidgets('UT-27-TC10: Detail Sheet header emoji tap opens Edit Scrapbook Screen (SRS-100)',
        (tester) async {
      final memory = scrapbook(
        id: 'edit-emoji-test',
        date: DateTime(2026, 8, 15),
        emoji: '🌟',
        imagePath: 'test.jpg',
      );

      await tester.pumpWidget(scrapbookTestApp(
        child: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showScrapbookDetailSheet(context, scrapbooks: [memory]),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('🌟'));
      await tester.pumpAndSettle();

      expect(find.byType(EditScrapbookScreen), findsOneWidget);

      printTestOutputSimple(
        testId: 'UT-27-TC10',
        description: 'Detail Sheet header emoji tap opens Edit Scrapbook Screen',
        input: 'Tap emoji 🌟 in Detail Sheet header',
        expectedOutput: {'navigatedToEditScreen': true},
        actualOutput: {'navigatedToEditScreen': true},
      );
    });

    testWidgets('UT-27-TC11: Detail Sheet vocabulary word chip tap opens VocabularyDetailBottomSheet (SRS-101)',
        (tester) async {
      final memory = scrapbook(
        id: 'vocab-test',
        date: DateTime(2026, 8, 15),
        emoji: '😊',
        vocabulary: [
          const ScrapbookVocabularyWord(word: 'Galaxy', thaiTranslation: 'กาแล็กซี', partOfSpeech: 'noun'),
        ],
      );

      await tester.pumpWidget(scrapbookTestApp(
        child: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showScrapbookDetailSheet(context, scrapbooks: [memory]),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Galaxy'), findsOneWidget);
      await tester.tap(find.text('Galaxy'));
      await tester.pumpAndSettle();

      expect(find.byType(VocabularyDetailBottomSheet), findsOneWidget);

      printTestOutputSimple(
        testId: 'UT-27-TC11',
        description: 'Detail Sheet vocabulary word chip tap opens VocabularyDetailBottomSheet',
        input: 'Tap vocabulary chip Galaxy',
        expectedOutput: {'detailBottomSheetOpened': true},
        actualOutput: {'detailBottomSheetOpened': true},
      );
    });

    testWidgets('UT-27-TC12: Tapping memory card in horizontal strip opens Edit Scrapbook Screen (SRS-102)',
        (tester) async {
      final day = DateTime.now();
      final memory = scrapbook(id: 'card-test', date: day, imagePath: 'test_card.jpg');

      await tester.pumpWidget(scrapbookTestApp(
        child: const ScrapbookTab(),
        scrapbooks: [memory],
      ));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      final polaroidFinder = find.byType(ScrapbookPolaroid).first;
      await tester.tap(polaroidFinder);
      await tester.pumpAndSettle();

      expect(find.byType(EditScrapbookScreen), findsOneWidget);

      printTestOutputSimple(
        testId: 'UT-27-TC12',
        description: 'Tapping memory card in horizontal strip opens Edit Scrapbook Screen',
        input: 'Tap Polaroid memory card in strip',
        expectedOutput: {'navigatedToEditScreen': true},
        actualOutput: {'navigatedToEditScreen': true},
      );
    });
  });
}
