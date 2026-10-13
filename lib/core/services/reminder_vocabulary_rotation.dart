import '../../data/models/vocabulary_model.dart';

class ReminderVocabularyRotation {
  static List<VocabularyModel> buildCandidates({
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

  static List<VocabularyModel> selectBatch({
    required List<VocabularyModel> candidates,
    required String? previousBatchLastVocabularyId,
    required int count,
  }) {
    if (candidates.isEmpty || count <= 0) return const [];

    final previousIndex = candidates.indexWhere(
      (vocabulary) => vocabulary.id == previousBatchLastVocabularyId,
    );
    final startIndex =
        previousIndex < 0 ? 0 : (previousIndex + 1) % candidates.length;

    return List.generate(
      count,
      (index) => candidates[(startIndex + index) % candidates.length],
    );
  }
}
