import 'dart:convert';
import 'package:http/http.dart' as http;

/// Models for Dictionary API responses
class DictionaryEntry {
  final String word;
  final String? phonetic;
  final String? audio;
  final List<Meaning> meanings;

  DictionaryEntry({
    required this.word,
    this.phonetic,
    this.audio,
    required this.meanings,
  });

  factory DictionaryEntry.fromJson(Map<String, dynamic> json) {
    // Get phonetic text
    String? phonetic = json['phonetic'] as String?;

    // Get audio URL
    String? audio;
    if (json['phonetics'] != null && json['phonetics'] is List) {
      final phonetics = json['phonetics'] as List;
      for (final p in phonetics) {
        if (p is Map && p['audio'] != null && p['audio'].toString().isNotEmpty) {
          audio = p['audio'];
          break;
        }
      }
    }

    // Get meanings
    final meanings = <Meaning>[];
    if (json['meanings'] != null && json['meanings'] is List) {
      for (final m in json['meanings']) {
        if (m is Map) {
          meanings.add(Meaning.fromJson(Map<String, dynamic>.from(m)));
        }
      }
    }

    return DictionaryEntry(
      word: json['word'] as String? ?? '',
      phonetic: phonetic,
      audio: audio,
      meanings: meanings,
    );
  }
}

class Meaning {
  final String partOfSpeech;
  final List<String> definitions;
  final List<String> examples;
  final List<String> synonyms;
  final List<String> antonyms;

  Meaning({
    required this.partOfSpeech,
    required this.definitions,
    this.examples = const [],
    this.synonyms = const [],
    this.antonyms = const [],
  });

  factory Meaning.fromJson(Map<String, dynamic> json) {
    // Get definitions
    final definitions = <String>[];
    if (json['definitions'] != null && json['definitions'] is List) {
      for (final d in json['definitions']) {
        if (d is Map && d['definition'] != null) {
          definitions.add(d['definition'] as String);
        }
      }
    }

    // Get examples
    final examples = <String>[];
    if (json['examples'] != null && json['examples'] is List) {
      for (final e in json['examples']) {
        if (e is String) {
          examples.add(e);
        }
      }
    }

    // Get synonyms
    final synonyms = <String>[];
    if (json['synonyms'] != null && json['synonyms'] is List) {
      for (final s in json['synonyms']) {
        if (s is String) {
          synonyms.add(s);
        }
      }
    }

    // Get antonyms
    final antonyms = <String>[];
    if (json['antonyms'] != null && json['antonyms'] is List) {
      for (final a in json['antonyms']) {
        if (a is String) {
          antonyms.add(a);
        }
      }
    }

    return Meaning(
      partOfSpeech: json['partOfSpeech'] as String? ?? '',
      definitions: definitions,
      examples: examples,
      synonyms: synonyms,
      antonyms: antonyms,
    );
  }
}

/// Service for fetching dictionary data from Free Dictionary API
class DictionaryService {
  final http.Client _client;
  static const String _baseUrl = 'https://api.dictionaryapi.dev/api/v2/entries/en';

  DictionaryService({http.Client? client})
      : _client = client ?? http.Client();

  /// Fetch dictionary entry for a word
  /// Returns the first entry if multiple are found
  Future<DictionaryEntry?> getWordDefinition(String word) async {
    try {
      // Clean the word - trim whitespace and convert to lowercase for API
      final cleanWord = word.trim().toLowerCase();
      print('🔍 Fetching definition for: $cleanWord (original: $word)');

      // Use Uri.encodeComponent to properly encode the word for URL
      final url = '$_baseUrl/${Uri.encodeComponent(cleanWord)}';
      print('📍 URL: $url');

      final response = await _client.get(
        Uri.parse(url),
      ).timeout(
        const Duration(seconds: 10),
      );

      print('📡 Status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('✅ Parsed ${data.length} entries');
        if (data.isNotEmpty) {
          final entry = DictionaryEntry.fromJson(Map<String, dynamic>.from(data[0]));
          print('✅ Definition loaded: ${entry.word}, ${entry.meanings.length} meanings');
          return entry;
        } else {
          print('⚠️ No entries found in response');
        }
      } else if (response.statusCode == 404) {
        print('⚠️ Word not found in dictionary API: $cleanWord');
        print('💡 This word may not exist in the Free Dictionary API database');
        print('💡 Try checking spelling or try a more common English word');
      } else {
        print('❌ Unexpected status code: ${response.statusCode}');
        print('📄 Response: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');
      }
      return null;
    } catch (e, stackTrace) {
      print('❌ Error fetching dictionary definition: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Get multiple words definitions at once
  Future<Map<String, DictionaryEntry?>> getMultipleDefinitions(List<String> words) async {
    final results = <String, DictionaryEntry?>{};

    for (final word in words) {
      results[word] = await getWordDefinition(word);
    }

    return results;
  }

  void dispose() {
    _client.close();
  }
}
