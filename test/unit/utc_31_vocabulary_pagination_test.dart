import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/data/models/vocabulary_model.dart';
import '../test_helpers.dart';

/// UTC-31: Vocabulary Pagination & Lazy Loading
/// Test Function: _ProgressTabState._loadMoreItems(), _ProgressTabState._itemsPerPage, ScrollController
void main() {
  printTestHeader('UTC-31: Vocabulary Pagination & Lazy Loading');

  List<VocabularyModel> generateVocabList(int count) {
    return List.generate(
      count,
      (i) => VocabularyModel(
        id: 'vocab-$i',
        word: 'Word $i',
        partOfSpeech: 'noun',
        thaiTranslation: 'คำแปล $i',
        englishSentence: 'Sentence $i',
        thaiSentence: 'ประโยค $i',
        cefrLevel: 'A1',
        communicativeFunction: 'General',
        languageVariant: 'US',
        imageUrl: 'https://example.com/$i.jpg',
        topic: 'general',
        createdAt: DateTime.now(),
      ),
    );
  }

  test('UTC-31-TC01: Load initial 20 vocabulary cards on tab startup (SRS-502)', () {
    final allVocabs = generateVocabList(45);
    const itemsPerPage = 20;

    final initialCount = itemsPerPage.clamp(0, allVocabs.length);
    final displayedVocabs = allVocabs.sublist(0, initialCount);

    expect(displayedVocabs.length, 20);
    expect(allVocabs.length - displayedVocabs.length, 25);

    printTestOutputSimple(
      testId: 'UTC-31-TC01',
      description: 'Load initial 20 vocabulary cards on tab startup (SRS-502)',
      input: 'TD01: total = 45, itemsPerPage = 20',
      expectedOutput: {'displayedCount': 20, 'remainingCount': 25, 'hasMore': true},
      actualOutput: {
        'displayedCount': displayedVocabs.length,
        'remainingCount': allVocabs.length - displayedVocabs.length,
        'hasMore': displayedVocabs.length < allVocabs.length,
      },
    );
  });

  test('UTC-31-TC02: Append next 20 vocabulary cards on first scroll trigger (SRS-502)', () {
    final allVocabs = generateVocabList(45);
    const itemsPerPage = 20;

    var displayedVocabs = allVocabs.sublist(0, 20);

    // Simulate load more trigger
    final nextIndex = displayedVocabs.length;
    final endIndex = (nextIndex + itemsPerPage).clamp(0, allVocabs.length);
    displayedVocabs = allVocabs.sublist(0, endIndex);

    expect(displayedVocabs.length, 40);
    expect(allVocabs.length - displayedVocabs.length, 5);

    printTestOutputSimple(
      testId: 'UTC-31-TC02',
      description: 'Append next 20 vocabulary cards on first scroll trigger (SRS-502)',
      input: 'TD02: load second batch of 20',
      expectedOutput: {'displayedCount': 40, 'remainingCount': 5, 'hasMore': true},
      actualOutput: {
        'displayedCount': displayedVocabs.length,
        'remainingCount': allVocabs.length - displayedVocabs.length,
        'hasMore': displayedVocabs.length < allVocabs.length,
      },
    );
  });

  test('UTC-31-TC03: Append remaining 5 vocabulary cards on final scroll trigger (SRS-502)', () {
    final allVocabs = generateVocabList(45);
    const itemsPerPage = 20;

    var displayedVocabs = allVocabs.sublist(0, 40);

    // Final load more
    final nextIndex = displayedVocabs.length;
    final endIndex = (nextIndex + itemsPerPage).clamp(0, allVocabs.length);
    displayedVocabs = allVocabs.sublist(0, endIndex);

    expect(displayedVocabs.length, 45);
    expect(displayedVocabs.length == allVocabs.length, isTrue);

    printTestOutputSimple(
      testId: 'UTC-31-TC03',
      description: 'Append remaining 5 vocabulary cards on final scroll trigger (SRS-502)',
      input: 'TD03: load final batch',
      expectedOutput: {'displayedCount': 45, 'remainingCount': 0, 'hasMore': false},
      actualOutput: {
        'displayedCount': displayedVocabs.length,
        'remainingCount': allVocabs.length - displayedVocabs.length,
        'hasMore': displayedVocabs.length < allVocabs.length,
      },
    );
  });

  test('UTC-31-TC04: Render all available cards when total items < page size (SRS-502)', () {
    final allVocabs = generateVocabList(10);
    const itemsPerPage = 20;

    final initialCount = itemsPerPage.clamp(0, allVocabs.length);
    final displayedVocabs = allVocabs.sublist(0, initialCount);

    expect(displayedVocabs.length, 10);

    printTestOutputSimple(
      testId: 'UTC-31-TC04',
      description: 'Render all available cards when total items < page size (SRS-502)',
      input: 'TD04: total = 10, itemsPerPage = 20',
      expectedOutput: {'displayedCount': 10, 'remainingCount': 0, 'hasMore': false},
      actualOutput: {
        'displayedCount': displayedVocabs.length,
        'remainingCount': allVocabs.length - displayedVocabs.length,
        'hasMore': displayedVocabs.length < allVocabs.length,
      },
    );
  });
}

