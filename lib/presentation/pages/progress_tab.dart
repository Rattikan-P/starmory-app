import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/vocabulary_model.dart';
import '../../data/services/dictionary_service.dart';
import '../../data/services/tts_service.dart';
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
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Lazy loading state
  static const int _itemsPerPage = 20;
  final ScrollController _scrollController = ScrollController();
  List<VocabularyModel> _displayedVocabs = [];
  bool _isLoadingMore = false;
  List<VocabularyModel> _allFilteredVocabs = []; // Store filtered results
  bool _isInitialized = false; // Prevent infinite loop

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _isInitialized = false;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMoreItems();
    }
  }

  void _loadMoreItems() {
    if (_isLoadingMore) return;
    if (_displayedVocabs.length >= _allFilteredVocabs.length) return;

    setState(() {
      _isLoadingMore = true;
    });

    // Simulate async loading (in real app, this might be from pagination API)
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        final nextIndex = _displayedVocabs.length;
        final endIndex = (nextIndex + _itemsPerPage)
            .clamp(0, _allFilteredVocabs.length);

        setState(() {
          _displayedVocabs =
              _allFilteredVocabs.sublist(0, endIndex);
          _isLoadingMore = false;
        });
      }
    });
  }

  void _applyFiltersAndLoadInitial(List<VocabularyModel> allVocabularies) {
    // Apply filters
    final filtered = _applyFilters(allVocabularies);

    // Sort if needed
    _sortAndDisplayVocabs(filtered);
  }

  Future<void> _sortAndDisplayVocabs(List<VocabularyModel> filteredVocabularies) async {
    try {
      final hiveService = ref.read(hiveServiceProvider);
      final sorted = await _sortVocabulariesByDueDate(filteredVocabularies, hiveService);

      setState(() {
        _allFilteredVocabs = sorted;
        // Keep existing displayed items if sorted list is the same
        if (_displayedVocabs.isEmpty || !_listsAreEqual(_displayedVocabs, sorted)) {
          // Load initial items only if list changed
          final initialCount = _itemsPerPage.clamp(0, sorted.length);
          _displayedVocabs = sorted.sublist(0, initialCount);
        }
        _isLoadingMore = false;
      });
    } catch (e) {
      print('Error sorting vocabularies: $e');
      setState(() {
        _allFilteredVocabs = filteredVocabularies;
        // Keep existing if error
        if (_displayedVocabs.isEmpty) {
          final initialCount = _itemsPerPage.clamp(0, filteredVocabularies.length);
          _displayedVocabs = filteredVocabularies.sublist(0, initialCount);
        }
        _isLoadingMore = false;
      });
    }
  }

  // Check if two lists are equal (same items in same order)
  bool _listsAreEqual(List<VocabularyModel> list1, List<VocabularyModel> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('🔄 Build called - _isInitialized: $_isInitialized, _displayedVocabs: ${_displayedVocabs.length}');

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

    // Initialize or update displayed vocabs when vocab list changes
    if (!_isInitialized ||
        _allFilteredVocabs.length != allVocabularies.length ||
        (_allFilteredVocabs.isEmpty && allVocabularies.isNotEmpty)) {
      print('📋 Scheduling load - allVocabs: ${allVocabularies.length}, _allFiltered: ${_allFilteredVocabs.length}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print('📋 PostFrame callback executing');
        if (!_isInitialized) {
          _isInitialized = true;
          print('✅ Set _isInitialized = true');
        }
        _applyFiltersAndLoadInitial(allVocabularies);
      });
    }

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
                  controller: _scrollController,
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
                        _buildGalaxyCollectionSection(totalStars)
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

  /// Sort vocabularies by their word card's due date
  /// Vocab with card → sort by dueDate (earliest first)
  /// Vocab without card → sort by createdAt (newest first) → go to end
  Future<List<VocabularyModel>> _sortVocabulariesByDueDate(
    List<VocabularyModel> vocabularies,
    dynamic hiveService,
  ) async {
    try {
      // Get all word cards
      final cards = await hiveService.getWordCards();

      // Create map: vocabularyId → dueDate
      final vocabDueDates = <String, DateTime>{};
      for (final card in cards) {
        vocabDueDates[card.vocabularyId] = card.dueDate;
      }

      // Separate vocabularies into those with cards and without
      final vocabsWithCards = <VocabularyModel>[];
      final vocabsWithoutCards = <VocabularyModel>[];

      for (final vocab in vocabularies) {
        if (vocabDueDates.containsKey(vocab.id)) {
          vocabsWithCards.add(vocab);
        } else {
          vocabsWithoutCards.add(vocab);
        }
      }

      // Sort vocab with cards by dueDate
      vocabsWithCards.sort((a, b) {
        final dueDateA = vocabDueDates[a.id]!;
        final dueDateB = vocabDueDates[b.id]!;
        return dueDateA.compareTo(dueDateB);
      });

      // Sort vocab without cards by createdAt (newest first)
      vocabsWithoutCards.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Combine: with cards first, then without cards
      return [...vocabsWithCards, ...vocabsWithoutCards];
    } catch (e) {
      print('Error sorting vocabularies: $e');
      // Return original list if error
      return vocabularies;
    }
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
            onTap: () => _showPhotosGallery(context),
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
    VoidCallback? onTap,
  }) {
    final card = Container(
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
          // Chevron inside card for consistent size
          Icon(
            onTap != null
                ? Icons.chevron_right
                : null, // No icon when no onTap
            color: onTap != null
                ? const Color(0xFFd1d5db)
                : Colors.transparent,
            size: 20,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: card,
        ),
      );
    }

    return card;
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

  Widget _buildGalaxyCollectionSection(int totalCount) {
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
        if (_displayedVocabs.isEmpty)
          _buildEmptyState()
        else
          _buildVocabularyList(),
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
          // Reload list with new filter
          final vocabState = ref.read(vocabularyStateProvider);
          _applyFiltersAndLoadInitial(vocabState.vocabularies);
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
    // Get popular categories (top 4 by count)
    final popularCategories = _getPopularCategories(totalCount);
    final hasMore = popularCategories.length < _getAllCategories().length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // All chip
          _buildCategoryChip('All', _getCategoryCount('All', totalCount)),
          const SizedBox(width: 6),
          // Popular category chips with spacing
          for (int i = 0; i < popularCategories.length; i++) ...[
            if (i > 0) SizedBox(width: 6),
            _buildCategoryChip(popularCategories[i], _getCategoryCount(popularCategories[i], totalCount)),
          ],
          const SizedBox(width: 6),
          // More... dropdown if there are more categories
          if (hasMore)
            _buildMoreCategoryDropdown(),
        ],
      ),
    );
  }

  List<String> _getPopularCategories(int totalCount) {
    final vocabState = ref.read(vocabularyStateProvider);
    final allVocabs = vocabState.vocabularies;

    // Count vocabs per category
    final categoryCounts = <String, int>{};
    for (final vocab in allVocabs) {
      categoryCounts[vocab.topic] = (categoryCounts[vocab.topic] ?? 0) + 1;
    }

    // Sort by count (descending) and take top 4
    final sorted = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(4).map((e) => e.key).toList();
  }

  List<String> _getAllCategories() {
    return [
      'food', 'people', 'nature', 'home', 'daily_life',
      'clothing', 'hobbies', 'education', 'work',
      'technology', 'health', 'entertainment', 'other'
    ];
  }

  /// Format category name for display (e.g., "daily_life" → "Daily Life")
  String _formatCategoryName(String category) {
    if (category == 'All') return 'All';
    return category
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Widget _buildCategoryChip(String category, int count) {
    final isSelected = _selectedCategory == category;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
        // Reload list with new filter
        final vocabState = ref.read(vocabularyStateProvider);
        _applyFiltersAndLoadInitial(vocabState.vocabularies);
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
          category == 'All' ? 'All ($count)' : '${_formatCategoryName(category)} ($count)',
          style: GoogleFonts.lexend(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? const Color(0xFF1f2937) : const Color(0xFF6b7280),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreCategoryDropdown() {
    return InkWell(
      onTap: () {
        // Show category bottom sheet
        _showCategoryBottomSheet();
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
              'More...',
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

  void _showCategoryBottomSheet() {
    final vocabState = ref.read(vocabularyStateProvider);
    final allVocabs = vocabState.vocabularies;
    final allCategories = _getAllCategories();
    final popularCategories = _getPopularCategories(allVocabs.length);

    // Get categories NOT in popular list
    final remainingCategories = allCategories.where((cat) =>
      cat != 'All' && !popularCategories.contains(cat)
    ).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        width: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All Categories',
                    style: GoogleFonts.lexend(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1f2937),
                    ),
                  ),
                  SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: remainingCategories.map((cat) {
                      final count = _getCategoryCount(cat, allVocabs.length);
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedCategory = cat;
                          });
                          Navigator.pop(context);
                          // Reload list with new filter
                          final vocabState = ref.read(vocabularyStateProvider);
                          _applyFiltersAndLoadInitial(vocabState.vocabularies);
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedCategory == cat
                                ? Color(0xFFEDE9FE)
                                : Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _selectedCategory == cat
                                  ? Color(0xFF8B5CF6)
                                  : Color(0xFFe5e7eb),
                            ),
                          ),
                          child: Text(
                            '${_formatCategoryName(cat)} ($count)',
                            style: GoogleFonts.lexend(
                              fontSize: 13,
                              fontWeight: _selectedCategory == cat
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: _selectedCategory == cat
                                  ? Color(0xFF1f2937)
                                  : Color(0xFF6b7280),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getCategoryCount(String category, int totalCount) {
    final vocabState = ref.read(vocabularyStateProvider);
    final allVocabs = vocabState.vocabularies;

    if (category == 'All') {
      return totalCount;
    }

    return allVocabs.where((v) => v.topic == category).length;
  }

  List<VocabularyModel> _applyFilters(List<VocabularyModel> vocabularies) {
    var filtered = vocabularies;

    // Apply search (contains matching in word and thai only)
    if (_searchQuery.isNotEmpty) {
      final searchLower = _searchQuery.toLowerCase();
      filtered = filtered.where((v) {
        return v.word.toLowerCase().contains(searchLower) ||
            v.thaiTranslation.toLowerCase().contains(searchLower);
      }).toList();
    }

    // Apply category filter
    if (_selectedCategory != 'All') {
      filtered = filtered.where((v) => v.topic == _selectedCategory).toList();
    }

    return filtered;
  }

  Widget _buildVocabularyList() {
    return Column(
      children: [
        // Display all current vocabularies
        ..._displayedVocabs.map((vocab) =>
          _buildVocabularyItem(vocab, _displayedVocabs)
        ).toList(),

        // Loading indicator at bottom
        if (_isLoadingMore)
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            child: CircularProgressIndicator(
              color: const Color(0xFF8B5CF6),
            ),
          ),
      ],
    );
  }

  Widget _buildVocabularyItem(VocabularyModel vocab, List<VocabularyModel> allVocabularies) {
    final isReviewed = vocab.isFavorite;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2D1F9).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          // Show vocabulary detail bottom sheet
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (context) => VocabularyDetailBottomSheet(
              vocabulary: vocab,
              dictionaryService: DictionaryService(),
              allVocabularies: allVocabularies,
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Star icon (reviewed/unreviewed)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isReviewed
                      ? const Color(0xFFfbbf24).withValues(alpha: 0.15)
                      : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isReviewed ? Icons.star : Icons.star_border,
                  color: isReviewed
                      ? const Color(0xFFfbbf24) // Gold
                      : const Color(0xFF9ca3af), // Gray
                  size: 22,
                ),
              ),

              const SizedBox(width: 14),

              // Vocabulary info (vertical layout)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // English word
                    Text(
                      vocab.word,
                      style: GoogleFonts.lexend(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1f2937),
                        height: 1.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    // Thai translation
                    Text(
                      vocab.thaiTranslation,
                      style: GoogleFonts.lexend(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6b7280),
                        height: 1.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

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

  void _showPhotosGallery(BuildContext context) {
    final vocabState = ref.read(vocabularyStateProvider);
    final allVocabularies = vocabState.vocabularies;

    // Get unique images only (group vocabularies by image URL)
    final uniqueImagesMap = <String, List<VocabularyModel>>{};

    for (final vocab in allVocabularies) {
      if (vocab.imageUrl.isNotEmpty) {
        uniqueImagesMap.putIfAbsent(vocab.imageUrl, () => []).add(vocab);
      }
    }

    if (uniqueImagesMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No photos to display yet'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Convert to list of unique photo entries
    final photoEntries = uniqueImagesMap.entries.map((entry) {
      return PhotoEntry(
        imageUrl: entry.key,
        vocabularies: entry.value,
      );
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotosGalleryPage(photoEntries: photoEntries),
      ),
    );
  }
}

// Vocabulary Detail Bottom Sheet - Shows word details from dictionary API
class VocabularyDetailBottomSheet extends StatefulWidget {
  final VocabularyModel vocabulary;
  final DictionaryService dictionaryService;
  final List<VocabularyModel> allVocabularies;

  const VocabularyDetailBottomSheet({
    super.key,
    required this.vocabulary,
    required this.dictionaryService,
    required this.allVocabularies,
  });

  @override
  State<VocabularyDetailBottomSheet> createState() => _VocabularyDetailBottomSheetState();
}

class _VocabularyDetailBottomSheetState extends State<VocabularyDetailBottomSheet> {
  DictionaryEntry? _dictionaryEntry;
  DictionaryEntry? _twinDictionaryEntry;  // Dictionary entry for twin word
  bool _isLoading = true;
  bool _hasError = false;
  final TTSService _ttsService = TTSService();
  bool _isPlayingUK = false;  // Track UK TTS state
  bool _isPlayingUS = false;  // Track US TTS state
  StreamSubscription? _ttsCompletionSubscription;
  StreamSubscription? _ttsErrorSubscription;

  // Twin word (same word, different spelling like colour/color)
  VocabularyModel? _twinWord;

  @override
  void initState() {
    super.initState();
    _findTwinWord();
    _fetchDictionaryData();
    _setupTTSSubscriptions();
  }

  /// Find the twin word (same word, different variant)
  /// e.g., "colour (UK)" and "color (US)"
  void _findTwinWord() {
    final currentWord = widget.vocabulary.word.toLowerCase();
    final currentVariant = widget.vocabulary.languageVariant;

    for (final vocab in widget.allVocabularies) {
      // Skip self
      if (vocab.id == widget.vocabulary.id) continue;

      // Check if same word but different variant
      if (vocab.word.toLowerCase() == currentWord &&
          vocab.languageVariant != currentVariant) {
        setState(() {
          _twinWord = vocab;
        });
        print('🔗 Found twin word: ${vocab.word} (${vocab.languageVariant})');
        return;
      }
    }

    // Try to find words with common UK/US spelling differences
    final commonUKUSPairs = {
      'colour': 'color',
      'color': 'colour',
      'centre': 'center',
      'center': 'centre',
      'theatre': 'theater',
      'theater': 'theatre',
      'licence': 'license',
      'license': 'licence',
      'organisation': 'organization',
      'organization': 'organisation',
      'organise': 'organize',
      'organize': 'organise',
      'favourite': 'favorite',
      'favorite': 'favourite',
      'honour': 'honor',
      'honor': 'honour',
      'labour': 'labor',
      'labor': 'labour',
    };

    // Check if current word has a common pair
    final twinWord = commonUKUSPairs[currentWord];
    if (twinWord != null) {
      // Find the twin in the vocab list
      for (final vocab in widget.allVocabularies) {
        if (vocab.word.toLowerCase() == twinWord &&
            vocab.languageVariant != currentVariant) {
          setState(() {
            _twinWord = vocab;
          });
          print('🔗 Found common twin word: ${vocab.word} (${vocab.languageVariant})');
          return;
        }
      }
    }
  }

  void _setupTTSSubscriptions() {
    _ttsCompletionSubscription = _ttsService.onComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlayingUK = false;
          _isPlayingUS = false;
        });
      }
    });

    _ttsErrorSubscription = _ttsService.onError.listen((error) {
      if (mounted) {
        setState(() {
          _isPlayingUK = false;
          _isPlayingUS = false;
        });
      }
      print('🔊 TTS Error: $error');
    });
  }

  Future<void> _fetchDictionaryData() async {
    // Fetch dictionary for current word
    final result = await widget.dictionaryService.getWordDefinition(widget.vocabulary.word);

    // Fetch dictionary for twin word if exists
    DictionaryEntry? twinResult;
    if (_twinWord != null) {
      twinResult = await widget.dictionaryService.getWordDefinition(_twinWord!.word);
      print('🔗 Fetched twin dictionary: ${_twinWord!.word}');
    }

    if (mounted) {
      setState(() {
        _dictionaryEntry = result;
        _twinDictionaryEntry = twinResult;
        _isLoading = false;
        _hasError = result == null && twinResult == null;
      });
    }
  }

  Future<void> _playAudio(String word, String variant) async {
    if (word.isEmpty) {
      print('❌ Word is empty');
      return;
    }

    // Stop any currently playing audio
    await _ttsService.stop();

    print('🔊 Speaking word: $word ($variant)');

    try {
      setState(() {
        if (variant == 'UK') {
          _isPlayingUK = true;
          _isPlayingUS = false;
        } else {
          _isPlayingUS = true;
          _isPlayingUK = false;
        }
      });

      // Use TTS with specific language variant
      _ttsService.speak(
        word,
        language: TTSService.getLanguageCode(variant),
      );

      print('✅ TTS speak command sent for $variant');
    } catch (e) {
      print('❌ Error speaking word: $e');
      setState(() {
        _isPlayingUK = false;
        _isPlayingUS = false;
      });
    }
  }

  @override
  void dispose() {
    _ttsCompletionSubscription?.cancel();
    _ttsErrorSubscription?.cancel();
    _ttsService.stop();
    super.dispose();
  }

  /// Build phonetic row showing UK and US phonetics
  Widget _buildPhoneticRow() {
    final currentPhonetic = _dictionaryEntry?.phonetic;
    final twinPhonetic = _twinDictionaryEntry?.phonetic;

    // If twin word exists, show both phonetics
    if (_twinWord != null) {
      return Row(
        children: [
          if (currentPhonetic != null) ...[
            Text(
              'UK: $currentPhonetic',
              style: GoogleFonts.lexend(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8B5CF6),
              ),
            ),
            if (twinPhonetic != null) ...[
              SizedBox(width: 12),
              Text(
                '|',
                style: GoogleFonts.lexend(
                  fontSize: 13,
                  color: Color(0xFF9ca3af),
                ),
              ),
              SizedBox(width: 12),
              Text(
                'US: $twinPhonetic',
                style: GoogleFonts.lexend(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8B5CF6),
                ),
              ),
            ],
          ] else if (twinPhonetic != null)
            Text(
              twinPhonetic,
              style: GoogleFonts.lexend(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6b7280),
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      );
    }

    // No twin word, show single phonetic
    return Text(
      currentPhonetic ?? '',
      style: GoogleFonts.lexend(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Color(0xFF6b7280),
        fontStyle: FontStyle.italic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF60a5fa)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      widget.vocabulary.word[0].toUpperCase(),
                      style: GoogleFonts.lexend(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Show both spellings if twin word exists
                      if (_twinWord != null)
                        Row(
                          children: [
                            Text(
                              '${widget.vocabulary.word}',
                              style: GoogleFonts.lexend(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1f2937),
                              ),
                            ),
                            Text(
                              ' (${widget.vocabulary.languageVariant})',
                              style: GoogleFonts.lexend(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF8B5CF6),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '/',
                              style: GoogleFonts.lexend(
                                fontSize: 22,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF9ca3af),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '${_twinWord!.word}',
                              style: GoogleFonts.lexend(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1f2937),
                              ),
                            ),
                            Text(
                              ' (${_twinWord!.languageVariant})',
                              style: GoogleFonts.lexend(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF8B5CF6),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          widget.vocabulary.word,
                          style: GoogleFonts.lexend(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1f2937),
                          ),
                        ),
                      // Show phonetics for both words if twin exists
                      if (_dictionaryEntry?.phonetic != null || _twinDictionaryEntry?.phonetic != null)
                        _buildPhoneticRow(),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Color(0xFF9ca3af)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Audio Player (TTS) - UK and US buttons
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // UK Button
                Expanded(
                  child: InkWell(
                    onTap: () => _playAudio(
                      _twinWord?.languageVariant == 'UK' ? _twinWord!.word : widget.vocabulary.word,
                      'UK',
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isPlayingUK)
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                              ),
                            )
                          else
                            Icon(Icons.volume_up, color: Color(0xFF8B5CF6), size: 18),
                          SizedBox(width: 8),
                          Text(
                            '🇬🇧 UK',
                            style: GoogleFonts.lexend(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8B5CF6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // US Button
                Expanded(
                  child: InkWell(
                    onTap: () => _playAudio(
                      _twinWord?.languageVariant == 'US' ? _twinWord!.word : widget.vocabulary.word,
                      'US',
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isPlayingUS)
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                              ),
                            )
                          else
                            Icon(Icons.volume_up, color: Color(0xFF8B5CF6), size: 18),
                          SizedBox(width: 8),
                          Text(
                            '🇺🇸 US',
                            style: GoogleFonts.lexend(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8B5CF6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF8B5CF6)),
            SizedBox(height: 16),
            Text(
              'Loading dictionary...',
              style: GoogleFonts.lexend(
                fontSize: 14,
                color: Color(0xFF6b7280),
              ),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 48, color: Color(0xFF9ca3af)),
            SizedBox(height: 16),
            Text(
              'No definition found',
              style: GoogleFonts.lexend(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1f2937),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'This word may not be in the dictionary',
              style: GoogleFonts.lexend(
                fontSize: 14,
                color: Color(0xFF6b7280),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Try checking the spelling',
              style: GoogleFonts.lexend(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Color(0xFF9ca3af),
              ),
            ),
          ],
        ),
      );
    }

    if (_dictionaryEntry == null || _dictionaryEntry!.meanings.isEmpty) {
      return Center(
        child: Text(
          'No definitions available',
          style: GoogleFonts.lexend(
            fontSize: 14,
            color: Color(0xFF6b7280),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Original vocab info
        _buildOriginalVocabInfo(),

        SizedBox(height: 20),

        // Dictionary meanings
        ..._dictionaryEntry!.meanings.asMap().entries.map((entry) {
          final index = entry.key;
          final meaning = entry.value;
          return _buildMeaningSection(meaning, index);
        }),
      ],
    );
  }

  Widget _buildOriginalVocabInfo() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Vocabulary',
            style: GoogleFonts.lexend(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8B5CF6),
            ),
          ),
          SizedBox(height: 8),
          Text(
            widget.vocabulary.word,
            style: GoogleFonts.lexend(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1f2937),
            ),
          ),
          SizedBox(height: 4),
          Text(
            widget.vocabulary.thaiTranslation,
            style: GoogleFonts.lexend(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6b7280),
            ),
          ),
          if (widget.vocabulary.englishSentence.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              widget.vocabulary.englishSentence,
              style: GoogleFonts.lexend(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Color(0xFF5E3A8E),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMeaningSection(Meaning meaning, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Part of Speech badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              meaning.partOfSpeech.toUpperCase(),
              style: GoogleFonts.lexend(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8B5CF6),
              ),
            ),
          ),

          SizedBox(height: 12),

          // Definitions
          if (meaning.definitions.isNotEmpty) ...[
            Text(
              'Definitions',
              style: GoogleFonts.lexend(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1f2937),
              ),
            ),
            SizedBox(height: 8),
            ...meaning.definitions.take(3).map((def) => Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: Color(0xFF8B5CF6))),
                  Expanded(
                    child: Text(
                      def,
                      style: GoogleFonts.lexend(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF4b5563),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],

          // Examples
          if (meaning.examples.isNotEmpty) ...[
            SizedBox(height: 12),
            Text(
              'Examples',
              style: GoogleFonts.lexend(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1f2937),
              ),
            ),
            SizedBox(height: 8),
            ...meaning.examples.take(3).map((ex) => Container(
              margin: EdgeInsets.only(bottom: 6),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFEDE9FE).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                ex,
                style: GoogleFonts.lexend(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF5E3A8E),
                  fontStyle: FontStyle.italic,
                ),
              ),
            )),
          ],

          // Synonyms
          if (meaning.synonyms.isNotEmpty) ...[
            SizedBox(height: 12),
            Text(
              'Synonyms',
              style: GoogleFonts.lexend(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1f2937),
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: meaning.synonyms.take(6).map((syn) => Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  syn,
                  style: GoogleFonts.lexend(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6b7280),
                  ),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// Photo entry model (groups vocabularies by image)
class PhotoEntry {
  final String imageUrl;
  final List<VocabularyModel> vocabularies;

  PhotoEntry({
    required this.imageUrl,
    required this.vocabularies,
  });
}

// Photos Gallery Page
class PhotosGalleryPage extends StatelessWidget {
  final List<PhotoEntry> photoEntries;

  const PhotosGalleryPage({super.key, required this.photoEntries});

  @override
  Widget build(BuildContext context) {
    return GalaxyScreenBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'My Photos',
            style: GoogleFonts.lexend(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: photoEntries.length,
              itemBuilder: (context, index) {
                final entry = photoEntries[index];
                return _buildPhotoCard(context, entry);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoCard(BuildContext context, PhotoEntry entry) {
    final wordCount = entry.vocabularies.length;
    final firstVocab = entry.vocabularies.first;

    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => PhotoWordsBottomSheet(photoEntry: entry),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo
              Image.network(
                entry.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFFEDE9FE),
                    child: const Icon(
                      Icons.broken_image,
                      size: 40,
                      color: Color(0xFF8B5CF6),
                    ),
                  );
                },
              ),
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
              // Word count badge (top right)
              if (wordCount > 1)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.photo_library,
                          size: 12,
                          color: Color(0xFF8B5CF6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$wordCount',
                          style: GoogleFonts.lexend(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8B5CF6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Word label at bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    wordCount == 1 ? firstVocab.word : '$wordCount words',
                    style: GoogleFonts.lexend(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Tap indicator
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.touch_app,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Photo Words Bottom Sheet - shows all words for a specific photo
class PhotoWordsBottomSheet extends StatelessWidget {
  final PhotoEntry photoEntry;

  const PhotoWordsBottomSheet({super.key, required this.photoEntry});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      photoEntry.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFFEDE9FE),
                          child: const Icon(
                            Icons.broken_image,
                            size: 24,
                            color: Color(0xFF8B5CF6),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        photoEntry.vocabularies.length == 1
                            ? photoEntry.vocabularies.first.word
                            : '${photoEntry.vocabularies.length} Words',
                        style: GoogleFonts.lexend(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1f2937),
                        ),
                      ),
                      Text(
                        photoEntry.vocabularies.length == 1
                            ? 'Click to see pronunciation'
                            : 'All words using this photo',
                        style: GoogleFonts.lexend(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF6b7280),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF9ca3af)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(height: 1),
          ),

          // Words list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              itemCount: photoEntry.vocabularies.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final vocab = photoEntry.vocabularies[index];
                return _buildWordCard(context, vocab);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordCard(BuildContext context, VocabularyModel vocab) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
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
          const SizedBox(height: 6),
          // Thai translation
          Text(
            vocab.thaiTranslation,
            style: GoogleFonts.lexend(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6b7280),
            ),
          ),
          const SizedBox(height: 10),
          // Example sentence
          if (vocab.englishSentence.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.format_quote,
                    color: Color(0xFF8B5CF6),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      vocab.englishSentence,
                      style: GoogleFonts.lexend(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF5E3A8E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
