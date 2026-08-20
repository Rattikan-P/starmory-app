import 'package:flutter/material.dart';

/// Unlock criteria type for a sticker pack
enum StickerUnlockType {
  free,
  streak,
  category,
  stars,
}

/// Sticker Set Configuration
/// Defines available sticker packs in the app
class StickerSet {
  final String id;
  final String name;
  final String nameTh;
  final String description;
  final String descriptionTh;
  final String assetFolder; // Folder path in assets
  final int count; // Number of stickers in this set
  final List<String>? customFiles; // Optional: custom filenames
  final bool isLocked; // Whether this set is locked
  final StickerUnlockType unlockType;
  final int? requiredStreakDays; // Days required to unlock (if streak-based)
  final String? requiredCategory; // Topic category required to unlock (if category-based, e.g. 'nature')
  final int? requiredCategoryCount; // Number of category vocabularies required
  final int? requiredStars; // Total stars required (if stars-based)
  final List<Color> gradientColors;

  const StickerSet({
    required this.id,
    required this.name,
    this.nameTh = '',
    this.description = '',
    this.descriptionTh = '',
    required this.assetFolder,
    required this.count,
    this.customFiles,
    this.isLocked = false,
    this.unlockType = StickerUnlockType.free,
    this.requiredStreakDays,
    this.requiredCategory,
    this.requiredCategoryCount,
    this.requiredStars,
    this.gradientColors = const [Color(0xFF8B5CF6), Color(0xFF6366F1)],
  });

  /// Get preview asset (first sticker in pack)
  String get previewAsset => getStickerAsset(id, 0);

  /// Create a copy with modified fields
  StickerSet copyWith({
    String? id,
    String? name,
    String? nameTh,
    String? description,
    String? descriptionTh,
    String? assetFolder,
    int? count,
    List<String>? customFiles,
    bool? isLocked,
    StickerUnlockType? unlockType,
    int? requiredStreakDays,
    String? requiredCategory,
    int? requiredCategoryCount,
    int? requiredStars,
    List<Color>? gradientColors,
  }) {
    return StickerSet(
      id: id ?? this.id,
      name: name ?? this.name,
      nameTh: nameTh ?? this.nameTh,
      description: description ?? this.description,
      descriptionTh: descriptionTh ?? this.descriptionTh,
      assetFolder: assetFolder ?? this.assetFolder,
      count: count ?? this.count,
      customFiles: customFiles ?? this.customFiles,
      isLocked: isLocked ?? this.isLocked,
      unlockType: unlockType ?? this.unlockType,
      requiredStreakDays: requiredStreakDays ?? this.requiredStreakDays,
      requiredCategory: requiredCategory ?? this.requiredCategory,
      requiredCategoryCount: requiredCategoryCount ?? this.requiredCategoryCount,
      requiredStars: requiredStars ?? this.requiredStars,
      gradientColors: gradientColors ?? this.gradientColors,
    );
  }
}

/// Available sticker sets
/// 1. Doodle: Free starter pack
/// 2. Flower: 100 Nature vocabularies
/// 3. Space: 7-day streak
const List<StickerSet> stickerSets = [
  StickerSet(
    id: 'doodle',
    name: 'Doodle',
    nameTh: 'ดูเดิลน่ารัก',
    description: 'Cute hand-drawn doodles to decorate your scrapbooks.',
    descriptionTh: 'ชุดสติกเกอร์ลายเส้นน่ารัก ฟรีสำหรับผู้ใช้ทุกคน!',
    assetFolder: 'assets/stickers/doodle',
    count: 20,
    isLocked: false,
    unlockType: StickerUnlockType.free,
    gradientColors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
  ),
  StickerSet(
    id: 'flower',
    name: 'Flower',
    nameTh: 'ดอกไม้และธรรมชาติ',
    description: 'Vibrant blooming flowers and plants for your memories.',
    descriptionTh: 'ชุดสติกเกอร์ดอกไม้และพืชพรรณธรรมชาติอันสดใส',
    assetFolder: 'assets/stickers/flower',
    count: 16,
    isLocked: true,
    unlockType: StickerUnlockType.category,
    requiredCategory: 'nature',
    requiredCategoryCount: 100,
    gradientColors: [Color(0xFF10B981), Color(0xFF06B6D4)],
  ),
  StickerSet(
    id: 'space',
    name: 'Space',
    nameTh: 'อวกาศและดวงดาว',
    description: 'Planets, rockets, and cosmic wonders from across the galaxy.',
    descriptionTh: 'ชุดสติกเกอร์ท่องอวกาศ ดวงดาว และกาแล็กซีสุดล้ำ',
    assetFolder: 'assets/stickers/space',
    count: 16,
    isLocked: true,
    unlockType: StickerUnlockType.streak,
    requiredStreakDays: 7,
    gradientColors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
  ),
];

/// Get sticker asset path for a set and index
/// If customFiles is provided, use those names; otherwise use auto-numbered files (1.png, 2.png, etc.)
String getStickerAsset(String setId, int index) {
  final set = stickerSets.firstWhere(
    (s) => s.id == setId,
    orElse: () => stickerSets.first,
  );

  // If custom filenames are provided, use them
  if (set.customFiles != null && set.customFiles!.isNotEmpty) {
    return '${set.assetFolder}/${set.customFiles![index]}';
  }

  // Otherwise use auto-numbered files (1.png, 2.png, 3.png, etc. without leading zeros)
  final number = index + 1;
  return '${set.assetFolder}/$number.png';
}
