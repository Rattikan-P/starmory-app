import 'package:fsrs/fsrs.dart';
import '../../data/models/word_card_model.dart';

/// FSRS (Free Spaced Repetition Scheduler) Helper
/// Uses official FSRS package for spaced repetition algorithm
class FsrSHelper {
  /// FSRS scheduler with default parameters
  /// - desiredRetention: 0.9 (90% memory retention)
  /// - learningSteps: [1min, 10min] for new cards
  /// - relearningSteps: [10min] for forgot cards
  static Scheduler scheduler = Scheduler(
    desiredRetention: 0.9,
    learningSteps: [
      Duration(minutes: 1),
      Duration(minutes: 10),
    ],
    relearningSteps: [
      Duration(minutes: 10),
    ],
  );

  /// Map swipe gesture to FSRS rating
  /// - Swipe Left (Forgot) -> Rating.again
  /// - Swipe Right (Recalled) -> Rating.good
  static Rating getRatingFromSwipe(bool remembered) {
    return remembered ? Rating.good : Rating.again;
  }

  /// Create FSRS Card from WordCardModel
  static Card _createFsrsCard(WordCardModel model) {
    // Parse card ID as integer
    int cardId;
    try {
      cardId = int.parse(model.id.split('_').last);
    } catch (_) {
      cardId = DateTime.now().millisecondsSinceEpoch;
    }

    return Card(
      cardId: cardId,
      state: _mapCardState(model.state),
      due: model.dueDate.toUtc(),
      stability: model.stability == 0 ? null : model.stability,
      difficulty: model.difficulty == 0 ? null : model.difficulty,
      lastReview: model.lastReview?.toUtc(),
    );
  }

  /// Map our CardState to FSRS State
  /// Note: FSRS doesn't have "New" state, so we map newCard to Learning
  static State _mapCardState(CardState state) {
    switch (state) {
      case CardState.newCard:
        return State.learning;
      case CardState.learning:
        return State.learning;
      case CardState.review:
        return State.review;
      case CardState.relearning:
        return State.relearning;
    }
  }

  /// Map FSRS State to our CardState
  static CardState _mapFsrsStateToCardState(State state) {
    switch (state) {
      case State.learning:
        return CardState.learning;
      case State.review:
        return CardState.review;
      case State.relearning:
        return CardState.relearning;
    }
  }

  /// Review a card and return updated WordCardModel
  /// This is the main entry point for processing a review
  static Future<WordCardModel> reviewCard(WordCardModel card, bool remembered) async {
    // Get rating from swipe
    final rating = getRatingFromSwipe(remembered);

    // Create FSRS card from model
    final fsrsCard = _createFsrsCard(card);

    // Review with FSRS - this returns a record with (card, reviewLog)
    final result = scheduler.reviewCard(fsrsCard, rating);

    final now = DateTime.now();

    // 🧠 DEBUG: Print FSRS calculation values
    final minutesUntilDue = result.card.due.difference(now).inMinutes;
    print('🧠 FSRS Package Calculation:');
    print('   Input: rating=$rating, state=${fsrsCard.state}');
    print('   Before: stability=${fsrsCard.stability?.toStringAsFixed(2) ?? 'null'}, difficulty=${fsrsCard.difficulty?.toStringAsFixed(2) ?? 'null'}');
    print('   After: stability=${result.card.stability?.toStringAsFixed(2) ?? 'null'}, difficulty=${result.card.difficulty?.toStringAsFixed(2) ?? 'null'}');
    print('   Next due: ${result.card.due.toLocal()} ($minutesUntilDue min from now)');
    print('   State: ${fsrsCard.state} → ${result.card.state}');
    print('   ---');

    // Update card with new values from FSRS
    // Increment reps, and lapses if rating is Again
    return card.copyWith(
      state: _mapFsrsStateToCardState(result.card.state),
      stability: result.card.stability ?? 0,
      difficulty: result.card.difficulty ?? 0,
      dueDate: result.card.due.toLocal(),
      lastReview: now,
      reps: card.reps + 1,
      lapses: rating == Rating.again ? card.lapses + 1 : card.lapses,
      updatedAt: now,
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
