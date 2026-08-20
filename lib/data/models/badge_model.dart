import 'package:flutter/material.dart';

/// Categories for badges
enum BadgeCategory {
  timeBased,
  streakShield,
  learning,
  special,
}

/// Tier levels for badges
enum BadgeTier {
  bronze,
  silver,
  gold,
  nebula,
}

/// Represents an achievement badge in Starmory
class BadgeModel {
  final String id;
  final String title;
  final String titleTh;
  final String description;
  final String descriptionTh;
  final String iconEmoji;
  final BadgeCategory category;
  final BadgeTier tier;
  final int requirementCount;
  final List<Color> gradientColors;
  final IconData? iconData;

  const BadgeModel({
    required this.id,
    required this.title,
    required this.titleTh,
    required this.description,
    required this.descriptionTh,
    required this.iconEmoji,
    required this.category,
    required this.tier,
    required this.requirementCount,
    required this.gradientColors,
    this.iconData,
  });

  /// Get color for the tier badge indicator
  Color get tierColor {
    switch (tier) {
      case BadgeTier.bronze:
        return const Color(0xFFCD7F32);
      case BadgeTier.silver:
        return const Color(0xFFC0C0C0);
      case BadgeTier.gold:
        return const Color(0xFFFFD700);
      case BadgeTier.nebula:
        return const Color(0xFFC084FC);
    }
  }

  /// Get tier title string
  String get tierName {
    switch (tier) {
      case BadgeTier.bronze:
        return 'BRONZE';
      case BadgeTier.silver:
        return 'SILVER';
      case BadgeTier.gold:
        return 'GOLD';
      case BadgeTier.nebula:
        return 'NEBULA';
    }
  }
}

/// Registry of all defined badges in the app
class BadgeRegistry {
  static const String nightOwlId = 'night_owl';
  static const String lordOfDarkNebulaId = 'lord_of_dark_nebula';
  static const String morningNovaId = 'morning_nova';
  static const String solarPioneerId = 'solar_pioneer';
  static const String ironShieldId = 'iron_shield';

  static const List<BadgeModel> allBadges = [
    // 🌙 Night Owl: Active late night 22:00 - 04:00 (30 times)
    BadgeModel(
      id: nightOwlId,
      title: 'Night Owl',
      titleTh: 'นกฮูกราตรี',
      description: 'Active learning late at night (22:00 - 04:00) 30 times',
      descriptionTh: 'เรียนรู้คำศัพท์หรือทบทวนรอบดึก (22:00 - 04:00) ครบ 30 ครั้ง',
      iconEmoji: '🦉',
      category: BadgeCategory.timeBased,
      tier: BadgeTier.silver,
      requirementCount: 30,
      gradientColors: [Color(0xFF6B21A8), Color(0xFF3B82F6)],
      iconData: Icons.nights_stay,
    ),

    // 🪐 Lord of the Dark Nebula: Active late night 22:00 - 04:00 (50 times)
    BadgeModel(
      id: lordOfDarkNebulaId,
      title: 'Lord of the Dark Nebula',
      titleTh: 'เจ้าแห่งเนบิวลารามืด',
      description: 'Active learning late at night (22:00 - 04:00) 50 times',
      descriptionTh: 'เรียนรู้คำศัพท์หรือทบทวนรอบดึก (22:00 - 04:00) ครบ 50 ครั้ง',
      iconEmoji: '🪐',
      category: BadgeCategory.timeBased,
      tier: BadgeTier.nebula,
      requirementCount: 50,
      gradientColors: [Color(0xFF312E81), Color(0xFF7C3AED), Color(0xFF06B6D4)],
      iconData: Icons.auto_awesome,
    ),

    // 🌅 Morning Nova: Active early morning 05:00 - 08:00 (30 times)
    BadgeModel(
      id: morningNovaId,
      title: 'Morning Nova',
      titleTh: 'ซูเปอร์โนวารุ่งสาง',
      description: 'Active learning early morning (05:00 - 08:00) 30 times',
      descriptionTh: 'เรียนรู้คำศัพท์หรือทบทวนยามเช้าตรู่ (05:00 - 08:00) ครบ 30 ครั้ง',
      iconEmoji: '🌅',
      category: BadgeCategory.timeBased,
      tier: BadgeTier.silver,
      requirementCount: 30,
      gradientColors: [Color(0xFFFF7A00), Color(0xFFFFB800)],
      iconData: Icons.wb_twilight,
    ),

    // ☀️ Solar Pioneer: Active early morning 05:00 - 08:00 (50 times)
    BadgeModel(
      id: solarPioneerId,
      title: 'Solar Pioneer',
      titleTh: 'ผู้บุกเบิกแสงตะวัน',
      description: 'Active learning early morning (05:00 - 08:00) 50 times',
      descriptionTh: 'เรียนรู้คำศัพท์หรือทบทวนยามเช้าตรู่ (05:00 - 08:00) ครบ 50 ครั้ง',
      iconEmoji: '☀️',
      category: BadgeCategory.timeBased,
      tier: BadgeTier.gold,
      requirementCount: 50,
      gradientColors: [Color(0xFFEA580C), Color(0xFFF59E0B), Color(0xFFFEF08A)],
      iconData: Icons.wb_sunny,
    ),

    // 🛡️ Iron Shield: Protect streak with Streak Shield 3 times
    BadgeModel(
      id: ironShieldId,
      title: 'Iron Shield',
      titleTh: 'โล่เหล็กพิทักษ์สตรีค',
      description: 'Saved your streak with Streak Shield 3 times',
      descriptionTh: 'ใช้ Streak Shield ป้องกันสตรีคไม่ให้แตกสำเร็จ 3 ครั้ง',
      iconEmoji: '🛡️',
      category: BadgeCategory.streakShield,
      tier: BadgeTier.silver,
      requirementCount: 3,
      gradientColors: [Color(0xFF0284C7), Color(0xFF06B6D4), Color(0xFF38BDF8)],
      iconData: Icons.shield,
    ),
  ];

  /// Find badge by ID
  static BadgeModel? getById(String id) {
    try {
      return allBadges.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }
}
