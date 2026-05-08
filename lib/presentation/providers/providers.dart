import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/gemini_service.dart';
import '../../data/services/hive_service.dart';
import '../../data/models/user_model.dart';
import '../../data/models/vocabulary_model.dart';
import '../../data/models/calendar_model.dart';

// ============= Service Providers =============

/// Hive Service Provider
final hiveServiceProvider = Provider<HiveService>((ref) {
  return HiveService();
});

/// Gemini Service Provider
final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

// ============= App Initialization Provider =============

/// App initialization state
class AppInitialization {
  final bool isInitialized;
  final String? error;

  const AppInitialization({
    required this.isInitialized,
    this.error,
  });

  static const uninitialized = AppInitialization(isInitialized: false);
  static AppInitialization get initialized => const AppInitialization(isInitialized: true);

  AppInitialization copyWith({bool? isInitialized, String? error}) {
    return AppInitialization(
      isInitialized: isInitialized ?? this.isInitialized,
      error: error ?? this.error,
    );
  }
}

/// App Initialization Provider
final appInitializationProvider = StateProvider<AppInitialization>((ref) {
  return AppInitialization.uninitialized;
});

/// Initialize App
Future<void> initializeApp(Ref ref) async {
  try {
    final hiveService = ref.read(hiveServiceProvider);
    await hiveService.initialize();

    ref.read(appInitializationProvider.notifier).state =
        AppInitialization.initialized;
  } catch (e) {
    ref.read(appInitializationProvider.notifier).state =
        AppInitialization(isInitialized: false, error: e.toString());
    rethrow;
  }
}

// ============= User Providers =============

/// Current User State
class UserState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  const UserState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  UserState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
  }) {
    return UserState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// User State Provider
final userStateProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  return UserNotifier(ref.read(hiveServiceProvider));
});

/// User State Notifier
class UserNotifier extends StateNotifier<UserState> {
  final HiveService _hiveService;

  UserNotifier(this._hiveService)
      : super(const UserState(isLoading: true)) {
    _waitForInitializationAndLoad();
  }

  Future<void> _waitForInitializationAndLoad() async {
    try {
      print('⏳ Waiting for Hive initialization...');

      // Wait for Hive to be initialized
      while (!_hiveService.isInitialized) {
        print('⏳ Hive not ready, waiting...');
        await Future.delayed(const Duration(milliseconds: 100));
      }

      print('✅ Hive initialized, loading user...');
      await _loadUser();
    } catch (e, stackTrace) {
      print('❌ Error waiting for initialization: $e');
      print('📚 Stack trace: $stackTrace');
      state = UserState(error: 'Initialization failed: ${e.toString()}');
    }
  }

  Future<void> _loadUser() async {
    try {
      print('🔍 Loading user...');
      final user = await _hiveService.getCurrentUser();
      print('✅ Loaded user: ${user?.displayNameOrEmail ?? "null"}');

      if (user != null) {
        state = UserState(user: user);
      } else {
        // Create guest user
        print('👤 Creating guest user...');
        final guestUser = UserModel.createGuest();
        await _hiveService.saveUser(guestUser);
        print('✅ Guest user saved: ${guestUser.displayNameOrEmail}');
        state = UserState(user: guestUser);
      }
    } catch (e, stackTrace) {
      print('❌ Error loading user: $e');
      print('📚 Stack trace: $stackTrace');
      state = UserState(error: e.toString());
    }
  }

  Future<void> updateUser(UserModel user) async {
    try {
      state = state.copyWith(isLoading: true);
      await _hiveService.saveUser(user);
      state = UserState(user: user);
    } catch (e) {
      state = UserState(user: state.user, error: e.toString());
    }
  }

  Future<void> logout() async {
    try {
      state = state.copyWith(isLoading: true);
      await _hiveService.clearCurrentUser();

      // Create new guest user
      final guestUser = UserModel.createGuest();
      await _hiveService.saveUser(guestUser);
      state = UserState(user: guestUser);
    } catch (e) {
      state = UserState(user: state.user, error: e.toString());
    }
  }

  Future<void> updateLastActive() async {
    final user = state.user;
    if (user == null) return;

    final updatedUser = user.updateLastActive();
    await updateUser(updatedUser);
  }

  Future<void> incrementWordsLearned() async {
    final user = state.user;
    if (user == null) return;

    final updatedUser = user.incrementWordsLearned();
    await updateUser(updatedUser);
  }

