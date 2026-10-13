import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/scrapbook_model.dart';
import '../../data/models/word_card_model.dart';
import '../../data/models/vocabulary_model.dart';
import '../../data/services/review_service.dart';
import 'widget_vocabulary_selection.dart';

/// Bridges Flutter app data → Android Home Screen Widget.
/// Writes the "Word of the Day" (prioritizing FSRS due cards) and streak
/// to SharedPreferences so the native widget can read it without Flutter running.
class WidgetService {
  static const String _appGroupId = 'com.example.starmory_app';
  static const String _widgetName = 'VocabWidgetProvider';
  static const String _compactWidgetName = 'VocabCompactWidgetProvider';

  // SharedPreferences keys (must match VocabWidgetProvider.kt)
  static const String _keyWord = 'widget_word';
  static const String _keyTranslation = 'widget_translation';
  static const String _keyPartOfSpeech = 'widget_part_of_speech';
  static const String _keyCefrLevel = 'widget_cefr_level';
  static const String _keyImagePath = 'widget_image_path';
  static const String _keyVocabId = 'widget_vocab_id';
  static const String _keyDate = 'widget_date';
  static const String _keyStreak = 'widget_streak';
  static const String _keyStreakShields = 'widget_streak_shields';
  static const String _keyLastActivityDate = 'widget_last_activity_date';
  static const String _keyRetention = 'widget_retention';
  static const String _keySentence = 'widget_sentence';
  static const String _keyHasData = 'widget_has_data';
  static const String _keyHasError = 'widget_has_error';
  static const String _keyVocabQueue = 'widget_vocab_queue';
  static const String _keyDueVocabularyCount = 'widget_due_vocabulary_count';

