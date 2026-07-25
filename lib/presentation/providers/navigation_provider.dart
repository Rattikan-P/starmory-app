import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Navigation State for main tab navigation
class NavigationState {
  final int currentIndex;

  const NavigationState({this.currentIndex = 0});

  NavigationState copyWith({int? currentIndex}) {
    return NavigationState(
      currentIndex: currentIndex ?? this.currentIndex,
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
      state = NavigationState(currentIndex: index);
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
