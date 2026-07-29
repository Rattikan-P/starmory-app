import 'package:fsrs/fsrs.dart' as fsrs;
import '../../data/models/word_card_model.dart';

/// FSRS (Free Spaced Repetition Scheduler) Helper
/// Wraps FSRS algorithm for spaced repetition review system
class FsrSHelper {
  /// FSRS scheduler instance with default parameters
  static fsrs.Scheduler scheduler = fsrs.Scheduler();

  /// Map swipe gesture to FSRS rating
  /// - Swipe Left (Forgot) -> Rating.again
  /// - Swipe Right (Recalled) -> Rating.good
  static fsrs.Rating getRatingFromSwipe(bool remembered) {
    return remembered ? fsrs.Rating.good : fsrs.Rating.again;
  }

  /// Create FSRS Card from WordCardModel
  static fsrs.Card createCardFromModel(WordCardModel model) {
    return fsrs.Card(
      cardId: DateTime.now().millisecondsSinceEpoch,
      state: _mapCardStateToFsrs(model.state),
      due: model.dueDate.toUtc(),
      stability: model.stability == 0 ? null : model.stability,
      difficulty: model.difficulty == 0 ? null : model.difficulty,
      lastReview: model.lastReview?.toUtc(),
    );
  }

  /// Map our CardState to FSRS State
  static fsrs.State _mapCardStateToFsrs(CardState state) {
    switch (state) {
      case CardState.newCard:
        // New cards start in learning state
        return fsrs.State.learning;
      case CardState.learning:
        return fsrs.State.learning;
      case CardState.review:
        return fsrs.State.review;
      case CardState.relearning:
        return fsrs.State.relearning;
    }
  }

  /// Map FSRS State to our CardState
  static CardState _mapFsrsStateToCardState(fsrs.State state) {
    switch (state) {
      case fsrs.State.learning:
        return CardState.learning;
      case fsrs.State.review:
        return CardState.review;
      case fsrs.State.relearning:
        return CardState.relearning;
    }
  }

  /// Review a card and return updated WordCardModel
  /// This is the main entry point for processing a review
  static Future<WordCardModel> reviewCard(WordCardModel card, bool remembered) async {
    // Get rating from swipe
    final rating = getRatingFromSwipe(remembered);

    // Create FSRS card from model
    final fsrsCard = createCardFromModel(card);

    // Review with FSRS
    final result = scheduler.reviewCard(fsrsCard, rating);

    // 🧠 DEBUG: Print FSRS calculation values
    final now = DateTime.now();
    final minutesUntilDue = result.card.due.difference(now).inMinutes;
    print('🧠 FSRS Calculation:');
    print('   Input: rating=$rating, state=${fsrsCard.state}');
    print('   Before: stability=${fsrsCard.stability?.toStringAsFixed(2) ?? '0.0'}, difficulty=${fsrsCard.difficulty?.toStringAsFixed(2) ?? '0.0'}');
    print('   After: stability=${result.card.stability?.toStringAsFixed(2) ?? '0.0'}, difficulty=${result.card.difficulty?.toStringAsFixed(2) ?? '0.0'}');
    print('   Next due: ${result.card.due.toLocal()} ($minutesUntilDue min from now)');
    print('   ---');

    // Update card with new values
    return card.copyWith(
      state: _mapFsrsStateToCardState(result.card.state),
      stability: result.card.stability ?? 0,
      difficulty: result.card.difficulty ?? 0,
      dueDate: result.card.due.toLocal(),
      lastReview: DateTime.now(),
      reps: result.card.step ?? 0,
      lapses: 0, // FSRS doesn't track lapses directly
      updatedAt: DateTime.now(),
    );
  }

  /// Get time until next review (human-readable)
  static String getNextReviewText(WordCardModel card) {
    final now = DateTime.now();
    final diff = card.dueDate.difference(now);

    if (diff.isNegative) {
      return 'Due now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hr';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} day${diff.inDays > 1 ? "s" : ""}';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()} week${(diff.inDays / 7).floor() > 1 ? "s" : ""}';
    } else {
      return '${(diff.inDays / 30).floor()} month${(diff.inDays / 30).floor() > 1 ? "s" : ""}';
    }
  }

  /// Calculate retention rate for a list of cards
  static double calculateRetention(List<WordCardModel> cards) {
    if (cards.isEmpty) return 0.0;

    // Simple retention calculation based on difficulty
    // Lower difficulty = higher retention
    final totalDifficulty = cards.fold<double>(
      0.0,
      (sum, card) => sum + card.difficulty,
    );

    final avgDifficulty = totalDifficulty / cards.length;
    // Map difficulty (0-10) to retention (0-1)
    return (10 - avgDifficulty) / 10;
  }
}
