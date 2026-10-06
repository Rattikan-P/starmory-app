import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/design_tokens.dart';
import '../providers/providers.dart';
import 'reward_icon_widget.dart';
import 'bottom_sheet_chrome.dart';
import 'rounded_progress_bar.dart';

/// Helper function to show badge details bottom sheet modal
void showBadgeDetailsModal(
  BuildContext context,
  Badge badge,
  bool isUnlocked,
  int progress,
) {
  final gradient = badge.gradientColors.isNotEmpty
      ? badge.gradientColors
      : const [Color(0xFF7C5CFC), Color(0xFF6366F1)];

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1F7C5CFC),
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            const AppBottomSheetDragHandle(),
            const SizedBox(height: 20),

            // Badge Icon with Glow
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isUnlocked ? LinearGradient(colors: gradient) : null,
                color: isUnlocked ? null : const Color(0xFFF0EEF3),
                border: isUnlocked
                    ? null
                    : Border.all(color: const Color(0xFFE1DDE6)),
                boxShadow: isUnlocked
                    ? [
                        BoxShadow(
                          color: gradient.first.withValues(alpha: 0.35),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  RewardIconWidget(
                    icon: badge.icon,
                    size: 44,
                    isLocked: !isUnlocked,
                  ),
                  if (!isUnlocked)
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFDAD6E0),
                          ),
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          size: 14,
                          color: Color(0xFF817B89),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Tier Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: badge.tierColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: badge.tierColor.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                badge.tier.toUpperCase(),
                style: GoogleFonts.lexend(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: badge.tierColor,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Title
            Text(
              badge.name,
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF221F33),
              ),
            ),
            const SizedBox(height: 2),

            const SizedBox(height: 14),

            // Description Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF4EEFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE2DBFD),
                ),
              ),
              child: Text(
                badge.description,
                textAlign: TextAlign.center,
                style: GoogleFonts.lexend(
                  fontSize: 13,
                  color: const Color(0xFF4C3E72),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Progress Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isUnlocked ? 'Status: Unlocked ✨' : 'Progress',
                  style: GoogleFonts.lexend(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isUnlocked
                        ? const Color(0xFF059669)
                        : const Color(0xFF655D80),
                  ),
                ),
                Text(
                  isUnlocked
                      ? 'Completed'
                      : '$progress / ${badge.requiredStars}',
                  style: GoogleFonts.lexend(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isUnlocked
                        ? const Color(0xFF059669)
                        : const Color(0xFF7C5CFC),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            RoundedProgressBar(
              value: isUnlocked
                  ? 1.0
                  : (progress / badge.requiredStars).clamp(0.0, 1.0),
              height: 8,
              trackColor: const Color(0xFFEBE6FC),
              valueColor:
                  isUnlocked ? const Color(0xFF10B981) : gradient.first,
            ),
            const SizedBox(height: 24),

            // Close Button
            SizedBox(
              width: double.infinity,
              height: DesignTokens.dialogButtonHeight,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.dialogBrand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      DesignTokens.dialogButtonRadius,
                    ),
                  ),
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.lexend(
                    fontSize: DesignTokens.dialogButtonFontSize,
                    fontWeight: DesignTokens.weightSemiBold,
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

/// Showcase widget for displaying user badges and achievements in Profile
class BadgesSection extends ConsumerWidget {
  final VoidCallback? onSeeAll;
  final EdgeInsetsGeometry? margin;

  const BadgesSection({
    super.key,
    this.onSeeAll,
    this.margin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgeState = ref.watch(badgeStateProvider);
    final vocabState = ref.watch(vocabularyStateProvider);
    final streakData = ref.watch(streakProvider);
    final totalStars = vocabState.vocabularies.length;
    final streakDays = streakData?.currentStreak ?? 0;
    final allBadges = badgeState.badges;

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C5CFC).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFEBE6FC),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'ACHIEVEMENT BADGES',
                  style: GoogleFonts.lexend(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7C5CFC),
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4EEFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${badgeState.unlockedCount}/${badgeState.totalBadgesCount}',
                    style: GoogleFonts.lexend(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF7C5CFC),
                    ),
                  ),
                ),
                if (onSeeAll != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onSeeAll,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      child: Row(
                        children: [
                          Text(
                            'See All',
                            style: GoogleFonts.lexend(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF7C5CFC),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F2F5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Horizontal List of Badges
          SizedBox(
            height: 144,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              scrollDirection: Axis.horizontal,
              itemCount: allBadges.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final badge = allBadges[index];
                final isUnlocked = !badge.isLocked;
                final progress = badgeState.getProgress(
                  badge,
                  totalStars: totalStars,
                  streakDays: streakDays,
                );
                final progressRatio = badgeState.getProgressRatio(
                  badge,
                  totalStars: totalStars,
                  streakDays: streakDays,
                );
                final gradient = badge.gradientColors.isNotEmpty
                    ? badge.gradientColors
                    : const [Color(0xFF7C5CFC), Color(0xFF6366F1)];

                return GestureDetector(
                  onTap: () => showBadgeDetailsModal(
                      context, badge, isUnlocked, progress),
                  child: Container(
                    width: 104,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isUnlocked ? Colors.white : const Color(0xFFF6F4F8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isUnlocked
                            ? gradient.first.withValues(alpha: 0.4)
                            : const Color(0xFFEBE6FC),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Badge Icon Circle
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isUnlocked
                                ? Color.alphaBlend(
                                    gradient.first.withValues(alpha: 0.10),
                                    Colors.white,
                                  )
                                : const Color(0xFFF0EEF3),
                            border: Border.all(
                              color: isUnlocked
                                  ? gradient.first.withValues(alpha: 0.28)
                                  : const Color(0xFFE9E5EF),
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              RewardIconWidget(
                                icon: badge.icon,
                                size: 30,
                                isLocked: !isUnlocked,
                              ),
                              if (!isUnlocked)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFFDAD6E0),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.lock_rounded,
                                      size: 10,
                                      color: Color(0xFF817B89),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Title
                        Text(
                          badge.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.lexend(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isUnlocked
                                ? const Color(0xFF221F33)
                                : const Color(0xFF9892A6),
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Progress Indicator / Tag
                        if (isUnlocked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'UNLOCKED',
                              style: GoogleFonts.lexend(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF059669),
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RoundedProgressBar(
                                  value: progressRatio,
                                  trackColor: const Color(0xFFEBE6FC),
                                  valueColor: gradient.first,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$progress/${badge.requiredStars}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.lexend(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF655D80),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
