import '../../data/models/scrapbook_model.dart';
import '../../data/models/vocabulary_model.dart';

class WidgetVocabularySelection {
  static List<VocabularyModel> buildQueue({
    required Iterable<VocabularyModel> dueVocabulary,
    required Iterable<VocabularyModel> libraryVocabulary,
  }) {
    final seenIds = <String>{};
    return [
      for (final vocabulary in dueVocabulary)
        if (seenIds.add(vocabulary.id)) vocabulary,
      for (final vocabulary in libraryVocabulary)
        if (seenIds.add(vocabulary.id)) vocabulary,
    ];
  }

  static VocabularyModel? selectForDay({
    required List<VocabularyModel> queue,
    required int dueVocabularyCount,
    required int daySeed,
  }) {
    if (queue.isEmpty) return null;
    final priorityCount = dueVocabularyCount.clamp(0, queue.length).toInt();
    final selectionCount = priorityCount > 0 ? priorityCount : queue.length;
    final index = daySeed % selectionCount;
    return queue[index];
  }

  static Map<String, DateTime> buildScrapbookDateLookup({
    required Iterable<VocabularyModel> vocabularies,
    required Iterable<ScrapbookModel> scrapbooks,
  }) {
    final scrapbooksByWord = <String, List<ScrapbookModel>>{};
    for (final scrapbook in scrapbooks) {
      for (final scrapbookWord in scrapbook.vocabularyWords) {
        final normalizedWord = scrapbookWord.word.trim().toLowerCase();
        if (normalizedWord.isEmpty) continue;
        scrapbooksByWord.putIfAbsent(normalizedWord, () => []).add(scrapbook);
      }
    }
    for (final entries in scrapbooksByWord.values) {
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    final result = <String, DateTime>{};
    for (final vocabulary in vocabularies) {
      final relatedScrapbooks =
          scrapbooksByWord[vocabulary.word.trim().toLowerCase()];
      if (relatedScrapbooks == null || relatedScrapbooks.isEmpty) {
        result[vocabulary.id] = vocabulary.createdAt;
        continue;
      }

      final normalizedImage = _normalizeImageReference(vocabulary.imageUrl);
      if (normalizedImage.isEmpty) {
        result[vocabulary.id] = relatedScrapbooks.first.date;
        continue;
      }

      final matchingScrapbook = relatedScrapbooks
          .where(
            (scrapbook) =>
                _normalizeImageReference(scrapbook.imagePath) ==
                normalizedImage,
          )
          .firstOrNull;
      result[vocabulary.id] =
          matchingScrapbook?.date ?? vocabulary.createdAt;
    }
    return result;
  }

  static String _normalizeImageReference(String reference) {
    final trimmed = reference.trim();
    if (trimmed.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    if (uri?.scheme == 'file') return uri!.path;
    return trimmed.replaceAll(r'\', '/');
  }
}
