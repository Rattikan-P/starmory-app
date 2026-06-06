import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/error/failures.dart';
import '../../core/config/app_constants.dart';

/// Gemini Vision AI Service for Starmory
/// Using custom prompts for vocabulary extraction and sentence generation
class GeminiService {
  final GenerativeModel _visionModel;
  final GenerativeModel _textModel;

  static const int _maxRetries = 3;
  static const Duration _initialDelay = Duration(seconds: 2);
  static const Duration _requestTimeout = Duration(seconds: 60);

  GeminiService({String? apiKey})
    : _visionModel = GenerativeModel(
        model: 'gemini-3-flash-preview',
        apiKey: apiKey ?? AppConstants.geminiApiKey,
      ),
      _textModel = GenerativeModel(
        model: 'gemini-3-flash-preview',
        apiKey: apiKey ?? AppConstants.geminiApiKey,
      );

  /// Execute with exponential backoff retry
  Future<T> _retryWithBackoff<T>(
    Future<T> Function() operation, {
    int maxRetries = _maxRetries,
  }) async {
    Duration delay = _initialDelay;
    int attempts = 0;

    while (true) {
      attempts++;
      try {
        return await operation().timeout(
          _requestTimeout,
          onTimeout: () =>
              throw TimeoutException('Request timed out after ${_requestTimeout.inSeconds}s'),
        );
      } catch (e) {
        // Check if error is retryable (503, 429, network errors)
        final isRetryable = _isRetryableError(e);

        if (!isRetryable || attempts >= maxRetries) {
          debugPrint(
            '❌ Max retries ($attempts) reached or non-retryable error: $e',
          );

          // Check if it's a quota exceeded error (429)
          final errorStr = e.toString().toLowerCase();
          debugPrint('🔍 Checking error string: "$errorStr"');
          if (errorStr.contains('429') ||
              errorStr.contains('quota') ||
              errorStr.contains('rate limit') ||
              errorStr.contains('rate_limit')) {
            debugPrint('✅ Detected quota error, throwing QuotaExceededFailure');
            throw QuotaExceededFailure(
              'Starmory needs a rest today 😴\nNew lessons will be ready again tomorrow!',
            );
          }

          rethrow;
        }

        debugPrint(
          '⚠️ Retry $attempts/$maxRetries after ${delay.inSeconds}s due to: $e',
        );
        await Future.delayed(delay);
        delay *= 2; // Exponential backoff
      }
    }
  }

  /// Check if error is retryable
  bool _isRetryableError(dynamic error) {
    if (error is TimeoutException) return true;
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('503') ||
        errorStr.contains('429') ||
        errorStr.contains('unavailable') ||
        errorStr.contains('timeout') ||
        errorStr.contains('network') ||
        errorStr.contains('socket');
  }

  /// Check if returned words match requested words (case-insensitive)
  bool _wordsMatch(Set<String> returned, Set<String> requested) {
    final returnedLower = returned.map((w) => w.toLowerCase()).toSet();
    final requestedLower = requested.map((w) => w.toLowerCase()).toSet();
    return returnedLower.containsAll(requestedLower);
  }

  /// Get tone definition for prompt
  String _getToneDefinition(String tone) {
    final defs = {
      'describe':
          'DESCRIBE: factual statement about the scene (e.g., "The sun is bright.")',
      'command':
          'COMMAND: instruction starting with a verb (e.g., "Look at the sun.")',
      'wish':
          'WISH: desire using "I wish" or "I hope" (e.g., "I wish the sun was warmer.")',
      'conditional':
          'CONDITIONAL: if-then statement (e.g., "If the sun shines, we go outside.")',
    };
    return defs[tone.toLowerCase()] ?? tone;
  }

  /// Build normal mode output format
  String _buildNormalFormat(
    String level,
    String category,
    List<String> words,
    List<String> tones,
  ) {
    final tonesJson = tones
        .map(
          (t) => '"$t": {"text": "sentence with word", "thai": "แปลภาษาไทย"}',
        )
        .join(', ');
    return '''
Return JSON in this exact format:
{
  "mode": "normal",
  "level": "$level",
  "category": "$category",
  "results": [
${words.map((w) => '    {"word": "$w", "sentences": {$tonesJson}, "sentence_note": ""}').join(',\n')}
  ]
}

CRITICAL: Use these exact words: ${words.join(', ')}''';
  }

