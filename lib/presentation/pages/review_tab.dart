import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/topic_categories.dart';
import 'review_session_page.dart';
import '../providers/providers.dart';
import '../utils/photo_picker_flow.dart';

/// Review Tab - Pixel-perfect implementation matching the latest design
class ReviewTab extends ConsumerStatefulWidget {
  const ReviewTab({super.key});

  @override
  ConsumerState<ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends ConsumerState<ReviewTab>
    with WidgetsBindingObserver {
  bool _hasInitialized = false;
  Timer? _refreshTimer;
  DateTime? _lastLoadTime;
  bool _isReviewSessionOpen = false;

  bool _isHowItWorksExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Auto-refresh every 2 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (_hasInitialized && _isRouteVisible && !_isReviewSessionOpen) {
        ref.read(reviewStateProvider.notifier).loadSession();
      }
    });

    // Initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hasInitialized = true;
      _lastLoadTime = DateTime.now();
      ref.read(reviewStateProvider.notifier).loadSession();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _hasInitialized &&
        _isRouteVisible &&
        !_isReviewSessionOpen) {
      _reloadSession();
    }
  }

  bool get _isRouteVisible {
    return mounted && (ModalRoute.of(context)?.isCurrent ?? false);
  }

  void _reloadSession() {
    final now = DateTime.now();
    final shouldLoad =
        _lastLoadTime == null || now.difference(_lastLoadTime!).inSeconds >= 5;

    if (shouldLoad) {
      _lastLoadTime = now;
      ref.read(reviewStateProvider.notifier).loadSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewState = ref.watch(reviewStateProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            children: [
              // Header with user avatar
              _buildHeader(currentUser),

              const SizedBox(height: 18),

              // Main Content
              Expanded(
                child: _buildContent(context, ref, reviewState),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(dynamic user) {
    final displayName =
        (user?.displayName as String?) ?? (user?.email as String?) ?? 'G';
    final avatarLetter =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'G';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily Review',
                style: GoogleFonts.lexend(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: const Color(0xFF221F33),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Strengthen your vocabulary, one memory at a time',
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
        // User Avatar circle matching screenshot
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE2DBFD), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C5CFC).withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              avatarLetter,
              style: GoogleFonts.lexend(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF221F33),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, dynamic reviewState) {
    if (reviewState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF7C5CFC)),
      );
    }

    if (reviewState.error != null) {
      return _buildError(context, ref, reviewState.error!);
    }

    if (reviewState.cards.isEmpty) {
      return _buildEmpty(context);
    }

    return _buildHasCards(context, ref, reviewState);
  }

  Widget _buildError(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline, size: 48, color: Colors.red),
          ),
          const SizedBox(height: 16),
          Text(
            'Oops! Something went wrong',
            style: GoogleFonts.lexend(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF221F33),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: GoogleFonts.lexend(
              fontSize: 14,
              color: const Color(0xFF655D80),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () =>
                ref.read(reviewStateProvider.notifier).loadSession(),
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C5CFC),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildHeroCard(0),
          const SizedBox(height: 16),
          _buildHowItWorksCard(),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFEBE6FC), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5F45B2).withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 38, color: Color(0xFF278B5A)),
                const SizedBox(height: 12),
                Text(
                  "All caught up! ✨",
                  style: GoogleFonts.lexend(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF221F33),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'No words are due for review right now.\nAdd a new photo anytime to keep learning.',
                  style: GoogleFonts.lexend(
                    fontSize: 13,
                    height: 1.4,
                    color: const Color(0xFF7A7394),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _buildAddPhotoButton(
                        icon: Icons.camera_alt_rounded,
                        label: 'Camera',
                        colors: const [Color(0xFF60A5FA), Color(0xFF3B82F6)],
                        onTap: () => PhotoPickerFlow.pickAndPreview(
                            context, ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAddPhotoButton(
                        icon: Icons.photo_library_rounded,
                        label: 'Gallery',
                        colors: const [Color(0xFFA78BFA), Color(0xFF8B5CF6)],
                        onTap: () => PhotoPickerFlow.pickAndPreview(
                            context, ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHasCards(
      BuildContext context, WidgetRef ref, dynamic reviewState) {
    final totalDueCount = reviewState.remainingDueCount;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Hero Card with Mascot Illustration
          _buildHeroCard(totalDueCount),

          const SizedBox(height: 16),

          // How it works Collapsible Card (with 3 step cards)
          _buildHowItWorksCard(),

          const SizedBox(height: 18),

          // Action Buttons: Tune Filter + Quick Review
          _buildActionButtons(context, totalDueCount),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeroCard(int dueCount) {
    return Container(
      width: double.infinity,
      height: 152,
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
            // Scattered mix of filled and outline stars in background
            Positioned(
              top: -15,
              left: 110,
              child: Transform.rotate(
                angle: -0.15,
                child: const Opacity(
                  opacity: 0.35,
                  child: Icon(Icons.star_border_rounded,
                      size: 95, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 185,
              child: Transform.rotate(
                angle: 0.2,
                child: const Opacity(
                  opacity: 0.32,
                  child:
                      Icon(Icons.star_rounded, size: 44, color: Colors.white),
                ),
              ),
            ),
            const Positioned(
              top: 65,
              left: 140,
              child: Opacity(
                opacity: 0.38,
                child: Icon(Icons.star_border_rounded,
                    size: 32, color: Colors.white),
              ),
            ),
            Positioned(
              bottom: -20,
              left: 195,
              child: Transform.rotate(
                angle: 0.3,
                child: const Opacity(
                  opacity: 0.32,
                  child: Icon(Icons.star_border_rounded,
                      size: 85, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              top: -8,
              right: 25,
              child: Transform.rotate(
                angle: -0.1,
                child: const Opacity(
                  opacity: 0.30,
                  child:
                      Icon(Icons.star_rounded, size: 65, color: Colors.white),
                ),
              ),
            ),
            const Positioned(
              top: 65,
              right: -5,
              child: Opacity(
                opacity: 0.30,
                child: Icon(Icons.star_border_rounded,
                    size: 38, color: Colors.white),
              ),
            ),
            const Positioned(
              bottom: 8,
              right: 125,
              child: Opacity(
                opacity: 0.30,
                child: Icon(Icons.star_rounded, size: 30, color: Colors.white),
              ),
            ),
            const Positioned(
              top: 8,
              left: 20,
              child: Opacity(
                opacity: 0.28,
                child: Icon(Icons.star_border_rounded,
                    size: 22, color: Colors.white),
              ),
            ),

            // Left Side: White Circle badge with number + ready to review
            Positioned(
              left: 18,
              top: 0,
              bottom: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF5A4A88).withValues(alpha: 0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dueCount',
                            style: GoogleFonts.lexend(
                              fontSize: 42,
                              height: 1.0,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.0,
                              color: const Color(0xFF2B263E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'words',
                            style: GoogleFonts.lexend(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6B647E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ready to review',
                      style: GoogleFonts.lexend(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF63564A),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Right Side: Mascot Character Illustration
            Positioned(
              right: 8,
              bottom: 0,
              top: 4,
              child: Image.asset(
                'assets/images/review_mascot.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.auto_awesome,
                      size: 64,
                      color: Color(0xFF7C5CFC),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorksCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEBE6FC), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5F45B2).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            setState(() {
              _isHowItWorksExpanded = !_isHowItWorksExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              children: [
                Row(
                  children: [
                    // Purple Lightbulb Icon Circle
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1EDFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lightbulb_outline_rounded,
                        color: Color(0xFF7C5CFC),
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How it works',
                            style: GoogleFonts.lexend(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF221F33),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                'A quick, photo-based review with ',
                                style: GoogleFonts.lexend(
                                  fontSize: 12,
                                  color: const Color(0xFF7A7394),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _showFsrsInfoDialog(context),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'FSRS',
                                      style: GoogleFonts.lexend(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF7C5CFC),
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(
                                      Icons.info_outline_rounded,
                                      size: 13,
                                      color: Color(0xFF7C5CFC),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _isHowItWorksExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF221F33),
                      size: 24,
                    ),
                  ],
                ),
                if (_isHowItWorksExpanded) ...[
                  const SizedBox(height: 14),
                  // 3 Horizontal Step Cards matching the screenshot
                  Row(
                    children: [
                      Expanded(
                        child: _buildHorizontalStepCard(
                          icon: Icons.remove_red_eye_outlined,
                          title: '1. See photo',
                          subtitle: 'Guess the word first',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildHorizontalStepCard(
                          icon: Icons.lightbulb_outline_rounded,
                          title: '2. Flip Card',
                          subtitle: 'Tap card to check\nthe meaning',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildHorizontalStepCard(
                          icon: Icons.front_hand_outlined,
                          title: '3. Rate',
                          subtitle: 'Choose Not yet or\nGot it',
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalStepCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1EE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top icon circle
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 16,
              color: const Color(0xFFFA6E7F),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.lexend(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF221F33),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: GoogleFonts.lexend(
              fontSize: 9.5,
              height: 1.25,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF7A7394),
            ),
          ),
        ],
      ),
    );
  }

  void _showFsrsInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1EDFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF7C5CFC),
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'About FSRS',
                style: GoogleFonts.lexend(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF221F33),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'FSRS (Free Spaced Repetition Scheduler) is a modern memory algorithm that schedules reviews right before you forget, helping you retain vocabulary effortlessly.',
                style: GoogleFonts.lexend(
                  fontSize: 13,
                  height: 1.45,
                  color: const Color(0xFF655D80),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C5CFC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Got it',
                    style: GoogleFonts.lexend(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, int totalDueCount) {
    return Row(
      children: [
        // Left Filter / Tune Button (with smooth circular shadow)
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE2DBFD), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C5CFC).withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _showSettingsBottomSheet(context),
              child: const Center(
                child: Icon(
                  Icons.tune_rounded,
                  color: Color(0xFF7C5CFC),
                  size: 24,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Right Quick Review Pill Button (Fixed Default: All topic • 5 words)
        Expanded(
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8652FF), Color(0xFF7847FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(27),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7847FF).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(27),
              child: InkWell(
                borderRadius: BorderRadius.circular(27),
                onTap: totalDueCount == 0
                    ? null
                    : () => _startReview(
                          context,
                          topicFilter: null,
                          batchSize: 5,
                        ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                      const SizedBox(width: 6),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Review',
                            style: GoogleFonts.lexend(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'All topic • 5 words',
                            style: GoogleFonts.lexend(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.88),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _startReview(
    BuildContext context, {
    String? topicFilter,
    int batchSize = 5,
  }) {
    _isReviewSessionOpen = true;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewSessionPage(
          topicFilter: topicFilter,
          batchSize: batchSize,
        ),
      ),
    ).then((_) {
      _isReviewSessionOpen = false;
      ref.read(reviewStateProvider.notifier).loadSession();
    });
  }

  IconData _getTopicIcon(String topic) {
    switch (topic) {
      case TopicCategories.dailyLife:
        return Icons.favorite_border_rounded;
      case TopicCategories.technology:
        return Icons.laptop_chromebook_rounded;
      case TopicCategories.home:
        return Icons.home_outlined;
      case TopicCategories.clothing:
        return Icons.checkroom_outlined;
      case TopicCategories.nature:
        return Icons.eco_outlined;
      case TopicCategories.food:
        return Icons.restaurant_outlined;
      case TopicCategories.people:
        return Icons.people_outline_rounded;
      case TopicCategories.hobbies:
        return Icons.sports_esports_outlined;
      case TopicCategories.education:
        return Icons.school_outlined;
      case TopicCategories.work:
        return Icons.work_outline_rounded;
      case TopicCategories.health:
        return Icons.medical_services_outlined;
      case TopicCategories.entertainment:
        return Icons.movie_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  void _showSettingsBottomSheet(BuildContext context) {
    int selectedBatchSize = 5;
    String? selectedTopic;
    bool showAllTopics = false;
    final topicCountsFuture =
        ref.read(reviewServiceProvider).getAvailableCardCountsByTopic();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => FutureBuilder<Map<String, int>>(
          future: topicCountsFuture,
          builder: (context, snapshot) {
            final topicCounts = snapshot.data ?? const <String, int>{};
            final totalAvailable = selectedTopic == null
                ? topicCounts.values.fold(0, (total, count) => total + count)
                : topicCounts[selectedTopic] ?? 0;
            final topicsByAvailableCards = List<String>.of(TopicCategories.all)
              ..sort((a, b) =>
                  (topicCounts[b] ?? 0).compareTo(topicCounts[a] ?? 0));
            final visibleTopics = showAllTopics
                ? topicsByAvailableCards
                : topicsByAvailableCards.take(5).toList();
            final hiddenTopicCount =
                topicsByAvailableCards.length - visibleTopics.length;

            final List<Map<String, dynamic>> options = [];
            const steps = [5, 10, 15, 20, 25, 30];

            for (final s in steps) {
              if (s <= totalAvailable) {
                options.add({'label': '$s', 'value': s});
              }
            }

            if (totalAvailable > 0 &&
                !options.any((o) => o['value'] == totalAvailable)) {
              options.add(
                  {'label': 'All ($totalAvailable)', 'value': totalAvailable});
            }

            if (options.isNotEmpty &&
                !options.any((o) => o['value'] == selectedBatchSize)) {
              selectedBatchSize = options.last['value'];
            }

            final allCount =
                topicCounts.values.fold(0, (total, count) => total + count);

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Drag handle
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header Row: Custom review + Close button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Custom review',
                                style: GoogleFonts.lexend(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF221F33),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Choose a topic and session size',
                                style: GoogleFonts.lexend(
                                  fontSize: 13,
                                  color: const Color(0xFF8E88A8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFF3F4F6),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: Color(0xFF221F33),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Card 1: Choose a topic
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                            color: const Color(0xFFEBE6FC), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF7C5CFC).withValues(alpha: 0.05),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFF1EDFF),
                                ),
                                child: const Icon(
                                  Icons.tag_rounded,
                                  color: Color(0xFF7C5CFC),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Choose a topic',
                                      style: GoogleFonts.lexend(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF221F33),
                                      ),
                                    ),
                                    Text(
                                      'Topics without words are unavailable',
                                      style: GoogleFonts.lexend(
                                        fontSize: 12,
                                        color: const Color(0xFF8E88A8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Inner outlined container with topic chips
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: const Color(0xFFEBE6FC), width: 1.0),
                            ),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 10,
                              children: [
                                // 'All' Pill
                                _buildCustomTopicChip(
                                  label: 'All',
                                  count: allCount,
                                  isSelected: selectedTopic == null,
                                  isAvailable: allCount > 0,
                                  icon: null,
                                  onTap: () {
                                    setModalState(() => selectedTopic = null);
                                  },
                                ),

                                // Dynamic Topic Pills
                                ...visibleTopics.map((topic) {
                                  final count = topicCounts[topic] ?? 0;
                                  final isSelected = selectedTopic == topic;
                                  final isAvailable = count > 0;

                                  return _buildCustomTopicChip(
                                    label:
                                        TopicCategories.getDisplayNameEn(topic),
                                    count: count,
                                    isSelected: isSelected,
                                    isAvailable: isAvailable,
                                    icon: _getTopicIcon(topic),
                                    onTap: isAvailable
                                        ? () {
                                            setModalState(() => selectedTopic =
                                                isSelected ? null : topic);
                                          }
                                        : null,
                                  );
                                }),

                                // '... More (8)' or '... Less' Pill
                                if (!showAllTopics && hiddenTopicCount > 0)
                                  InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      setModalState(
                                          () => showAllTopics = true);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: Border.all(
                                            color: const Color(0xFFE5E2F0),
                                            width: 1.0),
                                      ),
                                      child: Text(
                                        '... More ($hiddenTopicCount)',
                                        style: GoogleFonts.lexend(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                  )
                                else if (showAllTopics &&
                                    topicsByAvailableCards.length > 5)
                                  InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      setModalState(
                                          () => showAllTopics = false);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: Border.all(
                                            color: const Color(0xFFE5E2F0),
                                            width: 1.0),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '... Less',
                                            style: GoogleFonts.lexend(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF6B7280),
                                            ),
                                          ),
                                          const SizedBox(width: 3),
                                          const Icon(
                                            Icons.keyboard_arrow_up_rounded,
                                            size: 16,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Card 2: Choose session size
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                            color: const Color(0xFFEBE6FC), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF7C5CFC).withValues(alpha: 0.05),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFF1EDFF),
                                ),
                                child: const Icon(
                                  Icons.favorite_border_rounded,
                                  color: Color(0xFF7C5CFC),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Choose session size',
                                      style: GoogleFonts.lexend(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF221F33),
                                      ),
                                    ),
                                    Text(
                                      'Choose how many words to review',
                                      style: GoogleFonts.lexend(
                                        fontSize: 12,
                                        color: const Color(0xFF8E88A8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Inner outlined container with size chips
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: const Color(0xFFEBE6FC), width: 1.0),
                            ),
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: options.map((opt) {
                                final isSelected =
                                    selectedBatchSize == opt['value'];
                                return InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    setModalState(() =>
                                        selectedBatchSize = opt['value']);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFF4F0FF)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF7C5CFC)
                                            : const Color(0xFFE5E2F0),
                                        width: isSelected ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Text(
                                      opt['label'],
                                      style: GoogleFonts.lexend(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? const Color(0xFF7C5CFC)
                                            : const Color(0xFF4B5563),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Start Custom Review Button
                    Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8652FF), Color(0xFF7847FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(27),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF7847FF).withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(27),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(27),
                          onTap: totalAvailable == 0
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  _startReview(
                                    context,
                                    topicFilter: selectedTopic,
                                    batchSize: selectedBatchSize,
                                  );
                                },
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Start Custom Review',
                                  style: GoogleFonts.lexend(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCustomTopicChip({
    required String label,
    required int count,
    required bool isSelected,
    required bool isAvailable,
    IconData? icon,
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: isAvailable ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF4F0FF)
              : isAvailable
                  ? Colors.white
                  : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF7C5CFC)
                : isAvailable
                    ? const Color(0xFFE5E2F0)
                    : const Color(0xFFF3F4F6),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? const Color(0xFF7C5CFC)
                    : isAvailable
                        ? const Color(0xFF4B5563)
                        : const Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: GoogleFonts.lexend(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF7C5CFC)
                    : isAvailable
                        ? const Color(0xFF221F33)
                        : const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFE5DCFF)
                    : isAvailable
                        ? const Color(0xFFF3F4F6)
                        : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.lexend(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? const Color(0xFF7C5CFC)
                      : isAvailable
                          ? const Color(0xFF6B7280)
                          : const Color(0xFF9CA3AF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddPhotoButton({
    required IconData icon,
    required String label,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: colors.last.withValues(alpha: 0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 19),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.lexend(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
