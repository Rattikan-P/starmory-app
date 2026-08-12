import 'package:equatable/equatable.dart';

/// Text overlay on a scrapbook page
class ScrapbookTextOverlay extends Equatable {
  final String id;
  final String text;
  final double x; // Position 0.0 - 1.0 (relative to image)
  final double y;
  final int color; // ARGB color
  final double fontSize;
  final String fontFamily;
  final double scale; // Scale multiplier for resizing
  final double rotation; // Rotation in radians
  final bool flip; // Horizontal flip (mirror)
  final int? backgroundColor; // ARGB background color, null = transparent
  final double? width; // Width as fraction of canvas width (0.0 - 1.0), null = auto

  const ScrapbookTextOverlay({
    required this.id,
    required this.text,
    required this.x,
    required this.y,
    this.color = 0xFF000000,
    this.fontSize = 16.0,
    this.fontFamily = 'Lexend',
    this.scale = 1.0,
    this.rotation = 0.0,
    this.flip = false,
    this.backgroundColor,
    this.width,
  });

  ScrapbookTextOverlay copyWith({
    String? id,
    String? text,
    double? x,
    double? y,
    int? color,
    double? fontSize,
    String? fontFamily,
    double? scale,
    double? rotation,
    bool? flip,
    int? backgroundColor,
    double? width,
  }) {
    return ScrapbookTextOverlay(
      id: id ?? this.id,
      text: text ?? this.text,
      x: x ?? this.x,
      y: y ?? this.y,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      flip: flip ?? this.flip,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      width: width ?? this.width,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'x': x,
      'y': y,
      'color': color,
      'fontSize': fontSize,
      'fontFamily': fontFamily,
      'scale': scale,
      'rotation': rotation,
      'flip': flip,
      'backgroundColor': backgroundColor,
      'width': width,
    };
  }

  factory ScrapbookTextOverlay.fromJson(Map<String, dynamic> json) {
    return ScrapbookTextOverlay(
      id: json['id'] as String,
      text: json['text'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      color: json['color'] as int? ?? 0xFF000000,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
      fontFamily: json['fontFamily'] as String? ?? 'Lexend',
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      flip: json['flip'] as bool? ?? false,
      backgroundColor: json['backgroundColor'] as int?,
      width: (json['width'] as num?)?.toDouble(),
    );
  }

  @override
  List<Object?> get props => [id, text, x, y, color, fontSize, fontFamily, scale, rotation, flip, backgroundColor, width];
}

/// Sticker/emoji on a scrapbook page
class ScrapbookSticker extends Equatable {
  final String id;
  final String emoji;
  final double x; // Position 0.0 - 1.0
  final double y;
  final double scale;
  final double rotation; // Rotation in radians
  final bool flip; // Horizontal flip (mirror)

  const ScrapbookSticker({
    required this.id,
    required this.emoji,
    required this.x,
    required this.y,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.flip = false,
  });

  ScrapbookSticker copyWith({
    String? id,
    String? emoji,
    double? x,
    double? y,
    double? scale,
    double? rotation,
    bool? flip,
  }) {
    return ScrapbookSticker(
      id: id ?? this.id,
      emoji: emoji ?? this.emoji,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      flip: flip ?? this.flip,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'emoji': emoji,
      'x': x,
      'y': y,
      'scale': scale,
      'rotation': rotation,
      'flip': flip,
    };
  }

