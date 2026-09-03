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
  Future<List<WordCardModel>> getDueCards(
      {int limit = 5, String? topicFilter}) async {
    final userId = currentUserId;
    if (userId == null) {
      // Guest mode: get from Hive
      final result = await _getDueCardsFromHive(limit, topicFilter);
      return result;
    } else {
      // Registered mode: get from Supabase
      final result = await _getDueCardsFromSupabase(userId, limit, topicFilter);
      return result;
    }
  }

  /// Get due cards from Hive (Guest mode)
  Future<List<WordCardModel>> _getDueCardsFromHive(
      int limit, String? topicFilter) async {
    try {
      final allCards = await _hiveService.getWordCards();

      // Filter due cards
      var dueCards = allCards.where((card) => card.isDue).toList();

      // Apply topic filter if specified
      if (topicFilter != null && topicFilter.isNotEmpty) {
        if (topicFilter.toLowerCase() == 'favorites') {
          dueCards = dueCards.where((card) => card.vocabulary?.isFavorite == true).toList();
        } else {
          dueCards = dueCards.where((card) {
            final cardTopic = card.vocabulary?.topic;
            return cardTopic == topicFilter;
          }).toList();
        }
      }

      // Sort by due date (FSRS determines when cards are due)
      dueCards.sort((a, b) => a.dueDate.compareTo(b.dueDate));

      // Limit
      return dueCards.take(limit).toList();
    } catch (e) {
      Error.throwWithStackTrace(e, StackTrace.current);
    }
  }

  /// Get due cards from Supabase (Registered mode)
  Future<List<WordCardModel>> _getDueCardsFromSupabase(
      String userId, int limit, String? topicFilter) async {
    try {
      final response = await _client.rpc('get_due_cards', params: {
        'p_user_id': userId,
        'p_limit': limit,
        'p_topic_filter': topicFilter
      });

      if (response == null) {
        return [];
      }

      final List<dynamic> data = response as List<dynamic>;

      final cards = data
          .map((json) => WordCardModel.fromSupabaseWithVocabulary(
              json as Map<String, dynamic>))
          .toList();

      // Sort by due date (FSRS determines when cards are due)
      cards.sort((a, b) => a.dueDate.compareTo(b.dueDate));

      return cards;
    } catch (e) {
      Error.throwWithStackTrace(e, StackTrace.current);
    }
  }

  /// Get new vocabularies (without cards) to fill session
  /// Returns vocabularies that don't have a word_card yet
  Future<List<VocabularyModel>> getNewVocabularies(
      {int limit = 5, String? topicFilter}) async {
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
  Future<List<VocabularyModel>> _getNewVocabulariesFromHive(
      int limit, String? topicFilter) async {
    try {
      final allVocab = await _hiveService.getAllVocabulary();
      final allCards = await _hiveService.getWordCards();

      // Get IDs of vocabularies that already have cards
      final cardVocabIds = allCards.map((c) => c.vocabularyId).toSet();

      // Filter vocabularies without cards
      var newVocab =
          allVocab.where((v) => !cardVocabIds.contains(v.id)).toList();

      // Apply topic filter if specified
      if (topicFilter != null && topicFilter.isNotEmpty) {
        if (topicFilter.toLowerCase() == 'favorites') {
          newVocab = newVocab.where((v) => v.isFavorite).toList();
        } else {
          newVocab = newVocab.where((v) => v.topic == topicFilter).toList();
        }
      }

      // Limit
      return newVocab.take(limit).toList();
    } catch (e) {
      print('❌ Error getting new vocabularies from Hive: $e');
      Error.throwWithStackTrace(e, StackTrace.current);
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
              .toList() ??
          <String>[];

      // Then get vocabularies NOT in that list
      var query = _client
          .from('vocabularies')
          .select(
              'id, word, part_of_speech, thai_translation, english_sentence, thai_sentence, cefr_level, communicative_function, language_variant, image_url, created_at, updated_at, tags, is_favorite, topic')
          .eq('user_id', userId);

      if (existingVocabIds.isNotEmpty) {
        query = query.not('id', 'in', existingVocabIds);
      }

      // Apply topic filter if specified
      if (topicFilter != null && topicFilter.isNotEmpty) {
        query = query.eq('topic', topicFilter);
      }

      final response = await query.limit(limit);

      if (response == null) return [];

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map((json) =>
              VocabularyModel.fromSupabaseJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error getting new vocabularies from Supabase: $e');
      Error.throwWithStackTrace(e, StackTrace.current);
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
  Future<WordCardModel?> createCardWithVocabulary(
      String vocabularyId, VocabularyModel vocabulary) async {
    final userId = currentUserId;

    if (userId == null) {
      // Guest mode: create in Hive (already has vocab in _createCardInHive)
      return _createCardInHive(vocabularyId);
    } else {
      // Registered mode: create in Supabase and include vocab
      return _createCardInSupabaseWithVocabulary(
          userId, vocabularyId, vocabulary);
    }
  }

  /// Create card in Supabase with vocabulary data included
  Future<WordCardModel?> _createCardInSupabaseWithVocabulary(
      String userId, String vocabularyId, VocabularyModel vocabulary) async {
    try {
      final response = await _client.from('word_cards').insert({
        'user_id': userId,
        'vocabulary_id': vocabularyId,
        'due_date': DateTime.now().toUtc().toIso8601String(),
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
        dueDate: DateTime.now().toUtc(), // Use UTC for consistency
        createdAt: DateTime.now().toUtc(), // Use UTC for consistency
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
  Future<WordCardModel?> _createCardInSupabase(
      String userId, String vocabularyId) async {
    try {
      final response = await _client.from('word_cards').insert({
        'user_id': userId,
        'vocabulary_id': vocabularyId,
        'due_date': DateTime.now().toUtc().toIso8601String(),
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
      final updatedCard = card.copyWith(updatedAt: DateTime.now().toUtc());
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
      final now = DateTime.now().toUtc();
      final updatedCard = card.copyWith(updatedAt: now);
      final response = await _client
          .from('word_cards')
          .update(updatedCard.toSupabaseJson())
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

  /// Get a complete review session (due cards + new cards to fill batchSize)
  /// Optionally filter by topic
  Future<List<WordCardModel>> getReviewSession(
      {String? topicFilter, int batchSize = 5}) async {
    final userId = currentUserId;

    // Get due cards first
    final dueCards =
        await getDueCards(limit: batchSize, topicFilter: topicFilter);

    // If already have batchSize, return
    if (dueCards.length >= batchSize) {
      return dueCards;
    }

    // Fill with new vocabularies
    final needed = batchSize - dueCards.length;
    final newVocab =
        await getNewVocabularies(limit: needed, topicFilter: topicFilter);

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

  /// Get total count of cards available for review (due + new)
  Future<int> getTotalAvailableCardsCount({String? topicFilter}) async {
    final userId = currentUserId;

    // 1. Count due cards
    final dueCount = await getRemainingDueCount(topicFilter: topicFilter);

    // 2. Count new vocabularies
    int newVocabCount = 0;
    if (userId == null) {
      // Guest mode
      final allVocab = await _hiveService.getAllVocabulary();
      final allCards = await _hiveService.getWordCards();
      final cardVocabIds = allCards.map((c) => c.vocabularyId).toSet();
      var newVocab =
          allVocab.where((v) => !cardVocabIds.contains(v.id)).toList();
      if (topicFilter != null && topicFilter.isNotEmpty) {
        newVocab = newVocab.where((v) => v.topic == topicFilter).toList();
      }
      newVocabCount = newVocab.length;
    } else {
      // Registered mode - count new vocabularies
      final existingCardsResponse = await _client
          .from('word_cards')
          .select('vocabulary_id')
          .eq('user_id', userId);

      final existingVocabIds = (existingCardsResponse as List<dynamic>?)
              ?.map((row) => row['vocabulary_id'] as String)
              .toList() ??
          <String>[];

      // Build query to get vocabularies without cards
      var query =
          _client.from('vocabularies').select('id').eq('user_id', userId);

      if (existingVocabIds.isNotEmpty) {
        query = query.not('id', 'in', existingVocabIds);
      }

      // Apply topic filter if specified
      if (topicFilter != null && topicFilter.isNotEmpty) {
        query = query.eq('topic', topicFilter);
      }

      final response = await query;
      newVocabCount = (response as List<dynamic>).length;
    }

    return dueCount + newVocabCount;
  }

  /// Returns the number of cards that can be reviewed for each topic.
  /// An available card is either already due or a new vocabulary without a card.
  Future<Map<String, int>> getAvailableCardCountsByTopic() async {
    final userId = currentUserId;
    final counts = <String, int>{};

    void addTopic(String? topic) {
      if (topic == null || topic.isEmpty) return;
      counts[topic] = (counts[topic] ?? 0) + 1;
    }

    if (userId == null) {
      final allCards = await _hiveService.getWordCards();
      final allVocabulary = await _hiveService.getAllVocabulary();
      final cardVocabularyIds =
          allCards.map((card) => card.vocabularyId).toSet();
      final vocabularyById = {
        for (final vocabulary in allVocabulary) vocabulary.id: vocabulary,
      };

      int favCount = 0;
      for (final card in allCards.where((card) => card.isDue)) {
        final vocab = card.vocabulary ?? vocabularyById[card.vocabularyId];
        addTopic(vocab?.topic);
        if (vocab?.isFavorite == true) favCount++;
      }
      for (final vocabulary in allVocabulary
          .where((vocabulary) => !cardVocabularyIds.contains(vocabulary.id))) {
        addTopic(vocabulary.topic);
        if (vocabulary.isFavorite) favCount++;
      }
      if (favCount > 0) {
        counts['favorites'] = favCount;
      }
      return counts;
    }

    // The RPC already applies the same due-date rules as review sessions.
    final dueCards = await getDueCards(limit: 10000);
    for (final card in dueCards) {
      addTopic(card.vocabulary?.topic);
    }

    final existingCardsResponse = await _client
        .from('word_cards')
        .select('vocabulary_id')
        .eq('user_id', userId);
    final existingVocabularyIds = (existingCardsResponse as List<dynamic>)
        .map((row) => row['vocabulary_id'] as String)
        .toSet();
    final vocabulariesResponse = await _client
        .from('vocabularies')
        .select('id, topic')
        .eq('user_id', userId);

    for (final row in vocabulariesResponse as List<dynamic>) {
      final vocabulary = row as Map<String, dynamic>;
      if (!existingVocabularyIds.contains(vocabulary['id'] as String)) {
        addTopic(vocabulary['topic'] as String?);
      }
    }
    return counts;
  }

    Future<UserStatsModel?> getUserStats() async {
    if (!isLoggedIn) return _hiveService.getUserStats();
    try {
      final response = await _client
          .from('users')
          .select('total_reviews')
          .eq('id', currentUserId!)
          .maybeSingle();
      if (response == null) return null;
      return UserStatsModel(
        totalReviewsCompleted: response['total_reviews'] as int? ?? 0,
        averageTimePerCard: 7.0, // Fixed, no longer tracked
        lastReviewDate: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUserStats({
    required int totalReviewsCompleted,
    double? averageTimePerCard,
  }) async {
    if (!isLoggedIn) {
      final current = await _hiveService.getUserStats();
      await _hiveService.saveUserStats(UserStatsModel(
        totalReviewsCompleted: totalReviewsCompleted,
        averageTimePerCard:
            averageTimePerCard ?? current?.averageTimePerCard ?? 7.0,
        lastReviewDate: DateTime.now(),
        createdAt: current?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      return;
    }
    await _client.from('users').update({
      'total_reviews': totalReviewsCompleted,
    }).eq('id', currentUserId!);
  }

  /// Get remaining due count (due cards only, no limit)
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
        if (topicFilter.toLowerCase() == 'favorites') {
          dueCards = dueCards
              .where((card) => card.vocabulary?.isFavorite == true)
              .toList();
        } else {
          dueCards = dueCards
              .where((card) => card.vocabulary?.topic == topicFilter)
              .toList();
        }
      }

      return dueCards.length;
    } catch (e) {
      print('❌ Error counting due cards from Hive: $e');
      Error.throwWithStackTrace(e, StackTrace.current);
    }
  }

  /// Get remaining due cards from Supabase (Registered mode)
  Future<int> _getRemainingDueFromSupabase(
      String userId, String? topicFilter) async {
    try {
      // Count all due cards (no limit)
      final response = await _client.rpc('get_due_cards', params: {
        'p_user_id': userId,
        'p_limit': 999,
        'p_topic_filter': topicFilter
      });

      if (response == null) return 0;

      final List<dynamic> data = response as List<dynamic>;
      return data.length;
    } catch (e) {
      print('❌ Error counting due cards from Supabase: $e');
      Error.throwWithStackTrace(e, StackTrace.current);
    }
  }

  /// Load more cards for review (when user clicks Continue)
  Future<List<WordCardModel>> getMoreCards(
      {int batchSize = 5,
      List<String>? excludeIds,
      String? topicFilter}) async {
    final userId = currentUserId;

    if (userId == null) {
      // Guest mode: get from Hive
      return _getMoreCardsFromHive(batchSize, excludeIds, topicFilter);
    } else {
      // Registered mode: get from Supabase
      return _getMoreCardsFromSupabase(
          userId, batchSize, excludeIds, topicFilter);
    }
  }

  /// Get more cards from Hive (Guest mode)
  Future<List<WordCardModel>> _getMoreCardsFromHive(
      int batchSize, List<String>? excludeIds, String? topicFilter) async {
    try {
      final allCards = await _hiveService.getWordCards();
      final now = DateTime.now();

      // Filter due cards
      var dueCards = allCards.where((card) => card.isDue).toList();

      // Apply topic filter if specified
      if (topicFilter != null && topicFilter.isNotEmpty) {
        if (topicFilter.toLowerCase() == 'favorites') {
          dueCards = dueCards
              .where((card) => card.vocabulary?.isFavorite == true)
              .toList();
        } else {
          dueCards = dueCards
              .where((card) => card.vocabulary?.topic == topicFilter)
              .toList();
        }
      }

      // Exclude already reviewed cards
      if (excludeIds != null && excludeIds.isNotEmpty) {
        dueCards =
            dueCards.where((card) => !excludeIds.contains(card.id)).toList();
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
  Future<List<WordCardModel>> _getMoreCardsFromSupabase(String userId,
      int batchSize, List<String>? excludeIds, String? topicFilter) async {
    try {
      // Get due cards with higher limit to get more
      final response = await _client.rpc('get_due_cards', params: {
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
