import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/vocabulary_model.dart';
import '../models/user_model.dart';
import '../../core/config/app_constants.dart';
import '../../core/error/failures.dart';

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
      print('🔧 Initializing Hive...');

      // Initialize Hive (auto-detects platform)
      await Hive.initFlutter();
      print('✅ Hive.initFlutter() successful');

      // Register adapters
      _registerAdapters();
      print('✅ Adapters registered');

      // Open boxes
      await _openBoxes();
      print('✅ Boxes opened');

      _isInitialized = true;
      print('✅ Hive initialization complete');
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
      print('📦 Opening ${AppConstants.boxVocabulary} box...');
      await Hive.openBox<String>(AppConstants.boxVocabulary);
      print('✅ ${AppConstants.boxVocabulary} box opened');

      print('📦 Opening ${AppConstants.boxUser} box...');
      await Hive.openBox<String>(AppConstants.boxUser);
      print('✅ ${AppConstants.boxUser} box opened');
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
      return VocabularyModel.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
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
          vocabularies.add(VocabularyModel.fromJson(jsonDecode(jsonString) as Map<String, dynamic>));
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

  // ============= Utility Methods =============

  /// Clear all data (useful for testing or logout)
  Future<void> clearAllData() async {
    try {
      await Hive.box<String>(AppConstants.boxVocabulary).clear();
      await Hive.box<String>(AppConstants.boxUser).clear();
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

      return totalSize;
    } catch (e) {
      throw CacheFailure('Failed to get storage size: ${e.toString()}');
    }
  }
}
