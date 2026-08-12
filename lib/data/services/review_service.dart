import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/word_card_model.dart';
import '../models/vocabulary_model.dart';
import '../models/user_stats_model.dart';
import 'hive_service.dart';

/// Review Service for Spaced Repetition System
/// Supports both Guest mode (Hive) and Registered mode (Supabase)
class ReviewService {
  final SupabaseClient _client;
  final HiveService _hiveService;

  ReviewService({
    SupabaseClient? client,
    required HiveService hiveService,
  })  : _client = client ?? Supabase.instance.client,
        _hiveService = hiveService;

  /// Get current user ID (null for guest)
  String? get currentUserId => _client.auth.currentSession?.user.id;

  /// Check if user is logged in (registered mode)
  bool get isLoggedIn => currentUserId != null;

  /// Expose HiveService for direct access (needed for user stats in guest mode)
  HiveService get hiveService => _hiveService;

  /// Get due cards for review (max 5)
  /// Guest: from Hive | Registered: from Supabase
  Future<List<WordCardModel>> getDueCards({int limit = 5, String? topicFilter}) async {
    final userId = currentUserId;

    if (userId == null) {
      // Guest mode: get from Hive
      return _getDueCardsFromHive(limit, topicFilter);
    } else {
      // Registered mode: get from Supabase
      return _getDueCardsFromSupabase(userId, limit, topicFilter);
    }
  }

  /// Get due cards from Hive (Guest mode)
  Future<List<WordCardModel>> _getDueCardsFromHive(int limit, String? topicFilter) async {
    try {
      final allCards = await _hiveService.getWordCards();
      final now = DateTime.now();

      // 🔍 DEBUG: Print all cards with due status
      print('🔍 _getDueCardsFromHive: Total cards = ${allCards.length}');
      print('🔍 Current time: $now (milliseconds: ${now.millisecondsSinceEpoch})');
      for (var card in allCards) {
        print('   Card ${card.id}: dueDate=${card.dueDate} (ms: ${card.dueDate.millisecondsSinceEpoch}), isDue=${card.isDue}');
      }

      // Filter due cards
      var dueCards = allCards.where((card) => card.isDue).toList();
      print('🔍 Due cards found: ${dueCards.length}');

      // Apply topic filter if specified
      if (topicFilter != null && topicFilter.isNotEmpty) {
        final beforeFilter = dueCards.length;
        print('🔍 Applying topic filter: $topicFilter');
        dueCards = dueCards.where((card) {
          final cardTopic = card.vocabulary?.topic;
          print('   Card ${card.id}: topic="$cardTopic", match=${cardTopic == topicFilter}');
          return cardTopic == topicFilter;
        }).toList();
        print('🔍 After filter: ${dueCards.length} cards (was $beforeFilter)');
      }

      // Sort by due date (FSRS determines when cards are due)
      dueCards.sort((a, b) => a.dueDate.compareTo(b.dueDate));

      // Limit
      return dueCards.take(limit).toList();
    } catch (e) {
      print('❌ Error getting due cards from Hive: $e');
      return [];
    }
  }

  /// Get due cards from Supabase (Registered mode)
  Future<List<WordCardModel>> _getDueCardsFromSupabase(String userId, int limit, String? topicFilter) async {
    try {
      print('🔍 _getDueCardsFromSupabase: userId=$userId, limit=$limit, topicFilter=$topicFilter');

      final response = await _client
          .rpc('get_due_cards', params: {
            'p_user_id': userId,
            'p_limit': limit,
            'p_topic_filter': topicFilter
          });

      print('🔍 Supabase response: $response');

      if (response == null) {
        print('🔍 Response is null');
        return [];
      }

      final List<dynamic> data = response as List<dynamic>;
      print('🔍 Data length: ${data.length}');

      // 🔍 DEBUG: Print ALL topics from response to see what's in database
      print('🔍 Topics in database response:');
      for (var item in data) {
        final json = item as Map<String, dynamic>;
        print('   - word: ${json['word']}, topic: "${json['topic']}" (type: ${json['topic'].runtimeType})');
      }

      final cards = data
          .map((json) => WordCardModel.fromSupabaseWithVocabulary(
              json as Map<String, dynamic>))
          .toList();

      // Debug: Print card info
      final now = DateTime.now();
      print('🔍 Current time: $now (ms: ${now.millisecondsSinceEpoch})');
      for (var card in cards) {
        print('   Card ${card.id}: dueDate=${card.dueDate} (ms: ${card.dueDate.millisecondsSinceEpoch}), isDue=${card.isDue}');
      }

      // Sort by due date (FSRS determines when cards are due)
      cards.sort((a, b) => a.dueDate.compareTo(b.dueDate));

      return cards;
    } catch (e) {
      print('❌ Error getting due cards from Supabase: $e');
      return [];
    }
  }

