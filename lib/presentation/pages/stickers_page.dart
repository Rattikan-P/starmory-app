import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/providers.dart';
import '../widgets/galaxy_screen_background.dart';
import '../widgets/reward_icon_widget.dart';

class StickersPage extends ConsumerStatefulWidget {
  const StickersPage({super.key});

  @override
  ConsumerState<StickersPage> createState() => _StickersPageState();
}

class _StickersPageState extends ConsumerState<StickersPage> {
  String _selectedPack = 'All';

  @override
  Widget build(BuildContext context) {
    final stickerState = ref.watch(stickerStateProvider);
    final vocabState = ref.watch(vocabularyStateProvider);
    final totalStars = vocabState.vocabularies.length;

    final availablePacks = stickerState.availablePacks;
    final totalStickers = stickerState.stickers.length;
    final unlockedCount = stickerState.unlockedCount;
    final progressPercent = totalStickers > 0 ? (unlockedCount / totalStickers) : 0.0;
    final progressPercentInt = (progressPercent * 100).toInt();

    final filteredStickers = _selectedPack == 'All'
        ? stickerState.stickers
        : stickerState.stickers.where((s) => s.packName == _selectedPack).toList();

    // Check and unlock stickers if eligible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(stickerStateProvider.notifier).checkAndUnlockStickers(totalStars);
    });

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
            'My Stickers',
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
                    borderRadius: BorderRadius.circular(16),
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
                          Text(
                            'Sticker Collection',
                            style: GoogleFonts.lexend(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$progressPercentInt%',
                              style: GoogleFonts.lexend(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Unlocked $unlockedCount of $totalStickers stickers',
                        style: GoogleFonts.lexend(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 10),
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

                // Pack Tabs / Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: availablePacks.map((pack) {
                      final isSelected = _selectedPack == pack;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            pack == 'All' ? '🌟 All Packs' : '📦 $pack Pack',
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
                              setState(() {
                                _selectedPack = pack;
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 16),

                // Stickers Grid
                Expanded(
                  child: filteredStickers.isEmpty
                      ? _buildEmptyState()
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: filteredStickers.length,
                          itemBuilder: (context, index) {
                            final sticker = filteredStickers[index];
                            return _buildStickerCard(context, sticker, totalStars);
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

  Widget _buildStickerCard(BuildContext context, dynamic sticker, int totalStars) {
    final isLocked = sticker.isLocked;

    return InkWell(
      onTap: () => _showStickerDetailModal(context, sticker, totalStars),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLocked
                ? Colors.grey.withValues(alpha: 0.2)
                : const Color(0xFFE2D1F9).withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isLocked
                  ? Colors.black.withValues(alpha: 0.03)
                  : const Color(0xFF8B5CF6).withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isLocked
                    ? Colors.grey.withValues(alpha: 0.12)
                    : const Color(0xFFEDE9FE),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: RewardIconWidget(
                  icon: sticker.icon,
                  size: 28,
                  isLocked: isLocked,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                sticker.name,
                style: GoogleFonts.lexend(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isLocked ? Colors.grey : const Color(0xFF1F2937),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            if (isLocked)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_rounded, size: 11, color: Colors.grey.shade500),
                  const SizedBox(width: 2),
                  Text(
                    '${sticker.requiredStars} ⭐',
                    style: GoogleFonts.lexend(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF10B981)),
                  const SizedBox(width: 2),
                  Text(
                    'Ready to use',
                    style: GoogleFonts.lexend(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showStickerDetailModal(BuildContext context, dynamic sticker, int totalStars) {
    final isLocked = sticker.isLocked;
    final remainingStars = (sticker.requiredStars - totalStars).clamp(0, 999999);
    final progress = (totalStars / sticker.requiredStars).clamp(0.0, 1.0);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: isLocked
                      ? Colors.grey.shade100
                      : const Color(0xFFEDE9FE),
                  shape: BoxShape.circle,
                  boxShadow: isLocked
                      ? []
                      : [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                ),
                child: Center(
                  child: RewardIconWidget(
                    icon: sticker.icon,
                    size: 56,
                    isLocked: isLocked,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                sticker.name,
                style: GoogleFonts.lexend(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '📦 ${sticker.packName} Pack',
                      style: GoogleFonts.lexend(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF8B5CF6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLocked
                          ? Colors.grey.shade100
                          : const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isLocked ? '🔒 Locked' : '✨ Unlocked',
                      style: GoogleFonts.lexend(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isLocked ? Colors.grey.shade600 : const Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description',
                      style: GoogleFonts.lexend(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sticker.description,
                      style: GoogleFonts.lexend(
                        fontSize: 14,
                        color: const Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Required Stars',
                          style: GoogleFonts.lexend(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '${sticker.requiredStars} ⭐',
                          style: GoogleFonts.lexend(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF8B5CF6),
                          ),
                        ),
                      ],
                    ),
                    if (isLocked) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF8B5CF6),
                          ),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$remainingStars more stars needed to unlock',
                        style: GoogleFonts.lexend(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFE11D48),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Got It!',
                    style: GoogleFonts.lexend(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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
            'No stickers in this pack',
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
