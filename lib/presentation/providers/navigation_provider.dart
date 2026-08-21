import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Navigation State for main tab navigation
class NavigationState {
  final int currentIndex;
  final int homeScrollToTopTrigger;
  final int reviewScrollToTopTrigger;
  final int scrapbookScrollToTopTrigger;
  final int progressScrollToTopTrigger;

  const NavigationState({
    this.currentIndex = 0,
    this.homeScrollToTopTrigger = 0,
    this.reviewScrollToTopTrigger = 0,
    this.scrapbookScrollToTopTrigger = 0,
    this.progressScrollToTopTrigger = 0,
  });

  NavigationState copyWith({
    int? currentIndex,
    int? homeScrollToTopTrigger,
    int? reviewScrollToTopTrigger,
    int? scrapbookScrollToTopTrigger,
    int? progressScrollToTopTrigger,
  }) {
    return NavigationState(
      currentIndex: currentIndex ?? this.currentIndex,
      homeScrollToTopTrigger:
          homeScrollToTopTrigger ?? this.homeScrollToTopTrigger,
      reviewScrollToTopTrigger:
          reviewScrollToTopTrigger ?? this.reviewScrollToTopTrigger,
      scrapbookScrollToTopTrigger:
          scrapbookScrollToTopTrigger ?? this.scrapbookScrollToTopTrigger,
      progressScrollToTopTrigger:
          progressScrollToTopTrigger ?? this.progressScrollToTopTrigger,
    );
  }
}

/// Navigation State Provider
/// Use this to change tabs from anywhere in the app
final navigationProvider = StateNotifierProvider<NavigationNotifier, NavigationState>((ref) {
  return NavigationNotifier();
});

/// Navigation Notifier
class NavigationNotifier extends StateNotifier<NavigationState> {
  NavigationNotifier() : super(const NavigationState());

  /// Navigate to a specific tab index
  /// 0: Home, 1: Review, 2: Scrapbook, 3: Progress
  void setIndex(int index) {
    if (index >= 0 && index <= 3) {
      switch (index) {
        case 0:
          state = state.copyWith(
            currentIndex: 0,
            homeScrollToTopTrigger: state.homeScrollToTopTrigger + 1,
          );
          break;
        case 1:
          state = state.copyWith(
            currentIndex: 1,
            reviewScrollToTopTrigger: state.reviewScrollToTopTrigger + 1,
          );
          break;
        case 2:
          state = state.copyWith(
            currentIndex: 2,
            scrapbookScrollToTopTrigger: state.scrapbookScrollToTopTrigger + 1,
          );
          break;
        case 3:
          state = state.copyWith(
            currentIndex: 3,
            progressScrollToTopTrigger: state.progressScrollToTopTrigger + 1,
          );
          break;
      }
    }
  }

  /// Navigate to Home tab
  void goHome() => setIndex(0);

  /// Navigate to Review tab
  void goReview() => setIndex(1);

  /// Navigate to Scrapbook tab
  void goScrapbook() => setIndex(2);

  /// Navigate to Progress tab
  void goProgress() => setIndex(3);
}