  /// Build combined mode output format
  String _buildCombinedFormat(
    String level,
    String category,
    List<String> words,
    List<String> tones,
  ) {
    final tonesJson = tones
        .map(
          (t) =>
              '"$t": {"text": "sentence using all words", "thai": "แปลภาษาไทย"}',
        )
        .join(', ');
    return '''
Return JSON in this exact format:
{
  "mode": "combined",
  "level": "$level",
  "category": "$category",
  "words": ${jsonEncode(words)},
  "sentences": {$tonesJson},
  "sentence_note": ""
}

CRITICAL: Use these exact words: ${words.join(', ')}''';
  }

  /// Generate vocabulary from image with bounding boxes
  Future<VocabularyExtractionResult> extractVocabulary({
    required Uint8List imageData,
    required String level,
    required String category,
  }) async {
    // Validate API key before making request
    final apiKey = AppConstants.geminiApiKey;
    if (!isValidApiKey(apiKey)) {
      throw AIServiceFailure(
        'Invalid API key. Please set a valid GEMINI_API_KEY in your .env file. '
        'Get your key from: https://ai.google.dev/',
      );
    }

    // System instruction with all the rules
    final systemInstruction = '''
You are a visual vocabulary extraction engine for a language learning app called "Starmory".
Analyze the image and extract exactly 5 vocabulary items with bounding boxes.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WORD EXTRACTION RULES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Identify exactly 5 vocabulary items: a mix of nouns (objects) and verbs (visible actions).

Noun items
• Clearly visible, tangible physical objects
• Each from a different noun category
• One bounding box per object; pick the most prominent instance

Verb items
• Must be a visible action actively occurring in the image
• Must have a clear human or subject performing it
• Minimum 1 verb, maximum 3 verbs across the 5 items
• If no action is visible → all 5 items are nouns

Combined rule: Nouns + verbs = exactly 5 items total, no duplicates.
Exclude: shadows, lighting effects, abstract concepts, background blur, implied or off-screen actions.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WORD RULES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• One single English word (noun or base-form verb)
• No spaces, hyphens, or adjective+noun combinations
• Validation: Can a learner look at the image and confirm this word?
  ✅ YES → use it | ❌ NO → find a more visually grounded synonym

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CEFR LEVEL GUIDE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Level | Vocabulary style
A1    | Most common everyday word      (e.g. cup, eat)
A2    | Common, slightly broader       (e.g. mug, sip)
B1    | Familiar but slightly formal   (e.g. container, consume)
B2    | Formal / academic, still visual (e.g. receptacle, imbibe)

• Prefer the most natural word AT that level — not the hardest possible
• If no appropriate synonym exists at target level, use the closest level below
• Verbs must be base form (drink, not drinking/drank)

Thai word register:
• A1–B1 → everyday Thai (ภาษาพูดทั่วไป)
• B2    → precise Thai (อาจใช้ศัพท์ทางการ)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WORD SELECTION PRIORITY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. CONTEXT (primary)      → must influence at least 3 of 5 words
2. CEFR LEVEL (secondary) → narrows the synonym pool per word

For each word:
List valid synonyms → filter by context → filter by CEFR level → pick best fit

Context interpretation:
• Any language including Thai → interpret intent and apply
• Vague/uninterpretable input (e.g. "idk", "123", "!@#\$") → treat as empty
  → fall back to visible items + level only

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
BOUNDING BOX RULES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Normalized coordinates 0.0–1.0
• (x_min, y_min) = top-left corner
• (x_max, y_max) = bottom-right corner
• x_min < x_max and y_min < y_max
• Nouns → box wraps the object itself
• Verbs → box wraps the subject performing the action

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OUTPUT FORMAT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Return strictly valid JSON only — no markdown, no explanation, no extra text.

{
  "level": "string",
  "category": "string",
  "vocab_list": [
    {
      "word": "string",
      "type": "noun" | "verb",
      "thai": "string",
      "bounding_box": {
        "x_min": 0.0,
        "y_min": 0.0,
        "x_max": 1.0,
        "y_max": 1.0
      }
    }
  ]
}

Return exactly 5 items.''';

    // User prompt with just the parameters
    final userPrompt = TextPart('''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
INPUT PARAMETERS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• level    — $level
• category — $category

Extract exactly 5 vocabulary items from the image.''');

    final mimeType = _detectMimeType(imageData);
    final imagePart = DataPart(mimeType, imageData);

    return await _retryWithBackoff(() async {
      final response = await _visionModel.generateContent(
        [
          Content.system(systemInstruction),
          Content.multi([userPrompt, imagePart]),
        ],
        generationConfig: GenerationConfig(
          temperature: 1.0, // Match AI Studio setting
          topP: 0.94,
          topK: 40,
          maxOutputTokens: 8192,
        ),
      );

      final text = response.text ?? '';
      debugPrint('🔍 Raw AI Response length: ${text.length} chars');
      debugPrint(
        '📄 Raw AI Response (first 500 chars): ${text.substring(0, text.length > 500 ? 500 : text.length)}',
      );

      final result = VocabularyExtractionResult.fromJson(text);
      debugPrint('✅ Parsed ${result.vocabList.length} vocabulary items');

      return result;
    });
  }

