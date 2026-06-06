import 'vocabulary_model.dart';

/// Vocabulary word with position on image for interactive display
class VocabularyWithPosition {
  final VocabularyModel vocabulary;
  final double x; // Normalized x position (0-1)
  final double y; // Normalized y position (0-1)
  final String? objectId; // Optional object identifier
  bool isSelected;

  VocabularyWithPosition({
    required this.vocabulary,
    required this.x,
    required this.y,
    this.objectId,
    this.isSelected = false,
  });

  VocabularyWithPosition copyWith({
    VocabularyModel? vocabulary,
    double? x,
    double? y,
    String? objectId,
    bool? isSelected,
  }) {
    return VocabularyWithPosition(
      vocabulary: vocabulary ?? this.vocabulary,
      x: x ?? this.x,
      y: y ?? this.y,
      objectId: objectId ?? this.objectId,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

/// Generation result with multiple vocabulary words and their positions
class VocabularyGenerationResult {
  final List<VocabularyWithPosition> vocabularies;
  final String imageUrl;
  final String cefrLevel;
  final String communicativeFunction;

  VocabularyGenerationResult({
    required this.vocabularies,
    required this.imageUrl,
    required this.cefrLevel,
    required this.communicativeFunction,
  });

  /// Get selected vocabularies
  List<VocabularyWithPosition> get selected =>
      vocabularies.where((v) => v.isSelected).toList();

  /// Get selected vocabulary models
  List<VocabularyModel> get selectedVocabularies =>
      selected.map((v) => v.vocabulary).toList();
}
