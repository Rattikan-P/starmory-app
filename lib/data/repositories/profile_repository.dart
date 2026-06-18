import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/hive_service.dart';
import '../services/vocabulary_sync_service.dart';
import '../services/streak_service.dart';
import '../services/app_state_service.dart';
import '../models/user_model.dart';
import '../models/vocabulary_model.dart';
import '../../utils/csv_export_helper.dart';
import '../../utils/snackbar_helper.dart';

/// Result type for repository operations
class Result<T> {
  final T? data;
  final String? error;
  final bool success;

  Result.success(this.data)
      : success = true,
        error = null;

  Result.failure(this.error)
      : success = false,
        data = null;
}

/// User type enumeration
enum UserType { guest, registered }

/// Repository for profile-related operations
///
/// This repository handles:
/// - Display name management
/// - Profile photo upload/remove
/// - Language level & English variant preferences
/// - Start Over (reset progress)
/// - Vocabulary export
/// - Cache management
class ProfileRepository {
  final AuthService _authService;
  final HiveService _hiveService;
  final VocabularySyncService _vocabSyncService;
  final StreakService _streakService;
  final AppStateService _appStateService;
  final SupabaseClient _supabaseClient;

  ProfileRepository({
    required AuthService authService,
    required HiveService hiveService,
    required VocabularySyncService vocabSyncService,
    required StreakService streakService,
    required AppStateService appStateService,
    required SupabaseClient supabaseClient,
  })  : _authService = authService,
        _hiveService = hiveService,
        _vocabSyncService = vocabSyncService,
        _streakService = streakService,
        _appStateService = appStateService,
        _supabaseClient = supabaseClient;

  // ==================== DISPLAY NAME ====================

