import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/vocabulary_model.dart';
import '../providers/providers.dart';
import '../widgets/galaxy_screen_background.dart';
import 'badges_page.dart';
import 'stickers_page.dart';

class ProgressTab extends ConsumerStatefulWidget {
  const ProgressTab({super.key});

  @override
  ConsumerState<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends ConsumerState<ProgressTab> {
  // Tab state
  String _selectedTab = 'Vocab';

  // Filter state (for Vocab tab)
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vocabState = ref.watch(vocabularyStateProvider);
    final streakData = ref.watch(streakProvider);

    // Get all vocabularies
    final allVocabularies = vocabState.vocabularies;

    // Calculate stats
    final totalStars = allVocabularies.length;
    final uniqueImages = allVocabularies.map((v) => v.imageUrl).toSet();
    final totalPhotos = uniqueImages.where((url) => url.isNotEmpty).length;
    final daysLearning = streakData?.currentStreak ?? 0;
    final shields = streakData?.shieldsAvailable ?? 0;
    final streakMultiplier = _calculateStreakMultiplier(daysLearning);

    // Apply filters
    List<VocabularyModel> filteredVocabularies = _applyFilters(allVocabularies);

    return GalaxyScreenBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Streak Banner
                      _buildStreakBanner(daysLearning, streakMultiplier, shields),

                      const SizedBox(height: 12),

                      // Stars Stats Card
                      _buildStarsStatsCard(totalStars),

                      const SizedBox(height: 12),

                      // Mini Stats Row
                      _buildMiniStatsRow(totalPhotos, daysLearning),

                      const SizedBox(height: 16),

                      // Tab Bar
                      _buildTabBar(),

                      const SizedBox(height: 16),

                      // Tab content
                      if (_selectedTab == 'Vocab')
                        _buildGalaxyCollectionSection(filteredVocabularies, totalStars)
                      else
                        _buildRewardSection(),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _calculateStreakMultiplier(int streak) {
    if (streak >= 30) return 3;
    if (streak >= 14) return 2;
    if (streak >= 7) return 2;
    return 1;
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Text(
            'My Progress',
            style: GoogleFonts.lexend(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakBanner(int days, int multiplier, int shields) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B35), // Orange-red
            const Color(0xFFFF8C42).withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_fire_department,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            '$days Day Streak!',
            style: GoogleFonts.lexend(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          // Shield badge
          GestureDetector(
            onTap: () => _showShieldInfoDialog(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$shields',
                    style: GoogleFonts.lexend(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarsStatsCard(int totalStars) {
    // Calculate progress toward next badge (every 50 stars)
    final nextBadgeThreshold = ((totalStars ~/ 50) + 1) * 50;
    final progress = totalStars % 50;
    final progressPercent = progress / 50;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stars count
          Row(
            children: [
              Text(
                '$totalStars',
                style: GoogleFonts.lexend(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1f2937),
                  height: 1,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'stars in your galaxy',
                      style: GoogleFonts.lexend(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF2d2d44),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$progress / 50',
                    style: GoogleFonts.lexend(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8B5CF6), // Purple
                    ),
                  ),
                  Text(
                    'STARS TO unlock 🏅 New Badge',
                    style: GoogleFonts.lexend(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6b7280),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progressPercent,
                  backgroundColor: const Color(0xFFf3f4f6),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF8B5CF6), // Purple
                  ),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatsRow(int photos, int days) {
    return Row(
      children: [
        Expanded(
          child: _buildMiniStatCard(
            icon: Icons.photo_library_rounded,
            label: 'photos captured',
            value: '$photos',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMiniStatCard(
            icon: Icons.calendar_today_rounded,
            label: 'days learning',
            value: '$days',
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE), // Light purple
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 22,
              color: const Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.lexend(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1f2937),
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.lexend(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF6b7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Vocab Tab
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedTab = 'Vocab';
                });
              },
              borderRadius: BorderRadius.circular(24),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: _selectedTab == 'Vocab'
                      ? const Color(0xFFEDE9FE) // Light purple
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.star,
                      size: 20,
                      color: _selectedTab == 'Vocab'
                          ? const Color(0xFF8B5CF6)
                          : const Color(0xFF9ca3af),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Vocab',
                      style: GoogleFonts.lexend(
                        fontSize: 15,
                        fontWeight: _selectedTab == 'Vocab'
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: _selectedTab == 'Vocab'
                            ? const Color(0xFF1f2937)
                            : const Color(0xFF9ca3af),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Reward Tab
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedTab = 'Reward';
                });
              },
              borderRadius: BorderRadius.circular(24),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: _selectedTab == 'Reward'
                      ? const Color(0xFFEDE9FE) // Light purple
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.card_giftcard,
                      size: 20,
                      color: _selectedTab == 'Reward'
                          ? const Color(0xFF8B5CF6)
                          : const Color(0xFF9ca3af),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Reward',
                      style: GoogleFonts.lexend(
                        fontSize: 15,
                        fontWeight: _selectedTab == 'Reward'
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: _selectedTab == 'Reward'
                            ? const Color(0xFF1f2937)
                            : const Color(0xFF9ca3af),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalaxyCollectionSection(List<VocabularyModel> filteredVocabularies, int totalCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Text(
          'Galaxy Collection',
          style: GoogleFonts.lexend(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),

        // Search bar
        _buildSearchBar(),

        const SizedBox(height: 12),

        // Filter chips
        _buildFilterChips(totalCount),

        const SizedBox(height: 12),

        // Vocabulary list
        if (filteredVocabularies.isEmpty)
          _buildEmptyState()
        else
          _buildVocabularyList(filteredVocabularies),
      ],
    );
  }

  Widget _buildRewardSection() {
    final badgeState = ref.watch(badgeStateProvider);
    final stickerState = ref.watch(stickerStateProvider);

    return Column(
      children: [
        // Badges preview section
        _buildBadgePreviewSection(badgeState.badges),

        const SizedBox(height: 24),

        // Stickers preview section
        _buildStickerPreviewSection(stickerState.stickers),
      ],
    );
  }

  Widget _buildBadgePreviewSection(List badges) {
    // Show first 4 badges
    final previewBadges = badges.take(4).toList();

    return Column(
      children: [
        // Header with See All button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Badges',
              style: GoogleFonts.lexend(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BadgesPage()),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      'See All',
                      style: GoogleFonts.lexend(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Preview row
        if (previewBadges.isEmpty)
          _buildEmptyPreviewMessage('No badges yet')
        else
          Row(
            children: previewBadges.map((badge) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildBadgePreviewCard(badge),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildStickerPreviewSection(List stickers) {
    // Show first 4 stickers
    final previewStickers = stickers.take(4).toList();

    return Column(
      children: [
        // Header with See All button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Stickers',
              style: GoogleFonts.lexend(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StickersPage()),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      'See All',
                      style: GoogleFonts.lexend(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Preview row
        if (previewStickers.isEmpty)
          _buildEmptyPreviewMessage('No stickers yet')
        else
          Row(
            children: previewStickers.map((sticker) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildStickerPreviewCard(sticker),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildBadgePreviewCard(dynamic badge) {
    final isLocked = badge.isLocked ?? false;
    final icon = badge.icon ?? '🏅';
    final name = badge.name ?? 'Badge';

    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2D1F9).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isLocked
                  ? Colors.grey.withValues(alpha: 0.1)
                  : const Color(0xFFE2D1F9).withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                icon,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Name
          Text(
            name,
            style: GoogleFonts.lexend(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isLocked ? Colors.grey : const Color(0xFF1f2937),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Locked indicator
          if (isLocked)
            Icon(
              Icons.lock,
              size: 10,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
        ],
      ),
    );
  }

  Widget _buildStickerPreviewCard(dynamic sticker) {
    final isLocked = sticker.isLocked ?? false;
    final icon = sticker.icon ?? '😊';
    final name = sticker.name ?? 'Sticker';

    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2D1F9).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isLocked
                  ? Colors.grey.withValues(alpha: 0.1)
                  : const Color(0xFFEDE9FE),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                icon,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Name
          Text(
            name,
            style: GoogleFonts.lexend(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isLocked ? Colors.grey : const Color(0xFF1f2937),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Locked indicator
          if (isLocked)
            Icon(
              Icons.lock,
              size: 10,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyPreviewMessage(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        message,
        style: GoogleFonts.lexend(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.white.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Find vocab or sentence...',
          hintStyle: GoogleFonts.lexend(
            color: const Color(0xFF9ca3af),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: const Color(0xFF9ca3af),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: GoogleFonts.lexend(
          color: const Color(0xFF1f2937),
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildFilterChips(int totalCount) {
    return Row(
      children: [
        _buildFilterChip('All', _getFilterCount('All', totalCount)),
        const SizedBox(width: 8),
        _buildFilterChip('Reviewed', _getFilterCount('Reviewed', totalCount)),
        const SizedBox(width: 8),
        _buildFilterChip('Unreviewed', _getFilterCount('Unreviewed', totalCount)),
        const SizedBox(width: 8),
        _buildCategoryDropdown(),
      ],
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _selectedFilter == label;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEDE9FE) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFFe5e7eb),
          ),
        ),
        child: Text(
          '$label ($count)',
          style: GoogleFonts.lexend(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? const Color(0xFF1f2937) : const Color(0xFF6b7280),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return InkWell(
      onTap: () {
        // TODO: Show category dropdown
        print('Show category dropdown');
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFe5e7eb),
          ),
        ),
        child: Row(
          children: [
            Text(
              'Category',
              style: GoogleFonts.lexend(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF6b7280),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: const Color(0xFF9ca3af),
            ),
          ],
        ),
      ),
    );
  }

  int _getFilterCount(String filter, int totalCount) {
    final vocabState = ref.read(vocabularyStateProvider);
    final allVocabs = vocabState.vocabularies;

    switch (filter) {
      case 'All':
        return totalCount;
      case 'Reviewed':
        // For now, count favorites as "reviewed"
        return allVocabs.where((v) => v.isFavorite).length;
      case 'Unreviewed':
        return allVocabs.where((v) => !v.isFavorite).length;
      default:
        return 0;
    }
  }

  List<VocabularyModel> _applyFilters(List<VocabularyModel> vocabularies) {
    var filtered = vocabularies;

    // Apply search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((v) {
        return v.word.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            v.thaiTranslation.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            v.englishSentence.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Apply selected filter
    switch (_selectedFilter) {
      case 'Reviewed':
        filtered = filtered.where((v) => v.isFavorite).toList();
        break;
      case 'Unreviewed':
        filtered = filtered.where((v) => !v.isFavorite).toList();
        break;
      case 'All':
      default:
        // No filter
        break;
    }

    return filtered;
  }

  Widget _buildVocabularyList(List<VocabularyModel> vocabularies) {
    return Column(
      children: vocabularies.map((vocab) {
        return _buildVocabularyItem(vocab);
      }).toList(),
    );
  }

  Widget _buildVocabularyItem(VocabularyModel vocab) {
    final isReviewed = vocab.isFavorite;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2D1F9).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          // Navigate to vocabulary detail (optional)
          print('Tapped: ${vocab.word}');
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Star icon (reviewed/unreviewed)
              Icon(
                isReviewed ? Icons.star : Icons.star_border,
                color: isReviewed
                    ? const Color(0xFFfbbf24) // Gold
                    : const Color(0xFFd1d5db), // Gray
                size: 24,
              ),

              const SizedBox(width: 12),

              // Vocabulary info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Word
                    Text(
                      vocab.word,
                      style: GoogleFonts.lexend(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1f2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Thai translation
                    Text(
                      vocab.thaiTranslation,
                      style: GoogleFonts.lexend(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6b7280),
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.chevron_right,
                color: const Color(0xFFd1d5db),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2D1F9).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.star_border,
            size: 64,
            color: const Color(0xFFd1d5db),
          ),
          const SizedBox(height: 16),
          Text(
            'No vocabulary found',
            style: GoogleFonts.lexend(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1f2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start learning to build your galaxy!',
            style: GoogleFonts.lexend(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF6b7280),
            ),
          ),
        ],
      ),
    ),
    );
  }

  void _showShieldInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFf8f9ff)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8b5cf6).withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF8B5CF6), Color(0xFF60a5fa)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Streak Shields',
                  style: GoogleFonts.lexend(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1f2937),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Don\'t let a missed day break your streak!',
                  style: GoogleFonts.lexend(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF6b7280),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2D1F9).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildShieldInfoItem(
                        icon: Icons.shield_rounded,
                        title: 'Shield Protection',
                        description:
                            'Each shield protects your streak for 1 missed day',
                      ),
                      const SizedBox(height: 12),
                      _buildShieldInfoItem(
                        icon: Icons.star_rounded,
                        title: 'Earn Shields',
                        description:
                            'Keep learning for 7 days to earn a shield',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF8B5CF6), Color(0xFF60a5fa)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(14),
                        child: const Center(
                          child: Text(
                            'Got it!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShieldInfoItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFEDE9FE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF5E3A8E)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.lexend(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5E3A8E),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.lexend(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
