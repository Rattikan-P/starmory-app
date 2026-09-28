import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import 'hive_service.dart';

/// Persists the calendar days on which a user generated vocabulary or reviewed.
class LearningActivityService {
  final HiveService _hiveService;
  final SupabaseClient _client;

  LearningActivityService({
    required HiveService hiveService,
    SupabaseClient? client,
  })  : _hiveService = hiveService,
        _client = client ?? Supabase.instance.client;

  Future<void> recordActivityDay(UserModel user, DateTime activityTime) async {
    final day = _dayKey(activityTime);
    if (user.isGuest) {
      await _hiveService.recordLearningActivityDay(day);
      return;
    }

    await _client.from('learning_activity_days').upsert(
      {
        'user_id': user.id,
        'activity_date': day,
      },
      onConflict: 'user_id,activity_date',
      ignoreDuplicates: true,
    );
  }

  Future<Set<String>> getLearningDays(UserModel? user) async {
    if (user == null) return <String>{};

    // Seed from locally available records so previously saved learning data
    // remains represented while the activity-day log fills in going forward.
    final days = await _hiveService.getLearningActivityDays();
    final vocabularies = await _hiveService.getAllVocabulary();
    for (final vocabulary in vocabularies) {
      days.add(_dayKey(vocabulary.createdAt));
    }
    final wordCards = await _hiveService.getWordCards();
    for (final card in wordCards) {
      final lastReview = card.lastReview;
      if (lastReview != null) days.add(_dayKey(lastReview));
    }

    if (user.isGuest) return days;

    try {
      final activityRows = await _client
          .from('learning_activity_days')
          .select('activity_date')
          .eq('user_id', user.id);
      for (final row in activityRows) {
        final value = row['activity_date'] as String?;
        if (value != null && value.length >= 10) {
          days.add(value.substring(0, 10));
        }
      }
    } catch (_) {
      // The local records below still provide a useful count if the activity
      // log table has not been migrated yet or the request is unavailable.
    }

    try {
      final vocabularyRows = await _client
          .from('vocabularies')
          .select('created_at')
          .eq('user_id', user.id);
      for (final row in vocabularyRows) {
        final value = row['created_at'] as String?;
        if (value != null) days.add(_dayKey(DateTime.parse(value)));
      }
    } catch (_) {}

    try {
      final reviewRows = await _client
          .from('word_cards')
          .select('last_review')
          .eq('user_id', user.id)
          .not('last_review', 'is', null);
      for (final row in reviewRows) {
        final value = row['last_review'] as String?;
        if (value != null) days.add(_dayKey(DateTime.parse(value)));
      }
    } catch (_) {}

    return days;
  }

  String _dayKey(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
