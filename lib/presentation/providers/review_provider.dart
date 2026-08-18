import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/word_card_model.dart';
import '../../data/services/review_service.dart';
import '../../core/utils/fsrs_helper.dart';
import 'providers.dart';

// Flag to track if streak has been updated in current session
bool _hasUpdatedStreakThisSession = false;

// ============= Review State Providers =============

/// Review Session State
class ReviewState {
  final List<WordCardModel> cards;
  final int currentIndex;
  final bool isLoading;
  final String? error;
  final int sessionCount;
  final bool showFeedback;
  final bool? lastRating; // true = remembered, false = forgot
  final int remainingDueCount; // Number of due cards remaining (for Continue button)
  final Set<String> reviewedCardIds; // Track cards already reviewed in this session
  final DateTime? sessionStartTime; // Track when review session started
  final int totalReviewsCompleted; // Total number of reviews completed by user
  final double averageTimePerCard; // Average seconds per card (from historical data)
  final bool canUndo; // Whether undo is available (for last swipe)
  final WordCardModel? previousCardState; // Card state before last swipe (for undo)
  final String? currentTopicFilter; // Current topic filter being applied

  const ReviewState({
    this.cards = const [],
    this.currentIndex = 0,
    this.isLoading = false,
    this.error,
    this.sessionCount = 0,
    this.showFeedback = false,
    this.lastRating,
    this.remainingDueCount = 0,
    this.reviewedCardIds = const {},
    this.sessionStartTime,
    this.totalReviewsCompleted = 0,
    this.averageTimePerCard = 7.0, // Default 7 seconds (FSRS team baseline)
    this.canUndo = false,
    this.previousCardState,
    this.currentTopicFilter,
  });

  ReviewState copyWith({
    List<WordCardModel>? cards,
    int? currentIndex,
    bool? isLoading,
    String? error,
    int? sessionCount,
    bool? showFeedback,
    bool? lastRating,
    int? remainingDueCount,
    Set<String>? reviewedCardIds,
    DateTime? sessionStartTime,
    int? totalReviewsCompleted,
    double? averageTimePerCard,
    bool? canUndo,
    WordCardModel? previousCardState,
    String? currentTopicFilter,
  }) {
    return ReviewState(
      cards: cards ?? this.cards,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      sessionCount: sessionCount ?? this.sessionCount,
      showFeedback: showFeedback ?? this.showFeedback,
      lastRating: lastRating ?? this.lastRating,
      remainingDueCount: remainingDueCount ?? this.remainingDueCount,
      reviewedCardIds: reviewedCardIds ?? this.reviewedCardIds,
      sessionStartTime: sessionStartTime ?? this.sessionStartTime,
      totalReviewsCompleted: totalReviewsCompleted ?? this.totalReviewsCompleted,
      averageTimePerCard: averageTimePerCard ?? this.averageTimePerCard,
      canUndo: canUndo ?? this.canUndo,
      previousCardState: previousCardState ?? this.previousCardState,
      currentTopicFilter: currentTopicFilter ?? this.currentTopicFilter,
    );
  }

  /// Get current card (null if out of bounds)
  WordCardModel? get currentCard {
    if (currentIndex >= 0 && currentIndex < cards.length) {
      return cards[currentIndex];
    }
    return null;
  }

  /// Check if session is complete
  bool get isComplete => currentIndex >= cards.length;

  /// Get remaining cards count
  int get remainingCards => cards.length - currentIndex;

  /// Get progress (0.0 to 1.0)
  double get progress {
    if (cards.isEmpty) return 0.0;
    return currentIndex / cards.length;
  }
}

/// Review Service Provider
final reviewServiceProvider = Provider<ReviewService>((ref) {
  return ReviewService(
    hiveService: ref.watch(hiveServiceProvider),
  );
});

/// Review State Provider
final reviewStateProvider =
    StateNotifierProvider<ReviewNotifier, ReviewState>((ref) {
  return ReviewNotifier(
    ref.watch(reviewServiceProvider),
  );
});

/// Review State Notifier
class ReviewNotifier extends StateNotifier<ReviewState> {
  final ReviewService _reviewService;

  ReviewNotifier(this._reviewService)
      : super(const ReviewState(isLoading: true));

  /// Load review session (due cards + new cards to fill batchSize)
  /// Optionally filter by topic
  Future<void> loadSession({String? topicFilter, int batchSize = 5}) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final sessionCards = await _reviewService.getReviewSession(
        topicFilter: topicFilter, 
        batchSize: batchSize
      );
      
      // Check if there are more due cards remaining (with same topic filter)
      final remainingDue = await _reviewService.getRemainingDueCount(topicFilter: topicFilter);

      // Load user stats for adaptive time estimation
      final userStats = await _reviewService.hiveService.getUserStats();

      // Reset streak update flag for new session
      _hasUpdatedStreakThisSession = false;