  Future<bool> recordQuotaUsage({String? imageId, String? vocabularyId}) async {
    final user = state.user;
    if (user == null) return false;

    // Check if user can generate
    if (!user.canGenerate) {
      return false;
    }

    // Record usage
    final updatedQuotaManager = user.quotaManager.recordUsage(
      imageId: imageId,
      vocabularyId: vocabularyId,
    );

    final updatedUser = user.copyWith(quotaManager: updatedQuotaManager);
    await updateUser(updatedUser);
    return true;
  }

  bool get canGenerate => state.user?.canGenerate ?? false;
}

// ============= Vocabulary Providers =============

/// Vocabulary List State
class VocabularyState {
  final List<VocabularyModel> vocabularies;
  final bool isLoading;
  final String? error;

  const VocabularyState({
    this.vocabularies = const [],
    this.isLoading = false,
    this.error,
  });

  VocabularyState copyWith({
    List<VocabularyModel>? vocabularies,
    bool? isLoading,
    String? error,
  }) {
    return VocabularyState(
      vocabularies: vocabularies ?? this.vocabularies,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  /// Get vocabulary count
  int get totalCount => vocabularies.length;

  /// Get words learned today
  int get wordsLearnedToday {
    final today = DateTime.now();
    return vocabularies.where((vocab) {
      return vocab.createdAt.year == today.year &&
          vocab.createdAt.month == today.month &&
          vocab.createdAt.day == today.day;
    }).length;
  }
}

/// Vocabulary State Provider
final vocabularyStateProvider =
    StateNotifierProvider<VocabularyNotifier, VocabularyState>((ref) {
  return VocabularyNotifier(ref.read(hiveServiceProvider));
});

/// Vocabulary State Notifier
class VocabularyNotifier extends StateNotifier<VocabularyState> {
  final HiveService _hiveService;

  VocabularyNotifier(this._hiveService)
      : super(const VocabularyState(isLoading: true)) {
    _waitForInitializationAndLoad();
  }

  Future<void> _waitForInitializationAndLoad() async {
    try {
      print('⏳ VocabularyNotifier: Waiting for Hive initialization...');

      // Wait for Hive to be initialized
      while (!_hiveService.isInitialized) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      print('✅ VocabularyNotifier: Hive initialized, loading vocabularies...');
      await _loadVocabularies();
    } catch (e) {
      print('❌ VocabularyNotifier: Initialization failed: $e');
      state = VocabularyState(error: 'Initialization failed: ${e.toString()}');
    }
  }

  Future<void> _loadVocabularies() async {
    try {
      final vocabularies = await _hiveService.getAllVocabulary();
      state = VocabularyState(vocabularies: vocabularies);
    } catch (e) {
      state = VocabularyState(error: e.toString());
    }
  }

  Future<void> addVocabulary(VocabularyModel vocabulary) async {
    try {
      await _hiveService.saveVocabulary(vocabulary);
      state = VocabularyState(
        vocabularies: [...state.vocabularies, vocabulary],
      );
    } catch (e) {
      state = VocabularyState(
        vocabularies: state.vocabularies,
        error: e.toString(),
      );
    }
  }

  Future<void> updateVocabulary(VocabularyModel vocabulary) async {
    try {
      await _hiveService.saveVocabulary(vocabulary);

      final updatedList = state.vocabularies.map((v) {
        return v.id == vocabulary.id ? vocabulary : v;
      }).toList();

      state = VocabularyState(vocabularies: updatedList);
    } catch (e) {
      state = VocabularyState(
        vocabularies: state.vocabularies,
        error: e.toString(),
      );
    }
  }

  Future<void> deleteVocabulary(String id) async {
    try {
      await _hiveService.deleteVocabulary(id);

      final updatedList = state.vocabularies.where((v) => v.id != id).toList();
      state = VocabularyState(vocabularies: updatedList);
    } catch (e) {
      state = VocabularyState(
        vocabularies: state.vocabularies,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _loadVocabularies();
  }
}

// ============= Utility Providers =============

/// Get current user (convenience provider)
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(userStateProvider).user;
});

/// Check if user can generate
final canGenerateProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.canGenerate ?? false;
});

/// Get quota status message
final quotaStatusProvider = Provider<String>((ref) {
  final userState = ref.watch(userStateProvider);

  if (userState.isLoading) {
    return 'Loading...';
  }

  if (userState.error != null) {
    return 'Error loading quota';
  }

  final user = userState.user;
  if (user == null) {
    return 'No user data';
  }

  return user.quotaManager.getStatusMessage();
});