  /// Generate sentences for selected vocabulary words
  Future<SentenceGenerationResult> generateSentences({
    required List<String> words,
    required String level,
    required List<String> tones,
    required String category,
    required bool combined,
  }) async {
    return await _retryWithBackoff(() async {
      final result = await _generateSentencesInternal(
        words: words,
        level: level,
        tones: tones,
        category: category,
        combined: combined,
      );

      // Validate that returned words match requested words
      if (!combined) {
        final returnedWords = result.results.keys.toSet();
        final requestedWords = words.toSet();

        if (!_wordsMatch(returnedWords, requestedWords)) {
          debugPrint(
            '⚠️ Word mismatch: requested $requestedWords but got $returnedWords',
          );
          throw AIServiceFailure(
            'API returned unexpected words. Requested: $requestedWords, Got: $returnedWords',
          );
        }

        // Validate that all requested tones are present
        final requestedTones = tones.toSet();
        for (final word in requestedWords) {
          final wordSentences = result.results[word];
          if (wordSentences == null || wordSentences.isEmpty) {
            debugPrint('⚠️ No sentences found for word: $word');
            throw AIServiceFailure('No sentences found for word: $word');
          }

          final returnedTones = wordSentences.keys.toSet();
          if (!returnedTones.containsAll(requestedTones)) {
            final missingTones = requestedTones.difference(returnedTones);
            debugPrint('⚠️ Missing tones for $word: $missingTones');
            throw AIServiceFailure(
              'API returned incomplete data. Missing tones: $missingTones',
            );
          }
        }
      }

      return result;
    });
  }

