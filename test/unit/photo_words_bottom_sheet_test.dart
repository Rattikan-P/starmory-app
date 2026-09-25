import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/data/models/vocabulary_model.dart';
import 'package:starmory_app/presentation/pages/progress_tab.dart';
import 'package:starmory_app/presentation/providers/scrapbook_provider.dart';
import 'package:starmory_app/presentation/widgets/vocabulary_detail_bottom_sheet.dart';
import '../test_setup.dart';

class _FakeScrapbookNotifier extends StateNotifier<ScrapbookState> implements ScrapbookNotifier {
  _FakeScrapbookNotifier() : super(const ScrapbookState(scrapbooks: []));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    await setupTestEnvironment();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (MethodCall methodCall) async => 1,
    );
  });

  final testVocab = VocabularyModel(
    id: 'test_vocab_1',
    word: 'Butterfly',
    partOfSpeech: 'noun',
    thaiTranslation: 'ผีเสื้อ',
    englishSentence: 'A colorful butterfly landed on the flower.',
    thaiSentence: 'ผีเสื้อหลากสีเกาะอยู่บนดอกไม้',
    cefrLevel: 'A2',
    communicativeFunction: 'Indicative',
    languageVariant: 'US',
    imageUrl: 'https://example.com/butterfly.jpg',
    topic: 'nature',
    createdAt: DateTime(2026, 9, 26),
  );

  final testPhotoEntry = PhotoEntry(
    imageUrl: 'https://example.com/butterfly.jpg',
    vocabularies: [testVocab],
  );

  testWidgets('PhotoWordsBottomSheet displays unified card with vocab and sentence', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scrapbookStateProvider.overrideWith((ref) => _FakeScrapbookNotifier()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PhotoWordsBottomSheet(
              photoEntry: testPhotoEntry,
              allVocabularies: [testVocab],
            ),
          ),
        ),
      ),
    );

    // Verify word and translation
    expect(find.text('Butterfly'), findsAtLeastNWidgets(1));
    expect(find.text('ผีเสื้อ'), findsAtLeastNWidgets(1));

    // Verify badge
    expect(find.text('VOCAB'), findsOneWidget);

    // Verify sentence inside the card
    expect(find.text('A colorful butterfly landed on the flower.'), findsOneWidget);
    expect(find.text('ผีเสื้อหลากสีเกาะอยู่บนดอกไม้'), findsOneWidget);
  });

  testWidgets('Tapping the unified card displays VocabularyDetailBottomSheet', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scrapbookStateProvider.overrideWith((ref) => _FakeScrapbookNotifier()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => PhotoWordsBottomSheet(
                        photoEntry: testPhotoEntry,
                        allVocabularies: [testVocab],
                      ),
                    );
                  },
                  child: const Text('Open Sheet'),
                );
              },
            ),
          ),
        ),
      ),
    );

    // Open sheet
    await tester.tap(find.text('Open Sheet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify card exists
    expect(find.text('VOCAB'), findsOneWidget);

    // Tap card
    await tester.tap(find.text('Butterfly').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify VocabularyDetailBottomSheet is displayed
    expect(find.byType(VocabularyDetailBottomSheet), findsOneWidget);
  });
}