  factory ScrapbookSticker.fromJson(Map<String, dynamic> json) {
    return ScrapbookSticker(
      id: json['id'] as String,
      emoji: json['emoji'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      flip: json['flip'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, emoji, x, y, scale, rotation, flip];
}

/// Additional photo on a scrapbook page
class ScrapbookPhoto extends Equatable {
  final String id;
  final String imagePath;
  final double x; // Position 0.0 - 1.0 (relative to canvas)
  final double y;
  final double width; // Width as fraction of canvas width (0.0 - 1.0)
  final double height; // Height as fraction of canvas height (0.0 - 1.0)
  final double rotation; // Rotation in radians
  final bool flip; // Horizontal flip (mirror)

  const ScrapbookPhoto({
    required this.id,
    required this.imagePath,
    required this.x,
    required this.y,
    this.width = 0.25, // Default to 25% of canvas width
    this.height = 0.25, // Default to 25% of canvas height
    this.rotation = 0.0,
    this.flip = false,
  });

  ScrapbookPhoto copyWith({
    String? id,
    String? imagePath,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    bool? flip,
  }) {
    return ScrapbookPhoto(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      flip: flip ?? this.flip,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imagePath': imagePath,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'rotation': rotation,
      'flip': flip,
    };
  }

  factory ScrapbookPhoto.fromJson(Map<String, dynamic> json) {
    return ScrapbookPhoto(
      id: json['id'] as String,
      imagePath: json['imagePath'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num?)?.toDouble() ?? 0.25,
      height: (json['height'] as num?)?.toDouble() ?? 0.25,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      flip: json['flip'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, imagePath, x, y, width, height, rotation, flip];
}

/// Vocabulary word reference in a scrapbook
class ScrapbookVocabularyWord extends Equatable {
  final String word;
  final String thaiTranslation;
  final String partOfSpeech;

  const ScrapbookVocabularyWord({
    required this.word,
    required this.thaiTranslation,
    required this.partOfSpeech,
  });

  ScrapbookVocabularyWord copyWith({
    String? word,
    String? thaiTranslation,
    String? partOfSpeech,
  }) {
    return ScrapbookVocabularyWord(
      word: word ?? this.word,
      thaiTranslation: thaiTranslation ?? this.thaiTranslation,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'thaiTranslation': thaiTranslation,
      'partOfSpeech': partOfSpeech,
    };
  }

  factory ScrapbookVocabularyWord.fromJson(Map<String, dynamic> json) {
    return ScrapbookVocabularyWord(
      word: json['word'] as String,
      thaiTranslation: json['thaiTranslation'] as String,
      partOfSpeech: json['partOfSpeech'] as String,
    );
  }

  @override
  List<Object?> get props => [word, thaiTranslation, partOfSpeech];
}

/// Main Scrapbook Model
class ScrapbookModel extends Equatable {
  final String id;
  final DateTime date;
  final String imagePath;
  final List<ScrapbookVocabularyWord> vocabularyWords;
  final String englishSentence;
  final String thaiSentence;
  final String selectedEmoji;
  final int backgroundColor; // ARGB color
  final List<ScrapbookTextOverlay> textOverlays;
  final List<ScrapbookSticker> stickers;
  final List<ScrapbookPhoto> additionalPhotos; // Additional photos with positions
  final List<String> elementLayerOrder; // Order of elements (z-index), format: 'type:id'
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ScrapbookModel({
    required this.id,
    required this.date,
    required this.imagePath,
    this.vocabularyWords = const [],
    this.englishSentence = '',
    this.thaiSentence = '',
    this.selectedEmoji = '😊',
    this.backgroundColor = 0xFFFFFFFF,
    this.textOverlays = const [],
    this.stickers = const [],
    this.additionalPhotos = const [],
    this.elementLayerOrder = const [],
    required this.createdAt,
    this.updatedAt,
  });

  ScrapbookModel copyWith({
    String? id,
    DateTime? date,
    String? imagePath,
    List<ScrapbookVocabularyWord>? vocabularyWords,
    String? englishSentence,
    String? thaiSentence,
    String? selectedEmoji,
    int? backgroundColor,
    List<ScrapbookTextOverlay>? textOverlays,
    List<ScrapbookSticker>? stickers,
    List<ScrapbookPhoto>? additionalPhotos,
    List<String>? elementLayerOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ScrapbookModel(
      id: id ?? this.id,
      date: date ?? this.date,
      imagePath: imagePath ?? this.imagePath,
      vocabularyWords: vocabularyWords ?? this.vocabularyWords,
      englishSentence: englishSentence ?? this.englishSentence,
      thaiSentence: thaiSentence ?? this.thaiSentence,
      selectedEmoji: selectedEmoji ?? this.selectedEmoji,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textOverlays: textOverlays ?? this.textOverlays,
      stickers: stickers ?? this.stickers,
      additionalPhotos: additionalPhotos ?? this.additionalPhotos,
      elementLayerOrder: elementLayerOrder ?? this.elementLayerOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Generate unique ID
  static String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  /// Create from vocabulary generation result
  factory ScrapbookModel.fromVocabularyResult({
    required String imagePath,
    required List<ScrapbookVocabularyWord> vocabularyWords,
    required String englishSentence,
    required String thaiSentence,
    String selectedEmoji = '😊',
    DateTime? date,
  }) {
    final now = DateTime.now();
    return ScrapbookModel(
      id: _generateId(),
      date: date ?? now,
      imagePath: imagePath,
      vocabularyWords: vocabularyWords,
      englishSentence: englishSentence,
      thaiSentence: thaiSentence,
      selectedEmoji: selectedEmoji,
      backgroundColor: 0xFFFFFFFF,
      createdAt: now,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'imagePath': imagePath,
      'vocabularyWords': vocabularyWords.map((v) => v.toJson()).toList(),
      'englishSentence': englishSentence,
      'thaiSentence': thaiSentence,
      'selectedEmoji': selectedEmoji,
      'backgroundColor': backgroundColor,
      'textOverlays': textOverlays.map((t) => t.toJson()).toList(),
      'stickers': stickers.map((s) => s.toJson()).toList(),
      'additionalPhotos': additionalPhotos.map((p) => p.toJson()).toList(),
      'elementLayerOrder': elementLayerOrder,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory ScrapbookModel.fromJson(Map<String, dynamic> json) {
    return ScrapbookModel(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      imagePath: json['imagePath'] as String,
      vocabularyWords: (json['vocabularyWords'] as List<dynamic>?)
              ?.map((v) => ScrapbookVocabularyWord.fromJson(v as Map<String, dynamic>))
              .toList() ??
          [],
      englishSentence: json['englishSentence'] as String? ?? '',
      thaiSentence: json['thaiSentence'] as String? ?? '',
      selectedEmoji: json['selectedEmoji'] as String? ?? '😊',
      backgroundColor: json['backgroundColor'] as int? ?? 0xFFFFFFFF,
      textOverlays: (json['textOverlays'] as List<dynamic>?)
              ?.map((t) => ScrapbookTextOverlay.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      stickers: (json['stickers'] as List<dynamic>?)
              ?.map((s) => ScrapbookSticker.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      additionalPhotos: (json['additionalPhotos'] as List<dynamic>?)
              ?.map((p) => ScrapbookPhoto.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      elementLayerOrder: (json['elementLayerOrder'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  /// Create from Supabase JSON (snake_case from database)
  factory ScrapbookModel.fromSupabaseJson(Map<String, dynamic> json) {
    return ScrapbookModel(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      imagePath: json['image_path'] as String? ?? json['imagePath'] as String,
      vocabularyWords: (json['vocabulary_words'] as List<dynamic>?)
              ?.map((v) => ScrapbookVocabularyWord.fromJson(v as Map<String, dynamic>))
              .toList() ??
          (json['vocabularyWords'] as List<dynamic>?)
              ?.map((v) => ScrapbookVocabularyWord.fromJson(v as Map<String, dynamic>))
              .toList() ??
          [],
      englishSentence: json['english_sentence'] as String? ?? json['englishSentence'] as String? ?? '',
      thaiSentence: json['thai_sentence'] as String? ?? json['thaiSentence'] as String? ?? '',
      selectedEmoji: json['selected_emoji'] as String? ?? json['selectedEmoji'] as String? ?? '😊',
      backgroundColor: json['background_color'] as int? ?? json['backgroundColor'] as int? ?? 0xFFFFFFFF,
      textOverlays: (json['text_overlays'] as List<dynamic>?)
              ?.map((t) => ScrapbookTextOverlay.fromJson(t as Map<String, dynamic>))
              .toList() ??
          (json['textOverlays'] as List<dynamic>?)
              ?.map((t) => ScrapbookTextOverlay.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      stickers: (json['stickers'] as List<dynamic>?)
              ?.map((s) => ScrapbookSticker.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      additionalPhotos: (json['additional_photos'] as List<dynamic>?)
              ?.map((p) => ScrapbookPhoto.fromJson(p as Map<String, dynamic>))
              .toList() ??
          (json['additionalPhotos'] as List<dynamic>?)
              ?.map((p) => ScrapbookPhoto.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      elementLayerOrder: (json['element_layer_order'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          (json['elementLayerOrder'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [id, date];
}
