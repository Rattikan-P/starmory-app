import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-Speech Service
/// Singleton service for managing TTS functionality across the app
class TTSService {
  // Singleton pattern
  TTSService._internal();
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;

  FlutterTts? _flutterTts;
  bool _isInitialized = false;

  // Configuration defaults
  static const double _defaultSpeechRate = 0.5;
  static const double _defaultVolume = 1.0;
  static const double _defaultPitch = 1.0;

  // Current configuration
  double _speechRate = _defaultSpeechRate;
  double _volume = _defaultVolume;
  double _pitch = _defaultPitch;

  // Stream controllers for TTS events
  final StreamController<void> _onCompleteController = StreamController.broadcast();
  final StreamController<String> _onErrorController = StreamController.broadcast();

  /// Stream that emits when TTS completes speaking
  Stream<void> get onComplete => _onCompleteController.stream;

  /// Stream that emits when TTS encounters an error
  Stream<String> get onError => _onErrorController.stream;

  /// Initialize the TTS service
  /// Can be called multiple times safely (idempotent)
  Future<void> initialize({
    double? speechRate,
    double? volume,
    double? pitch,
  }) async {
    if (_isInitialized) {
      debugPrint('🔊 TTSService already initialized');
      return;
    }

    try {
      _flutterTts = FlutterTts();

      // Set configuration
      _speechRate = speechRate ?? _defaultSpeechRate;
      _volume = volume ?? _defaultVolume;
      _pitch = pitch ?? _defaultPitch;

      await _flutterTts!.setSpeechRate(_speechRate);
      await _flutterTts!.setVolume(_volume);
      await _flutterTts!.setPitch(_pitch);

      // Set up completion handler
      _flutterTts!.setCompletionHandler(() {
        if (!_onCompleteController.isClosed) {
          _onCompleteController.add(null);
        }
      });

      // Set up error handler
      _flutterTts!.setErrorHandler((message) {
        debugPrint('🔊 TTS Error: $message');
        if (!_onErrorController.isClosed) {
          _onErrorController.add(message);
        }
      });

      _isInitialized = true;
      debugPrint('🔊 TTSService initialized');
    } catch (e) {
      debugPrint('🔊 Failed to initialize TTSService: $e');
      rethrow;
    }
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Speak the given text
  ///
  /// Parameters:
  /// - [text]: The text to speak
  /// - [language]: Optional language code (e.g., 'en-US', 'en-GB'). If null, uses current language.
  /// - [autoInit]: If true (default), initializes service if not already initialized
  ///
  /// Returns the estimated duration for the speech based on text length
  Duration speak(
    String text, {
    String? language,
    bool autoInit = true,
  }) {
    if (autoInit && !_isInitialized) {
      // Initialize synchronously if not already done
      // Note: This will return immediately, actual initialization happens async
      initialize();
    }

    if (_flutterTts == null) {
      debugPrint('🔊 TTSService not initialized');
      return Duration.zero;
    }

    if (language != null) {
      _flutterTts!.setLanguage(language);
    }

    _flutterTts!.speak(text);

    // Calculate estimated duration for fallback timeout
    // ~150ms per character, clamped between 500ms and 3000ms
    final estimatedMs = (text.length * 150).clamp(500, 3000);
    return Duration(milliseconds: estimatedMs);
  }

  /// Stop any currently playing speech
  Future<void> stop() async {
    if (_flutterTts != null) {
      await _flutterTts!.stop();
    }
  }

  /// Set the speech rate
  /// Range: typically 0.0 to 1.0 (platform dependent)
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    if (_flutterTts != null) {
      await _flutterTts!.setSpeechRate(rate);
    }
  }

  /// Set the volume
  /// Range: 0.0 to 1.0
  Future<void> setVolume(double volume) async {
    _volume = volume;
    if (_flutterTts != null) {
      await _flutterTts!.setVolume(volume);
    }
  }

  /// Set the pitch
  /// Range: typically 0.5 to 2.0 (platform dependent)
  Future<void> setPitch(double pitch) async {
    _pitch = pitch;
    if (_flutterTts != null) {
      await _flutterTts!.setPitch(pitch);
    }
  }

  /// Set the language for speech
  /// Common codes: 'en-US', 'en-GB', 'th-TH', etc.
  Future<void> setLanguage(String language) async {
    if (_flutterTts != null) {
      await _flutterTts!.setLanguage(language);
    }
  }

  /// Get current language code from variant ('US' or 'UK')
  static String getLanguageCode(String? variant) {
    return variant == 'UK' ? 'en-GB' : 'en-US';
  }

  /// Get available languages (platform dependent)
  Future<List<String>> getLanguages() async {
    if (_flutterTts == null) {
      return [];
    }
    return await _flutterTts!.getLanguages;
  }

  /// Get available voices (platform dependent)
  Future<List<String>> getVoices() async {
    if (_flutterTts == null) {
      return [];
    }
    return await _flutterTts!.getVoices;
  }

  /// Check if speech is currently in progress
  /// Note: This may not be available on all platforms
  Future<bool> isSpeaking() async {
    if (_flutterTts == null) {
      return false;
    }
    // FlutterTts doesn't have a built-in isSpeaking getter
    // This is a placeholder for future implementation if needed
    return false;
  }

  /// Dispose of resources
  /// Call this when the app is shutting down
  Future<void> dispose() async {
    await stop();
    await _onCompleteController.close();
    await _onErrorController.close();
    _flutterTts = null;
    _isInitialized = false;
    debugPrint('🔊 TTSService disposed');
  }
}
