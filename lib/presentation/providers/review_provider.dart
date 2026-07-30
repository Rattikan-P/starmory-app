import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/word_card_model.dart';
import '../../data/services/review_service.dart';
import '../../data/services/hive_service.dart';
import '../../core/utils/fsrs_helper.dart';
import 'providers.dart';

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
      : super(const ReviewState(isLoading: true)) {
    loadSession();
  }

  /// Load review session (due cards + new cards to fill 5)
  Future<void> loadSession() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final sessionCards = await _reviewService.getReviewSession();

      // Check if there are more due cards remaining
      final remainingDue = await _reviewService.getRemainingDueCount();

      state = ReviewState(
        cards: sessionCards,
        currentIndex: 0,
        isLoading: false,
        sessionCount: sessionCards.length,
        remainingDueCount: remainingDue,
        reviewedCardIds: {}, // Clear reviewed cards on new session
      );
    } catch (e) {
      state = ReviewState(
        isLoading: false,
        error: e.toString(),
        reviewedCardIds: {},
      );
    }
  }

  /// Load more cards (when user clicks Continue)
  Future<void> loadMore() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      // Get more cards, excluding already reviewed ones
      final moreCards = await _reviewService.getMoreCards(
        excludeIds: state.reviewedCardIds.toList(),
      );

      if (moreCards.isEmpty) {
        // No more cards
        state = state.copyWith(isLoading: false, remainingDueCount: 0);
        return;
      }

      // Add to current session
      final currentCards = List<WordCardModel>.from(state.cards);
      currentCards.addAll(moreCards);

      // Update remaining count
      final remainingDue = await _reviewService.getRemainingDueCount();

      state = ReviewState(
        cards: currentCards,
        currentIndex: state.currentIndex, // Keep current position
        isLoading: false,
        sessionCount: currentCards.length,
        remainingDueCount: remainingDue,
        reviewedCardIds: state.reviewedCardIds, // Keep tracking
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
      // Update card with FSRS
      final updatedCard = await FsrSHelper.reviewCard(currentCard, remembered);

      // Save to storage
      await _reviewService.updateCard(updatedCard);

      // Add card ID to reviewed set
      final newReviewedIds = Set<String>.from(state.reviewedCardIds);
      newReviewedIds.add(currentCard.id);

      // Show feedback first
      state = state.copyWith(
        showFeedback: true,
        lastRating: remembered,
        reviewedCardIds: newReviewedIds,
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
      );
    } else {
      // Move directly to next card
      state = state.copyWith(
        currentIndex: state.currentIndex + 1,
      );
    }
  }

  /// End session and reload
  Future<void> endSession() async {
    await loadSession();
  }

  /// Skip current card
  void skipCard() {
    if (state.currentIndex < state.cards.length - 1) {
      state = state.copyWith(
        currentIndex: state.currentIndex + 1,
      );
    }
  }
}