  /// Get new vocabularies (without cards) to fill session
  /// Returns vocabularies that don't have a word_card yet
  Future<List<VocabularyModel>> getNewVocabularies({int limit = 5, String? topicFilter}) async {
    final userId = currentUserId;

    if (userId == null) {
      // Guest mode: get from Hive
      return _getNewVocabulariesFromHive(limit, topicFilter);
    } else {
      // Registered mode: get from Supabase
      return _getNewVocabulariesFromSupabase(userId, limit, topicFilter);
    }
  }

  /// Get new vocabularies from Hive (Guest mode)
  Future<List<VocabularyModel>> _getNewVocabulariesFromHive(int limit, String? topicFilter) async {
    try {
      final allVocab = await _hiveService.getAllVocabulary();
      final allCards = await _hiveService.getWordCards();

      // Get IDs of vocabularies that already have cards
      final cardVocabIds = allCards.map((c) => c.vocabularyId).toSet();

      // Filter vocabularies without cards
      var newVocab = allVocab.where((v) => !cardVocabIds.contains(v.id)).toList();

      // Apply topic filter if specified
      if (topicFilter != null && topicFilter.isNotEmpty) {
        newVocab = newVocab.where((v) => v.topic == topicFilter).toList();
      }

      // Limit
      return newVocab.take(limit).toList();
    } catch (e) {
      print('❌ Error getting new vocabularies from Hive: $e');
      return [];
    }
  }

