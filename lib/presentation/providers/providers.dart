import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/gemini_service.dart';
import '../../data/services/hive_service.dart';
import '../../data/services/vocabulary_sync_service.dart';
import '../../data/services/image_storage_service.dart';
import '../../data/services/merge_service.dart';
import '../../data/services/streak_service.dart';
import '../../data/models/user_model.dart';
import '../../data/models/vocabulary_model.dart';
import '../../data/models/calendar_model.dart';
import '../../core/utils/quota_manager.dart';
import '../../constants/app_defaults.dart';
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

/// Merge Service Provider
final mergeServiceProvider = Provider<MergeService>((ref) {
  return MergeService();
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
        print('🔄 User updated - refreshing preferences from Supabase');
        await _refreshUserFromSupabase();
        break;

      default:
        break;
    }
  }

  Future<void> _convertToRegisteredUser(User supabaseUser) async {
    try {
      // Get current user from Hive (might be guest or null)
      final currentUser = await _hiveService.getCurrentUser();
      final hasGuestData = currentUser?.isGuest ?? false;

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

      // Fetch existing user data from Supabase to preserve streak and progress
      Map<String, dynamic>? serverUserData;
      try {
        final client = Supabase.instance.client;
        final existingData = await client
            .from('users')
            .select()
            .eq('id', supabaseUser.id)
            .maybeSingle();
        serverUserData = existingData as Map<String, dynamic>?;

        if (serverUserData != null) {
          print('📥 Loaded existing data from server:');
          print('   - streak: ${serverUserData['current_streak']}');
          print('   - longest_streak: ${serverUserData['longest_streak']}');
        }
      } catch (e) {
        print('⚠️ Failed to fetch user data from server: $e');
      }

      // Use Merge Framework to merge guest data with server data
      UserModel registeredUser;
      if (hasGuestData) {
        // Guest → Registered: Use Merge Framework
        print('🔄 Migrating guest data to registered user...');

        // Read guest streak from local database (Hive) - this is the source of truth for guests
        final streakService = StreakService();
        final guestStreakData = await streakService.getStreakData();

        // Prepare guest data map
        final guestDataMap = <String, dynamic>{
          'currentStreak': guestStreakData?.currentStreak ?? 0,
          'longestStreak': guestStreakData?.longestStreak ?? 0,
          'lastStreakActivityDate': guestStreakData?.lastActivityDate?.toIso8601String(),
          'shields': currentUser!.shields,
          'totalWordsLearned': currentUser.totalWordsLearned,
          'badges': currentUser.badges,
          'stickers': currentUser.stickers,
          'preferences': currentUser.preferences,
        };

        // Use Merge Service
        final mergeService = MergeService();
        final mergeResult = await mergeService.mergeUserData(
          guestDataMap,
          serverUserData,
        );

        print('📊 Merge result: ${mergeResult.summary}');

        // Merge preferences with metadata
        final mergedPrefs = Map<String, dynamic>.from(
          mergeResult.mergedData['preferences'] as Map? ?? currentUser.preferences
        );
        if (languageLevel != null) mergedPrefs['defaultCefrLevel'] = languageLevel;
        if (englishVariant != null) mergedPrefs['languageVariant'] = englishVariant;

        // Parse last activity date
        DateTime? lastActivityDate;
        final lastActivityStr = mergeResult.mergedData['lastStreakActivityDate'] as String?;
        if (lastActivityStr != null) {
          lastActivityDate = DateTime.tryParse(lastActivityStr);
        }

        // Convert Set to List for badges/stickers if needed
        final badgesValue = mergeResult.mergedData['badges'];
        final stickersValue = mergeResult.mergedData['stickers'];
        final badgesList = badgesValue is Set
            ? badgesValue.toList()
            : (badgesValue is List ? badgesValue : <String>[]);
        final stickersList = stickersValue is Set
            ? stickersValue.toList()
            : (stickersValue is List ? stickersValue : <String>[]);

        registeredUser = UserModel.createRegisteredUser(
          id: supabaseUser.id,
          email: supabaseUser.email ?? 'user@example.com',
          displayName: supabaseUser.userMetadata?['display_name'] as String?,
          photoUrl: supabaseUser.userMetadata?['avatar_url'] as String?,
        ).copyWith(
          quotaManager: quotaManager,
          preferences: mergedPrefs,
          // Use merged values from merge framework
          totalWordsLearned: mergeResult.mergedData['total_words_learned'] as int? ?? 0,
          currentStreak: mergeResult.mergedData['current_streak'] as int? ?? 0,
          longestStreak: mergeResult.mergedData['longest_streak'] as int? ?? 0,
          shields: mergeResult.mergedData['shields'] as int? ?? 0,
          lastStreakActivityDate: lastActivityDate,
          badges: badgesList.cast<String>(),
          stickers: stickersList.cast<String>(),
          createdAt: currentUser.createdAt, // Keep original join time
        );

        // Sync merged data to server if any guest values were used
        if (mergeResult.mergeDetails.isNotEmpty) {
          await _syncStreakToServer(
            supabaseUser.id,
            registeredUser.currentStreak,
            registeredUser.longestStreak,
          );
          print('✅ Synced merged data to server: streak=${registeredUser.currentStreak}');
        } else {
          print('✅ Using server data (no guest values were better)');
        }
      } else {
        // No guest data - use server data or defaults
        final serverStreak = serverUserData?['current_streak'] as int? ?? 0;
        final serverLongestStreak = serverUserData?['longest_streak'] as int? ?? 0;

        registeredUser = UserModel.createRegisteredUser(
          id: supabaseUser.id,
          email: supabaseUser.email ?? 'user@example.com',
          displayName: supabaseUser.userMetadata?['display_name'] as String?,
          photoUrl: supabaseUser.userMetadata?['avatar_url'] as String?,
        ).copyWith(
          quotaManager: quotaManager,
          preferences: {
            'defaultCefrLevel': languageLevel ?? AppDefaults.defaultLanguageLevel,
            'languageVariant': englishVariant ?? AppDefaults.defaultEnglishVariant,
          },
          // Use server data if available
          currentStreak: serverStreak,
          longestStreak: serverLongestStreak,
        );
        print('✅ Loaded existing user data from server: streak=$serverStreak');
      }

      await _hiveService.saveUser(registeredUser);
      state = UserState(user: registeredUser);
      print('✅ Registered user saved: ${registeredUser.displayNameOrEmail}');
      print('📊 Streak: ${registeredUser.currentStreak} days (longest: ${registeredUser.longestStreak})');
      print('📚 Words learned: ${registeredUser.totalWordsLearned}');
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
          'defaultCefrLevel': languageLevel ?? AppDefaults.defaultLanguageLevel,
          'languageVariant': englishVariant ?? AppDefaults.defaultEnglishVariant,
        },
      );
      await _hiveService.saveUser(registeredUser);
      state = UserState(user: registeredUser);
    }
  }

  /// Sync user streak to Supabase
  Future<void> _syncStreakToServer(String userId, int currentStreak, int longestStreak) async {
    try {
      final client = Supabase.instance.client;
      await client.from('users').upsert({
        'id': userId,
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
      });
      print('✅ Streak synced to server: current=$currentStreak, longest=$longestStreak');
    } catch (e) {
      print('⚠️ Failed to sync streak to server: $e');
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
          // User has local registered data but no Supabase session
          // Try to refresh session first (token might be expired)
          print('🔄 No Supabase session but local user is registered, attempting refresh...');
          try {
            await Supabase.instance.client.auth.refreshSession();
            print('✅ Session refreshed successfully');
            // After refresh, reload user to get updated data
            final newSession = Supabase.instance.client.auth.currentSession;
            if (newSession != null && newSession.user != null) {
              await _convertToRegisteredUser(newSession.user);
            } else {
              // Refresh succeeded but no user data - should not happen, fallback to logout
              print('⚠️ Refresh succeeded but no user data, logging out...');
              await logout();
            }
          } catch (e) {
            // Token truly expired or invalid - clear local data
            print('❌ Session refresh failed: $e');
            print('🔄 Clearing local data - please log in again');
            await logout();
          }
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

      // ⭐ CRITICAL: Check if guest user already exists BEFORE clearing
      // This preserves guest quota (device-based quota persistence)
      final existingUser = await _hiveService.getCurrentUser();

      if (existingUser != null && existingUser.isGuest) {
        // Guest already exists - just use it (preserves quota!)
        print('👤 Preserving existing guest user with quota');
        state = UserState(user: existingUser);
        return;
      }

      // No guest user exists - need to create one
      await _hiveService.clearCurrentUser();

      // Create new guest user
      final guestUser = UserModel.createGuest();
      await _hiveService.saveUser(guestUser);
      // Save initial quota backup for device-based trial
      await _hiveService.saveGuestQuotaBackup(guestUser.quotaManager);
      state = UserState(user: guestUser);
    } catch (e) {
      state = UserState(user: state.user, error: e.toString());
    }
  }

  /// Create guest user with default preferences
  /// Preferences are now stored in UserModel only (no more SharedPreferences)
  Future<UserModel> _createGuestUserWithPreferences() async {
    // Try to load existing guest user from Hive first
    final existingUser = await _hiveService.getCurrentUser();

    // If guest user exists with preferences, return it
    if (existingUser != null && existingUser.isGuest) {
      print('👤 Loaded existing guest user with preferences');
      return existingUser;
    }

    // Otherwise create new guest with defaults
    print('👤 Creating new guest user with default preferences');
    final guestUser = UserModel.createGuest();
    // Save initial quota backup for device-based trial
    await _hiveService.saveGuestQuotaBackup(guestUser.quotaManager);
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

  /// Update user preferences (single source of truth pattern)
  /// - Guest: Save to Hive only
  /// - Cloud: Save to Hive + Sync to Supabase
  Future<void> updatePreferences(Map<String, dynamic> newPrefs) async {
    final user = state.user;
    if (user == null) return;

    try {
      // 1. Update UserModel with new preferences
      final updatedPrefs = Map<String, dynamic>.from(user.preferences);
      updatedPrefs.addAll(newPrefs);
      final updatedUser = user.copyWith(preferences: updatedPrefs);

      // 2. Save to Hive (both guest and cloud)
      await _hiveService.saveUser(updatedUser);

      // 3. Sync to Supabase for cloud users
      if (!user.isGuest) {
        final client = Supabase.instance.client;
        final userId = client.auth.currentUser?.id;
        if (userId != null) {
          try {
            // Map preference keys to database columns
            final dbData = <String, dynamic>{};
            if (newPrefs.containsKey('defaultCefrLevel')) {
              dbData['language_level'] = newPrefs['defaultCefrLevel'];
            }
            if (newPrefs.containsKey('languageVariant')) {
              dbData['english_variant'] = newPrefs['languageVariant'];
            }

            if (dbData.isNotEmpty) {
              // Update auth metadata
              await client.auth.updateUser(
                UserAttributes(data: dbData),
              );
              // Update users table
              await client.from('users').update(dbData).eq('id', userId);
              print('✅ Preferences synced to Supabase: $dbData');
            }
          } catch (e) {
            print('⚠️ Failed to sync preferences to Supabase: $e');
            // Continue anyway - local save succeeded
          }
        }
      }

      // 4. Update state
      state = UserState(user: updatedUser);
      print('✅ Preferences updated: $newPrefs');
    } catch (e) {
      print('❌ Error updating preferences: $e');
      state = UserState(user: state.user, error: e.toString());
    }
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

    // ⭐ CRITICAL: Save guest quota to backup (persists across login/logout)
    // This ensures device-based trial quota is preserved
    if (user.isGuest) {
      try {
        await _hiveService.saveGuestQuotaBackup(updatedQuotaManager);
        print('💾 Guest quota backup updated: ${updatedQuotaManager.usageHistory.length}/10');
      } catch (e) {
        print('⚠️ Failed to save guest quota backup: $e');
        // Continue anyway - local update succeeded
      }
    }

    debugPrint('✅ recordQuotaUsage completed - new daily: ${updatedQuotaManager.getTodayUsage()}/${updatedQuotaManager.dailyLimit}');
    return true;
  }

  bool get canGenerate => state.user?.canGenerate ?? false;

  /// Refresh user preferences from Supabase when user metadata is updated
  Future<void> _refreshUserFromSupabase() async {
    try {
      final currentUser = state.user;
      if (currentUser == null || currentUser.isGuest) {
        print('⏭️ Skipping refresh - user is null or guest');
        return;
      }

      final client = Supabase.instance.client;
      final supabaseUser = client.auth.currentUser;
      if (supabaseUser == null) {
        print('⚠️ No Supabase user found');
        return;
      }

      // Fetch fresh data from database (users table) - like Profile tab does
      final userData = await client
          .from('users')
          .select()
          .eq('id', currentUser.id)
          .single();

      final displayName = userData['display_name'] as String?;
      final photoUrl = userData['avatar_url'] as String?;
      final languageLevel = userData['language_level'] as String?;
      final englishVariant = userData['english_variant'] as String?;

      print('📥 Refreshing from database: displayName=$displayName, photoUrl=$photoUrl');

      // Update UserModel with fresh data from database
      final updatedUser = currentUser.copyWith(
        displayName: displayName ?? currentUser.displayName,
        photoUrl: photoUrl ?? currentUser.photoUrl,
        preferences: {
          // Preserve other preferences
          ...currentUser.preferences,
          // Override with fresh values from Supabase
          'defaultCefrLevel': languageLevel ?? currentUser.preferences['defaultCefrLevel'] ?? AppDefaults.defaultLanguageLevel,
          'languageVariant': englishVariant ?? currentUser.preferences['languageVariant'] ?? AppDefaults.defaultEnglishVariant,
        },
      );

      print('📝 OLD: ${currentUser.displayName} → NEW: ${updatedUser.displayName}');
      print('📝 OLD: ${currentUser.photoUrl} → NEW: ${updatedUser.photoUrl}');

      await _hiveService.saveUser(updatedUser);
      state = UserState(user: updatedUser);

      print('✅ User data updated from database');
    } catch (e, stackTrace) {
      print('❌ Error refreshing user from database: $e');
      print('📚 Stack trace: $stackTrace');
    }
  }

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