  /// Internal sentence generation without validation
  Future<SentenceGenerationResult> _generateSentencesInternal({
    required List<String> words,
    required String level,
    required List<String> tones,
    required String category,
    required bool combined,
  }) async {
    // System instruction with all the rules
    final systemInstruction = '''
You are a sentence generation engine for a language learning app called "Starmory".
You receive vocabulary words selected by the user and return example sentences for language practice.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CEFR LEVEL GUIDE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Level | Sentence structure
A1    | Simple SVO, present tense only
A2    | Simple sentences, 1–2 clauses
B1    | Compound sentences, common tenses
B2    | Complex sentences, varied tenses

Conditional type by level:
• A1–A2 → Type 1 only  (If + present simple, will + base verb)
• B1    → Type 1 or 2  (choose more natural fit)
• B2    → Type 2 or 3  (unreal or past unreal)

Thai translation register:
• A1–B1 → everyday Thai (ภาษาพูดทั่วไป)
• B2    → precise Thai (อาจใช้ศัพท์ทางการ)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TONE & INTENT DEFINITIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Generate ONLY the tones listed in the "tones" input. Skip any not selected.

DESCRIBE
  Purpose : factual or descriptive statement about what is visible in the image
  Form    : declarative sentence (positive or negative)
  Example (B1): "The pastry on the wooden tray has a soft, golden-brown crust."

COMMAND
  Purpose : instruction, suggestion, or warning related to the visual context
  Form    : base-verb opening; no subject (or "Let's…" for inclusive)
  Example (B1): "Pick up the pastry gently so it doesn't lose its shape."

WISH
  Purpose : desire, hope, or hypothetical wish tied to the scene
  Form    : "I wish…" / "If only…" / "I hope…" / subjunctive clause
  Example (B1): "I wish I could visit a bakery like this one every morning."

CONDITIONAL
  Purpose : if-clause structure based on the visual scene
  Form    : match conditional type to CEFR level above
  Example (B1): "If you order a pastry here, you will not be disappointed."

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SENTENCE CONSTRAINTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Every sentence must satisfy ALL of the following:

1. CEFR complexity   — grammar and structure match the learner's level
2. Context relevance — content ties to the selected category or custom text
   • "Food"       → eating, cooking, dining context
   • "Moment"     → personal, time-specific experience
   • "Nature"     → outdoor or natural setting
   • "Study"      → learning or academic context
   • "Daily Life" → everyday routine situations
   • Custom text  → interpret user's intent and apply naturally
3. Image grounding   — sentence references something visible in the photo
   ✅ "She smiled at the adorable pastry sitting on the wooden tray."
   ❌ "Something adorable can make people happy." (too generic)
4. Word usage        — sentence must use the exact vocab word naturally
5. Sentence coherence — when generating multiple sentences, they must form ONE coherent scene
   ✅ "The cart has groceries." + "The juice is in the cart." + "The bread is in bags."
   ❌ "The cart has groceries." + "I like running." + "Birds fly high." (unrelated)

If any constraint cannot be satisfied, explain in sentence_note.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MODE A — NORMAL MODE  (combined: false)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• All sentences must share the SAME visual scene and context
• Treat multiple words as telling ONE coherent story about the image
• Sentences should reference each other when natural (e.g., "The cart has groceries" → "The juice is in the cart")
• For each word → one sentence per selected tone using that word as the focus
• The collection of sentences should flow together as describing one unified scene

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MODE B — COMBINED SENTENCE MODE  (combined: true)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Treat all words as a single group
• For each selected tone → ONE sentence that naturally uses ALL words together
• Words must appear meaningfully — not forced or listed
• If words cannot be naturally combined for a tone, explain in sentence_note

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OUTPUT FORMAT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Return strictly valid JSON only — no markdown, no explanation, no extra text.

─── NORMAL MODE (combined: false) ───

{
  "mode": "normal",
  "level": "string",
  "category": "string",
  "results": [
    {
      "word": "string",
      "sentences": {
        "describe":     { "text": "string", "thai": "string" },
        "command":      { "text": "string", "thai": "string" },
        "wish":         { "text": "string", "thai": "string" },
        "conditional":  { "text": "string", "thai": "string" }
      },
      "sentence_note": "string"
    }
  ]
}

─── COMBINED SENTENCE MODE (combined: true) ───

{
  "mode": "combined",
  "level": "string",
  "category": "string",
  "words": ["string", "string"],
  "sentences": {
    "describe":     { "text": "string", "thai": "string" },
    "command":      { "text": "string", "thai": "string" },
    "wish":         { "text": "string", "thai": "string" },
    "conditional":  { "text": "string", "thai": "string" }
  },
  "sentence_note": "string"
}

FIELD RULES:
• Include ONLY the tone keys that were selected in "tones"
• combined: false → "results" array, one object per word
• combined: true  → flat "sentences" object + "words" array, no "results"''';

    // User prompt with just the parameters
    final userPrompt =
        '''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
INPUT PARAMETERS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• words    — ${words.join(', ')}
• level    — $level
• tones    — ${tones.join(', ')}
• category — $category
• combined — $combined

REMINDER: All sentences must describe ONE coherent scene. When multiple words are provided, their sentences should reference each other naturally (e.g., items in a cart, objects on a table).

Generate sentences now.''';

    return await _retryWithBackoff(() async {
      final response = await _textModel.generateContent(
        [Content.system(systemInstruction), Content.text(userPrompt)],
        generationConfig: GenerationConfig(
          temperature: 1.0, // Match AI Studio setting
          topP: 0.94,
          topK: 40,
          maxOutputTokens: 8192,
        ),
      );

      final text = response.text ?? '';
      debugPrint(
        '🔍 Sentence Generation Response (first 500 chars): ${text.length > 500 ? text.substring(0, 500) : text}',
      );

      return SentenceGenerationResult.fromJson(text, tones);
    });
  }

  /// Detect MIME type from image bytes
  String _detectMimeType(Uint8List bytes) {
    if (bytes.length < 4) return 'image/jpeg';

    // Check for PNG
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }

    // Check for JPEG
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }

    // Check for GIF
    if (bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return 'image/gif';
    }

    // Check for WebP
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      return 'image/webp';
    }

    // Default to JPEG
    return 'image/jpeg';
  }

  /// Validate API key
  static bool isValidApiKey(String apiKey) {
    return apiKey.isNotEmpty &&
        apiKey != 'YOUR_GEMINI_API_KEY_HERE' &&
        apiKey.startsWith('AIza');
  }
}

