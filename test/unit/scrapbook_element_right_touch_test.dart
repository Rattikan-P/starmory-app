import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/data/models/scrapbook_model.dart';
import 'package:starmory_app/presentation/pages/edit_scrapbook_screen.dart';

import '../scrapbook_widget_test_support.dart';

void main() {
  setUpAll(initializeScrapbookTestDependencies);

  group('Scrapbook Element Right-Side Touch Test', () {
    testWidgets(
        'Sticker positioned to the right of polaroid can be tapped, selected, and duplicated',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // An existing scrapbook with a sticker placed to the right of the polaroid (x = 0.85)
      final existingScrapbook = ScrapbookModel(
        id: 'test_scrapbook_1',
        date: DateTime(2026, 9, 25),
        createdAt: DateTime(2026, 9, 25),
        imagePath: '',
        vocabularyWords: const [],
        englishSentence: 'Test sentence',
        thaiSentence: 'ประโยคทดสอบ',
        stickers: const [
          ScrapbookSticker(
            id: 'sticker_on_right',
            emoji: 'assets/stickers/space/space_01.png',
            x: 0.85, // To the right of the polaroid
            y: 0.5,
          ),
        ],
      );

      await tester.pumpWidget(scrapbookTestApp(
        scrapbooks: [existingScrapbook],
        child: EditScrapbookScreen(
          scrapbookId: existingScrapbook.id,
          imagePath: existingScrapbook.imagePath,
          vocabularyWords: existingScrapbook.vocabularyWords,
          englishSentence: existingScrapbook.englishSentence,
          thaiSentence: existingScrapbook.thaiSentence,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Find the sticker widget on the right
      final stickerFinder =
          find.byKey(const ValueKey('sticker:sticker_on_right'));
      expect(stickerFinder, findsOneWidget);

      final stickerCenter = tester.getCenter(stickerFinder);
      expect(stickerCenter.dx, greaterThan(320.0));

      // 2. Tap to select
      await tester.tap(stickerFinder);
      await tester.pump(const Duration(milliseconds: 100));

      // 3. Verify control handles are visible on the right side
      final duplicateBtn = find.bySemanticsLabel('Duplicate element');
      final deleteBtn = find.bySemanticsLabel('Delete element');
      expect(duplicateBtn, findsOneWidget);
      expect(deleteBtn, findsOneWidget);

      // Verify duplicate button is also on the right side
      final dupCenter = tester.getCenter(duplicateBtn);
      expect(dupCenter.dx, greaterThan(320.0));

      // 4. Tap the duplicate button
      await tester.tap(duplicateBtn);
      await tester.pump(const Duration(milliseconds: 100));

      // 1 polaroid image + 2 stickers = 3 images
      expect(find.byType(Image), findsNWidgets(3));
    });

    testWidgets(
        'Text overlay positioned to the right of polaroid can be tapped and selected',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final existingScrapbook = ScrapbookModel(
        id: 'test_scrapbook_2',
        date: DateTime(2026, 9, 25),
        createdAt: DateTime(2026, 9, 25),
        imagePath: '',
        vocabularyWords: const [],
        englishSentence: 'Test sentence',
        thaiSentence: 'ประโยคทดสอบ',
        textOverlays: const [
          ScrapbookTextOverlay(
            id: 'text_on_right',
            text: 'Right Side Text',
            x: 0.85,
            y: 0.5,
          ),
        ],
      );

      await tester.pumpWidget(scrapbookTestApp(
        scrapbooks: [existingScrapbook],
        child: EditScrapbookScreen(
          scrapbookId: existingScrapbook.id,
          imagePath: existingScrapbook.imagePath,
          vocabularyWords: existingScrapbook.vocabularyWords,
          englishSentence: existingScrapbook.englishSentence,
          thaiSentence: existingScrapbook.thaiSentence,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      final textWidget = find.text('Right Side Text');
      expect(textWidget, findsOneWidget);

      final textCenter = tester.getCenter(textWidget);
      expect(textCenter.dx, greaterThan(320.0));

      await tester.tap(textWidget);
      // Wait for double-tap timer to elapse (kDoubleTapTimeout is 300ms)
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.bySemanticsLabel('Delete element'), findsOneWidget);
    });

    testWidgets(
        'Element dragged to the right of polaroid maintains tap responsiveness',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Start with a sticker in the center (x = 0.5)
      final existingScrapbook = ScrapbookModel(
        id: 'test_scrapbook_3',
        date: DateTime(2026, 9, 25),
        createdAt: DateTime(2026, 9, 25),
        imagePath: '',
        vocabularyWords: const [],
        englishSentence: 'Test sentence',
        thaiSentence: 'ประโยคทดสอบ',
        stickers: const [
          ScrapbookSticker(
            id: 'center_sticker',
            emoji: 'assets/stickers/space/space_01.png',
            x: 0.5, // Center
            y: 0.5,
          ),
        ],
      );

      await tester.pumpWidget(scrapbookTestApp(
        scrapbooks: [existingScrapbook],
        child: EditScrapbookScreen(
          scrapbookId: existingScrapbook.id,
          imagePath: existingScrapbook.imagePath,
          vocabularyWords: existingScrapbook.vocabularyWords,
          englishSentence: existingScrapbook.englishSentence,
          thaiSentence: existingScrapbook.thaiSentence,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      final stickerFinder =
          find.byKey(const ValueKey('sticker:center_sticker'));
      expect(stickerFinder, findsOneWidget);

      // Drag the sticker 150 pixels to the right
      await tester.drag(stickerFinder, const Offset(150, 0));
      await tester.pump(const Duration(milliseconds: 100));

      final movedCenter = tester.getCenter(stickerFinder);
      expect(movedCenter.dx, greaterThan(320.0));

      // Tapping the selected sticker toggles selection off
      await tester.tap(stickerFinder);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.bySemanticsLabel('Delete element'), findsNothing);

      // Now tap the sticker again at its new position on the right side to re-select
      await tester.tap(stickerFinder);
      await tester.pump(const Duration(milliseconds: 100));

      // It should be selected again!
      expect(find.bySemanticsLabel('Delete element'), findsOneWidget);
    });
  });
}
