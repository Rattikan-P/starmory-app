import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/gemini_service.dart';
import '../../data/services/hive_service.dart';
import '../../data/services/preference_service.dart';
import '../../data/services/vocabulary_sync_service.dart';
import '../../data/services/image_storage_service.dart';
import '../../data/models/user_model.dart';
import '../../data/models/vocabulary_model.dart';
import '../../data/models/calendar_model.dart';
import '../../core/utils/quota_manager.dart';
import 'auth_quota_provider.dart';

// ============= Service Providers =============

/// Hive Service Provider
final hiveServiceProvider = Provider<HiveService>((ref) {
  return HiveService();
});

/// Image Storage Service Provider
final imageStorageServiceProvider = Provider<ImageStorageService>((ref) {
  return ImageStorageService();
});

/// Vocabulary Sync Service Provider
final vocabularySyncServiceProvider = Provider<VocabularySyncService>((ref) {
  final imageStorageService = ref.read(imageStorageServiceProvider);
  return VocabularySyncService(imageStorageService: imageStorageService);
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
  StreamSubscription<AuthState>? _authSubscription;

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

      // Listen to Supabase auth changes
      _listenToAuthChanges();
    } catch (e, stackTrace) {
      print('❌ Error waiting for initialization: $e');
      print('📚 Stack trace: $stackTrace');
      state = UserState(error: 'Initialization failed: ${e.toString()}');
    }
  }

  void _listenToAuthChanges() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        print('🔐 Auth state changed: ${data.event}');
        _handleAuthChange(data.event, data.session?.user);
      },
    );
  }

  Future<void> _handleAuthChange(AuthChangeEvent event, User? supabaseUser) async {
    switch (event) {
      case AuthChangeEvent.signedIn:
        print('✅ User signed in: ${supabaseUser?.email}');
        if (supabaseUser != null) {
          await _convertToRegisteredUser(supabaseUser);
        }
        break;

      case AuthChangeEvent.signedOut:
        print('👋 User signed out');
        await logout();
        break;

      case AuthChangeEvent.userUpdated:
        print('🔄 User updated');
        // Refresh user data if needed
        break;

      default:
        break;
    }
  }

  Future<void> _convertToRegisteredUser(User supabaseUser) async {
    try {
      // Get current user from Hive
      final currentUser = await _hiveService.getCurrentUser();

      // Fetch quota from Supabase using auto-reset function
      final client = Supabase.instance.client;
      final today = DateTime.now().toIso8601String().split('T')[0];

      // Use RPC function that auto-resets if new day
      final quotaResponse = await client
          .rpc('get_user_quota_with_reset', params: {'p_user_id': supabaseUser.id})
          .maybeSingle();

      QuotaManager quotaManager;
      if (quotaResponse == null) {
        // Create new quota record
        await client.from('user_quotas').insert({
          'user_id': supabaseUser.id,
          'daily_gen_count': 0,
          'daily_gen_reset_date': today,
          'total_gen_count': 0,
        });
        quotaManager = QuotaManager.registeredUser();
        print('📝 Created new quota record for user');
      } else {
        // Load existing quota (already auto-reset by RPC if needed)
        final dailyCount = quotaResponse['daily_gen_count'] as int? ?? 0;
        final totalCount = quotaResponse['total_gen_count'] as int? ?? 0;

        // Build usage history from total count
        final usageHistory = List<QuotaEntry>.generate(
          totalCount,
          (_) => QuotaEntry(timestamp: DateTime.now()),
        );

        quotaManager = QuotaManager(
          totalLimit: 999999,
          dailyLimit: 15,
          usageHistory: usageHistory,
        );
        print('📊 Loaded quota: daily=$dailyCount, total=$totalCount');
      }

      // Sync language_level and english_variant from Supabase user metadata
      final languageLevel = supabaseUser.userMetadata?['language_level'] as String?;
      final englishVariant = supabaseUser.userMetadata?['english_variant'] as String?;

      // Create registered user with synced quota and preferences
      final registeredUser = UserModel.createRegisteredUser(
        id: supabaseUser.id,
        email: supabaseUser.email ?? 'user@example.com',
        displayName: supabaseUser.userMetadata?['display_name'] as String?,
        photoUrl: supabaseUser.userMetadata?['avatar_url'] as String?,
      ).copyWith(
        quotaManager: quotaManager,
        preferences: {
          'defaultCefrLevel': languageLevel ?? 'A1',
          'languageVariant': englishVariant ?? 'US',
        },
      );

      await _hiveService.saveUser(registeredUser);
      state = UserState(user: registeredUser);
      print('✅ Registered user saved: ${registeredUser.displayNameOrEmail}');
      print('📊 Quota: ${quotaManager.getTodayUsage()}/${quotaManager.dailyLimit} today');
    } catch (e, stackTrace) {
      print('❌ Error converting to registered user: $e');
      print('📚 Stack trace: $stackTrace');
      // Fallback: create user with default quota and preferences
      final languageLevel = supabaseUser.userMetadata?['language_level'] as String?;
      final englishVariant = supabaseUser.userMetadata?['english_variant'] as String?;

      final registeredUser = UserModel.createRegisteredUser(
        id: supabaseUser.id,
        email: supabaseUser.email ?? 'user@example.com',
        displayName: supabaseUser.userMetadata?['display_name'] as String?,
        photoUrl: supabaseUser.userMetadata?['avatar_url'] as String?,
      ).copyWith(
        preferences: {
          'defaultCefrLevel': languageLevel ?? 'A1',
          'languageVariant': englishVariant ?? 'US',
        },
      );
      await _hiveService.saveUser(registeredUser);
      state = UserState(user: registeredUser);
    }
  }

  Future<void> _loadUser() async {
    try {
      print('🔍 Loading user...');
      final user = await _hiveService.getCurrentUser();
      print('✅ Loaded user: ${user?.displayNameOrEmail ?? "null"}');

      if (user != null) {
        // Check if auth state matches
        final supabaseSession = Supabase.instance.client.auth.currentSession;
        if (supabaseSession != null && user.isGuest) {
          // User is logged in but local user is guest - convert
          print('🔄 User logged in but local is guest, converting...');
          await _convertToRegisteredUser(supabaseSession.user);
        } else if (supabaseSession == null && !user.isGuest) {
          // User logged out but local is registered - create guest
          print('🔄 User logged out but local is registered, creating guest...');
          await logout();
        } else {
          state = UserState(user: user);
        }
      } else {
        // Check if user is logged in to Supabase
        final supabaseSession = Supabase.instance.client.auth.currentSession;
        if (supabaseSession != null) {
          // User logged in but no local user - create registered
          print('🔄 No local user but logged in, creating registered...');
          await _convertToRegisteredUser(supabaseSession.user);
        } else {
          // Create guest user
          print('👤 Creating guest user...');
          final guestUser = await _createGuestUserWithPreferences();
          await _hiveService.saveUser(guestUser);
          print('✅ Guest user saved: ${guestUser.displayNameOrEmail}');
          state = UserState(user: guestUser);
        }
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

      // Create new guest user with preferences from SharedPreferences
      final guestUser = await _createGuestUserWithPreferences();
      await _hiveService.saveUser(guestUser);
      state = UserState(user: guestUser);
    } catch (e) {
      state = UserState(user: state.user, error: e.toString());
    }
  }

  /// Create guest user with preferences loaded from SharedPreferences
  Future<UserModel> _createGuestUserWithPreferences() async {
    final preferenceService = PreferenceService();
    await preferenceService.init();

    // Load guest preferences
    final guestLanguageLevel = await preferenceService.getLanguageLevel();
    final guestEnglishVariant = await preferenceService.getEnglishVariant();

    print('👤 Loading guest preferences: languageLevel=$guestLanguageLevel, englishVariant=$guestEnglishVariant');

    // Create guest user with loaded preferences
    final guestUser = UserModel.createGuest().copyWith(
      preferences: {
        'defaultCefrLevel': guestLanguageLevel ?? 'A1',
        'languageVariant': guestEnglishVariant ?? 'US',
      },
    );

    return guestUser;
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

    debugPrint('🔢 recordQuotaUsage called - current daily: ${user.quotaManager.getTodayUsage()}/${user.quotaManager.dailyLimit}');

    // Check if user can generate
    if (!user.canGenerate) {
      debugPrint('❌ Cannot generate - quota exhausted');
      return false;
    }

    // Sync to Supabase if registered user
    if (!user.isGuest) {
      try {
        final client = Supabase.instance.client;
        final supabaseUser = client.auth.currentUser;
        if (supabaseUser != null) {
          final today = DateTime.now().toIso8601String().split('T')[0];

          // Get current quota from Supabase
          final quotaResponse = await client
              .from('user_quotas')
              .select()
              .eq('user_id', supabaseUser.id)
              .maybeSingle();

          if (quotaResponse != null) {
            final lastReset = quotaResponse['daily_gen_reset_date'] as String?;
            final dailyCount = quotaResponse['daily_gen_count'] as int? ?? 0;
            final totalCount = quotaResponse['total_gen_count'] as int? ?? 0;

            // Check if needs reset
            int newDailyCount = (lastReset == today) ? dailyCount + 1 : 1;

            // Update Supabase
            await client
                .from('user_quotas')
                .update({
                  'daily_gen_count': newDailyCount,
                  'daily_gen_reset_date': today,
                  'total_gen_count': totalCount + 1,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('user_id', supabaseUser.id);

            print('✅ Synced quota to Supabase: daily=$newDailyCount, total=${totalCount + 1}');
          }
        }
      } catch (e) {
        print('⚠️ Failed to sync quota to Supabase: $e');
        // Continue anyway - local update is more important
      }
    }

    // Record usage locally
    final updatedQuotaManager = user.quotaManager.recordUsage(
      imageId: imageId,
      vocabularyId: vocabularyId,
    );

    final updatedUser = user.copyWith(quotaManager: updatedQuotaManager);
    await updateUser(updatedUser);

    debugPrint('✅ recordQuotaUsage completed - new daily: ${updatedQuotaManager.getTodayUsage()}/${updatedQuotaManager.dailyLimit}');
    return true;
  }

  bool get canGenerate => state.user?.canGenerate ?? false;

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
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
  return VocabularyNotifier(
    ref.read(hiveServiceProvider),
    ref.read(vocabularySyncServiceProvider),
  );
});

/// Vocabulary State Notifier
class VocabularyNotifier extends StateNotifier<VocabularyState> {
  final HiveService _hiveService;
  final VocabularySyncService _syncService;

  VocabularyNotifier(this._hiveService, this._syncService)
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
      // Always save to local storage
      await _hiveService.saveVocabulary(vocabulary);

      // Sync to cloud if registered user
      if (_syncService.isLoggedIn) {
        await _syncService.saveToCloud(vocabulary);
        print('✅ Vocabulary synced to cloud: ${vocabulary.word}');
      }

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
      // Always update local storage
      await _hiveService.saveVocabulary(vocabulary);

      // Sync to cloud if registered user
      if (_syncService.isLoggedIn) {
        await _syncService.updateInCloud(vocabulary);
        print('✅ Vocabulary updated in cloud: ${vocabulary.word}');
      }

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
      // Always delete from local storage
      await _hiveService.deleteVocabulary(id);

      // Delete from cloud if registered user
      if (_syncService.isLoggedIn) {
        await _syncService.deleteFromCloud(id);
        print('✅ Vocabulary deleted from cloud: $id');
      }

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
