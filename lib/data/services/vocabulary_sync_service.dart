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
  Future<bool> saveToCloud(VocabularyModel vocabulary) async {
    if (!isLoggedIn) {
      // Guest user - don't sync to cloud
      return false;
    }

    try {
      final userId = currentUserId!;

      await _client.from('vocabularies').upsert({
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
        'tags': vocabulary.tags,
        'is_favorite': vocabulary.isFavorite,
        'created_at': vocabulary.createdAt.toIso8601String(),
        'updated_at': vocabulary.updatedAt?.toIso8601String() ?? vocabulary.createdAt.toIso8601String(),
      });

      return true;
    } catch (e) {
      print('❌ Error saving vocabulary to cloud: $e');
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
            'tags': vocabulary.tags,
            'is_favorite': vocabulary.isFavorite,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', vocabulary.id)
          .eq('user_id', currentUserId!);

      return true;
    } catch (e) {
      print('❌ Error updating vocabulary in cloud: $e');
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
      print('❌ Error deleting vocabulary from cloud: $e');
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

      return (response as List<dynamic>)
          .map((json) => VocabularyModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error fetching vocabularies from cloud: $e');
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

    try {
      // Upload vocabularies with image processing
      final data = <Map<String, dynamic>>[];

      for (final vocab in vocabularies) {
        String finalImageUrl = vocab.imageUrl;

        // Check if imageUrl is a local path (not http/https)
        if (_imageStorageService != null &&
            !vocab.imageUrl.startsWith('http') &&
            vocab.imageUrl.isNotEmpty) {
          try {
            // Upload local image to cloud
            final cloudUrl = await _imageStorageService!.uploadVocabularyImage(
              imageFile: File(vocab.imageUrl),
              userId: userId,
            );
            finalImageUrl = cloudUrl;
            print('✅ Uploaded image for ${vocab.word}: $cloudUrl');
          } catch (e) {
            print('⚠️ Failed to upload image for ${vocab.word}, using local path: $e');
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
          'tags': vocab.tags,
          'is_favorite': vocab.isFavorite,
          'created_at': vocab.createdAt.toIso8601String(),
          'updated_at': vocab.updatedAt?.toIso8601String() ?? vocab.createdAt.toIso8601String(),
        });
      }

      // Batch insert
      await _client.from('vocabularies').insert(data);

      successCount = vocabularies.length;
      print('✅ Uploaded $successCount vocabularies to cloud');
    } catch (e) {
      print('⚠️ Batch upload failed, trying individual uploads: $e');

      // Fallback: upload individually
      for (final vocab in vocabularies) {
        try {
          await saveToCloud(vocab);
          successCount++;
        } catch (e) {
          print('❌ Failed to upload vocabulary ${vocab.word}: $e');
        }
      }

      print('✅ Uploaded $successCount/${vocabularies.length} vocabularies individually');
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
      int newFromLocal = 0;
      for (final localVocab in localVocabs) {
        if (!cloudMap.containsKey(localVocab.id)) {
          mergedVocabs.add(localVocab);
          // Also upload this local-only vocabulary to cloud
          await saveToCloud(localVocab);
          newFromLocal++;
        } else {
          print('  ⚠️ Duplicate vocabulary found (cloud has it): ${localVocab.word}');
        }
      }

      // Sort by created date descending
      mergedVocabs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print('✅ Merged vocabularies: ${cloudVocabs.length} from cloud + $newFromLocal new from local = ${mergedVocabs.length} total');

      return mergedVocabs;
    } catch (e) {
      print('⚠️ Failed to merge with cloud, using local only: $e');
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
      print('❌ Error clearing cloud vocabularies: $e');
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
      print('❌ Error fetching cloud stats: $e');
      return {'total': 0, 'favorites': 0, 'today': 0};
    }
  }
}