  /// Get new vocabularies from Supabase (Registered mode)
  Future<List<VocabularyModel>> _getNewVocabulariesFromSupabase(
      String userId, int limit, String? topicFilter) async {
    try {
      // Get vocabularies that don't have cards yet
      // First, get IDs of vocabularies that already have cards
      final existingCardsResponse = await _client
          .from('word_cards')
          .select('vocabulary_id')
          .eq('user_id', userId);

      final existingVocabIds = (existingCardsResponse as List<dynamic>?)
          ?.map((row) => row['vocabulary_id'] as String)
          .toList() ?? <String>[];

      // Then get vocabularies NOT in that list
      final response = existingVocabIds.isEmpty
          ? await _client
              .from('vocabularies')
              .select('id, word, part_of_speech, thai_translation, english_sentence, thai_sentence, cefr_level, communicative_function, language_variant, image_url, created_at, updated_at, tags, is_favorite, topic')
              .eq('user_id', userId)
              .limit(limit)
          : await _client
              .from('vocabularies')
              .select('id, word, part_of_speech, thai_translation, english_sentence, thai_sentence, cefr_level, communicative_function, language_variant, image_url, created_at, updated_at, tags, is_favorite, topic')
              .eq('user_id', userId)
              .not('id', 'in', existingVocabIds)
              .limit(limit);

      if (response == null) return [];

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map((json) => VocabularyModel.fromSupabaseJson(
              json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error getting new vocabularies from Supabase: $e');
      return [];
    }
  }

  /// Create a new word card for a vocabulary
  Future<WordCardModel?> createCard(String vocabularyId) async {
    final userId = currentUserId;

    if (userId == null) {
      // Guest mode: create in Hive
      return _createCardInHive(vocabularyId);
    } else {
      // Registered mode: create in Supabase
      return _createCardInSupabase(userId, vocabularyId);
    }
  }

  /// Create a new word card with vocabulary data included
  /// This ensures the card has vocabulary data immediately after creation
  Future<WordCardModel?> createCardWithVocabulary(String vocabularyId, VocabularyModel vocabulary) async {
    final userId = currentUserId;

    if (userId == null) {
      // Guest mode: create in Hive (already has vocab in _createCardInHive)
      return _createCardInHive(vocabularyId);
    } else {
      // Registered mode: create in Supabase and include vocab
      return _createCardInSupabaseWithVocabulary(userId, vocabularyId, vocabulary);
    }
  }

  /// Create card in Supabase with vocabulary data included
  Future<WordCardModel?> _createCardInSupabaseWithVocabulary(String userId, String vocabularyId, VocabularyModel vocabulary) async {
    try {
      final response = await _client.from('word_cards').insert({
        'user_id': userId,
        'vocabulary_id': vocabularyId,
        'due_date': DateTime.now().toIso8601String(),
      }).select();

      if (response == null || response.isEmpty) return null;

      final json = response.first as Map<String, dynamic>;
      final card = WordCardModel.fromSupabaseJson(json);

      // Include vocabulary data
      return card.copyWith(vocabulary: vocabulary);
    } catch (e) {
      print('❌ Error creating card in Supabase with vocab: $e');
      return null;
    }
  }

  /// Create card in Hive (Guest mode)
  Future<WordCardModel?> _createCardInHive(String vocabularyId) async {
    try {
      // Get vocabulary from Hive
      final allVocab = await _hiveService.getAllVocabulary();
      final vocabulary = allVocab.firstWhere((v) => v.id == vocabularyId);

      final card = WordCardModel(
        id: _generateId(),
        userId: 'guest',
        vocabularyId: vocabularyId,
        dueDate: DateTime.now().toUtc(),  // Use UTC for consistency
        createdAt: DateTime.now().toUtc(),  // Use UTC for consistency
        vocabulary: vocabulary,
      );

      await _hiveService.saveWordCard(card);
      return card;
    } catch (e) {
      print('❌ Error creating card in Hive: $e');
      return null;
    }
  }

  /// Create card in Supabase (Registered mode)
  Future<WordCardModel?> _createCardInSupabase(String userId, String vocabularyId) async {
    try {
      final response = await _client.from('word_cards').insert({
        'user_id': userId,
        'vocabulary_id': vocabularyId,
        'due_date': DateTime.now().toIso8601String(),
      }).select();

      if (response == null || response.isEmpty) return null;

      final json = response.first as Map<String, dynamic>;
      return WordCardModel.fromSupabaseJson(json);
    } catch (e) {
      print('❌ Error creating card in Supabase: $e');
      return null;
    }
  }

  /// Update card after review
  Future<WordCardModel?> updateCard(WordCardModel card) async {
    final userId = currentUserId;

    if (userId == null) {
      // Guest mode: update in Hive
      return _updateCardInHive(card);
    } else {
      // Registered mode: update in Supabase
      return _updateCardInSupabase(card);
    }
  }

  /// Update card in Hive (Guest mode)
  Future<WordCardModel?> _updateCardInHive(WordCardModel card) async {
    try {
      final updatedCard = card.copyWith(updatedAt: DateTime.now());
      await _hiveService.saveWordCard(updatedCard);
      return updatedCard;
    } catch (e) {
      print('❌ Error updating card in Hive: $e');
      return null;
    }
  }

  /// Update card in Supabase (Registered mode)
  Future<WordCardModel?> _updateCardInSupabase(WordCardModel card) async {
    try {
      final response = await _client
          .from('word_cards')
          .update(card.toSupabaseJson())
          .eq('id', card.id)
          .select();

      if (response == null || response.isEmpty) return null;

      final json = response.first as Map<String, dynamic>;
      return WordCardModel.fromSupabaseJson(json);
    } catch (e) {
      print('❌ Error updating card in Supabase: $e');
      return null;
    }
  }

  /// Get a complete review session (due cards + new cards to fill 5)
  /// Optionally filter by topic category
  Future<List<WordCardModel>> getReviewSession({String? topicFilter}) async {
    final userId = currentUserId;
    print('🔍 getReviewSession: userId=$userId, isLoggedIn=$isLoggedIn');

    // Get due cards first
    final dueCards = await getDueCards(limit: 5, topicFilter: topicFilter);
    print('🔍 getReviewSession: dueCards=${dueCards.length}');

    // If already have 5, return
    if (dueCards.length >= 5) {
      return dueCards;
    }

    // Fill with new vocabularies
    final needed = 5 - dueCards.length;
    final newVocab = await getNewVocabularies(limit: needed, topicFilter: topicFilter);

    // Create cards for new vocabularies with vocabulary data included
    final sessionCards = List<WordCardModel>.from(dueCards);
    for (final vocab in newVocab) {
      final card = await createCardWithVocabulary(vocab.id, vocab);
      if (card != null) {
        sessionCards.add(card);
      }
    }

    return sessionCards;
  }

  /// Check if there are more due cards available (for Continue button)
  Future<int> getRemainingDueCount({String? topicFilter}) async {
    final userId = currentUserId;

    if (userId == null) {
      // Guest mode: count from Hive
      return _getRemainingDueFromHive(topicFilter);
    } else {
      // Registered mode: count from Supabase
      return _getRemainingDueFromSupabase(userId, topicFilter);
    }
  }

  /// Get remaining due cards from Hive (Guest mode)
  Future<int> _getRemainingDueFromHive(String? topicFilter) async {
    try {
      final allCards = await _hiveService.getWordCards();
      final now = DateTime.now();

      // Filter and count due cards
      var dueCards = allCards.where((card) => card.isDue).toList();

      // Apply topic filter if specified
      if (topicFilter != null && topicFilter.isNotEmpty) {
        dueCards = dueCards.where((card) => card.vocabulary?.topic == topicFilter).toList();
      }

      return dueCards.length;
    } catch (e) {
      print('❌ Error counting due cards from Hive: $e');
      return 0;
    }
  }

  /// Get remaining due cards from Supabase (Registered mode)
  Future<int> _getRemainingDueFromSupabase(String userId, String? topicFilter) async {
    try {
      // Count all due cards (no limit)
      final response = await _client
          .rpc('get_due_cards', params: {
            'p_user_id': userId,
            'p_limit': 999,
            'p_topic_filter': topicFilter
          });

      if (response == null) return 0;

      final List<dynamic> data = response as List<dynamic>;
      return data.length;
    } catch (e) {
      print('❌ Error counting due cards from Supabase: $e');
      return 0;
    }
  }

  /// Get user statistics from storage (for adaptive time estimation)
  Future<Map<String, dynamic>> getUserStats() async {
    final userId = currentUserId;

    if (userId == null) {
      // Guest mode: get from Hive
      return _getUserStatsFromHive();
    } else {
      // Registered mode: get from Supabase
      return _getUserStatsFromSupabase(userId);
    }
  }

  /// Get user stats from Hive (Guest mode)
  Future<Map<String, dynamic>> _getUserStatsFromHive() async {
    try {
      final stats = await _hiveService.getUserStats();
      if (stats == null) return {};
      return stats.toJson();
    } catch (e) {
      print('❌ Error getting user stats from Hive: $e');
      return {};
    }
  }

  /// Get user stats from Supabase (Registered mode)
  Future<Map<String, dynamic>> _getUserStatsFromSupabase(String userId) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select('total_reviews, average_time_per_card')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return {};

      return {
        'totalReviewsCompleted': response['total_reviews'] as int? ?? 0,
        'averageTimePerCard': (response['average_time_per_card'] as num?)?.toDouble() ?? 7.0,
      };
    } catch (e) {
      print('❌ Error getting user stats from Supabase: $e');
      return {};
    }
  }

