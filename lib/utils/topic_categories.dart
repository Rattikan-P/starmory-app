/// Vocabulary topic categories for AI generation and review filtering
class TopicCategories {
  TopicCategories._();

  static const List<String> all = [
    food,
    people,
    nature,
    home,
    dailyLife,
    clothing,
    hobbies,
    education,
    work,
    technology,
    health,
    entertainment,
    other,
  ];

  // Category identifiers
  static const String food = 'food';
  static const String people = 'people';
  static const String nature = 'nature';
  static const String home = 'home';
  static const String dailyLife = 'daily_life';
  static const String clothing = 'clothing';
  static const String hobbies = 'hobbies';
  static const String education = 'education';
  static const String work = 'work';
  static const String technology = 'technology';
  static const String health = 'health';
  static const String entertainment = 'entertainment';
  static const String other = 'other';

  // Display names (Thai)
  static const Map<String, String> displayNamesTh = {
    food: 'อาหาร & เครื่องดื่ม',
    people: 'คน & ครอบครัว',
    nature: 'ธรรมชาติ & สัตว์',
    home: 'บ้าน & สิ่งของ',
    dailyLife: 'ชีวิตประจำวัน',
    clothing: 'เสื้อผ้า & แฟชั่น',
    hobbies: 'งานอดิเรก & กีฬา',
    education: 'การศึกษา',
    work: 'งาน & ธุรกิจ',
    technology: 'เทคโนโลยี',
    health: 'สุขภาพ',
    entertainment: 'บันเทิง',
    other: 'อื่นๆ',
  };

  // Display names (English)
  static const Map<String, String> displayNamesEn = {
    food: 'Food & Drinks',
    people: 'People & Family',
    nature: 'Nature & Animals',
    home: 'Home & Things',
    dailyLife: 'Daily Life',
    clothing: 'Clothing & Fashion',
    hobbies: 'Hobbies & Sports',
    education: 'Education',
    work: 'Work & Business',
    technology: 'Technology',
    health: 'Health',
    entertainment: 'Entertainment',
    other: 'Other',
  };

  // Category descriptions for AI
  static const Map<String, String> descriptions = {
    food: 'Food, drinks, cooking, restaurants',
    people: 'People, family members, professions, relationships',
    nature: 'Animals, plants, weather, landscape, environment',
    home: 'Furniture, rooms, household items',
    dailyLife: 'Daily routines, transportation, places, locations',
    clothing: 'Clothing, shoes, accessories, fashion',
    hobbies: 'Sports, games, leisure activities, arts',
    education: 'School, learning, subjects, studying',
    work: 'Office, business, jobs, meetings',
    technology: 'Computers, phones, apps, digital devices',
    health: 'Body, medicine, hospital, fitness',
    entertainment: 'Movies, music, games, fun activities',
    other: 'Anything that doesn\'t fit the above categories',
  };

  /// Get Thai display name for a category
  static String getDisplayNameTh(String category) {
    return displayNamesTh[category] ?? displayNamesTh[other]!;
  }

  /// Get English display name for a category
  static String getDisplayNameEn(String category) {
    return displayNamesEn[category] ?? displayNamesEn[other]!;
  }

  /// Get description for AI prompt
  static String getDescription(String category) {
    return descriptions[category] ?? descriptions[other]!;
  }

  /// Build category selection string for AI prompt
  static String buildPromptString() {
    final buffer = StringBuffer();
    buffer.writeln('Choose ONE category from this list:');
    for (final category in all) {
      buffer.writeln('  - $category: ${descriptions[category]}');
    }
    return buffer.toString();
  }

  /// Validate if a string is a valid category
  static bool isValid(String? category) {
    if (category == null || category.isEmpty) return false;
    return all.contains(category);
  }

  /// Get a safe category (returns 'other' if invalid)
  static String safeValue(String? category) {
    return isValid(category) ? category! : other;
  }
}