  /// Update display name for the current user
  ///
  /// Validates the name (2-40 characters, not empty/whitespace),
  /// updates auth service and database.
  ///
  /// Returns Result.success() if update succeeds
  /// Returns Result.failure() with error message if validation fails or update fails
  Future<Result<void>> updateDisplayName(String displayName) async {
    // Validation
    final name = displayName.trim();

    if (name.isEmpty) {
      return Result.failure('Please enter a name');
    }

    if (name.length < 2) {
      return Result.failure('Name must be at least 2 characters');
    }

    if (name.length > 40) {
      return Result.failure('Name must not exceed 40 characters');
    }

    try {
      final client = _supabaseClient;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        return Result.failure('User not authenticated');
      }

      // Update auth service
      await client.auth.updateUser(
        UserAttributes(data: {'display_name': name}),
      );

      // Update database
      await client
          .from('users')
          .update({'display_name': name})
          .eq('id', userId);

      return Result.success(null);
    } catch (e) {
      return Result.failure('Failed to save changes. Please try again.');
    }
  }

  // ==================== PROFILE PHOTO ====================

  /// Upload profile photo from camera or gallery
  ///
  /// Validates image format (JPEG/PNG only), deletes old photo if exists,
  /// uploads new photo to storage, updates auth service and database.
  ///
  /// Returns Result.success() if upload succeeds
  /// Returns Result.failure() with error message if validation fails or upload fails
  Future<Result<void>> uploadProfilePhoto(File imageFile, ImageSource source) async {
    try {
      final client = _supabaseClient;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        return Result.failure('User not authenticated');
      }

      // Validate file format
      final pathLower = imageFile.path.toLowerCase();
      if (pathLower.endsWith('.gif') ||
          pathLower.endsWith('.webp') ||
          pathLower.endsWith('.bmp')) {
        return Result.failure('Only JPEG and PNG images are supported.');
      }

      // Get file extension
      final fileName = imageFile.path.split('/').last;
      final fileExt = fileName.split('.').last.toLowerCase();

      String getContentType(String ext) {
        switch (ext) {
          case 'jpg':
          case 'jpeg':
            return 'image/jpeg';
          case 'png':
            return 'image/png';
          default:
            return 'image/jpeg';
        }
      }

      final validExtensions = ['jpg', 'jpeg', 'png'];
      final safeExt = validExtensions.contains(fileExt) ? fileExt : 'jpg';
      final newFileName = '${userId}_avatar.$safeExt';

      // Delete old avatar if exists (with different extension)
      try {
        final currentUser = client.auth.currentUser;
        final oldAvatarUrl = currentUser?.userMetadata?['avatar_url'] as String?;
        if (oldAvatarUrl != null) {
          final urlWithoutParams = oldAvatarUrl.split('?').first;
          final oldFileName = urlWithoutParams.split('/').last;
          if (oldFileName != newFileName) {
            try {
              await client.storage.from('avatars').remove([oldFileName]);
            } catch (e) {
              // Log but continue with upload
              print('Failed to delete old photo: $e');
            }
          }
        }
      } catch (e) {
        // Ignore if metadata fetch fails
      }

      // Upload new photo
      final fileBytes = await imageFile.readAsBytes();
      await client.storage
          .from('avatars')
          .uploadBinary(
            newFileName,
            fileBytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: getContentType(fileExt),
            ),
          );

      // Add version parameter for cache busting
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final baseUrl = client.storage.from('avatars').getPublicUrl(newFileName);
      final avatarUrl = '$baseUrl?v=$timestamp';

      // Update auth service
      await client.auth.updateUser(
        UserAttributes(data: {'avatar_url': avatarUrl}),
      );

      // Update database
      await client
          .from('users')
          .update({'avatar_url': avatarUrl})
          .eq('id', userId);

      return Result.success(null);
    } catch (e) {
      return Result.failure('Failed to save changes. Please try again.');
    }
  }

  /// Remove profile photo
  ///
  /// Deletes photo from cloud storage, sets avatar_url to null
  /// in auth service and database.
  ///
  /// Returns Result.success() if removal succeeds
  /// Returns Result.failure() if database update fails
  Future<Result<void>> removeProfilePhoto() async {
    try {
      final client = _supabaseClient;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        return Result.failure('User not authenticated');
      }

      final currentAvatarUrl = client.auth.currentUser?.userMetadata?['avatar_url'] as String?;

      // Delete from storage
      if (currentAvatarUrl != null) {
        try {
          final urlWithoutParams = currentAvatarUrl.split('?').first;
          final fileName = urlWithoutParams.split('/').last;
          await client.storage.from('avatars').remove([fileName]);
        } catch (e) {
          // Log but continue with database update
          print('Failed to delete photo from storage: $e');
        }
      }

      // Update auth service
      await client.auth.updateUser(UserAttributes(data: {'avatar_url': null}));

      // Update database
      await client.from('users').update({'avatar_url': null}).eq('id', userId);

      return Result.success(null);
    } catch (e) {
      return Result.failure('Failed to save changes. Please try again.');
    }
  }

  // ==================== LANGUAGE LEVEL ====================

  /// Update language level preference
  ///
  /// For guest users: saves to local storage (Hive)
  /// For registered users: syncs to database
  ///
  /// Returns Result.success() if update succeeds
  /// Returns Result.failure() if update fails
  Future<Result<void>> updateLanguageLevel(String level) async {
    try {
      final user = await _hiveService.getCurrentUser();

      if (user == null) {
        return Result.failure('User not found');
      }

      final updatedUser = user.updateLanguageLevel(level);
      await _hiveService.saveUser(updatedUser);

      // For registered users, sync to cloud
      if (!user.isGuest) {
        final client = _supabaseClient;
        await client
            .from('users')
            .update({'language_level': level})
            .eq('id', user.id);
      }

      return Result.success(null);
    } catch (e) {
      return Result.failure('Failed to update preference. Please try again.');
    }
  }

  // ==================== ENGLISH VARIANT ====================

  /// Update English variant preference
  ///
  /// For guest users: saves to local storage (Hive)
  /// For registered users: syncs to database
  ///
  /// Returns Result.success() if update succeeds
  /// Returns Result.failure() if update fails
  Future<Result<void>> updateEnglishVariant(String variant) async {
    try {
      final user = await _hiveService.getCurrentUser();

      if (user == null) {
        return Result.failure('User not found');
      }

      final updatedUser = user.updateEnglishVariant(variant);
      await _hiveService.saveUser(updatedUser);

      // For registered users, sync to cloud
      if (!user.isGuest) {
        final client = _supabaseClient;
        await client
            .from('users')
            .update({'english_variant': variant})
            .eq('id', user.id);
      }

      return Result.success(null);
    } catch (e) {
      return Result.failure('Failed to update preference. Please try again.');
    }
  }

  // ==================== START OVER ====================

  /// Reset learning progress while preserving preferences
  ///
  /// For guest users:
  /// - Clears local vocabulary
  /// - Resets streak
  /// - Creates fresh guest with preserved quota and preferences
  ///
  /// For registered users:
  /// - Clears local and cloud vocabulary
  /// - Resets streak
  /// - Preserves account and preferences
  ///
  /// Returns Result with updated user if reset succeeds
  /// Returns Result.failure() with warning if partial success
  Future<Result<UserModel?>> startOver(UserType userType) async {
    try {
      final user = await _hiveService.getCurrentUser();

      if (user == null) {
        return Result.failure('User not found');
      }

      if (userType == UserType.guest) {
        return await _startOverGuest(user);
      } else {
        return await _startOverRegistered(user);
      }
    } catch (e) {
      return Result.failure('Failed to reset progress. Please try again.');
    }
  }

  Future<Result<UserModel?>> _startOverGuest(UserModel user) async {
    try {
      // Clear vocabulary
      await _hiveService.clearAllVocabulary();

      // Reset streak
      try {
        await _streakService.resetStreak();
      } catch (e) {
        return Result.failure('Progress reset. Streak reset failed. Please try again.');
      }

      // Preserve quota and preferences
      final currentQuota = user.quotaManager;
      final freshGuest = UserModel.createGuest().copyWith(
        preferences: user.preferences,
        quotaManager: currentQuota,
      );

      await _hiveService.saveUser(freshGuest);
      await _hiveService.saveGuestQuotaBackup(currentQuota);

      return Result.success(freshGuest);
    } catch (e) {
      return Result.failure('Failed to reset progress. Please try again.');
    }
  }

  Future<Result<UserModel?>> _startOverRegistered(UserModel user) async {
    // Clear local vocabulary
    await _hiveService.clearAllVocabulary();

    // Clear cloud vocabulary
    final cloudCleared = await _vocabSyncService.clearCloud();

    if (!cloudCleared) {
      // Local cleared but cloud failed - show warning but continue
    }

    // Reset streak
    try {
      await _streakService.resetStreak();
    } catch (e) {
      // Vocabulary cleared but streak failed
      return Result.failure('Progress reset. Streak reset failed. Please try again.');
    }

    // Return user with reset streak (cloud streak was reset above)
    final updatedUser = user.copyWith(
      currentStreak: 0,
      longestStreak: 0,
      shields: 0,
      lastStreakActivityDate: null,
    );
    await _hiveService.saveUser(updatedUser);

    return Result.success(updatedUser);
  }

  // ==================== EXPORT VOCABULARY ====================

  /// Export vocabulary list to CSV file
  ///
  /// For guest users: fetches from local storage
  /// For registered users: fetches from cloud with local fallback
  ///
  /// Returns Result.success() with vocabulary count if user successfully shares
  /// Returns Result.failure() if user dismisses, no vocabulary, or export fails
  Future<Result<int>> exportVocabulary(UserType userType) async {
    try {
      List<VocabularyModel> vocabularyList;

      if (userType == UserType.guest) {
        // Guest: fetch from local
        vocabularyList = await _hiveService.getAllVocabulary();
      } else {
        // Registered: try cloud first, fallback to local
        vocabularyList = await _vocabSyncService.fetchFromCloud();
        if (vocabularyList.isEmpty) {
          vocabularyList = await _hiveService.getAllVocabulary();
        }
      }

      if (vocabularyList.isEmpty) {
        return Result.failure('No vocabulary to export yet.');
      }

      // Generate CSV and share
      final exportResult = await CsvExportHelper.exportVocabularyToCsv(vocabularyList);

      // Check if user dismissed the share sheet
      if (exportResult.dismissed) {
        return Result.failure('Export cancelled.');
      }

      // Check if export failed
      if (!exportResult.success) {
        return Result.failure(exportResult.error ?? 'Failed to export vocabulary.');
      }

      // Success - user shared the file
      return Result.success(exportResult.wordCount ?? vocabularyList.length);
    } catch (e) {
      return Result.failure('Failed to export vocabulary.');
    }
  }

  // ==================== CLEAR CACHE ====================

  /// Clear app cache (images, temporary files)
  ///
  /// Preserves user data (vocabulary, preferences, streak)
  ///
  /// Returns Result.success() if cache cleared
  /// Returns Result.failure() if clear fails
  Future<Result<void>> clearCache() async {
    try {
      await _appStateService.clearCache();
      return Result.success(null);
    } catch (e) {
      return Result.failure('Failed to clear cache. Please try again.');
    }
  }

  // ==================== HELPER METHODS ====================

  /// Get current user
  Future<UserModel?> getCurrentUser() async {
    return await _hiveService.getCurrentUser();
  }

  /// Check if user is guest
  Future<bool> isGuest() async {
    final user = await getCurrentUser();
    return user?.isGuest ?? true;
  }

  /// Get current language level
  Future<String> getLanguageLevel() async {
    final user = await getCurrentUser();
    return user?.languageLevel ?? 'B1';
  }

  /// Get current English variant
  Future<String> getEnglishVariant() async {
    final user = await getCurrentUser();
    return user?.englishVariant ?? 'US';
  }
}
