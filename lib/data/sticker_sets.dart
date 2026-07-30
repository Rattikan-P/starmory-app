/// Sticker Set Configuration
/// Defines available sticker packs in the app
class StickerSet {
  final String id;
  final String name;
  final String assetFolder; // Folder path in assets
  final int count; // Number of stickers in this set
  final List<String>? customFiles; // Optional: custom filenames (e.g., ['planet.png', 'star.png'])
  final bool isLocked; // Whether this set is locked
  final int? requiredStreakDays; // Days required to unlock (if locked)

  const StickerSet({
    required this.id,
    required this.name,
    required this.assetFolder,
    required this.count,
    this.customFiles,
    this.isLocked = false,
    this.requiredStreakDays,
  });
}

/// Available sticker sets
/// Update counts when you add/remove stickers
const List<StickerSet> stickerSets = [
  StickerSet(
    id: 'doodle',
    name: 'Doodle',
    assetFolder: 'assets/stickers/doodle',
    count: 20,
    isLocked: false,
  ),
  StickerSet(
    id: 'flower',
    name: 'Flower',
    assetFolder: 'assets/stickers/flower',
    count: 16,
    isLocked: false,
  ),
  StickerSet(
    id: 'space',
    name: 'Space',
    assetFolder: 'assets/stickers/space',
    count: 16,
    isLocked: false,
  ),
];

/// Get sticker asset path for a set and index
/// If customFiles is provided, use those names; otherwise use auto-numbered files (1.png, 2.png, etc.)
String getStickerAsset(String setId, int index) {
  final set = stickerSets.firstWhere((s) => s.id == setId);

  // If custom filenames are provided, use them
  if (set.customFiles != null && set.customFiles!.isNotEmpty) {
    return '${set.assetFolder}/${set.customFiles![index]}';
  }

  // Otherwise use auto-numbered files (1.png, 2.png, 3.png, etc. without leading zeros)
  final number = index + 1;
  return '${set.assetFolder}/$number.png';
}
