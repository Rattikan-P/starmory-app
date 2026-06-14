import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/auth_service.dart';
import '../../data/models/user_model.dart';
import 'providers.dart';
import 'streak_provider.dart';

/// Combined Auth + Quota State
class AuthQuotaState {
  final bool isLoggedIn;
  final UserModel? localUser;
  final bool isLoading;
  final String? error;

  const AuthQuotaState({
    required this.isLoggedIn,
    this.localUser,
    this.isLoading = false,
    this.error,
  });

  /// Check if user can generate (regardless of auth status)
  bool get canGenerate => localUser?.canGenerate ?? false;

  /// Check if user is guest
  bool get isGuest => localUser?.isGuest ?? true;

  /// Get remaining quota info
  String get quotaMessage {
    final user = localUser;
    if (user == null) return 'Loading...';

    final quota = user.quotaManager;
    final todayUsage = quota.getTodayUsage();
    final dailyLimit = quota.dailyLimit;
    final totalUsage = quota.usageHistory.length;
    final totalLimit = quota.totalLimit;

    if (isGuest) {
      return 'Guest: $todayUsage/$dailyLimit today • $totalUsage/$totalLimit total';
    } else {
      return '$todayUsage/$dailyLimit today';
    }
  }

  /// Check if quota is exhausted
  bool get isQuotaExhausted => !canGenerate;

  AuthQuotaState copyWith({
    bool? isLoggedIn,
    UserModel? localUser,
    bool? isLoading,
    String? error,
  }) {
    return AuthQuotaState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      localUser: localUser ?? this.localUser,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Provider for combined auth + quota state
final authQuotaProvider = StateNotifierProvider<AuthQuotaNotifier, AuthQuotaState>((ref) {
  return AuthQuotaNotifier(ref);
});

/// Notifier for auth + quota state
class AuthQuotaNotifier extends StateNotifier<AuthQuotaState> {
  final Ref _ref;

  // Listen to Supabase auth changes
  late final StreamSubscription<AuthState> _authSubscription;

  AuthService get _authService => AuthService();

  AuthQuotaNotifier(this._ref)
      : super(const AuthQuotaState(
              isLoggedIn: false,
              isLoading: true,
            )) {
    _initialize();
  }

  Future<void> _initialize() async {
    // Check current auth state
    final isLoggedIn = _authService.isLoggedIn;

    // Listen to auth changes
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        _handleAuthChange(data.event);
      },
    );

    // Set initial state
    state = state.copyWith(isLoggedIn: isLoggedIn);

    // Sync with local user
    await _syncLocalUser();
  }

  void _handleAuthChange(AuthChangeEvent event) {
    switch (event) {
      case AuthChangeEvent.signedIn:
        state = state.copyWith(isLoggedIn: true);
        _syncLocalUser();
        // ⭐ CRITICAL: Refresh streak data after login to load cloud data
        _refreshStreak();
        break;
      case AuthChangeEvent.signedOut:
        state = state.copyWith(isLoggedIn: false);
        _createGuestUser();
        break;
      case AuthChangeEvent.userUpdated:
        _syncLocalUser();
        break;
      default:
        break;
    }
  }

  /// Refresh streak data after auth state changes
  void _refreshStreak() {
    try {
      final streakNotifier = _ref.read(streakProvider.notifier);
      streakNotifier.refresh();
    } catch (e) {
      // Ignore if refresh fails
    }
  }

  Future<void> _syncLocalUser() async {
    try {
      final userNotifier = _ref.read(userStateProvider.notifier);
      final localUser = _ref.read(userStateProvider).user;

      if (state.isLoggedIn && localUser?.isGuest == true) {
        // User just logged in - convert guest to registered user
        final supabaseUser = _authService.currentUserId;
        if (supabaseUser != null) {
          final registeredUser = UserModel.createRegisteredUser(
            id: supabaseUser,
            email: Supabase.instance.client.auth.currentSession?.user.email ??
                'user@example.com',
          );

          // Preserve guest quota history if needed
          final updatedUser = registeredUser.copyWith(
            quotaManager: registeredUser.quotaManager,
          );

          await userNotifier.updateUser(updatedUser);
          state = state.copyWith(localUser: updatedUser);
        }
      } else if (!state.isLoggedIn) {
        // Not logged in - check if we need to create guest user
        if (localUser == null || localUser.isGuest == false) {
          // No user or logged out from registered account - create guest user
          await _createGuestUser();
        } else {
          // Guest user already exists - just update reference
          state = state.copyWith(localUser: localUser);
        }
      } else {
        // Logged in with registered user - update reference
        state = state.copyWith(localUser: localUser);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> _createGuestUser() async {
    try {
      final userNotifier = _ref.read(userStateProvider.notifier);

      // ⭐ OPTIMIZATION: Check if guest user already exists before calling logout()
      // This prevents unnecessary user creation during race conditions
      final existingUser = _ref.read(userStateProvider).user;
      if (existingUser != null && existingUser.isGuest) {
        // Guest already exists - just use it
        state = state.copyWith(localUser: existingUser);
        return;
      }

      // No guest user exists - create one via logout
      await userNotifier.logout(); // This creates guest user
      final guestUser = _ref.read(userStateProvider).user;
      state = state.copyWith(localUser: guestUser);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Record quota usage for AI generation
  Future<bool> recordQuotaUsage({
    String? imageId,
    String? vocabularyId,
  }) async {
    final userNotifier = _ref.read(userStateProvider.notifier);
    final success = await userNotifier.recordQuotaUsage(
      imageId: imageId,
      vocabularyId: vocabularyId,
    );

    // Update local user reference
    final updatedUser = _ref.read(userStateProvider).user;
    state = state.copyWith(localUser: updatedUser);

    return success;
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}

/// Convenience provider for checking if user can generate
final canGenerateProvider = Provider<bool>((ref) {
  return ref.watch(authQuotaProvider).canGenerate;
});

/// Convenience provider for quota message
final quotaMessageProvider = Provider<String>((ref) {
  return ref.watch(authQuotaProvider).quotaMessage;
});

/// Convenience provider for checking if user is guest
final isGuestProvider = Provider<bool>((ref) {
  return ref.watch(authQuotaProvider).isGuest;
});
