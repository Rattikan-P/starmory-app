import 'package:equatable/equatable.dart';
import 'vocabulary_model.dart';

/// FSRS Card State
enum CardState {
  newCard, // stored as 'new' in DB
  learning,
  review,
  relearning;

  static CardState fromString(String value) {
    return CardState.values.firstWhere(
      (e) => e.toValue() == value,
      orElse: () => CardState.newCard,
    );
  }

  /// Convert to database value (snake_case string)
  String toValue() {
    switch (this) {
      case CardState.newCard:
        return 'new';
      case CardState.learning:
        return 'learning';
      case CardState.review:
        return 'review';
      case CardState.relearning:
        return 'relearning';
    }
  }
}

/// Word Card Model for Spaced Repetition System
/// Stores FSRS (Free Spaced Repetition Scheduler) state
class WordCardModel extends Equatable {
  final String id;
  final String userId;
  final String vocabularyId;
  final double stability;
  final double difficulty;
  final CardState state;
  final DateTime dueDate;
  final DateTime? lastReview;
  final int reps;
  final int lapses;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Joined vocabulary data (populated when needed)
  final VocabularyModel? vocabulary;

  const WordCardModel({
    required this.id,
    required this.userId,
    required this.vocabularyId,
    this.stability = 0,
    this.difficulty = 0,
    this.state = CardState.newCard,
    required this.dueDate,
    this.lastReview,
    this.reps = 0,
    this.lapses = 0,
    required this.createdAt,
    this.updatedAt,
    this.vocabulary,
  });

  /// Create from Supabase JSON (snake_case from database)
  factory WordCardModel.fromSupabaseJson(Map<String, dynamic> json) {
    return WordCardModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      vocabularyId: json['vocabulary_id'] as String,
      stability: (json['stability'] as num?)?.toDouble() ?? 0,
      difficulty: (json['difficulty'] as num?)?.toDouble() ?? 0,
      state: CardState.fromString(json['state'] as String? ?? 'new'),
      dueDate: DateTime.parse(json['due_date'] as String),
      lastReview: json['last_review'] != null
          ? DateTime.parse(json['last_review'] as String)
          : null,
      reps: json['reps'] as int? ?? 0,
      lapses: json['lapses'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Create from local JSON (camelCase - for Hive storage)
  /// Note: dueDate is stored in local time (set by FSRS via .toLocal())
  factory WordCardModel.fromJson(Map<String, dynamic> json) {
    return WordCardModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      vocabularyId: json['vocabularyId'] as String,
      stability: (json['stability'] as num?)?.toDouble() ?? 0,
      difficulty: (json['difficulty'] as num?)?.toDouble() ?? 0,
      state: CardState.fromString(json['state'] as String? ?? 'new'),
      // Parse ISO-8601 string - assumes local time (matches FSRS .toLocal())
      dueDate: DateTime.parse(json['dueDate'] as String),
      lastReview: json['lastReview'] != null
          ? DateTime.parse(json['lastReview'] as String)
          : null,
      reps: json['reps'] as int? ?? 0,
      lapses: json['lapses'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      vocabulary: json['vocabulary'] != null
          ? VocabularyModel.fromJson(json['vocabulary'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Create from Supabase RPC function result (with joined vocabulary data)
  factory WordCardModel.fromSupabaseWithVocabulary(Map<String, dynamic> json) {
    final vocabJson = <String, dynamic>{
      'id': json['vocabulary_id'] as String,
      'word': json['word'] as String,
      'part_of_speech': '',
      'thai_translation': json['meaning'] as String,
      'english_sentence': json['example_sentence'] as String,
      'thai_sentence': '',
      'cefr_level': 'A1',
      'communicative_function': '',
      'language_variant': json['language_variant'] as String? ?? 'US',
      'image_url': json['photo_url'] as String,
      'topic': json['topic'] as String? ?? 'other',
      'created_at': json['due_date'] as String, // fallback
      'updated_at': null,
      'tags': [],
      'is_favorite': false,
    };

    return WordCardModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      vocabularyId: json['vocabulary_id'] as String,
      stability: (json['stability'] as num?)?.toDouble() ?? 0,
      difficulty: (json['difficulty'] as num?)?.toDouble() ?? 0,
      state: CardState.fromString(json['state'] as String? ?? 'new'),
      dueDate: DateTime.parse(json['due_date'] as String),
      lastReview: json['last_review'] != null
          ? DateTime.parse(json['last_review'] as String)
          : null,
      reps: json['reps'] as int? ?? 0,
      lapses: json['lapses'] as int? ?? 0,
      createdAt: DateTime.now().toUtc(), // fallback
      updatedAt: DateTime.now().toUtc(),
      vocabulary: VocabularyModel.fromSupabaseJson(vocabJson),
    );
  }

  WordCardModel copyWith({
    String? id,
    String? userId,
    String? vocabularyId,
    double? stability,
    double? difficulty,
    CardState? state,
    DateTime? dueDate,
    DateTime? lastReview,
    int? reps,
    int? lapses,
    DateTime? createdAt,
    DateTime? updatedAt,
    VocabularyModel? vocabulary,
  }) {
    return WordCardModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      vocabularyId: vocabularyId ?? this.vocabularyId,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      state: state ?? this.state,
      dueDate: dueDate ?? this.dueDate,
      lastReview: lastReview ?? this.lastReview,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      vocabulary: vocabulary ?? this.vocabulary,
    );
  }

  /// Convert to JSON for local storage (Hive - camelCase)
  Map<String, dynamic> toJson() {
    final now = DateTime.now().toUtc();
    final jsonMap = {
      'id': id,
      'userId': userId,
      'vocabularyId': vocabularyId,
      'stability': stability,
      'difficulty': difficulty,
      'state': state.toValue(),
      'dueDate': dueDate.toUtc().toIso8601String(),
      'lastReview': lastReview?.toUtc().toIso8601String(),
      'reps': reps,
      'lapses': lapses,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': (updatedAt ?? now).toUtc().toIso8601String(),
    };

    // Include vocabulary data if present (for Guest mode local storage)
    if (vocabulary != null) {
      jsonMap['vocabulary'] = vocabulary!.toJson();
    }

    return jsonMap;
  }

  /// Convert to JSON for Supabase (snake_case)
  Map<String, dynamic> toSupabaseJson() {
    final now = DateTime.now().toUtc();
    return {
      'id': id,
      'user_id': userId,
      'vocabulary_id': vocabularyId,
      'stability': stability,
      'difficulty': difficulty,
      'state': state.toValue(),
      'due_date': dueDate.toUtc().toIso8601String(),
      'last_review': lastReview?.toUtc().toIso8601String(),
      'reps': reps,
      'lapses': lapses,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': (updatedAt ?? now).toUtc().toIso8601String(),
    };
  }

  /// Check if card is due for review
  /// Uses millisecondsSinceEpoch comparison in UTC to avoid timezone and microsecond issues
  bool get isDue {
    final now = DateTime.now().toUtc();
    return now.millisecondsSinceEpoch >= dueDate.toUtc().millisecondsSinceEpoch;
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        vocabularyId,
        stability,
        difficulty,
        state,
        dueDate,
        reps,
        lapses,
      ];
}
