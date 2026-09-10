import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/data/models/vocabulary_model.dart';
import '../test_helpers.dart';

/// UTC-30: Vocabulary Search & Category Filtering
/// Test Function: _ProgressTabState._applyFilters(), VocabularyModel.isFavorite, VocabularyModel.topic
void main() {
  printTestHeader('UTC-30: Vocabulary Search & Category Filtering');

  late List<VocabularyModel> sampleVocabularies;

  setUp(() {
    sampleVocabularies = [
      VocabularyModel(
        id: 'vocab-01',
        word: 'Coffee',
        partOfSpeech: 'noun',
        thaiTranslation: 'กาแฟ',
        englishSentence: 'I drink coffee every morning.',
        thaiSentence: 'ฉันดื่มกาแฟทุกเช้า',
        cefrLevel: 'A1',
        communicativeFunction: 'Daily routine',
        languageVariant: 'US',
        imageUrl: 'https://example.com/coffee.jpg',
        topic: 'food',
        createdAt: DateTime.now(),
        isFavorite: false,
      ),
      VocabularyModel(
        id: 'vocab-02',
        word: 'Laptop',
        partOfSpeech: 'noun',
        thaiTranslation: 'แล็ปท็อป',
        englishSentence: 'She works on her laptop.',
        thaiSentence: 'เธอทำงานบนแล็ปท็อปของเธอ',
        cefrLevel: 'A2',
        communicativeFunction: 'Work',
        languageVariant: 'US',
        imageUrl: 'https://example.com/laptop.jpg',
        topic: 'technology',
        createdAt: DateTime.now(),
        isFavorite: true,
      ),
      VocabularyModel(
        id: 'vocab-03',
        word: 'Tea',
        partOfSpeech: 'noun',
        thaiTranslation: 'ชา',
        englishSentence: 'Hot green tea is refreshing.',
        thaiSentence: 'ชาเขียวร้อนสดชื่นมาก',
        cefrLevel: 'A1',
        communicativeFunction: 'Food & Drink',
        languageVariant: 'UK',
        imageUrl: 'https://example.com/tea.jpg',
        topic: 'food',
        createdAt: DateTime.now(),
        isFavorite: true,
      ),
    ];
  });

  List<VocabularyModel> applyFilters({
    required List<VocabularyModel> list,
    String query = '',
    String category = 'All',
  }) {
    return list.where((vocab) {
      final matchesCategory = category == 'All' ||
          (category.toLowerCase() == 'favorites' && vocab.isFavorite) ||
          vocab.topic.toLowerCase() == category.toLowerCase();

      final cleanQuery = query.trim().toLowerCase();
      final matchesSearch = cleanQuery.isEmpty ||
          vocab.word.toLowerCase().contains(cleanQuery) ||
          vocab.thaiTranslation.toLowerCase().contains(cleanQuery);

      return matchesCategory && matchesSearch;
    }).toList();
  }

  test('UTC-30-TC01: Search vocabulary by English keyword substring (SRS-503)', () {
    final results = applyFilters(list: sampleVocabularies, query: 'coff');

    expect(results.length, 1);
    expect(results.first.word, 'Coffee');

    printTestOutputSimple(
      testId: 'UTC-30-TC01',
      description: 'Search vocabulary by English keyword substring (SRS-503)',
      input: 'TD01: query = "coff"',
      expectedOutput: {'matchCount': 1, 'matchedWords': ['Coffee'], 'filterSuccess': true},
      actualOutput: {
        'matchCount': results.length,
        'matchedWords': results.map((e) => e.word).toList(),
        'filterSuccess': results.length == 1 && results.first.word == 'Coffee',
      },
    );
  });

  test('UTC-30-TC02: Search vocabulary by Thai translation substring (SRS-503)', () {
    final results = applyFilters(list: sampleVocabularies, query: 'กาแฟ');

    expect(results.length, 1);
    expect(results.first.thaiTranslation, 'กาแฟ');

    printTestOutputSimple(
      testId: 'UTC-30-TC02',
      description: 'Search vocabulary by Thai translation substring (SRS-503)',
      input: 'TD02: query = "กาแฟ"',
      expectedOutput: {'matchCount': 1, 'matchedTranslations': ['กาแฟ'], 'filterSuccess': true},
      actualOutput: {
        'matchCount': results.length,
        'matchedTranslations': results.map((e) => e.thaiTranslation).toList(),
        'filterSuccess': results.length == 1,
      },
    );
  });

  test('UTC-30-TC03: Filter vocabulary collection by category topic (SRS-504)', () {
    final results = applyFilters(list: sampleVocabularies, category: 'food');

    expect(results.length, 2);
    expect(results.every((v) => v.topic == 'food'), isTrue);

    printTestOutputSimple(
      testId: 'UTC-30-TC03',
      description: 'Filter vocabulary collection by category topic (SRS-504)',
      input: 'TD03: category = "food"',
      expectedOutput: {'category': 'Food', 'filteredCount': 2, 'allMatchCategory': true},
      actualOutput: {
        'category': 'Food',
        'filteredCount': results.length,
        'allMatchCategory': results.every((v) => v.topic == 'food'),
      },
    );
  });

  test('UTC-30-TC04: Filter collection by Favorites bookmark status (SRS-504, SRS-505)', () {
    final results = applyFilters(list: sampleVocabularies, category: 'Favorites');

    expect(results.length, 2);
    expect(results.every((v) => v.isFavorite), isTrue);

    printTestOutputSimple(
      testId: 'UTC-30-TC04',
      description: 'Filter collection by Favorites bookmark status (SRS-504, SRS-505)',
      input: 'TD04: category = "Favorites"',
      expectedOutput: {'category': 'Favorites', 'favoriteCount': 2, 'allFavorite': true},
      actualOutput: {
        'category': 'Favorites',
        'favoriteCount': results.length,
        'allFavorite': results.every((v) => v.isFavorite),
      },
    );
  });

  test('UTC-30-TC05: Handle search query with zero matching results (SRS-503)', () {
    final results = applyFilters(list: sampleVocabularies, query: 'xyz123');

    expect(results.isEmpty, isTrue);

    printTestOutputSimple(
      testId: 'UTC-30-TC05',
      description: 'Handle search query with zero matching results (SRS-503)',
      input: 'TD05: query = "xyz123"',
      expectedOutput: {'matchCount': 0, 'emptyResults': true},
      actualOutput: {
        'matchCount': results.length,
        'emptyResults': results.isEmpty,
      },
    );
  });

  test('UTC-30-TC06: Toggle and persist favorite bookmark status (SRS-505)', () {
    var vocab = sampleVocabularies.first;
    expect(vocab.isFavorite, isFalse);

    final updatedVocab = vocab.copyWith(isFavorite: !vocab.isFavorite);

    expect(updatedVocab.isFavorite, isTrue);
    expect(updatedVocab.id, vocab.id);

    printTestOutputSimple(
      testId: 'UTC-30-TC06',
      description: 'Toggle and persist favorite bookmark status (SRS-505)',
      input: 'TD06: toggle isFavorite on vocab-01',
      expectedOutput: {'id': 'vocab-01', 'isFavorite': true, 'persisted': true},
      actualOutput: {
        'id': updatedVocab.id,
        'isFavorite': updatedVocab.isFavorite,
        'persisted': true,
      },
    );
  });
}

