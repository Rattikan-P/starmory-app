import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/sticker_sets.dart';
import '../providers/providers.dart';
import '../widgets/galaxy_screen_background.dart';

class StickersPage extends ConsumerStatefulWidget {
  const StickersPage({super.key});

  @override
  ConsumerState<StickersPage> createState() => _StickersPageState();
}

class _StickersPageState extends ConsumerState<StickersPage> {
  String _filter = 'All'; // 'All', 'Unlocked', 'Locked'

  @override
  Widget build(BuildContext context) {
    final stickerState = ref.watch(stickerStateProvider);
    final userState = ref.watch(userStateProvider);
    final vocabState = ref.watch(vocabularyStateProvider);

    final totalStars = vocabState.vocabularies.length;
    final streakDays = userState.user?.currentStreak ?? 0;
    final natureVocabCount = vocabState.vocabularies
        .where((v) => v.topic.toLowerCase() == 'nature')
        .length;

    final totalPacks = stickerState.totalPacksCount;
    final unlockedCount = stickerState.unlockedCount;
    final progressPercent = totalPacks > 0 ? (unlockedCount / totalPacks) : 0.0;
    final progressPercentInt = (progressPercent * 100).toInt();

    // Check and unlock packs if eligible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(stickerStateProvider.notifier).checkAndUnlockPacks(
            totalStars: totalStars,
            streakDays: streakDays,
            natureVocabCount: natureVocabCount,
            context: context,
          );
    });

    final packs = stickerState.packs;
    final filteredPacks = packs.where((pack) {
      if (_filter == 'Unlocked') return !pack.isLocked;
      if (_filter == 'Locked') return pack.isLocked;
      return true;
    }).toList();

    return GalaxyScreenBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Sticker Collection',
            style: GoogleFonts.lexend(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F2937),
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // Overall Collection Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDE9FE),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text('🎨', style: TextStyle(fontSize: 20)),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Scrapbook Stickers',
                                    style: GoogleFonts.lexend(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1F2937),
                                    ),
                                  ),
                                  Text(
                                    'Unlocked $unlockedCount of $totalPacks packs',
                                    style: GoogleFonts.lexend(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              '$progressPercentInt%',
                              style: GoogleFonts.lexend(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progressPercent,
                          backgroundColor: const Color(0xFFF3F4F6),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF8B5CF6),
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Filter Chips
                Row(
                  children: ['All', 'Unlocked', 'Locked'].map((filterName) {
                    final isSelected = _filter == filterName;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          filterName == 'All'
                              ? '🌟 All ($totalPacks)'
                              : filterName == 'Unlocked'
                                  ? '✨ Unlocked ($unlockedCount)'
                                  : '🔒 Locked (${totalPacks - unlockedCount})',
                          style: GoogleFonts.lexend(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? Colors.white : const Color(0xFF4B5563),
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: const Color(0xFF8B5CF6),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF8B5CF6)
                              : const Color(0xFFE5E7EB),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _filter = filterName);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Sticker Packs List
                Expanded(
                  child: filteredPacks.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: filteredPacks.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final pack = filteredPacks[index];
                            return _buildPackCard(
                              context,
                              pack,
                              totalStars: totalStars,
                              streakDays: streakDays,
                              natureVocabCount: natureVocabCount,
                              stickerState: stickerState,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPackCard(
    BuildContext context,
    StickerSet pack, {
    required int totalStars,
    required int streakDays,
    required int natureVocabCount,
    required StickerState stickerState,
  }) {
    final isLocked = pack.isLocked;
    final gradient = pack.gradientColors.isNotEmpty
        ? pack.gradientColors
        : const [Color(0xFF8B5CF6), Color(0xFF6366F1)];

    final progressRatio = stickerState.getProgressRatio(
      pack,
      totalStars: totalStars,
      streakDays: streakDays,
      natureVocabCount: natureVocabCount,
    );
    final progressLabel = stickerState.getProgressLabel(
      pack,
      totalStars: totalStars,
      streakDays: streakDays,
      natureVocabCount: natureVocabCount,
    );

    return InkWell(
      onTap: () => showStickerPackModal(
        context,
        pack,
        totalStars: totalStars,
        streakDays: streakDays,
        natureVocabCount: natureVocabCount,
        stickerState: stickerState,
      ),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLocked
                ? Colors.grey.withValues(alpha: 0.2)
                : gradient.first.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isLocked
                  ? Colors.black.withValues(alpha: 0.03)
                  : gradient.first.withValues(alpha: 0.1),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Pack Icon Preview + Info + Unlock Badge
            Row(
              children: [
                // Pack Avatar / Icon
                Container(
                  width: 58,
                  height: 58,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isLocked
                        ? Colors.grey.shade100
                        : const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isLocked
                          ? Colors.grey.shade300
                          : gradient.first.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: ColorFiltered(
                    colorFilter: isLocked
                        ? const ColorFilter.matrix(<double>[
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0,      0,      0,      0.45, 0,
                          ])
                        : const ColorFilter.mode(
                            Colors.transparent,
                            BlendMode.dst,
                          ),
                    child: Image.asset(
                      pack.previewAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.image_outlined,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Name & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${pack.name} Pack',
                              style: GoogleFonts.lexend(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isLocked
                                    ? const Color(0xFF4B5563)
                                    : const Color(0xFF1F2937),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${pack.count} stickers',
                              style: GoogleFonts.lexend(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF8B5CF6),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pack.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lexend(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),

                // Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isLocked
                        ? Colors.grey.shade100
                        : const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLocked ? Icons.lock_rounded : Icons.check_circle_rounded,
                        size: 13,
                        color: isLocked ? Colors.grey.shade600 : const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isLocked ? 'Locked' : 'Ready',
                        style: GoogleFonts.lexend(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isLocked ? Colors.grey.shade600 : const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Description
            Text(
              pack.descriptionTh.isNotEmpty ? pack.descriptionTh : pack.description,
              style: GoogleFonts.kanit(
                fontSize: 12,
                color: const Color(0xFF4B5563),
                height: 1.35,
              ),
            ),

            const SizedBox(height: 12),

            // Sample Stickers Row (first 5 PNGs)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(
                  math.min(5, pack.count),
                  (idx) => Container(
                    width: 42,
                    height: 42,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: ColorFiltered(
                      colorFilter: isLocked
                          ? const ColorFilter.matrix(<double>[
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0,      0,      0,      0.4, 0,
                            ])
                          : const ColorFilter.mode(
                              Colors.transparent,
                              BlendMode.dst,
                            ),
                      child: Image.asset(
                        getStickerAsset(pack.id, idx),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.image,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Unlock Requirement & Progress Bar (if locked)
            if (isLocked) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      getStickerUnlockRequirementTitle(pack),
                      style: GoogleFonts.kanit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B7280),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    progressLabel,
                    style: GoogleFonts.lexend(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progressRatio,
                  backgroundColor: const Color(0xFFF3F4F6),
                  valueColor: AlwaysStoppedAnimation<Color>(gradient.first),
                  minHeight: 6,
                ),
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.palette_outlined, size: 14, color: Color(0xFF8B5CF6)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Ready to use in Scrapbook',
                            style: GoogleFonts.lexend(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6B7280),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'View all ${pack.count} stickers ›',
                    style: GoogleFonts.lexend(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.category_outlined,
            size: 64,
            color: Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 16),
          Text(
            'No sticker packs found in this category',
            style: GoogleFonts.lexend(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper function to get readable unlock requirement title
String getStickerUnlockRequirementTitle(StickerSet pack) {
  switch (pack.unlockType) {
    case StickerUnlockType.free:
      return 'Free for everyone';
    case StickerUnlockType.streak:
      return '🎯 Requirement: ${pack.requiredStreakDays}-day streak';
    case StickerUnlockType.category:
      if (pack.requiredCategory?.toLowerCase() == 'nature') {
        return '🌿 Requirement: Collect ${pack.requiredCategoryCount} Nature words';
      }
      return 'Requirement: Collect ${pack.requiredCategoryCount} ${pack.requiredCategory} words';
    case StickerUnlockType.stars:
      return '⭐ Requirement: Collect ${pack.requiredStars} stars';
  }
}

/// Helper function to show sticker pack details in dark galaxy themed modal bottom sheet
void showStickerPackModal(
  BuildContext context,
  StickerSet pack, {
  required int totalStars,
  required int streakDays,
  required int natureVocabCount,
  required StickerState stickerState,
}) {
  final isLocked = pack.isLocked;
  final isUnlocked = !pack.isLocked;
  final gradient = pack.gradientColors.isNotEmpty
      ? pack.gradientColors
      : const [Color(0xFF8B5CF6), Color(0xFF6366F1)];

  final progressRatio = stickerState.getProgressRatio(
    pack,
    totalStars: totalStars,
    streakDays: streakDays,
    natureVocabCount: natureVocabCount,
  );
  final progressLabel = stickerState.getProgressLabel(
    pack,
    totalStars: totalStars,
    streakDays: streakDays,
    natureVocabCount: natureVocabCount,
  );

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1F8B5CF6),
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Pack Info (Avatar with glow + titles + status tag)
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isUnlocked
                          ? gradient
                          : [const Color(0xFFE2E8F0), const Color(0xFFCBD5E1)],
                    ),
                    boxShadow: isUnlocked
                        ? [
                            BoxShadow(
                              color: gradient.first.withValues(alpha: 0.35),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: ColorFiltered(
                    colorFilter: isLocked
                        ? const ColorFilter.matrix(<double>[
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0,      0,      0,      0.5, 0,
                          ])
                        : const ColorFilter.mode(
                            Colors.transparent,
                            BlendMode.dst,
                          ),
                    child: Image.asset(
                      pack.previewAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.image_outlined,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${pack.name} Pack',
                        style: GoogleFonts.lexend(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${pack.count} stickers',
                        style: GoogleFonts.lexend(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLocked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Text(
                      'LOCKED',
                      style: GoogleFonts.lexend(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            // Description Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pack.description,
                    style: GoogleFonts.lexend(
                      fontSize: 13,
                      color: const Color(0xFF334155),
                      height: 1.4,
                    ),
                  ),
                  if (isLocked) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            getStickerUnlockRequirementTitle(pack),
                            style: GoogleFonts.lexend(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF8B5CF6),
                            ),
                          ),
                        ),
                        Text(
                          progressLabel,
                          style: GoogleFonts.lexend(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF8B5CF6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progressRatio,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(gradient.first),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            Text(
              'All stickers in pack (${pack.count})',
              style: GoogleFonts.lexend(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),

            // Grid of Stickers
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemCount: pack.count,
                itemBuilder: (context, index) {
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isUnlocked
                            ? const Color(0xFFE2E8F0)
                            : const Color(0xFFF1F5F9),
                      ),
                    ),
                    child: ColorFiltered(
                      colorFilter: isLocked
                          ? const ColorFilter.matrix(<double>[
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0,      0,      0,      0.4, 0,
                            ])
                          : const ColorFilter.mode(
                              Colors.transparent,
                              BlendMode.dst,
                            ),
                      child: Image.asset(
                        getStickerAsset(pack.id, index),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.image,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Close Button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.lexend(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
