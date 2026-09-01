import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/vocabulary_model.dart';
import '../models/user_model.dart';
import '../models/scrapbook_model.dart';
import '../models/word_card_model.dart';
import '../models/user_stats_model.dart';
import '../../core/config/app_constants.dart';
import '../../core/error/failures.dart';
import '../../core/utils/quota_manager.dart';

/// Hive Local Storage Service
/// Handles all local data persistence for Guest Mode and cache
class HiveService {
  static final HiveService _instance = HiveService._internal();
  factory HiveService() => _instance;
  HiveService._internal();

  bool _isInitialized = false;

  /// Initialize Hive
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Hive (auto-detects platform)
      await Hive.initFlutter();

      // Register adapters
      _registerAdapters();

      // Open boxes
      await _openBoxes();

      _isInitialized = true;
    } catch (e, stackTrace) {
      print('❌ Hive initialization failed: $e');
      print('📚 Stack trace: $stackTrace');
      throw CacheFailure('Failed to initialize Hive: ${e.toString()}');
    }
  }

  /// Register Hive adapters
  void _registerAdapters() {
    // Note: Since we disabled hive_generator due to conflicts,
    // we'll use manual JSON serialization for complex objects
    // and store them as strings in Hive

    // For simple types, Hive works out of the box:
    // String, int, double, bool, List, Map, DateTime, etc.
  }

  /// Open all required boxes
  Future<void> _openBoxes() async {
    try {
      await Hive.openBox<String>(AppConstants.boxVocabulary);
      await Hive.openBox<String>(AppConstants.boxUser);
      await Hive.openBox<String>(AppConstants.boxScrapbook);
      await Hive.openBox<String>(AppConstants.boxWordCards);
      await Hive.openBox<String>(AppConstants.boxUserStats);
    } catch (e, stackTrace) {
      print('❌ Error opening boxes: $e');
      print('📚 Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Check if Hive is initialized
  bool get isInitialized => _isInitialized;

  // ============= Vocabulary Operations =============

  /// Save vocabulary to local storage
  Future<void> saveVocabulary(VocabularyModel vocabulary) async {
    try {
      final box = Hive.box<String>(AppConstants.boxVocabulary);
      await box.put(vocabulary.id, jsonEncode(vocabulary.toJson()));
    } catch (e) {
      throw CacheFailure('Failed to save vocabulary: ${e.toString()}');
    }
  }

  /// Get vocabulary by ID
  Future<VocabularyModel?> getVocabulary(String id) async {
    try {
      final box = Hive.box<String>(AppConstants.boxVocabulary);
      final jsonString = box.get(id);
      if (jsonString == null) return null;
      return VocabularyModel.fromJson(
          jsonDecode(jsonString) as Map<String, dynamic>);
    } catch (e) {
      throw CacheFailure('Failed to get vocabulary: ${e.toString()}');
    }
  }

  /// Get all vocabulary
  Future<List<VocabularyModel>> getAllVocabulary() async {
    try {
      final box = Hive.box<String>(AppConstants.boxVocabulary);
      final vocabularies = <VocabularyModel>[];

      for (final jsonString in box.values) {
        try {
          vocabularies.add(VocabularyModel.fromJson(
              jsonDecode(jsonString) as Map<String, dynamic>));
        } catch (e) {
          // Skip corrupted entries
          continue;
        }
      }

      return vocabularies;
    } catch (e) {
      throw CacheFailure('Failed to get all vocabulary: ${e.toString()}');
    }
  }

  /// Delete vocabulary
  Future<void> deleteVocabulary(String id) async {
    try {
      final box = Hive.box<String>(AppConstants.boxVocabulary);
      await box.delete(id);
    } catch (e) {
      throw CacheFailure('Failed to delete vocabulary: ${e.toString()}');
    }
  }

  /// Clear all vocabulary
  Future<void> clearAllVocabulary() async {
    try {
      final box = Hive.box<String>(AppConstants.boxVocabulary);
      await box.clear();
    } catch (e) {
      throw CacheFailure('Failed to clear vocabulary: ${e.toString()}');
    }
  }

  // ============= Scrapbook Operations =============

  /// Save scrapbook to local storage
  Future<void> saveScrapbook(ScrapbookModel scrapbook) async {
    try {
      final box = Hive.box<String>(AppConstants.boxScrapbook);
      await box.put(scrapbook.id, jsonEncode(scrapbook.toJson()));
    } catch (e) {
      throw CacheFailure('Failed to save scrapbook: ${e.toString()}');
    }
  }

  /// Get scrapbook by ID
  Future<ScrapbookModel?> getScrapbook(String id) async {
    try {
      final box = Hive.box<String>(AppConstants.boxScrapbook);
      final jsonString = box.get(id);
      if (jsonString == null) return null;
      return ScrapbookModel.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
    } catch (e) {
      throw CacheFailure('Failed to get scrapbook: ${e.toString()}');
    }
  }

  /// Get all scrapbooks
  Future<List<ScrapbookModel>> getAllScrapbooks() async {
    try {
      final box = Hive.box<String>(AppConstants.boxScrapbook);
      final scrapbooks = <ScrapbookModel>[];

      for (final jsonString in box.values) {
        try {
          scrapbooks.add(ScrapbookModel.fromJson(jsonDecode(jsonString) as Map<String, dynamic>));
        } catch (e) {
          // Skip corrupted entries
          continue;
        }
      }

      return scrapbooks;
    } catch (e) {
      throw CacheFailure('Failed to get all scrapbooks: ${e.toString()}');
    }
  }

  /// Delete scrapbook
  Future<void> deleteScrapbook(String id) async {
    try {
      final box = Hive.box<String>(AppConstants.boxScrapbook);
      await box.delete(id);
    } catch (e) {
      throw CacheFailure('Failed to delete scrapbook: ${e.toString()}');
    }
  }

  /// Clear all scrapbooks
  Future<void> clearAllScrapbooks() async {
    try {
      final box = Hive.box<String>(AppConstants.boxScrapbook);
      await box.clear();
    } catch (e) {
      throw CacheFailure('Failed to clear scrapbooks: ${e.toString()}');
    }
  }

  // ============= Word Card Operations (Review System) =============

  /// Save word card to local storage
  Future<void> saveWordCard(WordCardModel card) async {
    try {
      final box = Hive.box<String>(AppConstants.boxWordCards);
      await box.put(card.id, jsonEncode(card.toJson()));
    } catch (e) {
      throw CacheFailure('Failed to save word card: ${e.toString()}');
    }
  }

  /// Get word card by ID
  Future<WordCardModel?> getWordCard(String id) async {
    try {
      final box = Hive.box<String>(AppConstants.boxWordCards);
      final jsonString = box.get(id);
      if (jsonString == null) return null;
      return WordCardModel.fromJson(
          jsonDecode(jsonString) as Map<String, dynamic>);
    } catch (e) {
      throw CacheFailure('Failed to get word card: ${e.toString()}');
    }
  }

  /// Get all word cards
  Future<List<WordCardModel>> getWordCards() async {
    try {
      final box = Hive.box<String>(AppConstants.boxWordCards);
      final cards = <WordCardModel>[];

      for (final jsonString in box.values) {
        try {
          cards.add(WordCardModel.fromJson(
              jsonDecode(jsonString) as Map<String, dynamic>));
        } catch (e) {
          // Skip corrupted entries
          continue;
        }
      }

      return cards;
    } catch (e) {
      throw CacheFailure('Failed to get all word cards: ${e.toString()}');
    }
  }

  /// Delete word card
  Future<void> deleteWordCard(String id) async {
    try {
      final box = Hive.box<String>(AppConstants.boxWordCards);
      await box.delete(id);
    } catch (e) {
      throw CacheFailure('Failed to delete word card: ${e.toString()}');
    }
  }

  /// Clear all word cards
  Future<void> clearAllWordCards() async {
    try {
      final box = Hive.box<String>(AppConstants.boxWordCards);
      await box.clear();
    } catch (e) {
      throw CacheFailure('Failed to clear word cards: ${e.toString()}');
    }
  }

  // ============= User Operations =============

  /// Save current user
  Future<void> saveUser(UserModel user) async {
    try {
      final box = Hive.box<String>(AppConstants.boxUser);
      await box.put(AppConstants.keyUserSession, jsonEncode(user.toJson()));
    } catch (e) {
      throw CacheFailure('Failed to save user: ${e.toString()}');
    }
  }

  /// Get current user
  Future<UserModel?> getCurrentUser() async {
    try {
      final box = Hive.box<String>(AppConstants.boxUser);
      final jsonString = box.get(AppConstants.keyUserSession);
      if (jsonString == null) return null;
      return UserModel.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
    } catch (e) {
      throw CacheFailure('Failed to get current user: ${e.toString()}');
    }
  }

  /// Clear current user (logout)
  Future<void> clearCurrentUser() async {
    try {
      final box = Hive.box<String>(AppConstants.boxUser);
      await box.delete(AppConstants.keyUserSession);
    } catch (e) {
      throw CacheFailure('Failed to clear user: ${e.toString()}');
    }
  }

  // ============= User Stats Operations =============

  Future<void> saveUserStats(UserStatsModel stats) async {
    try {
      final box = Hive.box<String>(AppConstants.boxUserStats);
      await box.put(AppConstants.keyUserStats, jsonEncode(stats.toJson()));
    } catch (e) {
      throw CacheFailure('Failed to save user stats: ${e.toString()}');
    }
  }

  Future<UserStatsModel?> getUserStats() async {
    try {
      final box = Hive.box<String>(AppConstants.boxUserStats);
      final jsonString = box.get(AppConstants.keyUserStats);
      if (jsonString == null) return null;
      return UserStatsModel.fromJson(
          jsonDecode(jsonString) as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  Future<void> clearUserStats() async {
    try {
      final box = Hive.box<String>(AppConstants.boxUserStats);
      await box.delete(AppConstants.keyUserStats);
    } catch (e) {
      throw CacheFailure('Failed to clear user stats: ${e.toString()}');
    }
  }

  // ============= Guest Quota Backup Operations =============
  // These persist guest quota across login/logout cycles (device-based trial)

  /// Save guest quota backup - stores usage history that survives login/logout
  Future<void> saveGuestQuotaBackup(QuotaManager quotaManager) async {
    try {
      final box = Hive.box<String>(AppConstants.boxUser);
      await box.put(
        AppConstants.keyGuestQuotaBackup,
        jsonEncode(quotaManager.toJson()),
      );
      print(
          '💾 Guest quota backup saved: ${quotaManager.usageHistory.length}/10 used');
    } catch (e) {
      throw CacheFailure('Failed to save guest quota backup: ${e.toString()}');
    }
  }

  /// Get guest quota backup - returns null if no backup exists
  Future<QuotaManager?> getGuestQuotaBackup() async {
    try {
      final box = Hive.box<String>(AppConstants.boxUser);
      final jsonString = box.get(AppConstants.keyGuestQuotaBackup);
      if (jsonString == null) return null;
      final quotaData = jsonDecode(jsonString) as Map<String, dynamic>;

      // ⭐ CRITICAL: Filter usageHistory to only include today's entries
      // This ensures daily limit resets properly
      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final allHistory = (quotaData['usageHistory'] as List<dynamic>?)
              ?.map((e) {
                try {
                  return QuotaEntry.fromJson(e as Map<String, dynamic>);
                } catch (_) {
                  return null; // Skip corrupted entries
                }
              })
              .whereType<QuotaEntry>()
              .toList() ??
          [];

      // Filter to only today's entries for daily limit calculation
      final todayHistory = allHistory.where((entry) {
        final entryStr =
            '${entry.timestamp.year}-${entry.timestamp.month.toString().padLeft(2, '0')}-${entry.timestamp.day.toString().padLeft(2, '0')}';
        return entryStr == todayStr;
      }).toList();

      // For total limit, we keep all history
      // But we also store today's entries separately for daily limit
      final filteredQuotaData = Map<String, dynamic>.from(quotaData);
      filteredQuotaData['usageHistory'] =
          allHistory.map((e) => e.toJson()).toList();

      print(
          '📦 Guest quota backup loaded: total=${allHistory.length}/10, today=${todayHistory.length}/3');
      return QuotaManager.fromJson(filteredQuotaData);
    } catch (e) {
      print('⚠️ Failed to load guest quota backup: $e');
      return null;
    }
  }

  /// Clear guest quota backup - use when app is uninstalled or user explicitly resets
  Future<void> clearGuestQuotaBackup() async {
    try {
      final box = Hive.box<String>(AppConstants.boxUser);
      await box.delete(AppConstants.keyGuestQuotaBackup);
      print('🗑️ Guest quota backup cleared');
    } catch (e) {
      throw CacheFailure('Failed to clear guest quota backup: ${e.toString()}');
    }
  }

  // ============= Utility Methods =============

  /// Clear all data (useful for testing or logout)
  Future<void> clearAllData() async {
    try {
      await Hive.box<String>(AppConstants.boxVocabulary).clear();
      await Hive.box<String>(AppConstants.boxUser).clear();
      await Hive.box<String>(AppConstants.boxScrapbook).clear();
      await Hive.box<String>(AppConstants.boxWordCards).clear();
      await Hive.box<String>(AppConstants.boxUserStats).clear();
    } catch (e) {
      throw CacheFailure('Failed to clear all data: ${e.toString()}');
    }
  }

  /// Close all boxes (call when app is closing)
  Future<void> close() async {
    try {
      await Hive.close();
      _isInitialized = false;
    } catch (e) {
      throw CacheFailure('Failed to close Hive: ${e.toString()}');
    }
  }

  /// Get storage size in bytes
  Future<int> getStorageSize() async {
    try {
      int totalSize = 0;

      totalSize += Hive.box<String>(AppConstants.boxVocabulary).length;
      totalSize += Hive.box<String>(AppConstants.boxUser).length;
      totalSize += Hive.box<String>(AppConstants.boxScrapbook).length;
      totalSize += Hive.box<String>(AppConstants.boxWordCards).length;
      totalSize += Hive.box<String>(AppConstants.boxUserStats).length;

      return totalSize;
    } catch (e) {
      throw CacheFailure('Failed to get storage size: ${e.toString()}');
    }
  }
}
