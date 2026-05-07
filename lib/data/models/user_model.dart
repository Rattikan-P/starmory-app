enum LanguageLevel {
  beginner,
  intermediate,
  advanced,
}

enum EnglishVariant {
  us,
  uk,
}

class UserModel {
  final String id;
  final String email;
  final String? displayName;
  final LanguageLevel? languageLevel;
  final EnglishVariant? englishVariant;
  final DateTime createdAt;
  final bool isGuest;

  UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.languageLevel,
    this.englishVariant,
    required this.createdAt,
    this.isGuest = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      languageLevel: json['language_level'] != null
          ? LanguageLevel.values.firstWhere(
              (e) => e.name == json['language_level'],
              orElse: () => LanguageLevel.beginner,
            )
          : null,
      englishVariant: json['english_variant'] != null
          ? EnglishVariant.values.firstWhere(
              (e) => e.name == json['english_variant'],
              orElse: () => EnglishVariant.us,
            )
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      isGuest: json['is_guest'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'language_level': languageLevel?.name,
      'english_variant': englishVariant?.name,
      'created_at': createdAt.toIso8601String(),
      'is_guest': isGuest,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    LanguageLevel? languageLevel,
    EnglishVariant? englishVariant,
    DateTime? createdAt,
    bool? isGuest,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      languageLevel: languageLevel ?? this.languageLevel,
      englishVariant: englishVariant ?? this.englishVariant,
      createdAt: createdAt ?? this.createdAt,
      isGuest: isGuest ?? this.isGuest,
    );
  }
}
