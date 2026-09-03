import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/scrapbook_model.dart';
import '../../data/services/hive_service.dart';
import '../../data/services/image_storage_service.dart';
import 'providers.dart';

/// Scrapbook List State
class ScrapbookState {
  final List<ScrapbookModel> scrapbooks;
  final bool isLoading;
  final String? error;

  const ScrapbookState({
    this.scrapbooks = const [],
    this.isLoading = false,
    this.error,
  });

  ScrapbookState copyWith({
    List<ScrapbookModel>? scrapbooks,
    bool? isLoading,
    String? error,
  }) {
    return ScrapbookState(
      scrapbooks: scrapbooks ?? this.scrapbooks,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  /// Get scrapbook count
  int get totalCount => scrapbooks.length;

  /// Get scrapbooks for a specific date (sorted by createdAt, newest first)
  List<ScrapbookModel> getScrapbooksForDate(DateTime date) {
    return scrapbooks.where((scrapbook) {
      return scrapbook.date.year == date.year &&
          scrapbook.date.month == date.month &&
          scrapbook.date.day == date.day;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Get recent scrapbooks (last 5)
  List<ScrapbookModel> get recentScrapbooks {
    final sorted = List<ScrapbookModel>.from(scrapbooks)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(5).toList();
  }

  /// Get all unique dates that have scrapbooks
  List<DateTime> getDatesWithScrapbooks() {
    final dates = <DateTime>{};
    for (final scrapbook in scrapbooks) {
      final date = DateTime(
          scrapbook.date.year, scrapbook.date.month, scrapbook.date.day);
      dates.add(date);
    }
    final sorted = dates.toList()..sort();
    return sorted;
  }
}

/// Scrapbook State Provider
final scrapbookStateProvider =
    StateNotifierProvider<ScrapbookNotifier, ScrapbookState>((ref) {
  return ScrapbookNotifier(
    ref.read(hiveServiceProvider),
    ref.read(imageStorageServiceProvider),
  );
});

/// Scrapbook State Notifier
class ScrapbookNotifier extends StateNotifier<ScrapbookState> {
  final HiveService _hiveService;
  final ImageStorageService _imageStorageService;
  StreamSubscription<AuthState>? _authSubscription;
  String? _currentUserId; // Track current user to detect account changes

  ScrapbookNotifier(
    this._hiveService,
    this._imageStorageService, {
    ScrapbookState? initialState,
    bool autoLoad = true,
  }) : super(initialState ?? const ScrapbookState(isLoading: true)) {
    if (autoLoad) {
      _waitForInitializationAndLoad();
    }
  }

  Future<void> _waitForInitializationAndLoad() async {
    try {
      print('⏳ ScrapbookNotifier: Waiting for Hive initialization...');

      // Wait for Hive to be initialized
      while (!_hiveService.isInitialized) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      print('✅ ScrapbookNotifier: Hive initialized, loading scrapbooks...');

      // Setup auth state listener for cloud sync
      _setupAuthListener();

      await _loadScrapbooks();

      // Sync from cloud if user is logged in
      final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
      if (isLoggedIn) {
        // Track the initial user ID
        _currentUserId = Supabase.instance.client.auth.currentUser?.id;
        print('🔄 User logged in ($_currentUserId), syncing from cloud...');
        await _syncFromCloud();
      }
    } catch (e) {
      print('❌ ScrapbookNotifier: Initialization failed: $e');
      state = ScrapbookState(error: 'Initialization failed: ${e.toString()}');
    }
  }

  void _setupAuthListener() {
    final authState = Supabase.instance.client.auth.onAuthStateChange;
    _authSubscription = authState.listen((data) async {
      final AuthChangeEvent event = data.event;
      print('🔐 Auth state changed: $event');

      if (event == AuthChangeEvent.signedIn) {
        final newUserId = Supabase.instance.client.auth.currentUser?.id;
        print('🔄 User signed in: $newUserId (previous: $_currentUserId)');

        // Check if this is a different user signing in
        if (_currentUserId != null && _currentUserId != newUserId) {
          print('🔄 Different user detected, clearing local scrapbooks...');
          _hiveService.clearAllScrapbooks();
        }

        // Update current user ID
        _currentUserId = newUserId;

        // Sync from cloud
        _syncFromCloud();
      } else if (event == AuthChangeEvent.signedOut) {
        print('👋 User signed out, clearing local scrapbooks...');
        // Clear current user ID
        _currentUserId = null;
        // Clear all local scrapbooks when user signs out
        await _hiveService.clearAllScrapbooks();
        // Clear state
        state = const ScrapbookState(scrapbooks: []);
      }
    });
  }

  Future<void> _loadScrapbooks() async {
    try {
      final scrapbooks = await _hiveService.getAllScrapbooks();
      // Sort by createdAt descending (newest first)
      scrapbooks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = ScrapbookState(scrapbooks: scrapbooks);
      print('✅ Loaded ${scrapbooks.length} scrapbooks from local storage');
    } catch (e) {
      state = ScrapbookState(error: e.toString());
    }
  }

  Future<void> addScrapbook(ScrapbookModel scrapbook) async {
    try {
      print('📝 Adding scrapbook: ${scrapbook.id}');

      // For new scrapbooks (no existing cloud record), use current UTC time as createdAt
      // This ensures it appears as the newest even after cloud sync
      final isNewScrapbook = !state.scrapbooks.any((s) => s.id == scrapbook.id);
      final scrapbookToSave = isNewScrapbook
          ? scrapbook.copyWith(createdAt: DateTime.now().toUtc())
          : scrapbook;

      // Always save to local storage
      await _hiveService.saveScrapbook(scrapbookToSave);

      // Sync to cloud if registered user
      final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
      if (isLoggedIn) {
        await _saveToCloud(scrapbookToSave);
        print('✅ Scrapbook synced to cloud: ${scrapbookToSave.id}');
      }

      // Create new list with new scrapbook at front and ensure sorted order
      final updatedList = [scrapbookToSave, ...state.scrapbooks];
      updatedList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = ScrapbookState(scrapbooks: updatedList);

      // Debug: Show order after sort
      print('📊 Scrapbook order after add:');
      for (int i = 0; i < updatedList.length && i < 10; i++) {
        print('  [$i] ID: ${updatedList[i].id}, createdAt: ${updatedList[i].createdAt.toIso8601String()}');
      }
      print('✅ Scrapbook added successfully - now ${updatedList.length} total');
    } catch (e) {
      print('❌ Error adding scrapbook: $e');
      state = ScrapbookState(
        scrapbooks: state.scrapbooks,
        error: e.toString(),
      );
    }
  }

  Future<void> updateScrapbook(ScrapbookModel scrapbook) async {
    try {
      print('📝 Updating scrapbook: ${scrapbook.id}');

      // Always update local storage
      await _hiveService.saveScrapbook(scrapbook);

      // Sync to cloud if registered user
      final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
      if (isLoggedIn) {
        await _updateInCloud(scrapbook);
        print('✅ Scrapbook updated in cloud: ${scrapbook.id}');
      }

      final updatedList = state.scrapbooks.map((s) {
        return s.id == scrapbook.id ? scrapbook : s;
      }).toList();

      state = ScrapbookState(scrapbooks: updatedList);
      print('✅ Scrapbook updated successfully');
    } catch (e) {
      print('❌ Error updating scrapbook: $e');
      state = ScrapbookState(
        scrapbooks: state.scrapbooks,
        error: e.toString(),
      );
    }
  }

  Future<void> deleteScrapbook(String id) async {
    try {
      print('🗑️ Deleting scrapbook: $id');

      // Get scrapbook before deleting (for cloud cleanup)
      final scrapbook = state.scrapbooks.firstWhere(
        (s) => s.id == id,
        orElse: () => throw Exception('Scrapbook not found'),
      );

      // Always delete from local storage
      await _hiveService.deleteScrapbook(id);

      // Delete from cloud if registered user
      final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
      if (isLoggedIn) {
        await _deleteFromCloud(scrapbook);
        print('✅ Scrapbook deleted from cloud: $id');
      }

      final updatedList = state.scrapbooks.where((s) => s.id != id).toList();
      state = ScrapbookState(scrapbooks: updatedList);
      print('✅ Scrapbook deleted successfully');
    } catch (e) {
      print('❌ Error deleting scrapbook: $e');
      state = ScrapbookState(
        scrapbooks: state.scrapbooks,
        error: e.toString(),
      );
    }
  }

  void clear() {
    state = const ScrapbookState(scrapbooks: []);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);

    // Sync from cloud if logged in
    final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
    if (isLoggedIn) {
      print('🔄 Refresh: Syncing from cloud...');
      await _syncFromCloud();
    } else {
      await _loadScrapbooks();
    }
  }

  /// Combines cloud data with local-only memories. A cloud record is
  /// authoritative when both sources contain the same ID.
  static List<ScrapbookModel> mergeCloudAndLocal(
    List<ScrapbookModel> cloudScrapbooks,
    List<ScrapbookModel> localScrapbooks,
  ) {
    final merged = [...cloudScrapbooks];
    final cloudIds = cloudScrapbooks.map((scrapbook) => scrapbook.id).toSet();
    merged.addAll(
      localScrapbooks.where((scrapbook) => !cloudIds.contains(scrapbook.id)),
    );
    merged.sort((first, second) => second.createdAt.compareTo(first.createdAt));
    return merged;
  }

  // ============= Cloud Sync Methods =============

  /// Load scrapbooks from Supabase cloud database
  Future<List<ScrapbookModel>> _loadFromCloud() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        print('⚠️ No user logged in, cannot load from cloud');
        return [];
      }

      print('📥 Fetching scrapbooks from cloud for user: $userId');

      final response = await client
          .from('scrapbooks')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (response == null) {
        print('⚠️ No response from cloud');
        return [];
      }

      final List<dynamic> data = response as List<dynamic>;
      print('📥 Found ${data.length} scrapbooks in cloud');

      final scrapbooks = <ScrapbookModel>[];
      for (final item in data) {
        try {
          scrapbooks.add(ScrapbookModel.fromSupabaseJson(item as Map<String, dynamic>));
        } catch (e) {
          print('⚠️ Failed to parse scrapbook: $e');
          continue;
        }
      }

      print('✅ Successfully parsed ${scrapbooks.length} scrapbooks from cloud');
      return scrapbooks;
    } catch (e) {
      print('❌ Failed to load from cloud: $e');
      return [];
    }
  }

  /// Sync scrapbooks from cloud to local storage
  Future<void> _syncFromCloud() async {
    try {
      print('🔄 Starting sync from cloud...');

      // Load from cloud
      final cloudScrapbooks = await _loadFromCloud();
      if (cloudScrapbooks.isEmpty) {
        print('📭 No scrapbooks in cloud to sync');
        return;
      }

      // Get local scrapbooks
      final localScrapbooks = await _hiveService.getAllScrapbooks();
      final localIds = localScrapbooks.map((s) => s.id).toSet();

      // Save cloud scrapbooks to local storage
      int syncedCount = 0;
      for (final cloudScrapbook in cloudScrapbooks) {
        try {
          await _hiveService.saveScrapbook(cloudScrapbook);
          syncedCount++;
          print('💾 Synced scrapbook: ${cloudScrapbook.id}');
        } catch (e) {
          print('⚠️ Failed to save scrapbook ${cloudScrapbook.id}: $e');
        }
      }

      print('✅ Synced $syncedCount scrapbooks from cloud to local');

      // Update state with merged scrapbooks
      // Priority: newer version wins based on updated_at
      final mergedScrapbooks = mergeCloudAndLocal(
        cloudScrapbooks,
        localScrapbooks,
      );
      state = ScrapbookState(scrapbooks: mergedScrapbooks);
      print('✅ State updated with ${mergedScrapbooks.length} total scrapbooks');
    } catch (e) {
      print('❌ Failed to sync from cloud: $e');
    }
  }

  /// Upload additional photos to cloud storage
  /// Returns a list of photos with cloud URLs (for uploaded ones) or original paths
  /// Skips photos with local paths that no longer exist (these are removed from scrapbook)
  Future<List<Map<String, dynamic>>> _uploadAdditionalPhotos(
    List<ScrapbookPhoto> photos,
    String userId,
    String scrapbookId,
  ) async {
    final uploadedPhotos = <Map<String, dynamic>>[];
    int keptCount = 0;
    int skippedCount = 0;

    for (final photo in photos) {
      // If already a cloud URL, keep as-is
      if (photo.imagePath.startsWith('http')) {
        uploadedPhotos.add(photo.toJson());
        keptCount++;
        continue;
      }

      // Try to upload local file
      try {
        final file = File(photo.imagePath);
        if (await file.exists()) {
          final cloudUrl = await _imageStorageService.uploadScrapbookImage(
            imageFile: file,
            userId: userId,
            scrapbookId: '$scrapbookId/additional',
          );
          // Update photo with cloud URL
          uploadedPhotos.add(photo.copyWith(imagePath: cloudUrl).toJson());
          keptCount++;
          print('✅ Additional photo uploaded to cloud: ${photo.id}');
        } else {
          // File doesn't exist - skip this photo (remove from list)
          skippedCount++;
          print('⚠️ Photo ${photo.id} skipped - local file not found: ${photo.imagePath}');
          // Don't add to uploadedPhotos - this removes it from the scrapbook
        }
      } catch (e) {
        // Upload failed - skip this photo
        skippedCount++;
        print('⚠️ Photo ${photo.id} skipped - upload failed: $e');
        // Don't add to uploadedPhotos - this removes it from the scrapbook
      }
    }

    if (skippedCount > 0) {
      print('📊 Photos sync summary: $keptCount kept, $skippedCount skipped (missing files)');
    }

    return uploadedPhotos;
  }

  Future<void> _saveToCloud(ScrapbookModel scrapbook) async {
    final newlyUploadedUrls = <String>[];

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        print('⚠️ No user logged in, skipping cloud sync');
        return;
      }

      // Upload main image if it's a local path
      String imageUrl = scrapbook.imagePath;
      if (!scrapbook.imagePath.startsWith('http')) {
        try {
          final file = File(scrapbook.imagePath);
          if (await file.exists()) {
            imageUrl = await _imageStorageService.uploadScrapbookImage(
              imageFile: file,
              userId: userId,
              scrapbookId: scrapbook.id,
            );
            newlyUploadedUrls.add(imageUrl);
            print('✅ Main image uploaded: $imageUrl');
          }
        } catch (e) {
          print('⚠️ Failed to upload main image: $e, using local path');
        }
      }

      // Upload additional photos
      final additionalPhotosJson = await _uploadAdditionalPhotos(
        scrapbook.additionalPhotos,
        userId,
        scrapbook.id,
      );
      // Track newly uploaded additional photo URLs
      for (final photoJson in additionalPhotosJson) {
        final path = photoJson['imagePath'] as String;
        if (path.startsWith('http')) {
          newlyUploadedUrls.add(path);
        }
      }

      // Prepare data for Supabase (snake_case)
      final data = {
        'id': scrapbook.id,
        'user_id': userId,
        'date': scrapbook.date.toIso8601String(),
        'image_path': imageUrl,
        'vocabulary_words':
            scrapbook.vocabularyWords.map((v) => v.toJson()).toList(),
        'english_sentence': scrapbook.englishSentence,
        'thai_sentence': scrapbook.thaiSentence,
        'selected_emoji': scrapbook.selectedEmoji,
        'background_color': scrapbook.backgroundColor,
        'text_overlays': scrapbook.textOverlays.map((t) => t.toJson()).toList(),
        'stickers': scrapbook.stickers.map((s) => s.toJson()).toList(),
        'additional_photos': additionalPhotosJson,
        'created_at': scrapbook.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await client.from('scrapbooks').insert(data);
      print('✅ Scrapbook saved to cloud');
    } catch (e) {
      await _cleanupFailedCloudUpload(newlyUploadedUrls);
      print('⚠️ Failed to save scrapbook to cloud: $e');
      rethrow;
    }
  }

