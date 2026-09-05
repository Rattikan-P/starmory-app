import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/providers.dart';
import '../widgets/reward_icon_widget.dart';

import '../widgets/badges_section.dart';

class BadgesPage extends ConsumerStatefulWidget {
  const BadgesPage({super.key});

  @override
  ConsumerState<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends ConsumerState<BadgesPage> {
  String _selectedCategory = 'All';

  final List<String> _categories = ['All', 'Stars', 'Streak', 'Special'];

  @override
  Widget build(BuildContext context) {
    final badgeState = ref.watch(badgeStateProvider);
    final streakData = ref.watch(streakProvider);
    final vocabState = ref.watch(vocabularyStateProvider);
    final totalStars = vocabState.vocabularies.length;
    final currentStreak = streakData?.currentStreak ?? 0;

    final totalBadges = badgeState.badges.length;
    final unlockedCount = badgeState.unlockedCount;
    final progressPercent = totalBadges > 0 ? (unlockedCount / totalBadges) : 0.0;
    final progressPercentInt = (progressPercent * 100).toInt();

    final filteredBadges = _selectedCategory == 'All'
        ? badgeState.badges
        : badgeState.badges.where((b) => b.category == _selectedCategory).toList();

    // Check and unlock badges if eligible (silently in background)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(badgeStateProvider.notifier).checkAndUnlockBadges(
            totalStars,
            currentStreak,
          );
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF221F33)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Badges',
          style: GoogleFonts.lexend(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF221F33),
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

              // Overall Progress Banner
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFEBE6FC),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C5CFC).withValues(alpha: 0.06),
                      blurRadius: 18,
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
                          'Collection Progress',
                          style: GoogleFonts.lexend(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF221F33),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4EEFF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$progressPercentInt%',
                            style: GoogleFonts.lexend(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF7C5CFC),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Unlocked $unlockedCount of $totalBadges badges',
                      style: GoogleFonts.lexend(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF9892A6),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progressPercent,
                        backgroundColor: const Color(0xFFF1EDFC),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF7C5CFC), // Primary Purple
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Category filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFF4EEFF) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF7C5CFC) : const Color(0xFFEBE6FC),
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            cat,
                            style: GoogleFonts.lexend(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? const Color(0xFF7C5CFC) : const Color(0xFF8E88A8),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              // Badges grid
              Expanded(
                child: filteredBadges.isEmpty
                    ? _buildEmptyState()
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: filteredBadges.length,
                        itemBuilder: (context, index) {
                          final badge = filteredBadges[index];
                          return _buildBadgeCard(
                            context,
                            badge,
                            badgeState,
                            totalStars: totalStars,
                            currentStreak: currentStreak,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeCard(
    BuildContext context,
    Badge badge,
    BadgeState badgeState, {
    int totalStars = 0,
    int currentStreak = 0,
  }) {
    final isUnlocked = !badge.isLocked;
    final progress = badgeState.getProgress(
      badge,
      totalStars: totalStars,
      streakDays: currentStreak,
    );
    final progressRatio = badgeState.getProgressRatio(
      badge,
      totalStars: totalStars,
      streakDays: currentStreak,
    );
    final gradient = badge.gradientColors.isNotEmpty
        ? badge.gradientColors
        : const [Color(0xFF8B5CF6), Color(0xFF6366F1)];

    return GestureDetector(
      onTap: () => showBadgeDetailsModal(context, badge, isUnlocked, progress),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isUnlocked
              ? const Color(0xFFF3E8FF).withValues(alpha: 0.6)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnlocked
                ? gradient.first.withValues(alpha: 0.4)
                : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: isUnlocked
              ? [
                  BoxShadow(
                    color: gradient.first.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Badge Icon Circle
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isUnlocked
                    ? LinearGradient(colors: gradient)
                    : const LinearGradient(
                        colors: [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
                      ),
                boxShadow: isUnlocked
                    ? [
                        BoxShadow(
                          color: gradient.first.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: RewardIconWidget(
                  icon: badge.icon,
                  size: 26,
                  isLocked: !isUnlocked,
                ),
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
                    ? const Color(0xFF1E293B)
                    : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 4),

            // Progress Indicator / Tag
            if (isUnlocked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
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
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progressRatio,
                        minHeight: 4,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          gradient.first,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$progress/${badge.requiredStars}',
                      style: GoogleFonts.lexend(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
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
            Icons.military_tech_outlined,
            size: 64,
            color: Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 16),
          Text(
            'No badges in this category',
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
