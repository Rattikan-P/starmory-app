import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../models/vocabulary_model.dart';
import '../../core/error/failures.dart';
import 'image_storage_service.dart';

/// Vocabulary Sync Service
/// Handles syncing vocabulary between local storage and Supabase cloud
/// - Guest users: Local only (no sync)
/// - Registered users: Local + Cloud sync
class VocabularySyncService {
  final SupabaseClient _client = Supabase.instance.client;
  final ImageStorageService? _imageStorageService;

  VocabularySyncService({ImageStorageService? imageStorageService})
      : _imageStorageService = imageStorageService;

  /// Get current user ID (null if guest/not logged in)
  String? get currentUserId => _client.auth.currentSession?.user.id;

  /// Check if user is logged in (not guest)
  bool get isLoggedIn => currentUserId != null;

  // ============= Sync Operations =============

  /// Save vocabulary to Supabase (for registered users only)
  /// Returns true if saved successfully, false if guest or error
  /// Uses INSERT (not upsert) so the streak trigger fires properly
  Future<bool> saveToCloud(VocabularyModel vocabulary) async {
    if (!isLoggedIn) {
      // Guest user - don't sync to cloud
      print('ℹ️ [Cloud Sync] Guest user - skipping cloud sync');
      return false;
    }

    try {
      final userId = currentUserId!;
      print('☁️ [Cloud Sync] Inserting vocabulary "${vocabulary.word}" (trigger will fire)...');

      // Use INSERT (not upsert) so the streak trigger fires on new vocabulary
      // If vocabulary already exists (duplicate id), this will fail silently
      await _client.from('vocabularies').insert({
        'id': vocabulary.id,
        'user_id': userId,
        'word': vocabulary.word,
        'part_of_speech': vocabulary.partOfSpeech,
        'thai_translation': vocabulary.thaiTranslation,
        'english_sentence': vocabulary.englishSentence,
        'thai_sentence': vocabulary.thaiSentence,
        'cefr_level': vocabulary.cefrLevel,
        'communicative_function': vocabulary.communicativeFunction,
        'language_variant': vocabulary.languageVariant,
        'image_url': vocabulary.imageUrl,
        'topic': vocabulary.topic,
        'tags': vocabulary.tags,
        'is_favorite': vocabulary.isFavorite,
        'created_at': vocabulary.createdAt.toIso8601String(),
        'updated_at': vocabulary.updatedAt?.toIso8601String() ?? vocabulary.createdAt.toIso8601String(),
      });

      print('✅ [Cloud Sync] Vocabulary inserted successfully - streak trigger fired');
      return true;
    } catch (e) {
      // Vocabulary might already exist (duplicate key) - that's OK
      print('⚠️ [Cloud Sync] Insert failed (likely duplicate): $e');
      // The streak trigger would have fired on first insert
      return false;
    }
  }

