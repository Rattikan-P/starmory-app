import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/topic_categories.dart';
import 'review_session_page.dart';
import '../providers/review_provider.dart';
import '../widgets/galaxy_screen_background.dart';

/// Review Tab - Main review screen
/// Shows review stats and start session button
class ReviewTab extends ConsumerStatefulWidget {
  const ReviewTab({super.key});

  @override
  ConsumerState<ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends ConsumerState<ReviewTab> with WidgetsBindingObserver {
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
    final shouldLoad = _lastLoadTime == null ||
        now.difference(_lastLoadTime!).inSeconds >= 5;

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
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Photos',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Remember words from your photos',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white60,
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, dynamic reviewState) {
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
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white60,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => ref.read(reviewStateProvider.notifier).loadSession(),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "You're all done! 🎉",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No photos to review right now.\nNew photos coming soon!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white60,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHasCards(BuildContext context, WidgetRef ref, dynamic reviewState) {
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

  /// Calculate adaptive time estimate based on card count and user history
  /// - New users (< 20 reviews): Use 7 sec/card baseline (FSRS team standard)
  ///   Reference: open-spaced-repetition/FSRS, Control-Alt-Backspace
  /// - Experienced users: Use personalized average from their history
  String _getTimeEstimate(int cardCount, int totalReviews, double avgTimePerCard) {
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
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B7CF6), Color(0xFF6C63FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B7CF6).withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.style_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Photos to Review',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$dueCount cards',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF8B7CF6).withValues(alpha: 0.12),
            const Color(0xFF6C63FF).withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8B7CF6).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Colors.amber.withValues(alpha: 0.9),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'How to use',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStep('1', 'See your photo & word'),
          const SizedBox(height: 12),
          _buildStep('2', 'Tap to reveal meaning'),
          const SizedBox(height: 12),
          _buildStep('3', 'Tell us if you knew it'),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF8B7CF6).withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B7CF6),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => FutureBuilder<int>(
          future: ref.read(reviewServiceProvider).getTotalAvailableCardsCount(topicFilter: selectedTopic),
          builder: (context, snapshot) {
            final totalAvailable = snapshot.data ?? 0;

            final List<Map<String, dynamic>> options = [];
            const steps = [5, 10, 15, 20, 25, 30];

            for (final s in steps) {
              if (s <= totalAvailable) {
                options.add({'label': '$s cards', 'value': s});
              }
            }

            if (totalAvailable > 0 && !options.any((o) => o['value'] == totalAvailable)) {
              options.add({'label': 'All ($totalAvailable)', 'value': totalAvailable});
            }

            // clamp selectedBatchSize
            if (options.isNotEmpty && !options.any((o) => o['value'] == selectedBatchSize)) {
              selectedBatchSize = options.last['value'];
            }

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: const EdgeInsets.all(28),
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
                  const SizedBox(height: 28),
                  const Text(
                    'Review Settings',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1f2937),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Batch Size Selection
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Batch Size',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (options.isEmpty)
                    const Text(
                      'No cards available right now',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
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
                          selectedColor: const Color(0xFF8B7CF6).withValues(alpha: 0.2),
                          onSelected: (val) => setModalState(() => selectedBatchSize = size),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_rounded, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          _getTimeEstimate(selectedBatchSize, ref.read(reviewStateProvider).totalReviewsCompleted, ref.read(reviewStateProvider).averageTimePerCard),
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Topic Filter - Chip style
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Topic',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
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
                        onTap: () => setModalState(() => selectedTopic = null),
                      ),
                      ...TopicCategories.all.map((topic) => _buildTopicChip(
                        label: TopicCategories.getDisplayNameEn(topic),
                        emoji: _getTopicEmoji(topic),
                        isSelected: selectedTopic == topic,
                        onTap: () => setModalState(() => selectedTopic = topic),
                      )),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B7CF6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
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
                          ref.read(reviewStateProvider.notifier).loadSession();
                        });
                      },
                      child: const Text('Start Review'),
                    ),
                  ),
                ],
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
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      avatar: Text(emoji, style: const TextStyle(fontSize: 14)),
      label: Text(label),
      backgroundColor: Colors.grey.shade200,
      selectedColor: const Color(0xFF8B7CF6).withValues(alpha: 0.2),
      selected: isSelected,
      side: isSelected
          ? const BorderSide(color: Color(0xFF8B7CF6), width: 1.5)
          : const BorderSide(color: Colors.grey, width: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      labelStyle: TextStyle(
        color: isSelected
            ? const Color(0xFF8B7CF6)
            : const Color(0xFF1f2937),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      onSelected: (selected) => onTap(),
    );
  }

  String _getTopicEmoji(String topic) {
    switch (topic) {
      case TopicCategories.food: return '🍎';
      case TopicCategories.people: return '👥';
      case TopicCategories.nature: return '🌿';
      case TopicCategories.home: return '🏠';
      case TopicCategories.dailyLife: return '📅';
      case TopicCategories.clothing: return '👕';
      case TopicCategories.hobbies: return '🎨';
      case TopicCategories.education: return '📚';
      case TopicCategories.work: return '💼';
      case TopicCategories.technology: return '💻';
      case TopicCategories.health: return '🏥';
      case TopicCategories.entertainment: return '🎬';
      default: return '🏷️';
    }
  }
}