/// Vocabulary extraction result with bounding boxes
class VocabularyExtractionResult {
  final String level;
  final String category;
  final List<VocabularyItem> vocabList;

  VocabularyExtractionResult({
    required this.level,
    required this.category,
    required this.vocabList,
  });

  factory VocabularyExtractionResult.fromJson(String jsonString) {
    // Extract JSON from response (handle markdown code blocks and extra text)
    String cleanJson = jsonString.trim();

    // Remove markdown code blocks
    if (cleanJson.startsWith('```')) {
      final start = cleanJson.indexOf('{');
      final end = cleanJson.lastIndexOf('}');
      if (start != -1 && end != -1) {
        cleanJson = cleanJson.substring(start, end + 1);
      } else {
        cleanJson = cleanJson.replaceAll('```', '').trim();
      }
    }

    // Find the first { and last } to extract just the JSON object
    // This handles cases where the AI adds extra text before/after the JSON
    final start = cleanJson.indexOf('{');
    final end = cleanJson.lastIndexOf('}');
    if (start != -1 && end != -1 && start < end) {
      cleanJson = cleanJson.substring(start, end + 1);
    }

    final json = jsonDecode(cleanJson) as Map<String, dynamic>;

    return VocabularyExtractionResult(
      level: json['level'] as String? ?? 'A1',
      category: json['category'] as String? ?? 'Daily Life',
      vocabList:
          (json['vocab_list'] as List<dynamic>?)
              ?.map(
                (item) => VocabularyItem.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }
}

/// Single vocabulary item with bounding box
class VocabularyItem {
  final String word;
  final String type; // 'noun' or 'verb'
  final String thai;
  final BoundingBox boundingBox;

  VocabularyItem({
    required this.word,
    required this.type,
    required this.thai,
    required this.boundingBox,
  });

  factory VocabularyItem.fromJson(Map<String, dynamic> json) {
    return VocabularyItem(
      word: json['word'] as String,
      type: json['type'] as String? ?? 'noun',
      thai: json['thai'] as String,
      boundingBox: BoundingBox.fromJson(
        json['bounding_box'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

/// Bounding box for vocabulary item
class BoundingBox {
  final double xMin;
  final double yMin;
  final double xMax;
  final double yMax;

  BoundingBox({
    required this.xMin,
    required this.yMin,
    required this.xMax,
    required this.yMax,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      xMin: (json['x_min'] as num).toDouble(),
      yMin: (json['y_min'] as num).toDouble(),
      xMax: (json['x_max'] as num).toDouble(),
      yMax: (json['y_max'] as num).toDouble(),
    );
  }

  /// Convert to center point for dot positioning
  (double x, double y) get center {
    return ((xMin + xMax) / 2, (yMin + yMax) / 2);
  }
}

/// Sentence generation result
class SentenceGenerationResult {
  final String mode;
  final String level;
  final String category;
  final Map<String, Map<String, SentenceData>> results;
  final Map<String, SentenceData>? combinedSentences;
  final List<String>? combinedWords;
  final String? sentenceNote;

  SentenceGenerationResult({
    required this.mode,
    required this.level,
    required this.category,
    required this.results,
    this.combinedSentences,
    this.combinedWords,
    this.sentenceNote,
  });

  factory SentenceGenerationResult.fromJson(
    String jsonString,
    List<String> selectedTones,
  ) {
    debugPrint(
      '🔍 SentenceGenerationResult.fromJson - selectedTones: $selectedTones',
    );
    debugPrint(
      '🔍 Raw response (first 300 chars): ${jsonString.length > 300 ? jsonString.substring(0, 300) : jsonString}',
    );

    // Extract JSON from response (handle markdown and extra text)
    String cleanJson = jsonString.trim();

    // Remove markdown code blocks
    if (cleanJson.startsWith('```')) {
      final start = cleanJson.indexOf('{');
      final end = cleanJson.lastIndexOf('}');
      if (start != -1 && end != -1) {
        cleanJson = cleanJson.substring(start, end + 1);
      } else {
        cleanJson = cleanJson.replaceAll('```', '').trim();
      }
    }

    // Find the first { and last } to extract just the JSON object
    final start = cleanJson.indexOf('{');
    final end = cleanJson.lastIndexOf('}');
    if (start != -1 && end != -1 && start < end) {
      cleanJson = cleanJson.substring(start, end + 1);
    }

    debugPrint('🔍 Cleaned JSON: $cleanJson');

    final json = jsonDecode(cleanJson) as Map<String, dynamic>;
    final mode = json['mode'] as String? ?? 'normal';

    debugPrint('🔍 Parsed mode: $mode');
    debugPrint('🔍 JSON keys: ${json.keys}');

    if (mode == 'combined') {
      final sentencesJson = json['sentences'] as Map<String, dynamic>?;
      final sentences = <String, SentenceData>{};
      if (sentencesJson != null) {
        for (final entry in sentencesJson.entries) {
          sentences[entry.key] = SentenceData.fromJson(
            entry.value as Map<String, dynamic>,
          );
        }
      }

      return SentenceGenerationResult.combined(
        level: json['level'] as String? ?? 'A1',
        category: json['category'] as String? ?? 'Daily Life',
        words:
            (json['words'] as List<dynamic>?)
                ?.map((w) => w as String)
                .toList() ??
            [],
        sentences: sentences,
        sentenceNote: json['sentence_note'] as String?,
      );
    } else {
      final resultsJson = json['results'] as List<dynamic>?;
      final results = <String, Map<String, SentenceData>>{};

      debugPrint('🔍 Results JSON: $resultsJson');

      if (resultsJson != null) {
        for (final item in resultsJson) {
          final itemMap = item as Map<String, dynamic>;
          final word = itemMap['word'] as String;
          final sentencesJson = itemMap['sentences'] as Map<String, dynamic>?;

          debugPrint('🔍 Processing word: $word, sentences: $sentencesJson');

          if (sentencesJson != null) {
            final sentences = <String, SentenceData>{};
            for (final entry in sentencesJson.entries) {
              sentences[entry.key] = SentenceData.fromJson(
                entry.value as Map<String, dynamic>,
              );
            }
            results[word] = sentences;
          }
        }
      }

      debugPrint('🔍 Final results map: $results');

      return SentenceGenerationResult.normal(
        level: json['level'] as String? ?? 'A1',
        category: json['category'] as String? ?? 'Daily Life',
        results: results,
        selectedTones: selectedTones,
      );
    }
  }

  factory SentenceGenerationResult.normal({
    required String level,
    required String category,
    required Map<String, Map<String, SentenceData>> results,
    List<String> selectedTones = const [],
  }) {
    debugPrint(
      '🔍 SentenceGenerationResult.normal - selectedTones: $selectedTones',
    );
    debugPrint('🔍 Input results keys: ${results.keys}');

    // Filter results to only include selected tones
    final filteredResults = <String, Map<String, SentenceData>>{};
    for (final entry in results.entries) {
      final word = entry.key;
      final sentences = entry.value;

      debugPrint(
        '🔍 Processing word: $word, available tones: ${sentences.keys}',
      );

      // Only include sentences for selected tones
      final filteredSentences = <String, SentenceData>{};
      for (final tone in selectedTones) {
        if (sentences.containsKey(tone)) {
          filteredSentences[tone] = sentences[tone]!;
          debugPrint('✅ Found sentence for tone: $tone');
        } else {
          debugPrint('⚠️ No sentence for tone: $tone');
        }
      }

      if (filteredSentences.isNotEmpty) {
        filteredResults[word] = filteredSentences;
      }
    }

    debugPrint('🔍 Filtered results keys: ${filteredResults.keys}');

    return SentenceGenerationResult(
      mode: 'normal',
      level: level,
      category: category,
      results: filteredResults,
    );
  }

  factory SentenceGenerationResult.combined({
    required String level,
    required String category,
    required List<String> words,
    required Map<String, SentenceData> sentences,
    String? sentenceNote,
  }) {
    return SentenceGenerationResult(
      mode: 'combined',
      level: level,
      category: category,
      results: {},
      combinedSentences: sentences,
      combinedWords: words,
      sentenceNote: sentenceNote,
    );
  }
}

/// Sentence data with English and Thai text
class SentenceData {
  final String text;
  final String thai;

  SentenceData({required this.text, required this.thai});

  factory SentenceData.fromJson(Map<String, dynamic> json) {
    return SentenceData(
      text: json['text'] as String,
      thai: json['thai'] as String,
    );
  }
}
