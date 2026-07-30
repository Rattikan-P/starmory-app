import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/review_provider.dart';
import '../widgets/review_card_widget.dart';
import '../widgets/galaxy_screen_background.dart';

/// Review Session Page
/// Main review interface with swipe cards and feedback
class ReviewSessionPage extends ConsumerWidget {
  const ReviewSessionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewState = ref.watch(reviewStateProvider);

    return GalaxyScreenBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Review Session'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            if (!reviewState.isLoading && reviewState.cards.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    '${reviewState.currentIndex + 1}/${reviewState.sessionCount}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
            'All caught up!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No cards due for review right now.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.home),
            label: const Text('Back to Review'),
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
            ),
          ),
        ),
        // Instructions
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '← Swipe left if you forgot | Swipe right if you recalled →',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
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
              // Result icon
              Icon(
                remembered ? Icons.check_circle : Icons.cancel,
                size: 80,
                color: remembered ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 24),
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
              // Meaning
              Text(
                vocab.thaiTranslation,
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white70,
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
              // Continue button
              ElevatedButton(
                onPressed: () => ref.read(reviewStateProvider.notifier).nextCard(),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                ),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteState(BuildContext context, WidgetRef ref) {
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
            'Session Complete!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.check),
            label: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  void _handleSwipe(WidgetRef ref, bool remembered) {
    ref.read(reviewStateProvider.notifier).swipeCard(remembered);
  }
}
