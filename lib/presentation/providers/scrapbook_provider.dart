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
      final date = DateTime(scrapbook.date.year, scrapbook.date.month, scrapbook.date.day);
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
      await _loadScrapbooks();
    } catch (e) {
      print('❌ ScrapbookNotifier: Initialization failed: $e');
      state = ScrapbookState(error: 'Initialization failed: ${e.toString()}');
    }
  }

  Future<void> _loadScrapbooks() async {
    try {
      final scrapbooks = await _hiveService.getAllScrapbooks();
      state = ScrapbookState(scrapbooks: scrapbooks);
      print('✅ Loaded ${scrapbooks.length} scrapbooks');
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
    await _loadScrapbooks();
  }

  // ============= Cloud Sync Methods =============

  Future<void> _saveToCloud(ScrapbookModel scrapbook) async {
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
        'vocabulary_words': scrapbook.vocabularyWords.map((v) => v.toJson()).toList(),
        'english_sentence': scrapbook.englishSentence,
        'thai_sentence': scrapbook.thaiSentence,
        'selected_emoji': scrapbook.selectedEmoji,
        'background_color': scrapbook.backgroundColor,
        'text_overlays': scrapbook.textOverlays.map((t) => t.toJson()).toList(),
        'stickers': scrapbook.stickers.map((s) => s.toJson()).toList(),
        'additional_photos': scrapbook.additionalPhotos.map((p) => p.toJson()).toList(),
        'created_at': scrapbook.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await client.from('scrapbooks').insert(data);
      print('✅ Scrapbook saved to cloud');
    } catch (e) {
      print('⚠️ Failed to save scrapbook to cloud: $e');
      rethrow;
    }
  }

  Future<void> _updateInCloud(ScrapbookModel scrapbook) async {
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
          }
        } catch (e) {
          print('⚠️ Failed to upload image: $e');
        }
      }

      final data = {
        'date': scrapbook.date.toIso8601String(),
        'image_path': imageUrl,
        'vocabulary_words': scrapbook.vocabularyWords.map((v) => v.toJson()).toList(),
        'english_sentence': scrapbook.englishSentence,
        'thai_sentence': scrapbook.thaiSentence,
        'selected_emoji': scrapbook.selectedEmoji,
        'background_color': scrapbook.backgroundColor,
        'text_overlays': scrapbook.textOverlays.map((t) => t.toJson()).toList(),
        'stickers': scrapbook.stickers.map((s) => s.toJson()).toList(),
        'additional_photos': scrapbook.additionalPhotos.map((p) => p.toJson()).toList(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await client.from('scrapbooks').update(data).eq('id', scrapbook.id).eq('user_id', userId);
      print('✅ Scrapbook updated in cloud');
    } catch (e) {
      print('⚠️ Failed to update scrapbook in cloud: $e');
      rethrow;
    }
  }

  Future<void> _deleteFromCloud(String id, String imagePath) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      await client.from('scrapbooks').delete().eq('id', id).eq('user_id', userId);

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
