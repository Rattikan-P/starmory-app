import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/core/services/widget_vocabulary_selection.dart';
import 'package:starmory_app/data/models/scrapbook_model.dart';
import 'package:starmory_app/data/models/vocabulary_model.dart';

void main() {
  group('WidgetVocabularySelection', () {
    final dueOne = _vocabulary('due-1');
    final dueTwo = _vocabulary('due-2');
    final libraryOnly = _vocabulary('library');

    test('builds a due-first queue without duplicate vocabulary IDs', () {
      final queue = WidgetVocabularySelection.buildQueue(
        dueVocabulary: [dueOne, dueTwo],
        libraryVocabulary: [dueOne, libraryOnly],
      );

      expect(queue.map((item) => item.id), ['due-1', 'due-2', 'library']);
    });

    test('selects only due vocabulary while due items are available', () {
      final queue = WidgetVocabularySelection.buildQueue(
        dueVocabulary: [dueOne, dueTwo],
        libraryVocabulary: [libraryOnly],
      );

      final selected = WidgetVocabularySelection.selectForDay(
        queue: queue,
        dueVocabularyCount: 2,
        daySeed: 5,
      );

      expect(selected?.id, 'due-2');
    });

    test('falls back to the saved vocabulary when nothing is due', () {
      final queue = WidgetVocabularySelection.buildQueue(
        dueVocabulary: const [],
        libraryVocabulary: [libraryOnly],
      );

      final selected = WidgetVocabularySelection.selectForDay(
        queue: queue,
        dueVocabularyCount: 0,
        daySeed: 99,
      );

      expect(selected?.id, 'library');
    });

    test('returns null when the queue is empty', () {
      expect(
        WidgetVocabularySelection.selectForDay(
          queue: const [],
          dueVocabularyCount: 0,
          daySeed: 0,
        ),
        isNull,
      );
    });

    test('uses scrapbook date matching the vocabulary photo', () {
      final olderPhoto = _scrapbook(
        id: 'older-photo',
        date: DateTime(2026, 2, 3),
        imagePath: '/photos/older.jpg',
      );
      final matchingPhoto = _scrapbook(
        id: 'matching-photo',
        date: DateTime(2025, 8, 14),
        imagePath: '/photos/matching.jpg',
      );
      final vocabulary = _vocabulary('photo-word').copyWith(
        word: 'Adorable',
        imageUrl: '/photos/matching.jpg',
      );

      final dates = WidgetVocabularySelection.buildScrapbookDateLookup(
        vocabularies: [vocabulary],
        scrapbooks: [olderPhoto, matchingPhoto],
      );

      expect(dates[vocabulary.id], DateTime(2025, 8, 14));
    });

    test('uses vocabulary creation date when no scrapbook matches', () {
      final vocabulary = _vocabulary('without-scrapbook');

      final dates = WidgetVocabularySelection.buildScrapbookDateLookup(
        vocabularies: [vocabulary],
        scrapbooks: const [],
      );

      expect(dates[vocabulary.id], vocabulary.createdAt);
    });

    test('does not use another scrapbook date when the photo differs', () {
      final vocabulary = _vocabulary('different-photo').copyWith(
        word: 'Adorable',
        imageUrl: '/photos/current.jpg',
      );

      final dates = WidgetVocabularySelection.buildScrapbookDateLookup(
        vocabularies: [vocabulary],
        scrapbooks: [
          _scrapbook(
            id: 'same-word-different-photo',
            date: DateTime(2026, 2, 3),
            imagePath: '/photos/other.jpg',
          ),
        ],
      );

      expect(dates[vocabulary.id], vocabulary.createdAt);
    });
  });
}

ScrapbookModel _scrapbook({
  required String id,
  required DateTime date,
  required String imagePath,
}) =>
    ScrapbookModel(
      id: id,
      date: date,
      imagePath: imagePath,
      vocabularyWords: const [
        ScrapbookVocabularyWord(
          word: 'adorable',
          thaiTranslation: 'น่ารัก',
          partOfSpeech: 'adjective',
        ),
      ],
      createdAt: date,
    );

VocabularyModel _vocabulary(String id) => VocabularyModel(
      id: id,
      word: id,
      partOfSpeech: 'noun',
      thaiTranslation: 'คำแปล',
      englishSentence: 'Example sentence.',
      thaiSentence: 'ตัวอย่างประโยค',
      cefrLevel: 'A1',
      communicativeFunction: 'General',
      languageVariant: 'US',
      imageUrl: '',
      topic: 'general',
      createdAt: DateTime(2026),
    );