  /// Save user statistics to storage
  Future<void> saveUserStats({
    required int totalReviewsCompleted,
    required double averageTimePerCard,
  }) async {
    final userId = currentUserId;

    if (userId == null) {
      // Guest mode: save to Hive
      await _saveUserStatsToHive(totalReviewsCompleted, averageTimePerCard);
    } else {
      // Registered mode: save to Supabase
      await _saveUserStatsToSupabase(userId, totalReviewsCompleted, averageTimePerCard);
    }
  }

  /// Save user stats to Hive (Guest mode)
  Future<void> _saveUserStatsToHive(
    int totalReviewsCompleted,
    double averageTimePerCard,
  ) async {
    try {
      final stats = await _hiveService.getUserStats();
      final updatedStats = (stats ?? UserStatsModel(
        lastReviewDate: DateTime.now(),
        createdAt: DateTime.now(),
      )).copyWith(
        totalReviewsCompleted: totalReviewsCompleted,
        averageTimePerCard: averageTimePerCard,
        lastReviewDate: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _hiveService.saveUserStats(updatedStats);
    } catch (e) {
      print('❌ Error saving user stats to Hive: $e');
    }
  }

  /// Save user stats to Supabase (Registered mode)
  Future<void> _saveUserStatsToSupabase(
    String userId,
    int totalReviewsCompleted,
    double averageTimePerCard,
  ) async {
    try {
      // Check if user profile exists
      final existing = await _client
          .from('user_profiles')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existing == null) {
        // Create new profile
        await _client.from('user_profiles').insert({
          'user_id': userId,
          'total_reviews': totalReviewsCompleted,
          'average_time_per_card': averageTimePerCard,
        });
      } else {
        // Update existing profile
        await _client
            .from('user_profiles')
            .update({
              'total_reviews': totalReviewsCompleted,
              'average_time_per_card': averageTimePerCard,
            })
            .eq('user_id', userId);
      }
    } catch (e) {
      print('❌ Error saving user stats to Supabase: $e');
    }
  }

