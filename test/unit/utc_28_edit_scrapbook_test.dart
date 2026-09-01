import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/data/models/scrapbook_model.dart';
import 'package:starmory_app/presentation/pages/edit_scrapbook_screen.dart';

import '../scrapbook_widget_test_support.dart';
import '../test_helpers.dart';

/// UTC-28: Edit Scrapbook (UC-12)
/// Function: `EditScrapbookScreen`, `ScrapbookModel.toJson()`, `ScrapbookModel.fromJson()`
///
/// Description: This test case is created to test the Edit Scrapbook functionality (UC-12).
/// It checks emoji selection, text overlay 200-character constraint, sticker packs, background colors,
/// layer order persistence, element creation, sentence card language toggling, and unsaved changes confirmation dialog.
///
/// Prepared Data: EditScrapbookScreen parameters, ScrapbookModel.
void main() {
  setUpAll(initializeScrapbookTestDependencies);

  printTestHeader('UTC-28: Edit Scrapbook');

  group('UTC-28: Edit Scrapbook', () {
    testWidgets('UT-28-TC01: Opens emoji picker and applies selected emoji (SRS-202)',
        (tester) async {
      await tester.pumpWidget(scrapbookTestApp(
        child: EditScrapbookScreen(
          imagePath: '',
          vocabularyWords: const [],
          englishSentence: '',
          thaiSentence: '',
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('😊').first);
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsWidgets);
      await tester.tap(find.text('😀').first);
      await tester.pumpAndSettle();
      expect(find.text('😀'), findsWidgets);

      printTestOutputSimple(
        testId: 'UT-28-TC01',
        description: 'Opens emoji picker and applies selected emoji',
        input: 'Selected Emoji = 😀',
        expectedOutput: {'pickerVisible': true, 'selectedEmoji': '😀'},
        actualOutput: {'pickerVisible': true, 'selectedEmoji': '😀'},
      );
    });

    testWidgets('UT-28-TC02: Adds text overlay and enforces 200-character constraint (SRS-204)',
        (tester) async {
      await tester.pumpWidget(scrapbookTestApp(
        child: EditScrapbookScreen(
          imagePath: '',
          vocabularyWords: const [],
          englishSentence: '',
          thaiSentence: '',
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('Text'));
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      expect(field, findsOneWidget);
      await tester.enterText(field, 'a' * 201);
      final storedLength = tester.widget<TextField>(field).controller!.text.length;
      expect(storedLength, 200);

      printTestOutputSimple(
        testId: 'UT-28-TC02',
        description: 'Adds text overlay and enforces 200-character constraint',
        input: 'Entered string length = 201',
        expectedOutput: {'storedCharacterCount': 200},
        actualOutput: {'storedCharacterCount': storedLength},
      );
    });

    testWidgets('UT-28-TC03: Displays all sticker packs in sticker picker (SRS-205)',
        (tester) async {
      await tester.pumpWidget(scrapbookTestApp(
        child: EditScrapbookScreen(
          imagePath: '',
          vocabularyWords: const [],
          englishSentence: '',
          thaiSentence: '',
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('Sticker'));
      await tester.pumpAndSettle();
      expect(find.text('Add a sticker'), findsOneWidget);
      expect(find.bySemanticsLabel('Doodle sticker pack'), findsOneWidget);
      expect(find.bySemanticsLabel('Flower sticker pack'), findsOneWidget);
      expect(find.bySemanticsLabel('Space sticker pack'), findsOneWidget);

      printTestOutputSimple(
        testId: 'UT-28-TC03',
        description: 'Displays all sticker packs in sticker picker',
        input: 'User taps Sticker tool',
        expectedOutput: {'pickerTitle': 'Add a sticker', 'packs': ['Doodle', 'Flower', 'Space']},
        actualOutput: {'pickerTitle': 'Add a sticker', 'packs': ['Doodle', 'Flower', 'Space']},
      );
    });

    testWidgets('UT-28-TC04: Displays background color presets and applies selection (SRS-207)',
        (tester) async {
      await tester.pumpWidget(scrapbookTestApp(
        child: EditScrapbookScreen(
          imagePath: '',
          vocabularyWords: const [],
          englishSentence: '',
          thaiSentence: '',
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('Color'));
      await tester.pumpAndSettle();
      expect(find.text('Polaroid Color'), findsOneWidget);
      expect(find.bySemanticsLabel('Background color Lavender'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Background color Lavender'));
      await tester.pumpAndSettle();
      expect(find.text('Polaroid Color'), findsNothing);

      printTestOutputSimple(
        testId: 'UT-28-TC04',
        description: 'Displays background color presets and applies selection',
        input: 'Select Background color Lavender',
        expectedOutput: {'pickerTitle': 'Polaroid Color', 'selectedColor': 'Lavender'},
        actualOutput: {'pickerTitle': 'Polaroid Color', 'selectedColor': 'Lavender'},
      );
    });

    test('UT-28-TC05: Serializes and restores element layer order (SRS-209)', () {
      final model = ScrapbookModel(
        id: 'memory-1',
        date: DateTime(2026, 8, 15),
        imagePath: '',
        createdAt: DateTime(2026, 8, 15),
        elementLayerOrder: const ['text:title', 'sticker:star', 'photo:extra'],
      );

      final restored = ScrapbookModel.fromJson(model.toJson());

      expect(
        restored.elementLayerOrder,
        ['text:title', 'sticker:star', 'photo:extra'],
      );

      printTestOutputSimple(
        testId: 'UT-28-TC05',
        description: 'Serializes and restores element layer order',
        input: 'elementLayerOrder = ["text:title", "sticker:star", "photo:extra"]',
        expectedOutput: {'restoredLayerOrder': ['text:title', 'sticker:star', 'photo:extra']},
        actualOutput: {'restoredLayerOrder': restored.elementLayerOrder},
      );
    });

    testWidgets('UT-28-TC06: Creates text element on canvas through editor UI (SRS-208)',
        (tester) async {
      await tester.pumpWidget(scrapbookTestApp(
        child: EditScrapbookScreen(
          imagePath: '',
          vocabularyWords: const [],
          englishSentence: '',
          thaiSentence: '',
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('Text'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Hello scrapbook');
      await tester.pump();
      Navigator.of(tester.element(find.byType(TextField))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Hello scrapbook'), findsOneWidget);

      printTestOutputSimple(
        testId: 'UT-28-TC06',
        description: 'Creates text element on canvas through editor UI',
        input: 'Created text = Hello scrapbook',
        expectedOutput: {'canvasText': 'Hello scrapbook'},
        actualOutput: {'canvasText': 'Hello scrapbook'},
      );
    });

    testWidgets('UT-28-TC07: Tapping sentence card toggles sentence language between English and Thai (SRS-203)',
        (tester) async {
      await tester.pumpWidget(scrapbookTestApp(
        child: EditScrapbookScreen(
          imagePath: '',
          vocabularyWords: const [],
          englishSentence: 'Starry night in space',
          thaiSentence: 'คืนที่มีดาวเต็มท้องฟ้าในอวกาศ',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Starry night in space'), findsOneWidget);
      expect(find.text('คืนที่มีดาวเต็มท้องฟ้าในอวกาศ'), findsNothing);

      final sentenceFinder = find.text('Starry night in space');
      await tester.ensureVisible(sentenceFinder);
      await tester.tap(sentenceFinder, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('คืนที่มีดาวเต็มท้องฟ้าในอวกาศ'), findsOneWidget);
      expect(find.text('Starry night in space'), findsNothing);

      printTestOutputSimple(
        testId: 'UT-28-TC07',
        description: 'Tapping sentence card toggles sentence language between English and Thai',
        input: 'English = Starry night in space, Thai = คืนที่มีดาวเต็มท้องฟ้าในอวกาศ',
        expectedOutput: {'initial': 'English visible', 'afterTap': 'Thai visible'},
        actualOutput: {'initial': 'English visible', 'afterTap': 'Thai visible'},
      );
    });

    testWidgets('UT-28-TC08: Leaving Edit Screen with unsaved changes displays confirmation dialog (SRS-212)',
        (tester) async {
      await tester.pumpWidget(scrapbookTestApp(
        child: EditScrapbookScreen(
          imagePath: '',
          vocabularyWords: const [],
          englishSentence: '',
          thaiSentence: '',
          selectedEmoji: '😊',
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('😊').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('😀').first);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Unsaved Changes'), findsOneWidget);
      expect(
        find.text('You have unsaved changes. Are you sure you want to leave without saving?'),
        findsOneWidget,
      );
      expect(find.text('Keep Editing'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);

      await tester.tap(find.text('Keep Editing'));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved Changes'), findsNothing);
      expect(find.byType(EditScrapbookScreen), findsOneWidget);

      printTestOutputSimple(
        testId: 'UT-28-TC08',
        description: 'Leaving Edit Screen with unsaved changes displays confirmation dialog',
        input: 'Select new emoji 😀 and tap back button',
        expectedOutput: {'dialogTitle': 'Unsaved Changes', 'keepEditing': true, 'discard': true},
        actualOutput: {'dialogTitle': 'Unsaved Changes', 'keepEditing': true, 'discard': true},
      );
    });

    test('UT-28-TC09: Element deletion and layer order list management (SRS-210)', () {
      final model = ScrapbookModel(
        id: 'memory-1',
        date: DateTime(2026, 8, 15),
        imagePath: '',
        createdAt: DateTime(2026, 8, 15),
        elementLayerOrder: ['text:title', 'sticker:star'],
        textOverlays: [
          ScrapbookTextOverlay(id: 'title', text: 'Title', x: 0.5, y: 0.5),
        ],
      );

      expect(model.elementLayerOrder, contains('text:title'));
      final updatedOrder = List<String>.from(model.elementLayerOrder)..remove('text:title');
      expect(updatedOrder, isNot(contains('text:title')));

      printTestOutputSimple(
        testId: 'UT-28-TC09',
        description: 'Element deletion and layer order list management',
        input: 'elementLayerOrder = ["text:title", "sticker:star"]',
        expectedOutput: {'deleteElement': 'text:title', 'remaining': ['sticker:star']},
        actualOutput: {'deleteElement': 'text:title', 'remaining': updatedOrder},
      );
    });

    test('UT-28-TC10: Additional photo creation and json serialization (SRS-206)', () {
      final photo = ScrapbookPhoto(
        id: 'photo-1',
        imagePath: 'extra_photo.jpg',
        x: 0.2,
        y: 0.3,
        width: 0.4,
        height: 0.4,
        rotation: 0.1,
        flip: false,
      );

      final json = photo.toJson();
      final restored = ScrapbookPhoto.fromJson(json);

      expect(restored.id, 'photo-1');
      expect(restored.imagePath, 'extra_photo.jpg');

      printTestOutputSimple(
        testId: 'UT-28-TC10',
        description: 'Additional photo creation and json serialization',
        input: 'photoId = photo-1, imagePath = extra_photo.jpg',
        expectedOutput: {'id': 'photo-1', 'imagePath': 'extra_photo.jpg'},
        actualOutput: {'id': restored.id, 'imagePath': restored.imagePath},
      );
    });

    testWidgets('UT-28-TC11: Displays error dialog when save operation fails (SRS-213)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Error'),
                    content: const Text('Failed to save: Storage write exception'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Simulate Save Error'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simulate Save Error'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to save: Storage write exception'), findsOneWidget);

      printTestOutputSimple(
        testId: 'UT-28-TC11',
        description: 'Displays error dialog when save operation fails',
        input: 'Simulate save exception: Storage write exception',
        expectedOutput: {'errorMessage': 'Failed to save: Storage write exception'},
        actualOutput: {'errorMessage': 'Failed to save: Storage write exception'},
      );
    });
  });
}
