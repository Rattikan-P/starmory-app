import 'dart:io';
import 'dart:math' as math;
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/word_card_model.dart';
import '../../data/models/vocabulary_model.dart';
import '../../data/services/review_service.dart';

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
  static const String _keyRetention = 'widget_retention';
  static const String _keySentence = 'widget_sentence';
  static const String _keyHasData = 'widget_has_data';

  /// Initialize home_widget — call once at app startup.
  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  /// Push the Word of the Day (prioritizing due cards) and streak to the widget.
  /// Call after: app open, review session complete, or learning activity.
  static Future<void> updateWidgetWithDueCard(
    ReviewService reviewService, {
    int? streak,
  }) async {
    try {
      final currentStreak = streak ?? 0;
      final now = DateTime.now();
      final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
      final daySeed = now.year * 366 + dayOfYear;

      // 1. Try due cards first (FSRS review queue, rotated by date)
      final dueCards = await reviewService.getDueCards(limit: 50);

      if (dueCards.isNotEmpty) {
        final cardIndex = daySeed % dueCards.length;
        final card = dueCards[cardIndex];
        final vocab = card.vocabulary;
        if (vocab != null) {
          await _writeVocabToWidget(
            vocab: vocab,
            card: card,
            streak: currentStreak,
          );
          return;
        }
      }

      // 2. Fallback: If no due cards, pick from general vocabulary collection rotated by date
      final allVocab = await reviewService.hiveService.getAllVocabulary();
      if (allVocab.isNotEmpty) {
        final vocabIndex = daySeed % allVocab.length;
        final fallbackVocab = allVocab[vocabIndex];
        await _writeVocabToWidget(
          vocab: fallbackVocab,
          card: null,
          streak: currentStreak,
        );
        return;
      }

      // 3. No vocabulary exists at all -> Empty State
      await _clearWidgetData(streak: currentStreak);
    } catch (_) {
      // Never crash the app due to widget update failure
    }
  }

  static Future<void> _writeVocabToWidget({
    required VocabularyModel vocab,
    WordCardModel? card,
    required int streak,
  }) async {
    final imagePath = await _resolveLocalImagePath(vocab.imageUrl);
    final retentionPct =
        card != null ? _calculateRetentionPercent(card) : 0;
    final dateStr = _formatDate(DateTime.now());

    await HomeWidget.saveWidgetData(_keyWord, vocab.word);
    await HomeWidget.saveWidgetData(_keyTranslation, vocab.thaiTranslation);
    await HomeWidget.saveWidgetData(_keySentence, vocab.englishSentence);
    await HomeWidget.saveWidgetData(_keyPartOfSpeech, vocab.partOfSpeech);
    await HomeWidget.saveWidgetData(_keyCefrLevel, vocab.cefrLevel);
    await HomeWidget.saveWidgetData(_keyImagePath, imagePath);
    await HomeWidget.saveWidgetData(_keyVocabId, vocab.id);
    await HomeWidget.saveWidgetData(_keyDate, dateStr);
    await HomeWidget.saveWidgetData(_keyStreak, streak);
    await HomeWidget.saveWidgetData(_keyRetention, retentionPct);
    await HomeWidget.saveWidgetData(_keyHasData, true);

    await HomeWidget.updateWidget(androidName: _widgetName);
    await HomeWidget.updateWidget(androidName: _compactWidgetName);
  }

  /// Clear widget when no cards or vocabularies are available.
  static Future<void> _clearWidgetData({int streak = 0}) async {
    await HomeWidget.saveWidgetData(_keyHasData, false);
    await HomeWidget.saveWidgetData(_keyWord, '');
    await HomeWidget.saveWidgetData(_keyTranslation, '');
    await HomeWidget.saveWidgetData(_keyStreak, streak);
    await HomeWidget.updateWidget(androidName: _widgetName);
    await HomeWidget.updateWidget(androidName: _compactWidgetName);
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
      if (tempFile.existsSync() && tempFile.lengthSync() > 0) return tempFile.path;
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
        final age = DateTime.now().difference((await cacheFile.stat()).modified);
        if (age.inHours < 24) return cacheFile.path;
      }

      final httpClient = HttpClient()
        ..badCertificateCallback = ((cert, host, port) => true);
      try {
        final request = await httpClient.getUrl(uri);
        final response = await request.close();
        if (response.statusCode != 200) {
          print('⚠️ [Widget] Image download failed with status ${response.statusCode}');
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

    final retention = math.pow(0.9, daysSinceReview / card.stability).toDouble();
    return (retention * 100).round().clamp(0, 100);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}