      state = ReviewState(
        cards: sessionCards,
        currentIndex: 0,
        isLoading: false,
        sessionCount: sessionCards.length,
        remainingDueCount: remainingDue,
        reviewedCardIds: {}, // Clear reviewed cards on new session
        sessionStartTime: DateTime.now(), // Track session start time
        totalReviewsCompleted: userStats?.totalReviewsCompleted ?? 0,
        averageTimePerCard: userStats?.averageTimePerCard ?? 7.0,
        canUndo: false,
        previousCardState: null,
        currentTopicFilter: topicFilter, // Save current topic filter
      );
    } catch (e) {
      state = ReviewState(
        isLoading: false,
        error: e.toString(),
        reviewedCardIds: {},
        canUndo: false,
        previousCardState: null,
        currentTopicFilter: topicFilter,
      );
    }
  }

  /// Load more cards (when user clicks Continue)
  Future<void> loadMore() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      // Get more cards, excluding already reviewed ones (with current topic filter)
      final moreCards = await _reviewService.getMoreCards(
        excludeIds: state.reviewedCardIds.toList(),
        topicFilter: state.currentTopicFilter,
      );

      if (moreCards.isEmpty) {
        // No more cards
        state = state.copyWith(isLoading: false, remainingDueCount: 0);
        return;
      }

      // Add to current session
      final currentCards = List<WordCardModel>.from(state.cards);
      currentCards.addAll(moreCards);

      // Update remaining count (with current topic filter)
      final remainingDue = await _reviewService.getRemainingDueCount(
        topicFilter: state.currentTopicFilter,
      );

      state = ReviewState(
        cards: currentCards,
        currentIndex: state.currentIndex, // Keep current position
        isLoading: false,
        sessionCount: currentCards.length,
        remainingDueCount: remainingDue,
        reviewedCardIds: state.reviewedCardIds, // Keep tracking
        canUndo: false,
        previousCardState: null,
        currentTopicFilter: state.currentTopicFilter, // Keep topic filter
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Swipe card and process rating
  /// [remembered] = true for swipe right (recalled), false for swipe left (forgot)
  Future<void> swipeCard(bool remembered) async {
    final currentCard = state.currentCard;
    if (currentCard == null) return;

    try {
      // Store previous card state for undo BEFORE updating
      final previousCard = currentCard;

      // Track time taken for this card
      final now = DateTime.now();
      final sessionStart = state.sessionStartTime ?? now;
      final elapsedSeconds = now.difference(sessionStart).inSeconds;

      // Update card with FSRS
      final updatedCard = await FsrSHelper.reviewCard(currentCard, remembered);

      // Save to storage
      await _reviewService.updateCard(updatedCard);

      // Update streak for first review of the day (guest mode)
      // For registered users, this is handled by database trigger
      if (!_hasUpdatedStreakThisSession) {
        final container = ProviderContainer();
        final streakNotifier = container.read(streakProvider.notifier);
        await streakNotifier.recordLearningActivity();
        _hasUpdatedStreakThisSession = true;
        container.dispose();
      }

      // Calculate new average time per card
      final totalReviews = state.totalReviewsCompleted + 1;
      final currentAvg = state.averageTimePerCard;
      final newAvg = ((currentAvg * state.totalReviewsCompleted) + elapsedSeconds) / totalReviews;

      // Add card ID to reviewed set
      final newReviewedIds = Set<String>.from(state.reviewedCardIds);
      newReviewedIds.add(currentCard.id);

      // Show feedback first and enable undo
      state = state.copyWith(
        showFeedback: true,
        lastRating: remembered,
        reviewedCardIds: newReviewedIds,
        totalReviewsCompleted: totalReviews,
        averageTimePerCard: newAvg,
        canUndo: true,
        previousCardState: previousCard,
      );

      // Save user stats to storage (Hive for guest, Supabase for registered)
      await _reviewService.saveUserStats(
        totalReviewsCompleted: totalReviews,
        averageTimePerCard: newAvg,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Undo the last swipe (restore card state and stats)
  Future<void> undoSwipe() async {
    if (!state.canUndo || state.previousCardState == null) return;

    try {
      // Restore previous card state
      final restoredCard = state.previousCardState!;

      // Save restored card to storage
      await _reviewService.updateCard(restoredCard);

      // Remove card from reviewed set
      final newReviewedIds = Set<String>.from(state.reviewedCardIds);
      newReviewedIds.remove(restoredCard.id);

      // Revert user stats (decrement totalReviews and restore average)
      final previousTotalReviews = state.totalReviewsCompleted - 1;
      final previousAvg = previousTotalReviews > 0
          ? state.averageTimePerCard // Keep previous average
          : 7.0; // Reset to default if no reviews

      // Update state with restored values
      state = state.copyWith(
        canUndo: false,
        previousCardState: null,
        reviewedCardIds: newReviewedIds,
        totalReviewsCompleted: previousTotalReviews > 0 ? previousTotalReviews : 0,
        averageTimePerCard: previousAvg,
        showFeedback: false,
        lastRating: null,
      );

      // Save restored user stats to storage
      await _reviewService.saveUserStats(
        totalReviewsCompleted: previousTotalReviews > 0 ? previousTotalReviews : 0,
        averageTimePerCard: previousAvg,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Move to next card after feedback
  void nextCard() {
    if (state.showFeedback) {
      // Hide feedback and move to next card
      state = state.copyWith(
        showFeedback: false,
        lastRating: null,
        currentIndex: state.currentIndex + 1,
        canUndo: false, // Disable undo after moving to next card
        previousCardState: null,
      );
    } else {
      // Move directly to next card
      state = state.copyWith(
        currentIndex: state.currentIndex + 1,
        canUndo: false, // Disable undo after moving to next card
        previousCardState: null,
      );
    }
  }

  /// End session and reload
  Future<void> endSession() async {
    await loadSession();
  }

}
