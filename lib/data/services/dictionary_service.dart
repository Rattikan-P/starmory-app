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
  static final Map<String, DictionaryEntry> _cache = {};

  DictionaryService({http.Client? client})
      : _client = client ?? http.Client();

  /// Clear the dictionary cache (useful for testing or memory release)
  static void clearCache() {
    _cache.clear();
  }

  /// Fetch dictionary entry for a word
  /// Returns the first entry if multiple are found
  Future<DictionaryEntry?> getWordDefinition(String word) async {
    try {
      // Clean the word - trim whitespace, lowercase, remove punctuation except hyphens/spaces
      final cleanWord = word.trim().toLowerCase().replaceAll(RegExp(r'[^a-zA-Z\s-]'), '');
      if (cleanWord.isEmpty) return null;

      // Check in-memory cache first
      if (_cache.containsKey(cleanWord)) {
        print('⚡ Cache hit for definition: $cleanWord');
        return _cache[cleanWord];
      }

      print('🔍 Fetching definition for: $cleanWord (original: $word)');

      // Try primary Free Dictionary API with 2.5s timeout
      try {
        final url = '$_baseUrl/${Uri.encodeComponent(cleanWord)}';
        final response = await _client.get(
          Uri.parse(url),
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'StarmoryApp/1.0',
          },
        ).timeout(const Duration(milliseconds: 2500));

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          if (data.isNotEmpty) {
            final entry = DictionaryEntry.fromJson(Map<String, dynamic>.from(data[0]));
            _cache[cleanWord] = entry;
            print('✅ Definition loaded from primary API: ${entry.word}');
            return entry;
          }
        }
      } catch (e) {
        print('ℹ️ Primary dictionary API timed out/failed for "$cleanWord", trying fallback...');
      }

      // Fast fallback to Datamuse API (99.9% uptime & sub-second response)
      final fallbackEntry = await _fetchFromDatamuse(cleanWord);
      if (fallbackEntry != null) {
        return fallbackEntry;
      }

      return null;
    } catch (e) {
      print('ℹ️ Dictionary lookup note for "$word": $e');
      return null;
    }
  }

  /// High-availability fallback dictionary parser using Datamuse API
  Future<DictionaryEntry?> _fetchFromDatamuse(String cleanWord) async {
    try {
      final url = 'https://api.datamuse.com/words?sp=${Uri.encodeComponent(cleanWord)}&md=dp';
      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'StarmoryApp/1.0',
        },
      ).timeout(const Duration(milliseconds: 2500));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final first = data.firstWhere(
            (item) => (item['word'] as String? ?? '').toLowerCase() == cleanWord,
            orElse: () => data.first,
          );

          final defs = (first['defs'] as List<dynamic>?)?.cast<String>() ?? [];
          if (defs.isNotEmpty) {
            final Map<String, List<String>> posMap = {};
            for (final defStr in defs) {
              final parts = defStr.split('\t');
              if (parts.length >= 2) {
                final posCode = parts[0].trim().toLowerCase();
                final definition = parts[1].trim();
                String pos;
                switch (posCode) {
                  case 'n':
                    pos = 'noun';
                    break;
                  case 'v':
                    pos = 'verb';
                    break;
                  case 'adj':
                    pos = 'adjective';
                    break;
                  case 'adv':
                    pos = 'adverb';
                    break;
                  default:
                    pos = posCode.isNotEmpty ? posCode : 'general';
                }
                posMap.putIfAbsent(pos, () => []).add(definition);
              }
            }

            final meanings = posMap.entries.map((e) {
              return Meaning(
                partOfSpeech: e.key,
                definitions: e.value,
              );
            }).toList();

            if (meanings.isNotEmpty) {
              final entry = DictionaryEntry(
                word: cleanWord,
                meanings: meanings,
              );
              _cache[cleanWord] = entry;
              print('✅ Definition loaded from Datamuse fallback: $cleanWord');
              return entry;
            }
          }
        }
      }
    } catch (e) {
      print('ℹ️ Datamuse fallback note for "$cleanWord": $e');
    }
    return null;
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