  /// Load more cards for review (when user clicks Continue)
  Future<List<WordCardModel>> getMoreCards({int batchSize = 5, List<String>? excludeIds, String? topicFilter}) async {
    final userId = currentUserId;

    if (userId == null) {
      // Guest mode: get from Hive
      return _getMoreCardsFromHive(batchSize, excludeIds, topicFilter);
    } else {
      // Registered mode: get from Supabase
      return _getMoreCardsFromSupabase(userId, batchSize, excludeIds, topicFilter);
    }
  }

  /// Get more cards from Hive (Guest mode)
  Future<List<WordCardModel>> _getMoreCardsFromHive(int batchSize, List<String>? excludeIds, String? topicFilter) async {
    try {
      final allCards = await _hiveService.getWordCards();
      final now = DateTime.now();

      // Filter due cards
      var dueCards = allCards.where((card) => card.isDue).toList();

      // Apply topic filter if specified
      if (topicFilter != null && topicFilter.isNotEmpty) {
        dueCards = dueCards.where((card) => card.vocabulary?.topic == topicFilter).toList();
      }

      // Exclude already reviewed cards
      if (excludeIds != null && excludeIds.isNotEmpty) {
        dueCards = dueCards.where((card) => !excludeIds.contains(card.id)).toList();
      }

      // Sort by due date
      dueCards.sort((a, b) => a.dueDate.compareTo(b.dueDate));

      // Limit
      return dueCards.take(batchSize).toList();
    } catch (e) {
      print('❌ Error getting more cards from Hive: $e');
      return [];
    }
  }

  /// Get more cards from Supabase (Registered mode)
  Future<List<WordCardModel>> _getMoreCardsFromSupabase(String userId, int batchSize, List<String>? excludeIds, String? topicFilter) async {
    try {
      // Get due cards with higher limit to get more
      final response = await _client
          .rpc('get_due_cards', params: {
            'p_user_id': userId,
            'p_limit': 100,
            'p_topic_filter': topicFilter
          });

      if (response == null) return [];

      final List<dynamic> data = response as List<dynamic>;
      var cards = data
          .map((json) => WordCardModel.fromSupabaseWithVocabulary(
              json as Map<String, dynamic>))
          .toList();

      // Exclude already reviewed cards
      if (excludeIds != null && excludeIds.isNotEmpty) {
        cards = cards.where((card) => !excludeIds.contains(card.id)).toList();
      }

      // Sort by due date (should already be sorted from RPC)
      cards.sort((a, b) => a.dueDate.compareTo(b.dueDate));

      // Limit
      return cards.take(batchSize).toList();
    } catch (e) {
      print('❌ Error getting more cards from Supabase: $e');
      return [];
    }
  }

  /// Generate unique ID for guest mode
  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }
}