  /// Update vocabulary in Supabase
  Future<bool> updateInCloud(VocabularyModel vocabulary) async {
    if (!isLoggedIn) return false;

    try {
      await _client
          .from('vocabularies')
          .update({
            'word': vocabulary.word,
            'part_of_speech': vocabulary.partOfSpeech,
            'thai_translation': vocabulary.thaiTranslation,
            'english_sentence': vocabulary.englishSentence,
            'thai_sentence': vocabulary.thaiSentence,
            'cefr_level': vocabulary.cefrLevel,
            'communicative_function': vocabulary.communicativeFunction,
            'language_variant': vocabulary.languageVariant,
            'image_url': vocabulary.imageUrl,
            'topic': vocabulary.topic,
            'tags': vocabulary.tags,
            'is_favorite': vocabulary.isFavorite,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', vocabulary.id)
          .eq('user_id', currentUserId!);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete vocabulary from Supabase
  Future<bool> deleteFromCloud(String vocabularyId) async {
    if (!isLoggedIn) return false;

    try {
      await _client
          .from('vocabularies')
          .delete()
          .eq('id', vocabularyId)
          .eq('user_id', currentUserId!);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Fetch all vocabularies from Supabase for current user
  Future<List<VocabularyModel>> fetchFromCloud() async {
    if (!isLoggedIn) {
      throw CacheFailure('User not logged in');
    }

    try {
      final response = await _client
          .from('vocabularies')
          .select()
          .eq('user_id', currentUserId!)
          .order('created_at', ascending: false);

      // Handle empty response
      if (response == null) {
        return [];
      }

      // Convert to list safely
      final List<dynamic> vocabList = response is List ? response : [];

      return vocabList
          .map((json) {
            if (json is Map<String, dynamic>) {
              return VocabularyModel.fromSupabaseJson(json);
            } else {
              throw CacheFailure('Invalid vocabulary format');
            }
          })
          .toList();
    } catch (e) {
      throw CacheFailure('Failed to fetch vocabularies: ${e.toString()}');
    }
  }

  /// Batch upload multiple vocabularies to cloud
  /// Used when migrating from guest to registered user
  /// Returns number of successfully uploaded vocabularies
  Future<int> batchUpload(List<VocabularyModel> vocabularies) async {
    if (!isLoggedIn || vocabularies.isEmpty) {
      return 0;
    }

    int successCount = 0;
    final userId = currentUserId!;

    // Cache for uploaded images: local path -> cloud URL
    final uploadedImages = <String, String>{};
    // Upload vocabularies with image processing
    final data = <Map<String, dynamic>>[];

    try {

      for (final vocab in vocabularies) {
        String finalImageUrl = vocab.imageUrl;

        // Check if imageUrl is a local path (not http/https)
        if (_imageStorageService != null &&
            !vocab.imageUrl.startsWith('http') &&
            vocab.imageUrl.isNotEmpty) {
          try {
            // Check if we already uploaded this image
            if (uploadedImages.containsKey(vocab.imageUrl)) {
              // Reuse existing uploaded URL
              finalImageUrl = uploadedImages[vocab.imageUrl]!;
            } else {
              // Upload local image to cloud
              final cloudUrl = await _imageStorageService!.uploadVocabularyImage(
                imageFile: File(vocab.imageUrl),
                userId: userId,
              );
              finalImageUrl = cloudUrl;
              uploadedImages[vocab.imageUrl] = cloudUrl; // Cache it
            }
          } catch (e) {
            // Keep local path on error
          }
        }

        data.add({
          'id': vocab.id,
          'user_id': userId,
          'word': vocab.word,
          'part_of_speech': vocab.partOfSpeech,
          'thai_translation': vocab.thaiTranslation,
          'english_sentence': vocab.englishSentence,
          'thai_sentence': vocab.thaiSentence,
          'cefr_level': vocab.cefrLevel,
          'communicative_function': vocab.communicativeFunction,
          'language_variant': vocab.languageVariant,
          'image_url': finalImageUrl,  // Use cloud URL or fallback to local
          'topic': vocab.topic,
          'tags': vocab.tags,
          'is_favorite': vocab.isFavorite,
          'created_at': vocab.createdAt.toIso8601String(),
          'updated_at': vocab.updatedAt?.toIso8601String() ?? vocab.createdAt.toIso8601String(),
        });
      }

      // Batch insert
      await _client.from('vocabularies').insert(data);

      successCount = vocabularies.length;
    } catch (e) {
      // Fallback: upload individually using already-processed data (with cloud URLs)
      for (final item in data) {
        try {
          await _client.from('vocabularies').insert(item);
          successCount++;
        } catch (e) {
          // Skip failed items
        }
      }
    }

    return successCount;
  }

  /// Merge local vocabularies with cloud vocabularies
  /// Returns merged list (cloud data takes precedence for conflicts, but keeps local unique items)
  Future<List<VocabularyModel>> mergeWithCloud(List<VocabularyModel> localVocabs) async {
    if (!isLoggedIn) {
      return localVocabs;
    }

    try {
      // Fetch cloud vocabularies
      final cloudVocabs = await fetchFromCloud();

      // Create map for quick lookup
      final cloudMap = {for (var v in cloudVocabs) v.id: v};

      // Merge: cloud takes precedence, but keep local items not in cloud
      final mergedVocabs = <VocabularyModel>[];

      // Add all cloud vocabularies
      mergedVocabs.addAll(cloudVocabs);

      // Add local vocabularies that don't exist in cloud
      final localOnlyVocabs = <VocabularyModel>[];
      for (final localVocab in localVocabs) {
        if (!cloudMap.containsKey(localVocab.id)) {
          mergedVocabs.add(localVocab);
          localOnlyVocabs.add(localVocab);
        }
      }

      // Batch upload local-only vocabularies to cloud (faster than one-by-one)
      if (localOnlyVocabs.isNotEmpty) {
        await batchUpload(localOnlyVocabs);
      }

      // Sort by created date descending
      mergedVocabs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return mergedVocabs;
    } catch (e) {
      return localVocabs;
    }
  }

  /// Clear all vocabularies from cloud (for testing or user request)
  Future<bool> clearCloud() async {
    if (!isLoggedIn) return false;

    try {
      await _client
          .from('vocabularies')
          .delete()
          .eq('user_id', currentUserId!);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get vocabulary statistics from cloud
  Future<Map<String, int>> getCloudStats() async {
    if (!isLoggedIn) {
      return {'total': 0, 'favorites': 0, 'today': 0};
    }

    try {
      final response = await _client.rpc('get_user_vocabulary_count', params: {
        'user_uuid': currentUserId!,
      });

      if (response != null) {
        return {
          'total': response['total_count'] as int? ?? 0,
          'favorites': response['favorites_count'] as int? ?? 0,
          'today': response['today_count'] as int? ?? 0,
        };
      }

      return {'total': 0, 'favorites': 0, 'today': 0};
    } catch (e) {
      return {'total': 0, 'favorites': 0, 'today': 0};
    }
  }
}
