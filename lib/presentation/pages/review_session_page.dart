import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../widgets/review_card_widget.dart';
import '../widgets/galaxy_screen_background.dart';

/// Review Session Page
/// Main review interface with flip cards and feedback
class ReviewSessionPage extends ConsumerStatefulWidget {
  final String? topicFilter;
  final int batchSize;

  const ReviewSessionPage({
    super.key, 
    this.topicFilter,
    this.batchSize = 5,
  });

  @override
  ConsumerState<ReviewSessionPage> createState() => _ReviewSessionPageState();
}

class _ReviewSessionPageState extends ConsumerState<ReviewSessionPage> {
  bool _hasTriedLoading = false;
  String? _currentTopicFilter;
  late int _batchSize;

  @override
  void initState() {
    super.initState();
    _currentTopicFilter = widget.topicFilter;
    _batchSize = widget.batchSize;
    print('🔍 ReviewSessionPage initState: topic=$_currentTopicFilter, batch=$_batchSize');
  }

  @override
  Widget build(BuildContext context) {
    final reviewState = ref.watch(reviewStateProvider);

    print('🔍 ReviewSessionPage build: _currentTopicFilter=$_currentTopicFilter, _hasTriedLoading=$_hasTriedLoading, cards=${reviewState.cards.length}');

    // Load session with topic filter and batch size on first build only
    // Note: We check !_hasTriedLoading to avoid multiple loads, but we don't check cards.isEmpty
    // because ReviewTab might have loaded cards already (with different filter/batchSize)
    if (!_hasTriedLoading && !reviewState.isLoading) {
      _hasTriedLoading = true;
      print('🔍 ReviewSessionPage: First load, calling loadSession with topicFilter=$_currentTopicFilter, batchSize=$_batchSize');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(reviewStateProvider.notifier).loadSession(
          topicFilter: _currentTopicFilter,
          batchSize: _batchSize,
        );
      });
    }

    return GalaxyScreenBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Your Photos'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            // Auto-saved hint
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_done, color: Colors.green, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'Auto-saved',
                      style: TextStyle(
                        color: Colors.green.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!reviewState.isLoading && reviewState.cards.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Current batch progress (primary)
                    Text(
                      '${reviewState.currentIndex + 1}/${reviewState.sessionCount}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Remaining cards count (secondary)
                    if (reviewState.remainingDueCount > 0)
                      Text(
                        '+${reviewState.remainingDueCount} more',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        body: _buildBody(context, ref, reviewState),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, ReviewState state) {
    // Loading state
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error state
    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error: ${state.error}',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(reviewStateProvider.notifier).loadSession(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Empty state (no cards)
    if (state.cards.isEmpty) {
      return _buildEmptyState(context);
    }

    // Show feedback
    if (state.showFeedback && state.lastRating != null) {
      return _buildFeedback(context, ref, state);
    }

    // Show card
    final currentCard = state.currentCard;
    if (currentCard == null) {
      return _buildCompleteState(context, ref);
    }

    return _buildCardSwipe(context, ref, currentCard);
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Colors.green.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 24),
          const Text(
            "You're all done!",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No photos to review right now.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.home),
            label: const Text('Back to Your Photos'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8b7cf6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSwipe(
    BuildContext context,
    WidgetRef ref,
    dynamic currentCard,
  ) {
    return Column(
      children: [
        // Progress indicator
        LinearProgressIndicator(
          value: ref.read(reviewStateProvider).progress,
          backgroundColor: Colors.grey.withValues(alpha: 0.3),
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8b7cf6)),
        ),
        const SizedBox(height: 8),
        // Card
        Expanded(
          child: Center(
            child: ReviewCardWidget(
              card: currentCard,
              onForgot: () => _handleSwipe(ref, false),
              onKnow: () => _handleSwipe(ref, true),
              canUndo: ref.read(reviewStateProvider).canUndo,
              onUndo: () => ref.read(reviewStateProvider.notifier).undoSwipe(),
              currentLanguageVariant: ref.read(currentUserProvider)?.englishVariant ?? 'US',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedback(BuildContext context, WidgetRef ref, ReviewState state) {
    final currentCard = state.cards[state.currentIndex];
    final vocab = currentCard.vocabulary;

    if (vocab == null) {
      return const Center(child: Text('No vocabulary data'));
    }

    final remembered = state.lastRating ?? false;

    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Result icon - friendly celebration instead of harsh X
              Icon(
                remembered ? Icons.celebration : Icons.auto_awesome,
                size: 80,
                color: remembered ? Colors.green : Colors.amber,
              ),
              const SizedBox(height: 16),
              // Friendly message
              Text(
                remembered ? 'You remember!' : "Not yet - that's okay!",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Word
              Text(
                vocab.word,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // "means" label
              Text(
                'means',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              // Meaning
              Text(
                vocab.thaiTranslation,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Example sentence
              if (vocab.englishSentence.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    vocab.englishSentence,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white60,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 32),
              // Undo button (if available)
              if (state.canUndo)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextButton.icon(
                    onPressed: () => ref.read(reviewStateProvider.notifier).undoSwipe(),
                    icon: const Icon(Icons.undo, color: Colors.white54),
                    label: const Text(
                      'Undo',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                ),
              // Continue button - friendly label
              ElevatedButton(
                onPressed: () => ref.read(reviewStateProvider.notifier).nextCard(),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                ),
                child: const Text('Next photo'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteState(BuildContext context, WidgetRef ref) {
    final reviewState = ref.watch(reviewStateProvider);
    final remaining = reviewState.remainingDueCount;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.celebration,
            size: 80,
            color: Colors.amber.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 24),
          const Text(
            "Great job! You're done!",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${reviewState.sessionCount} photos reviewed',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),

          // Show Continue button if there are more cards
          if (remaining > 0) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(reviewStateProvider.notifier).loadMore();
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  backgroundColor: const Color(0xFF8b7cf6),
                ),
                icon: const Icon(Icons.add_circle_outline, size: 22),
                label: Text('Continue with $remaining more photos'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Done for today',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ),
          ] else ...[
            // All caught up - just show Finish button
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  backgroundColor: const Color(0xFF8b7cf6),
                ),
                icon: const Icon(Icons.check),
                label: const Text('All done'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "🎉 You're all caught up!",
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handleSwipe(WidgetRef ref, bool remembered) {
    ref.read(reviewStateProvider.notifier).swipeCard(remembered);
  }
}
