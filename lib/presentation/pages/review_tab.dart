import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/topic_categories.dart';
import 'review_session_page.dart';
import '../providers/providers.dart';
import '../widgets/galaxy_screen_background.dart';
import '../utils/photo_picker_flow.dart';

/// Review Tab - Main review screen
/// Shows review stats and start session button
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
  String? _currentTopicFilter; // Keep track of current topic filter
  int _currentBatchSize = 5; // Keep track of current batch size

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    print('🔄 ReviewTab: initState - setting up 2 min timer');

    // Auto-refresh every 2 minutes - always load all due cards (no filter)
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (_hasInitialized) {
        ref.read(reviewStateProvider.notifier).loadSession();
      }
    });

    // Load initial session after first frame - always load all due cards (no filter)
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
    // Reload when app is resumed (e.g., returning from review session)
    if (state == AppLifecycleState.resumed && _hasInitialized) {
      _reloadSession();
    }
  }

  void _reloadSession() {
    final now = DateTime.now();
    final shouldLoad =
        _lastLoadTime == null || now.difference(_lastLoadTime!).inSeconds >= 5;

    if (shouldLoad) {
      _lastLoadTime = now;
      // Always reload with no filter - show all due cards
      ref.read(reviewStateProvider.notifier).loadSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewState = ref.watch(reviewStateProvider);

    return GalaxyScreenBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                // Header
                _buildHeader(),

                const SizedBox(height: 24),

                // Content
                Expanded(
                  child: _buildContent(context, ref, reviewState),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Photos',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: Color(0xFF2F2855),
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Build your memory, one photo at a time',
                style: TextStyle(fontSize: 14, color: Color(0xFF655D80)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, dynamic reviewState) {
    // Loading state
    if (reviewState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B7CF6)),
      );
    }

    // Error state
    if (reviewState.error != null) {
      return _buildError(context, ref, reviewState.error!);
    }

    // Empty state
    if (reviewState.cards.isEmpty) {
      return _buildEmpty(context);
    }

    // Has cards
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2F2855),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
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
              backgroundColor: const Color(0xFF8B7CF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7566B7).withValues(alpha: 0.16),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: const BoxDecoration(
                color: Color(0xFFD8F5E6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, size: 42, color: Color(0xFF278B5A)),
            ),
            const SizedBox(height: 18),
            const Text(
              "You're all caught up!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF2F2855)),
            ),
            const SizedBox(height: 8),
            const Text(
              'No photos are waiting for review.\nAdd a new photo anytime to keep learning.',
              style: TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF655D80)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            const Text(
              'Add a new photo to keep learning',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF594AAE),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildAddPhotoButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    colors: const [Color(0xFF60A5FA), Color(0xFF3B82F6)],
                    onTap: () => PhotoPickerFlow.pickAndPreview(context, ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAddPhotoButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    colors: const [Color(0xFFA78BFA), Color(0xFF8B5CF6)],
                    onTap: () => PhotoPickerFlow.pickAndPreview(context, ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHasCards(
      BuildContext context, WidgetRef ref, dynamic reviewState) {
    // Total due cards = remaining due cards only
    final totalDueCount = reviewState.remainingDueCount;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Hero Card - Cards Due
          _buildHeroCard(totalDueCount, reviewState),

          const SizedBox(height: 24),

          // How It Works
          _buildHowItWorks(),

          const SizedBox(height: 24),

          // Start Review Button
          _buildStartButton(context),

          const SizedBox(height: 16),
        ],
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
              BoxShadow(color: colors.last.withValues(alpha: 0.22), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 19),
              const SizedBox(width: 7),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  /// Calculate adaptive time estimate based on card count and user history
  /// - New users (< 20 reviews): Use 7 sec/card baseline (FSRS team standard)
  ///   Reference: open-spaced-repetition/FSRS, Control-Alt-Backspace
  /// - Experienced users: Use personalized average from their history
  String _getTimeEstimate(
      int cardCount, int totalReviews, double avgTimePerCard) {
    if (cardCount == 0) return '~0 min';

    int totalSeconds;

    if (totalReviews < 20) {
      // New user - use 7 sec/card baseline (FSRS team standard)
      totalSeconds = cardCount * 7;
    } else {
      // Experienced user - use personalized average
      totalSeconds = (cardCount * avgTimePerCard).round();
    }

    // Format output
    if (totalSeconds < 60) {
      return '~$totalSeconds sec';
    } else if (totalSeconds < 3600) {
      final minutes = (totalSeconds / 60).round();
      return '~$minutes min';
    } else {
      final hours = (totalSeconds / 3600).round();
      return '~$hours hour${hours > 1 ? "s" : ""}';
    }
  }

  Widget _buildHeroCard(int dueCount, dynamic reviewState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD7D0FF), Color(0xFFB6AAFF), Color(0xFF9C8EEA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8678D6).withValues(alpha: 0.26),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.48),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('READY FOR YOU',
                      style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF514588))),
                ),
                const SizedBox(height: 14),
                const Text('Photos to\nreview',
                    style: TextStyle(
                        fontSize: 25,
                        height: 1.08,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2F2855))),
                const SizedBox(height: 10),
                Text(
                    dueCount == 1
                        ? '1 card is waiting'
                        : '$dueCount cards are waiting',
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF5D567B))),
              ],
            ),
          ),
          Container(
            width: 100,
            height: 112,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.56),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.58)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.photo_library_rounded,
                    size: 24, color: Color(0xFF6354B5)),
                const SizedBox(height: 7),
                Text('$dueCount',
                    style: const TextStyle(
                        fontSize: 32,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2F2855))),
                const SizedBox(height: 3),
                const Text('CARDS',
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF655D80))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFEFF), Color(0xFFF0ECFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFD8D0FF),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF695C9E).withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1C9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lightbulb_outline_rounded,
                    color: Color(0xFFAA7800), size: 19),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How it works',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2F2855))),
                    SizedBox(height: 2),
                    Text('A quick, photo-based review',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF6B6383))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildStep('1', Icons.visibility_outlined, 'See the photo',
              'Recall the word before you flip'),
          const SizedBox(height: 10),
          _buildStep('2', Icons.touch_app_outlined, 'Reveal the meaning',
              'Tap the card when you are ready'),
          const SizedBox(height: 10),
          _buildStep('3', Icons.swipe_rounded, 'Rate your memory',
              'Swipe based on what you remembered'),
        ],
      ),
    );
  }

  Widget _buildStep(
      String number, IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFEAE6FF),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 19, color: const Color(0xFF7564CF)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$number  $title',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3A3263))),
              const SizedBox(height: 2),
              Text(subtitle,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF6B6383))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: () => _startReview(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8B7CF6),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          shadowColor: const Color(0xFF8B7CF6).withValues(alpha: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_arrow, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Start Review',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startReview(BuildContext context) {
    _showSettingsBottomSheet(context);
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
      // Keep the route unconstrained so it also grows when a desktop/web
      // window is resized after the sheet has opened.
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
                options.add({'label': '$s cards', 'value': s});
              }
            }

            if (totalAvailable > 0 &&
                !options.any((o) => o['value'] == totalAvailable)) {
              options.add(
                  {'label': 'All ($totalAvailable)', 'value': totalAvailable});
            }

            // clamp selectedBatchSize
            if (options.isNotEmpty &&
                !options.any((o) => o['value'] == selectedBatchSize)) {
              selectedBatchSize = options.last['value'];
            }

            final screenWidth = MediaQuery.sizeOf(context).width;
            final horizontalPadding = screenWidth < 380 ? 18.0 : 24.0;

            return SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFCFBFF), Color(0xFFF4F1FF)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF312E81).withValues(alpha: 0.16),
                      blurRadius: 28,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                padding: EdgeInsets.fromLTRB(
                    horizontalPadding, 12, horizontalPadding, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFd1d5db),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF9B8CFF), Color(0xFF6D5CE7)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.tune_rounded,
                                color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Review settings',
                                    style: TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1F2937))),
                                SizedBox(height: 2),
                                Text('Choose a topic and session size',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF6B7280))),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded,
                                color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF0EDFF), Color(0xFFE7E2FF)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFDCD5FF)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.style_rounded,
                                size: 18, color: Color(0xFF6D5CE7)),
                            const SizedBox(width: 8),
                            Text('$totalAvailable cards ready to review',
                                style: const TextStyle(
                                    color: Color(0xFF5145B7),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: _settingsSectionDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSettingsSectionTitle(
                              icon: Icons.category_outlined,
                              title: '1. Choose a topic',
                              subtitle: 'Topics without cards are unavailable',
                            ),
                            const SizedBox(height: 12),
                            // All Topics chip
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildTopicChip(
                                  label: 'All',
                                  emoji: '📷',
                                  isSelected: selectedTopic == null,
                                  count: totalAvailable,
                                  isEnabled: totalAvailable > 0,
                                  onTap: () =>
                                      setModalState(() => selectedTopic = null),
                                ),
                                ...visibleTopics.map((topic) => _buildTopicChip(
                                      label: TopicCategories.getDisplayNameEn(
                                          topic),
                                      emoji: _getTopicEmoji(topic),
                                      isSelected: selectedTopic == topic,
                                      count: topicCounts[topic] ?? 0,
                                      isEnabled: (topicCounts[topic] ?? 0) > 0,
                                      onTap: () => setModalState(
                                          () => selectedTopic = topic),
                                    )),
                                if (hiddenTopicCount > 0 || showAllTopics)
                                  ActionChip(
                                    avatar: const Icon(Icons.more_horiz_rounded,
                                        size: 18),
                                    label: Text(showAllTopics
                                        ? 'Less'
                                        : 'More ($hiddenTopicCount)'),
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(
                                        color: Color(0xFFD8D4FF)),
                                    labelStyle: const TextStyle(
                                        color: Color(0xFF6D5CE7),
                                        fontWeight: FontWeight.w600),
                                    onPressed: () => setModalState(
                                      () => showAllTopics = !showAllTopics,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: _settingsSectionDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSettingsSectionTitle(
                              icon: Icons.layers_outlined,
                              title: '2. Choose session size',
                              subtitle: 'You can review every available card',
                            ),
                            const SizedBox(height: 12),
                            if (options.isEmpty)
                              const Text(
                                'No cards available right now',
                                style:
                                    TextStyle(fontSize: 14, color: Colors.grey),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                children: options.map((option) {
                                  final size = option['value'] as int;
                                  final label = option['label'] as String;
                                  final isSelected = selectedBatchSize == size;
                                  return ChoiceChip(
                                    label: Text(label),
                                    selected: isSelected,
                                    showCheckmark: false,
                                    backgroundColor: Colors.white,
                                    selectedColor: const Color(0xFF8B7CF6)
                                        .withValues(alpha: 0.2),
                                    side: BorderSide(
                                      color: isSelected
                                          ? const Color(0xFF8B7CF6)
                                          : const Color(0xFFE5E7EB),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? const Color(0xFF6D5CE7)
                                          : const Color(0xFF4B5563),
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                    onSelected: (val) => setModalState(
                                        () => selectedBatchSize = size),
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.access_time_rounded,
                                      size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getTimeEstimate(
                                        selectedBatchSize,
                                        ref
                                            .read(reviewStateProvider)
                                            .totalReviewsCompleted,
                                        ref
                                            .read(reviewStateProvider)
                                            .averageTimePerCard),
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6D5CE7),
                            disabledBackgroundColor: const Color(0xFFE5E7EB),
                            foregroundColor: Colors.white,
                            disabledForegroundColor: const Color(0xFF9CA3AF),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: totalAvailable == 0
                              ? null
                              : () {
                                  // Save current filter settings
                                  _currentTopicFilter = selectedTopic;
                                  _currentBatchSize = selectedBatchSize;

                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ReviewSessionPage(
                                        topicFilter: selectedTopic,
                                        batchSize: selectedBatchSize,
                                      ),
                                    ),
                                  ).then((_) {
                                    // Reload all due cards (no filter) when returning from session
                                    // The filter is only used for the review session, not for the main tab
                                    ref
                                        .read(reviewStateProvider.notifier)
                                        .loadSession();
                                  });
                                },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow_rounded),
                              SizedBox(width: 6),
                              Text('Start Review',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopicChip({
    required String label,
    required String emoji,
    required int count,
    required bool isSelected,
    bool isEnabled = true,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      avatar: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF8B7CF6).withValues(alpha: 0.14)
              : const Color(0xFFF3F4F6),
          shape: BoxShape.circle,
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 13)),
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF8B7CF6).withValues(alpha: 0.16)
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$count',
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      showCheckmark: false,
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF8B7CF6).withValues(alpha: 0.12),
      selected: isSelected,
      disabledColor: Colors.grey.shade100,
      side: BorderSide(
        color: isSelected
            ? const Color(0xFF8B7CF6)
            : isEnabled
                ? const Color(0xFFE5E7EB)
                : const Color(0xFFE5E7EB),
        width: isSelected ? 1.5 : 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      labelStyle: TextStyle(
        color: !isEnabled
            ? Colors.grey.shade400
            : isSelected
                ? const Color(0xFF8B7CF6)
                : const Color(0xFF1f2937),
        fontWeight:
            isSelected && isEnabled ? FontWeight.w600 : FontWeight.normal,
      ),
      onSelected: isEnabled ? (selected) => onTap() : null,
    );
  }

  Widget _buildSettingsSectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFEEECFF),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 17, color: const Color(0xFF6D5CE7)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937))),
              const SizedBox(height: 2),
              Text(subtitle,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ],
          ),
        ),
      ],
    );
  }

  BoxDecoration _settingsSectionDecoration() {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE8E4FA)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF50458F).withValues(alpha: 0.05),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  String _getTopicEmoji(String topic) {
    switch (topic) {
      case TopicCategories.food:
        return '🍎';
      case TopicCategories.people:
        return '👥';
      case TopicCategories.nature:
        return '🌿';
      case TopicCategories.home:
        return '🏠';
      case TopicCategories.dailyLife:
        return '📅';
      case TopicCategories.clothing:
        return '👕';
      case TopicCategories.hobbies:
        return '🎨';
      case TopicCategories.education:
        return '📚';
      case TopicCategories.work:
        return '💼';
      case TopicCategories.technology:
        return '💻';
      case TopicCategories.health:
        return '🏥';
      case TopicCategories.entertainment:
        return '🎬';
      default:
        return '🏷️';
    }
  }
}
