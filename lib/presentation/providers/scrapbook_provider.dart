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

  /// Get scrapbooks for a specific date
  List<ScrapbookModel> getScrapbooksForDate(DateTime date) {
    return scrapbooks.where((scrapbook) {
      return scrapbook.date.year == date.year &&
          scrapbook.date.month == date.month &&
          scrapbook.date.day == date.day;
    }).toList();
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

  ScrapbookNotifier(this._hiveService, this._imageStorageService)
      : super(const ScrapbookState(isLoading: true)) {
    _waitForInitializationAndLoad();
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
        print('🔄 User logged in, syncing from cloud...');
        await _syncFromCloud();
      }
    } catch (e) {
      print('❌ ScrapbookNotifier: Initialization failed: $e');
      state = ScrapbookState(error: 'Initialization failed: ${e.toString()}');
    }
  }

  void _setupAuthListener() {
    final authState = Supabase.instance.client.auth.onAuthStateChange;
    _authSubscription = authState.listen((data) {
      final AuthChangeEvent event = data.event;
      print('🔐 Auth state changed: $event');

      if (event == AuthChangeEvent.signedIn) {
        print('🔄 User signed in, syncing from cloud...');
        _syncFromCloud();
      } else if (event == AuthChangeEvent.signedOut) {
        print('👋 User signed out, clearing cloud data from view...');
        // Clear state to only show local data
        _loadScrapbooks();
      }
    });
  }

  Future<void> _loadScrapbooks() async {
    try {
      final scrapbooks = await _hiveService.getAllScrapbooks();
      state = ScrapbookState(scrapbooks: scrapbooks);
      print('✅ Loaded ${scrapbooks.length} scrapbooks from local storage');
    } catch (e) {
      state = ScrapbookState(error: e.toString());
    }
  }

  Future<void> addScrapbook(ScrapbookModel scrapbook) async {
    try {
      print('📝 Adding scrapbook: ${scrapbook.id}');

      // Always save to local storage
      await _hiveService.saveScrapbook(scrapbook);

      // Sync to cloud if registered user
      final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
      if (isLoggedIn) {
        await _saveToCloud(scrapbook);
        print('✅ Scrapbook synced to cloud: ${scrapbook.id}');
      }

      state = ScrapbookState(
        scrapbooks: [...state.scrapbooks, scrapbook],
      );
      print('✅ Scrapbook added successfully');
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
        await _deleteFromCloud(id, scrapbook.imagePath);
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
      final mergedScrapbooks = <ScrapbookModel>[];

      // Add all cloud scrapbooks
      mergedScrapbooks.addAll(cloudScrapbooks);

      // Add local-only scrapbooks (not in cloud)
      final cloudIds = cloudScrapbooks.map((s) => s.id).toSet();
      for (final local in localScrapbooks) {
        if (!cloudIds.contains(local.id)) {
          mergedScrapbooks.add(local);
        }
      }

      state = ScrapbookState(scrapbooks: mergedScrapbooks);
      print('✅ State updated with ${mergedScrapbooks.length} total scrapbooks');
    } catch (e) {
      print('❌ Failed to sync from cloud: $e');
    }
  }

  Future<void> _saveToCloud(ScrapbookModel scrapbook) async {
    String? newlyUploadedImageUrl;

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        print('⚠️ No user logged in, skipping cloud sync');
        return;
      }

      // Upload image if it's a local path
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
            newlyUploadedImageUrl = imageUrl;
            print('✅ Image uploaded: $imageUrl');
          }
        } catch (e) {
          print('⚠️ Failed to upload image: $e, using local path');
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
        'additional_photos':
            scrapbook.additionalPhotos.map((p) => p.toJson()).toList(),
        'created_at': scrapbook.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await client.from('scrapbooks').insert(data);
      print('✅ Scrapbook saved to cloud');
    } catch (e) {
      await _cleanupFailedCloudUpload(newlyUploadedImageUrl);
      print('⚠️ Failed to save scrapbook to cloud: $e');
      rethrow;
    }
  }

  Future<void> _updateInCloud(ScrapbookModel scrapbook) async {
    String? newlyUploadedImageUrl;

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      // Upload image if it's a local path
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
            newlyUploadedImageUrl = imageUrl;
          }
        } catch (e) {
          print('⚠️ Failed to upload image: $e');
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
        'additional_photos':
            scrapbook.additionalPhotos.map((p) => p.toJson()).toList(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await client
          .from('scrapbooks')
          .update(data)
          .eq('id', scrapbook.id)
          .eq('user_id', userId);
      print('✅ Scrapbook updated in cloud');
    } catch (e) {
      await _cleanupFailedCloudUpload(newlyUploadedImageUrl);
      print('⚠️ Failed to update scrapbook in cloud: $e');
      rethrow;
    }
  }

  Future<void> _cleanupFailedCloudUpload(String? imageUrl) async {
    if (imageUrl == null) return;

    try {
      final deleted = await _imageStorageService.deleteImage(imageUrl);
      if (deleted) {
        print('✅ Removed image uploaded by failed cloud sync');
      } else {
        print('⚠️ Could not remove image uploaded by failed cloud sync');
      }
    } catch (cleanupError) {
      // Preserve the original database error while reporting cleanup failure.
      print('⚠️ Failed to clean up cloud image: $cleanupError');
    }
  }

  Future<void> _deleteFromCloud(String id, String imagePath) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      await client
          .from('scrapbooks')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);

      // Delete image from storage if it's a cloud URL
      if (imagePath.startsWith('http')) {
        try {
          await _imageStorageService.deleteImage(imagePath);
        } catch (e) {
          print('⚠️ Failed to delete image from cloud: $e');
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
