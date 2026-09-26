import 'dart:io';
import 'dart:math' as math;
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/word_card_model.dart';
import '../../data/services/review_service.dart';

/// Bridges Flutter app data → Android Home Screen Widget.
/// Writes the "most urgent due vocab" to SharedPreferences
/// so the native widget can read it without Flutter running.
class WidgetService {
  static const String _appGroupId = 'com.example.starmory_app';
  static const String _widgetName = 'VocabWidgetProvider';

  // SharedPreferences keys (must match VocabWidgetProvider.kt)
  static const String _keyWord = 'widget_word';
  static const String _keyTranslation = 'widget_translation';
  static const String _keyPartOfSpeech = 'widget_part_of_speech';
  static const String _keyCefrLevel = 'widget_cefr_level';
  static const String _keyImagePath = 'widget_image_path';
  static const String _keyVocabId = 'widget_vocab_id';
  static const String _keyDate = 'widget_date';
  static const String _keyRetention = 'widget_retention';
  static const String _keyHasData = 'widget_has_data';

  /// Initialize home_widget — call once at app startup.
  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  /// Push the most urgent due card to the widget.
  /// Call after: app open, review session complete, or background refresh.
  static Future<void> updateWidgetWithDueCard(ReviewService reviewService) async {
    try {
      final dueCards = await reviewService.getDueCards(limit: 1);

      if (dueCards.isEmpty) {
        await _clearWidgetData();
        return;
      }

      final card = dueCards.first;
      final vocab = card.vocabulary;
      if (vocab == null) {
        await _clearWidgetData();
        return;
      }

      // Resolve local image path — widget cannot load URLs directly.
      // Downloads Supabase URL to local cache if needed.
      final imagePath = await _resolveLocalImagePath(vocab.imageUrl);

      // Calculate approximate retention % from FSRS stability
      final retentionPct = _calculateRetentionPercent(card);

      // Format date nicely (e.g. "Sep 26")
      final dateStr = _formatDate(DateTime.now());

      // Write all data to SharedPreferences via home_widget
      await HomeWidget.saveWidgetData(_keyWord, vocab.word);
      await HomeWidget.saveWidgetData(_keyTranslation, vocab.thaiTranslation);
      await HomeWidget.saveWidgetData(_keyPartOfSpeech, vocab.partOfSpeech);
      await HomeWidget.saveWidgetData(_keyCefrLevel, vocab.cefrLevel);
      await HomeWidget.saveWidgetData(_keyImagePath, imagePath);
      await HomeWidget.saveWidgetData(_keyVocabId, vocab.id);
      await HomeWidget.saveWidgetData(_keyDate, dateStr);
      await HomeWidget.saveWidgetData(_keyRetention, retentionPct);
      await HomeWidget.saveWidgetData(_keyHasData, true);

      // Tell Android to redraw the widget
      await HomeWidget.updateWidget(androidName: _widgetName);
    } catch (_) {
      // Never crash the app due to widget update failure
    }
  }

  /// Clear widget when no due cards available.
  static Future<void> _clearWidgetData() async {
    await HomeWidget.saveWidgetData(_keyHasData, false);
    await HomeWidget.saveWidgetData(_keyWord, '');
    await HomeWidget.saveWidgetData(_keyTranslation, '');
    await HomeWidget.updateWidget(androidName: _widgetName);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Image Cache Bridge
  // Android RemoteViews can only show Bitmaps from local files — not URLs.
  // So Supabase signed URLs must be downloaded and cached locally first.
  // ─────────────────────────────────────────────────────────────────────────

  /// Resolve image URL/path → absolute local file path the widget can read.
  static Future<String> _resolveLocalImagePath(String imageUrl) async {
    if (imageUrl.isEmpty) return '';
    if (imageUrl.startsWith('/')) return imageUrl;
    if (imageUrl.startsWith('file://')) return imageUrl.substring(7);
    if (imageUrl.startsWith('http')) return _downloadAndCache(imageUrl);
    return '';
  }

  /// Download a remote image (Supabase signed URL) and cache it locally.
  ///
  /// Cache key = URL hash → same vocab image won't be re-downloaded within 24h.
  /// Returns the local file path on success, or '' on any error.
  static Future<String> _downloadAndCache(String url) async {
    try {
      // Stable cache filename: urlHash + original filename (without query params)
      final uri = Uri.parse(url);
      final baseName = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last.split('?').first
          : 'img.jpg';
      final urlHash = url.hashCode.abs();
      final cacheFileName = 'widget_img_${urlHash}_$baseName';

      final cacheDir = await _getWidgetCacheDir();
      final cacheFile = File('${cacheDir.path}/$cacheFileName');

      // Serve from cache if fresh (< 24 hours old)
      if (await cacheFile.exists()) {
        final age = DateTime.now().difference((await cacheFile.stat()).modified);
        if (age.inHours < 24) return cacheFile.path;
      }

      // Download from Supabase
      final httpClient = HttpClient();
      try {
        final request = await httpClient.getUrl(uri);
        final response = await request.close();
        if (response.statusCode != 200) return '';

        // Stream bytes to disk
        final sink = cacheFile.openWrite();
        await response.pipe(sink);
        await sink.flush();
        await sink.close();
      } finally {
        httpClient.close();
      }

      return cacheFile.path;
    } catch (_) {
      return '';
    }
  }

  /// Returns the widget image cache directory, creating it if needed.
  static Future<Directory> _getWidgetCacheDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/widget_image_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FSRS Retention Calculation
  // ─────────────────────────────────────────────────────────────────────────

  /// Approximate FSRS retrieval probability as integer percent (0–100).
  ///
  /// Formula: R(t) = 0.9^(t/S)
  ///   t = days since last review
  ///   S = stability (FSRS parameter)
  static int _calculateRetentionPercent(WordCardModel card) {
    if (card.stability <= 0 || card.lastReview == null) return 0;

    final daysSinceReview =
        DateTime.now().difference(card.lastReview!).inMinutes / 1440.0;

    if (daysSinceReview <= 0) return 90;

    // Use dart:math pow — safe for floating-point exponents
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