  /// Initialize home_widget — call once at app startup.
  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  /// Push the Word of the Day (prioritizing due cards) and streak to the widget.
  /// Call after: app open, review session complete, or learning activity.
  static Future<void> updateWidgetWithDueCard(
    ReviewService reviewService, {
    int? streak,
    DateTime? lastActivityDate,
    int? shields,
  }) async {
    final currentStreak = streak ?? 0;
    final currentShields = shields ?? 0;
    late final List<WordCardModel> dueCards;
    late final List<VocabularyModel> allVocab;
    late final List<ScrapbookModel> scrapbooks;
    try {
      dueCards = await reviewService.getDueCards(limit: 1000);
      allVocab = await reviewService.hiveService.getAllVocabulary();
      scrapbooks = await reviewService.hiveService.getAllScrapbooks();
    } catch (error, stackTrace) {
      debugPrint('Failed to load vocabulary for widget: $error\n$stackTrace');
      await _writeErrorState(
        streak: currentStreak,
        lastActivityDate: lastActivityDate,
        shields: currentShields,
      );
      return;
    }

    try {
      final now = DateTime.now();
      final localDate = DateTime.utc(now.year, now.month, now.day);
      final dayOfYear =
          localDate.difference(DateTime.utc(now.year, 1, 1)).inDays + 1;
      final daySeed = now.year * 366 + dayOfYear;

      final dueVocabs = dueCards
          .map((c) => c.vocabulary)
          .whereType<VocabularyModel>()
          .toList();
      final orderedVocabs = WidgetVocabularySelection.buildQueue(
        dueVocabulary: dueVocabs,
        libraryVocabulary: allVocab,
      );
      final scrapbookDateByVocabulary =
          WidgetVocabularySelection.buildScrapbookDateLookup(
        vocabularies: orderedVocabs,
        scrapbooks: scrapbooks,
      );
      final dueVocabularyCount =
          dueVocabs.map((vocabulary) => vocabulary.id).toSet().length;

      // Cache all vocabulary for Native Midnight AlarmManager
      if (orderedVocabs.isNotEmpty) {
        final queue = <Map<String, String>>[];
        for (final v in orderedVocabs) {
          final img = await _resolveLocalImagePath(v.imageUrl);
          final scrapbookDate = scrapbookDateByVocabulary[v.id] ?? v.createdAt;
          queue.add({
            'word': v.word,
            'translation': v.thaiTranslation,
            'sentence': v.englishSentence,
            'imagePath': img,
            'vocabId': v.id,
            'date': _formatDate(scrapbookDate),
          });
        }
        await HomeWidget.saveWidgetData(_keyVocabQueue, jsonEncode(queue));
      } else {
        await HomeWidget.saveWidgetData(_keyVocabQueue, '[]');
      }
      await HomeWidget.saveWidgetData(
        _keyDueVocabularyCount,
        dueVocabularyCount,
      );

      final selectedVocab = WidgetVocabularySelection.selectForDay(
        queue: orderedVocabs,
        dueVocabularyCount: dueVocabularyCount,
        daySeed: daySeed,
      );
      if (selectedVocab != null) {
        final matchingCard = dueCards
            .where((c) => c.vocabulary?.id == selectedVocab.id)
            .firstOrNull;

        await _writeVocabToWidget(
          vocab: selectedVocab,
          card: matchingCard,
          scrapbookDate: scrapbookDateByVocabulary[selectedVocab.id] ??
              selectedVocab.createdAt,
          streak: currentStreak,
          lastActivityDate: lastActivityDate,
          shields: currentShields,
        );
        return;
      }

      await _clearWidgetData(
        streak: currentStreak,
        lastActivityDate: lastActivityDate,
        shields: currentShields,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to update home screen widget: $error\n$stackTrace');
      await _writeErrorState(
        streak: currentStreak,
        lastActivityDate: lastActivityDate,
        shields: currentShields,
      );
    }
  }

  static Future<void> _writeVocabToWidget({
    required VocabularyModel vocab,
    WordCardModel? card,
    required DateTime scrapbookDate,
    required int streak,
    required DateTime? lastActivityDate,
    required int shields,
  }) async {
    final imagePath = await _resolveLocalImagePath(vocab.imageUrl);
    final retentionPct = card != null ? _calculateRetentionPercent(card) : 0;
    final dateStr = _formatDate(scrapbookDate);

    await HomeWidget.saveWidgetData(_keyWord, vocab.word);
    await HomeWidget.saveWidgetData(_keyTranslation, vocab.thaiTranslation);
    await HomeWidget.saveWidgetData(_keySentence, vocab.englishSentence);
    await HomeWidget.saveWidgetData(_keyPartOfSpeech, vocab.partOfSpeech);
    await HomeWidget.saveWidgetData(_keyCefrLevel, vocab.cefrLevel);
    await HomeWidget.saveWidgetData(_keyImagePath, imagePath);
    await HomeWidget.saveWidgetData(_keyVocabId, vocab.id);
    await HomeWidget.saveWidgetData(_keyDate, dateStr);
    await _saveStreakData(
      streak: streak,
      lastActivityDate: lastActivityDate,
      shields: shields,
    );
    await HomeWidget.saveWidgetData(_keyRetention, retentionPct);
    await HomeWidget.saveWidgetData(_keyHasData, true);
    await HomeWidget.saveWidgetData(_keyHasError, false);

    await HomeWidget.updateWidget(androidName: _widgetName);
    await HomeWidget.updateWidget(androidName: _compactWidgetName);
  }

  /// Clear widget when no cards or vocabularies are available.
  static Future<void> _clearWidgetData({
    required int streak,
    required DateTime? lastActivityDate,
    required int shields,
  }) async {
    await HomeWidget.saveWidgetData(_keyHasData, false);
    await HomeWidget.saveWidgetData(_keyHasError, false);
    await HomeWidget.saveWidgetData(_keyWord, '');
    await HomeWidget.saveWidgetData(_keyTranslation, '');
    await _saveStreakData(
      streak: streak,
      lastActivityDate: lastActivityDate,
      shields: shields,
    );
    await HomeWidget.saveWidgetData(_keyDueVocabularyCount, 0);
    await HomeWidget.saveWidgetData(_keyVocabQueue, '[]');
    await HomeWidget.updateWidget(androidName: _widgetName);
    await HomeWidget.updateWidget(androidName: _compactWidgetName);
  }

  static Future<void> _writeErrorState({
    required int streak,
    required DateTime? lastActivityDate,
    required int shields,
  }) async {
    await HomeWidget.saveWidgetData(_keyHasData, false);
    await HomeWidget.saveWidgetData(_keyHasError, true);
    await HomeWidget.saveWidgetData(_keyWord, '');
    await _saveStreakData(
      streak: streak,
      lastActivityDate: lastActivityDate,
      shields: shields,
    );
    await HomeWidget.updateWidget(androidName: _widgetName);
    await HomeWidget.updateWidget(androidName: _compactWidgetName);
  }

  static Future<void> _saveStreakData({
    required int streak,
    required DateTime? lastActivityDate,
    required int shields,
  }) async {
    await HomeWidget.saveWidgetData(_keyStreak, streak);
    await HomeWidget.saveWidgetData(_keyStreakShields, shields);
    await HomeWidget.saveWidgetData(
      _keyLastActivityDate,
      lastActivityDate?.toLocal().toIso8601String().split('T').first ?? '',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Image Cache Bridge
  // Android RemoteViews can only show Bitmaps from local files — not URLs.
  // ─────────────────────────────────────────────────────────────────────────

  /// Resolve image URL/path → absolute local file path the widget can read.
  static Future<String> _resolveLocalImagePath(String imageUrl) async {
    if (imageUrl.isEmpty) return '';

    // 1. If file:// URI
    String cleanPath = imageUrl;
    if (cleanPath.startsWith('file://')) {
      try {
        cleanPath = Uri.parse(cleanPath).toFilePath();
      } catch (_) {
        cleanPath = cleanPath.substring(7);
      }
    }

    // 2. Direct existing file on disk
    final directFile = File(cleanPath);
    if (directFile.existsSync() && directFile.lengthSync() > 0) {
      return directFile.path;
    }

    // 3. HTTP / HTTPS URL
    if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
      return await _downloadAndCache(cleanPath);
    }

    // 4. Try finding inside App Documents / Temporary directory
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final docFile = File('${docDir.path}/$cleanPath');
      if (docFile.existsSync() && docFile.lengthSync() > 0) return docFile.path;

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$cleanPath');
      if (tempFile.existsSync() && tempFile.lengthSync() > 0)
        return tempFile.path;
    } catch (_) {}

    return '';
  }

  /// Download a remote image and cache it locally.
  static Future<String> _downloadAndCache(String url) async {
    try {
      final uri = Uri.parse(url);
      final baseName = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last.split('?').first
          : 'img.jpg';
      final urlHash = url.hashCode.abs();
      final cacheFileName = 'widget_img_${urlHash}_$baseName';

      final cacheDir = await _getWidgetCacheDir();
      final cacheFile = File('${cacheDir.path}/$cacheFileName');

      if (await cacheFile.exists() && await cacheFile.length() > 0) {
        final age =
            DateTime.now().difference((await cacheFile.stat()).modified);
        if (age.inHours < 24) return cacheFile.path;
      }

      final httpClient = HttpClient()
        ..badCertificateCallback = ((cert, host, port) => true);
      try {
        final request = await httpClient.getUrl(uri);
        final response = await request.close();
        if (response.statusCode != 200) {
          print(
              '⚠️ [Widget] Image download failed with status ${response.statusCode}');
          return '';
        }

        final sink = cacheFile.openWrite();
        await response.pipe(sink);
        await sink.flush();
        await sink.close();
      } finally {
        httpClient.close();
      }

      return (await cacheFile.exists() && await cacheFile.length() > 0)
          ? cacheFile.path
          : '';
    } catch (e) {
      print('⚠️ [Widget] Error caching widget image: $e');
      return '';
    }
  }

  static Future<Directory> _getWidgetCacheDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/widget_image_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FSRS Retention Calculation
  // ─────────────────────────────────────────────────────────────────────────

  static int _calculateRetentionPercent(WordCardModel card) {
    if (card.stability <= 0 || card.lastReview == null) return 0;

    final daysSinceReview =
        DateTime.now().difference(card.lastReview!).inMinutes / 1440.0;

    if (daysSinceReview <= 0) return 90;

    final retention =
        math.pow(0.9, daysSinceReview / card.stability).toDouble();
    return (retention * 100).round().clamp(0, 100);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  static String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}