  Future<void> _updateInCloud(ScrapbookModel scrapbook) async {
    final newlyUploadedUrls = <String>[];

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      // Upload main image if it's a local path
      String imageUrl = scrapbook.imagePath;
      if (!scrapbook.imagePath.startsWith('http')) {
        try {
          final file = File(scrapbook.imagePath);
          if (await file.exists()) {
            imageUrl = await _imageStorageService.uploadScrapbookImage(
              imageFile: file,
              userId: userId,
              scrapbookId: scrapbook.id,
            );
            newlyUploadedUrls.add(imageUrl);
            print('✅ Main image uploaded: $imageUrl');
          }
        } catch (e) {
          print('⚠️ Failed to upload main image: $e');
        }
      }

      // Upload additional photos
      final additionalPhotosJson = await _uploadAdditionalPhotos(
        scrapbook.additionalPhotos,
        userId,
        scrapbook.id,
      );
      // Track newly uploaded additional photo URLs
      for (final photoJson in additionalPhotosJson) {
        final path = photoJson['imagePath'] as String;
        if (path.startsWith('http')) {
          newlyUploadedUrls.add(path);
        }
      }

      final data = {
        'date': scrapbook.date.toIso8601String(),
        'image_path': imageUrl,
        'vocabulary_words':
            scrapbook.vocabularyWords.map((v) => v.toJson()).toList(),
        'english_sentence': scrapbook.englishSentence,
        'thai_sentence': scrapbook.thaiSentence,
        'selected_emoji': scrapbook.selectedEmoji,
        'background_color': scrapbook.backgroundColor,
        'text_overlays': scrapbook.textOverlays.map((t) => t.toJson()).toList(),
        'stickers': scrapbook.stickers.map((s) => s.toJson()).toList(),
        'additional_photos': additionalPhotosJson,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await client
          .from('scrapbooks')
          .update(data)
          .eq('id', scrapbook.id)
          .eq('user_id', userId);
      print('✅ Scrapbook updated in cloud');
    } catch (e) {
      await _cleanupFailedCloudUpload(newlyUploadedUrls);
      print('⚠️ Failed to update scrapbook in cloud: $e');
      rethrow;
    }
  }

