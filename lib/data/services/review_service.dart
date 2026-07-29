import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/word_card_model.dart';
import '../models/vocabulary_model.dart';
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

  /// Get due cards for review (max 5)
  /// Guest: from Hive | Registered: from Supabase
  Future<List<WordCardModel>> getDueCards({int limit = 5}) async {
    final userId = currentUserId;

    if (userId == null) {
      // Guest mode: get from Hive
      return _getDueCardsFromHive(limit);
    } else {
      // Registered mode: get from Supabase
      return _getDueCardsFromSupabase(userId, limit);
    }
  }

  /// Get due cards from Hive (Guest mode)
  Future<List<WordCardModel>> _getDueCardsFromHive(int limit) async {
    try {
      final allCards = await _hiveService.getWordCards();
      final now = DateTime.now();

      // Filter due cards
      final dueCards = allCards.where((card) => card.isDue).toList();

      // Sort by due date
      dueCards.sort((a, b) => a.dueDate.compareTo(b.dueDate));

      // Limit
      return dueCards.take(limit).toList();
    } catch (e) {
      print('❌ Error getting due cards from Hive: $e');
      return [];
    }
  }

  /// Get due cards from Supabase (Registered mode)
  Future<List<WordCardModel>> _getDueCardsFromSupabase(String userId, int limit) async {
    try {
      final response = await _client
          .rpc('get_due_cards', params: {'p_user_id': userId, 'p_limit': limit});

      if (response == null) return [];

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map((json) => WordCardModel.fromSupabaseWithVocabulary(
              json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error getting due cards from Supabase: $e');
      return [];
    }
  }

  /// Get new vocabularies (without cards) to fill session
  /// Returns vocabularies that don't have a word_card yet
  Future<List<VocabularyModel>> getNewVocabularies({int limit = 5}) async {
    final userId = currentUserId;

    if (userId == null) {
      // Guest mode: get from Hive
      return _getNewVocabulariesFromHive(limit);
    } else {
      // Registered mode: get from Supabase
      return _getNewVocabulariesFromSupabase(userId, limit);
    }
  }

  /// Get new vocabularies from Hive (Guest mode)
  Future<List<VocabularyModel>> _getNewVocabulariesFromHive(int limit) async {
    try {
      final allVocab = await _hiveService.getAllVocabulary();
      final allCards = await _hiveService.getWordCards();

      // Get IDs of vocabularies that already have cards
      final cardVocabIds = allCards.map((c) => c.vocabularyId).toSet();

      // Filter vocabularies without cards
      final newVocab = allVocab.where((v) => !cardVocabIds.contains(v.id)).toList();

      // Limit
      return newVocab.take(limit).toList();
    } catch (e) {
      print('❌ Error getting new vocabularies from Hive: $e');
      return [];
    }
  }

  /// Get new vocabularies from Supabase (Registered mode)
  Future<List<VocabularyModel>> _getNewVocabulariesFromSupabase(
      String userId, int limit) async {
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
              .select('id, word, part_of_speech, thai_translation, english_sentence, thai_sentence, cefr_level, communicative_function, language_variant, image_url, created_at, updated_at, tags, is_favorite')
              .eq('user_id', userId)
              .limit(limit)
          : await _client
              .from('vocabularies')
              .select('id, word, part_of_speech, thai_translation, english_sentence, thai_sentence, cefr_level, communicative_function, language_variant, image_url, created_at, updated_at, tags, is_favorite')
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
        dueDate: DateTime.now(),
        createdAt: DateTime.now(),
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
  Future<List<WordCardModel>> getReviewSession() async {
    // Get due cards first
    final dueCards = await getDueCards(limit: 5);

    // If already have 5, return
    if (dueCards.length >= 5) {
      return dueCards;
    }

    // Fill with new vocabularies
    final needed = 5 - dueCards.length;
    final newVocab = await getNewVocabularies(limit: needed);

    // Create cards for new vocabularies
    final sessionCards = List<WordCardModel>.from(dueCards);
    for (final vocab in newVocab) {
      final card = await createCard(vocab.id);
      if (card != null) {
        sessionCards.add(card);
      }
    }

    return sessionCards;
  }

  /// Generate unique ID for guest mode
  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }
}
