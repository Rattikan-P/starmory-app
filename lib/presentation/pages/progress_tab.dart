import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/vocabulary_model.dart';
import '../../data/services/dictionary_service.dart';
import '../providers/providers.dart';
import '../widgets/reward_icon_widget.dart';
import '../widgets/badges_section.dart';
import '../widgets/vocabulary_detail_bottom_sheet.dart';
import 'badges_page.dart';
import 'stickers_page.dart';
import 'profile_tab.dart';

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
  int _lastVocabLength = -1;

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ProfileTab(),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _isInitialized = false;
    _lastVocabLength = -1;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMoreItems();
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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
    if (allVocabularies.isEmpty) {
      setState(() {
        _allFilteredVocabs = [];
        _displayedVocabs = [];
        _isLoadingMore = false;
      });
      return;
    }

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

  // Check if two lists are equal (same items in same order and same favorite state)
  bool _listsAreEqual(List<VocabularyModel> list1, List<VocabularyModel> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id || list1[i].isFavorite != list2[i].isFavorite) return false;
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

    // Listen for scroll to top signal from tab navigation
    ref.listen<int>(
      navigationProvider.select((s) => s.progressScrollToTopTrigger),
      (previous, next) {
        if (previous != next) {
          _scrollToTop();
        }
      },
    );

    // Reset local cache when user changes (e.g. login/logout)
    ref.listen(userStateProvider, (previous, next) {
      final prevUser = previous?.user;
      final nextUser = next.user;
      if (prevUser?.id != nextUser?.id || prevUser?.isGuest != nextUser?.isGuest) {
        setState(() {
          _isInitialized = false;
          _lastVocabLength = -1;
          _displayedVocabs = [];
          _allFilteredVocabs = [];
        });
      }
    });

    final vocabState = ref.watch(vocabularyStateProvider);
    final streakData = ref.watch(streakProvider);

    // Get all vocabularies
    final allVocabularies = vocabState.vocabularies;

    // Calculate stats
    final totalStars = allVocabularies.length;
    final uniqueImages = allVocabularies.map((v) => v.imageUrl).toSet();
    final totalPhotos = uniqueImages.where((url) => url.isNotEmpty).length;
    final streakDays = streakData?.currentStreak ?? 0;
    final longestStreak = streakData?.longestStreak ?? 0;
    final shields = streakData?.shieldsAvailable ?? 0;
    final streakMultiplier = _calculateStreakMultiplier(streakDays);

    // Calculate total unique learning days across all vocabularies, scrapbooks, and streak
    final scrapbookState = ref.watch(scrapbookStateProvider);
    final learningDates = <String>{};
    for (final v in allVocabularies) {
      final local = v.createdAt.toLocal();
      learningDates.add('${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}');
    }
    for (final sb in scrapbookState.scrapbooks) {
      final local = sb.createdAt.toLocal();
      learningDates.add('${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}');
    }
    if (allVocabularies.isNotEmpty || scrapbookState.scrapbooks.isNotEmpty || streakDays > 0) {
      final now = DateTime.now();
      learningDates.add('${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}');
    }
    final daysLearning = [
      learningDates.length,
      streakDays,
      longestStreak,
    ].reduce((a, b) => a > b ? a : b);

    final natureVocabCount = allVocabularies
        .where((v) => v.topic.toLowerCase() == 'nature')
        .length;

    // Check and unlock badges / stickers if eligible (silently in background)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(badgeStateProvider.notifier).checkAndUnlockBadges(
            totalStars,
            streakDays,
          );
      ref.read(stickerStateProvider.notifier).checkAndUnlockPacks(
            totalStars: totalStars,
            streakDays: streakDays,
            natureVocabCount: natureVocabCount,
          );
    });

    // Listen for vocabulary state changes to immediately refresh the list
    ref.listen<VocabularyState>(vocabularyStateProvider, (previous, next) {
      if (previous?.vocabularies != next.vocabularies) {
        _applyFiltersAndLoadInitial(next.vocabularies);
      }
    });

    // Initialize or update displayed vocabs when vocab list changes
    if (!_isInitialized || _lastVocabLength != allVocabularies.length) {
      _lastVocabLength = allVocabularies.length;
      print('📋 Scheduling load - allVocabs: ${allVocabularies.length}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print('📋 PostFrame callback executing');
        if (!_isInitialized) {
          _isInitialized = true;
          print('✅ Set _isInitialized = true');
        }
        _applyFiltersAndLoadInitial(allVocabularies);
      });
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            children: [
              // Header
              _buildHeader(),

              const SizedBox(height: 14),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Streak Banner
                      _buildStreakBanner(streakDays, streakMultiplier, shields),

                      const SizedBox(height: 12),

                      // Stars Stats Card
                      _buildStarsStatsCard(totalStars, streakDays),

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
                        _buildRewardSection(totalStars, streakDays),

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
    final userState = ref.watch(userStateProvider);
    final user = userState.user;
    final photoUrl = user?.photoUrl;
    final displayName = user?.displayName ?? 'User';
    final avatarLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Progress',
                style: GoogleFonts.lexend(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: const Color(0xFF221F33),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Your learning journey & collected vocabulary',
                style: GoogleFonts.lexend(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF9892A6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Interactive Circular User Avatar matching Profile & Review & Home
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openProfile,
            customBorder: const CircleBorder(),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF4EEFF),
                border: Border.all(color: const Color(0xFFE2DBFD), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C5CFC).withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipOval(
                child: photoUrl != null && photoUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: photoUrl,
                        fit: BoxFit.cover,
                        width: 48,
                        height: 48,
                        placeholder: (context, url) => Center(
                          child: Text(
                            avatarLetter,
                            style: GoogleFonts.lexend(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF7C5CFC),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Center(
                          child: Text(
                            avatarLetter,
                            style: GoogleFonts.lexend(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF7C5CFC),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          avatarLetter,
                          style: GoogleFonts.lexend(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF7C5CFC),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStreakBanner(int days, int multiplier, int shields) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFE6D8),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: Color(0xFFFFECE0),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: Color(0xFFFF5722),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Text(
                  '$days Day Streak',
                  style: GoogleFonts.lexend(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF221F33),
                  ),
                ),
                if (multiplier > 1) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5722),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${multiplier}x',
                      style: GoogleFonts.lexend(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Shield badge
          GestureDetector(
            onTap: () => _showShieldInfoDialog(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFDFCE),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.shield_rounded,
                    size: 13,
                    color: Color(0xFFFF7A51),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$shields',
                    style: GoogleFonts.lexend(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF221F33),
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

  Widget _buildStarsStatsCard(int totalStars, int streakDays) {
    final badgeState = ref.watch(badgeStateProvider);
    final upcoming = badgeState.getNextUpcomingBadge(totalStars, streakDays, category: 'Stars');

    final progressText = upcoming != null
        ? upcoming.progressLabel
        : 'All Badges Unlocked!';
    final progressPercent = upcoming?.progressPercentage ?? 1.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFEEDB),
            Color(0xFFFBE4EA),
            Color(0xFFEDE3FD),
            Color(0xFFDFD8FD),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8A6DC8).withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Scattered decorative stars in background
            Positioned(
              top: -10,
              right: 20,
              child: Transform.rotate(
                angle: 0.2,
                child: const Opacity(
                  opacity: 0.35,
                  child: Icon(Icons.star_border_rounded, size: 80, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              bottom: -15,
              left: 40,
              child: Transform.rotate(
                angle: -0.15,
                child: const Opacity(
                  opacity: 0.3,
                  child: Icon(Icons.star_rounded, size: 55, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              top: 35,
              right: 90,
              child: const Opacity(
                opacity: 0.3,
                child: Icon(Icons.star_rounded, size: 24, color: Colors.white),
              ),
            ),

            // Main Content
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stars count
                  Row(
                    children: [
                      Text(
                        '$totalStars',
                        style: GoogleFonts.lexend(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF221F33),
                          height: 1,
                          letterSpacing: -1,
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
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF221F33),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Vocabulary collected through discovery',
                              style: GoogleFonts.lexend(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF655D80),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Progress bar inside translucent white capsule
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.9),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              progressText,
                              style: GoogleFonts.lexend(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF7C5CFC),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'to unlock ',
                                  style: GoogleFonts.lexend(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF655D80),
                                  ),
                                ),
                                if (upcoming != null) ...[
                                  RewardIconWidget(
                                    icon: upcoming.badge.icon,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    upcoming.badge.name,
                                    style: GoogleFonts.lexend(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF221F33),
                                    ),
                                  ),
                                ] else ...[
                                  Text(
                                    '🎉 Galaxy Master!',
                                    style: GoogleFonts.lexend(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF221F33),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progressPercent,
                            backgroundColor: Colors.white,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF7C5CFC),
                            ),
                            minHeight: 7,
                          ),
                        ),
                      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEBE6FC),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C5CFC).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF4EEFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 20,
              color: const Color(0xFF7C5CFC),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.lexend(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF221F33),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: GoogleFonts.lexend(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF9892A6),
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFC4BDD9),
              size: 18,
            ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: card,
        ),
      );
    }

    return card;
  }

  Widget _buildTabBar() {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EEFF),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: const Color(0xFFE2DBFD),
          width: 1,
        ),
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
                _scrollToTop();
              },
              borderRadius: BorderRadius.circular(22),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _selectedTab == 'Vocab' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: _selectedTab == 'Vocab'
                      ? [
                          BoxShadow(
                            color: const Color(0xFF7C5CFC).withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_stories_rounded,
                      size: 18,
                      color: _selectedTab == 'Vocab'
                          ? const Color(0xFF7C5CFC)
                          : const Color(0xFF8E88A8),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Vocabulary',
                      style: GoogleFonts.lexend(
                        fontSize: 14.5,
                        fontWeight: _selectedTab == 'Vocab'
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _selectedTab == 'Vocab'
                            ? const Color(0xFF221F33)
                            : const Color(0xFF8E88A8),
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
                _scrollToTop();
              },
              borderRadius: BorderRadius.circular(22),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _selectedTab == 'Reward' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: _selectedTab == 'Reward'
                      ? [
                          BoxShadow(
                            color: const Color(0xFF7C5CFC).withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      size: 18,
                      color: _selectedTab == 'Reward'
                          ? const Color(0xFF7C5CFC)
                          : const Color(0xFF8E88A8),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Rewards',
                      style: GoogleFonts.lexend(
                        fontSize: 14.5,
                        fontWeight: _selectedTab == 'Reward'
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _selectedTab == 'Reward'
                            ? const Color(0xFF221F33)
                            : const Color(0xFF8E88A8),
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
            fontWeight: FontWeight.w700,
            color: const Color(0xFF221F33),
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

  Widget _buildRewardSection(int totalStars, int currentStreak) {
    final stickerState = ref.watch(stickerStateProvider);
    final allVocabularies = ref.watch(vocabularyStateProvider).vocabularies;
    final natureVocabCount = allVocabularies
        .where((v) => v.topic.toLowerCase() == 'nature')
        .length;

    return Column(
      children: [
        // Badges Section (Uses identical BadgesSection component)
        BadgesSection(
          margin: EdgeInsets.zero,
          onSeeAll: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BadgesPage()),
            );
          },
        ),

        const SizedBox(height: 16),

        // Stickers Section (Uses matching container, cards, and modal)
        _buildStickerSection(
          stickerState,
          totalStars: totalStars,
          streakDays: currentStreak,
          natureVocabCount: natureVocabCount,
        ),
      ],
    );
  }

  Widget _buildStickerSection(
    StickerState stickerState, {
    required int totalStars,
    required int streakDays,
    required int natureVocabCount,
  }) {
    final packs = stickerState.packs;

    return Container(
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
                    color: const Color(0xFF7C5CFC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'STICKER PACKS',
                  style: GoogleFonts.lexend(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7C5CFC),
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4EEFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${stickerState.unlockedCount}/${stickerState.totalPacksCount}',
                    style: GoogleFonts.lexend(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF7C5CFC),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StickersPage()),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 10,
                          color: Color(0xFF7C5CFC),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Horizontal List of Sticker Packs
          SizedBox(
            height: 144,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              scrollDirection: Axis.horizontal,
              itemCount: packs.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final pack = packs[index];
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

                return GestureDetector(
                  onTap: () => showStickerPackModal(
                    context,
                    pack,
                    totalStars: totalStars,
                    streakDays: streakDays,
                    natureVocabCount: natureVocabCount,
                    stickerState: stickerState,
                  ),
                  child: Container(
                    width: 104,
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
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pack Icon Circle with glow
                        Container(
                          width: 48,
                          height: 48,
                          padding: const EdgeInsets.all(6),
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
                            child: ColorFiltered(
                              colorFilter: isUnlocked
                                  ? const ColorFilter.mode(
                                      Colors.transparent,
                                      BlendMode.dst,
                                    )
                                  : const ColorFilter.matrix(<double>[
                                      0.2126, 0.7152, 0.0722, 0, 0,
                                      0.2126, 0.7152, 0.0722, 0, 0,
                                      0.2126, 0.7152, 0.0722, 0, 0,
                                      0,      0,      0,      0.45, 0,
                                    ]),
                              child: Image.asset(
                                pack.previewAsset,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.image_outlined,
                                  size: 24,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Title
                        Text(
                          pack.name,
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
                              mainAxisSize: MainAxisSize.min,
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
                                  progressLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFEBE6FC),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C5CFC).withValues(alpha: 0.05),
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
          final vocabState = ref.read(vocabularyStateProvider);
          _applyFiltersAndLoadInitial(vocabState.vocabularies);
        },
        decoration: InputDecoration(
          hintText: 'Search vocabulary or translation...',
          hintStyle: GoogleFonts.lexend(
            color: const Color(0xFF9892A6),
            fontSize: 13.5,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF9892A6),
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF9892A6)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                    final vocabState = ref.read(vocabularyStateProvider);
                    _applyFiltersAndLoadInitial(vocabState.vocabularies);
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: GoogleFonts.lexend(
          color: const Color(0xFF221F33),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildFilterChips(int totalCount) {
    // Get popular categories (top 4 by count)
    final popularCategories = _getPopularCategories(totalCount);
    final hasMore = popularCategories.length < _getAllCategories().length;
    final favCount = _getCategoryCount('Favorites', totalCount);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // All chip
          _buildCategoryChip('All', _getCategoryCount('All', totalCount)),
          const SizedBox(width: 8),
          // Favorites chip
          if (favCount > 0 || _selectedCategory == 'Favorites') ...[
            _buildCategoryChip('Favorites', favCount),
            const SizedBox(width: 8),
          ],
          // Popular category chips with spacing
          for (int i = 0; i < popularCategories.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _buildCategoryChip(popularCategories[i], _getCategoryCount(popularCategories[i], totalCount)),
          ],
          const SizedBox(width: 8),
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
    if (category == 'Favorites') return '❤️ Favorites';
    return category
        .split('_')
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
        .join(' ');
  }

  Widget _buildCategoryChip(String category, int count) {
    final isSelected = _selectedCategory == category;
    final isFav = category == 'Favorites';

    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
        final vocabState = ref.read(vocabularyStateProvider);
        _applyFiltersAndLoadInitial(vocabState.vocabularies);
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF4EEFF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF7C5CFC) : const Color(0xFFEBE6FC),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF7C5CFC).withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isFav) ...[
              const Icon(
                Icons.favorite_rounded,
                size: 14,
                color: Color(0xFFEC4899),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              isFav
                  ? 'Favorites'
                  : (category == 'All' ? 'All' : _formatCategoryName(category)),
              style: GoogleFonts.lexend(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF7C5CFC) : const Color(0xFF8E88A8),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF7C5CFC).withValues(alpha: 0.15)
                    : const Color(0xFFF4F2FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.lexend(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? const Color(0xFF7C5CFC) : const Color(0xFF8E88A8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreCategoryDropdown() {
    final isCustomCategorySelected = _selectedCategory != 'All' &&
        _selectedCategory != 'Favorites' &&
        !_getPopularCategories(_allFilteredVocabs.length).contains(_selectedCategory);

    return InkWell(
      onTap: _showCategoryBottomSheet,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isCustomCategorySelected ? const Color(0xFFF4EEFF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCustomCategorySelected
                ? const Color(0xFF7C5CFC)
                : const Color(0xFFEBE6FC),
            width: isCustomCategorySelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isCustomCategorySelected ? _formatCategoryName(_selectedCategory) : 'More...',
              style: GoogleFonts.lexend(
                fontSize: 13,
                fontWeight: isCustomCategorySelected ? FontWeight.w700 : FontWeight.w500,
                color: isCustomCategorySelected
                    ? const Color(0xFF7C5CFC)
                    : const Color(0xFF8E88A8),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: isCustomCategorySelected
                  ? const Color(0xFF7C5CFC)
                  : const Color(0xFF8E88A8),
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
    if (category == 'Favorites') {
      return allVocabs.where((v) => v.isFavorite).length;
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
    if (_selectedCategory == 'Favorites') {
      filtered = filtered.where((v) => v.isFavorite).toList();
    } else if (_selectedCategory != 'All') {
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
        ),

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
    final isFavorite = vocab.isFavorite;
    final topicName = _formatCategoryName(vocab.topic).replaceAll('❤️ ', '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEBE6FC),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C5CFC).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 3),
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
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Row(
            children: [
              // Vocabulary info (vertical layout)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            vocab.word,
                            style: GoogleFonts.lexend(
                              fontSize: 17.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF221F33),
                              height: 1.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (vocab.topic.isNotEmpty && vocab.topic != 'other') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4EEFF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              topicName,
                              style: GoogleFonts.lexend(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF7C5CFC),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    // Thai translation
                    Text(
                      vocab.thaiTranslation,
                      style: GoogleFonts.lexend(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF655D80),
                        height: 1.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Favorite Heart Button in circle pill
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _displayedVocabs = _displayedVocabs.map((v) {
                        return v.id == vocab.id ? v.copyWith(isFavorite: !v.isFavorite) : v;
                      }).toList();
                    });
                    ref.read(vocabularyStateProvider.notifier).toggleFavorite(vocab.id);
                  },
                  borderRadius: BorderRadius.circular(19),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFavorite ? const Color(0xFFFDF2F8) : const Color(0xFFF9F7FD),
                      border: Border.all(
                        color: isFavorite ? const Color(0xFFFCE7F3) : const Color(0xFFEBE6FC),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFavorite
                            ? const Color(0xFFEC4899)
                            : const Color(0xFFA69EB8),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Arrow
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFC4BDD9),
                size: 22,
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFEBE6FC),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C5CFC).withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF4EEFF),
                border: Border.all(
                  color: const Color(0xFFE2DBFD),
                  width: 1.5,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 32,
                  color: Color(0xFF7C5CFC),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No vocabulary found',
              style: GoogleFonts.lexend(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF221F33),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Start discovering words with new photos to build your galaxy!',
              style: GoogleFonts.lexend(
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF9892A6),
              ),
              textAlign: TextAlign.center,
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
          'My Photos',
          style: GoogleFonts.lexend(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF221F33),
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
              entry.imageUrl.startsWith('http://') || entry.imageUrl.startsWith('https://')
                  ? Image.network(
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
                    )
                  : Image.file(
                      File(entry.imageUrl),
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
                    child: photoEntry.imageUrl.startsWith('http://') || photoEntry.imageUrl.startsWith('https://')
                        ? Image.network(
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
                          )
                        : Image.file(
                            File(photoEntry.imageUrl),
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