  Future<void> _cleanupFailedCloudUpload(List<String> imageUrls) async {
    if (imageUrls.isEmpty) return;

    for (final imageUrl in imageUrls) {
      try {
        final deleted = await _imageStorageService.deleteImage(imageUrl);
        if (deleted) {
          print('✅ Removed image uploaded by failed cloud sync: $imageUrl');
        } else {
          print('⚠️ Could not remove image uploaded by failed cloud sync: $imageUrl');
        }
      } catch (cleanupError) {
        // Preserve the original database error while reporting cleanup failure.
        print('⚠️ Failed to clean up cloud image $imageUrl: $cleanupError');
      }
    }
  }

  Future<void> _deleteFromCloud(ScrapbookModel scrapbook) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      await client
          .from('scrapbooks')
          .delete()
          .eq('id', scrapbook.id)
          .eq('user_id', userId);

      // Delete main image from storage if it's a cloud URL
      if (scrapbook.imagePath.startsWith('http')) {
        try {
          await _imageStorageService.deleteImage(scrapbook.imagePath);
          print('✅ Main image deleted from cloud: ${scrapbook.imagePath}');
        } catch (e) {
          print('⚠️ Failed to delete main image from cloud: $e');
        }
      }

      // Delete additional photos from storage if they are cloud URLs
      for (final photo in scrapbook.additionalPhotos) {
        if (photo.imagePath.startsWith('http')) {
          try {
            await _imageStorageService.deleteImage(photo.imagePath);
            print('✅ Additional photo deleted from cloud: ${photo.imagePath}');
          } catch (e) {
            print('⚠️ Failed to delete additional photo from cloud: $e');
          }
        }
      }

      print('✅ Scrapbook deleted from cloud');
    } catch (e) {
      print('⚠️ Failed to delete scrapbook from cloud: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
