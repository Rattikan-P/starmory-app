import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'review_session_page.dart';
import '../providers/review_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/galaxy_screen_background.dart';

/// Review Tab - Main review screen
/// Shows review stats and start session button
class ReviewTab extends ConsumerStatefulWidget {
  const ReviewTab({super.key});

  @override
  ConsumerState<ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends ConsumerState<ReviewTab> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  bool _hasInitialized = false;
  Timer? _refreshTimer;
  DateTime? _lastLoadTime;

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    print('🔄 ReviewTab: initState - setting up 2 min timer');

    // Auto-refresh every 2 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      print('🔄 ReviewTab: Timer fired (2 min) - calling loadSession');
      if (_hasInitialized) {
        ref.read(reviewStateProvider.notifier).loadSession();
      }
    });

    // Load initial session after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hasInitialized = true;
      _lastLoadTime = DateTime.now();
      print('🔄 ReviewTab: Initial load session');
      ref.read(reviewStateProvider.notifier).loadSession();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
      print('🔄 ReviewTab: Reloading session (debounce: 5s)');
      ref.read(reviewStateProvider.notifier).loadSession();
    } else {
      print('🔄 ReviewTab: Skipped reload (debounced)');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for scroll to top signal from tab navigation
    ref.listen<int>(
      navigationProvider.select((s) => s.reviewScrollToTopTrigger),
      (previous, next) {
        if (previous != next) {
          _scrollToTop();
        }
      },
    );

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
    final dueCount = reviewState.cards.length;

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Hero Card - Cards Due
          _buildHeroCard(dueCount, reviewState),

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
    // Handle state inconsistency during hot reload
    final totalReviews = reviewState.totalReviewsCompleted ?? 0;
    final avgTime = reviewState.averageTimePerCard ?? 7.0;
    final timeEstimate = _getTimeEstimate(dueCount, totalReviews, avgTime);

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
            '$dueCount',
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '$dueCount ${dueCount == 1 ? 'card' : 'cards'} • ',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const Icon(
                Icons.access_time,
                size: 14,
                color: Colors.white70,
              ),
              const SizedBox(width: 4),
              Text(
                timeEstimate,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReviewSessionPage()),
    ).then((_) {
      // Reload session data when returning from review
      ref.read(reviewStateProvider.notifier).loadSession();
    });
  }
}
