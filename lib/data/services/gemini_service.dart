import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
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

          final errorStr = e.toString().toLowerCase();

          // Check if it's a quota exceeded error (429)
          if (errorStr.contains('429') ||
              errorStr.contains('quota') ||
              errorStr.contains('rate limit') ||
              errorStr.contains('rate_limit')) {
            // debugPrint('✅ Detected quota error, throwing QuotaExceededFailure');
            throw QuotaExceededFailure(
              'Starmory needs a rest today 😴\nNew lessons will be ready again tomorrow!',
            );
          }

          // Check if it's a service unavailable error (503)
          if (errorStr.contains('503') ||
              errorStr.contains('unavailable') ||
              errorStr.contains('high demand')) {
            throw AIServiceFailure(
              'AI service is temporarily busy 😅\nPlease wait a moment and try again!',
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
    // FormatException from incomplete JSON is retryable (AI sometimes truncates output)
    if (error is FormatException) return true;
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

  /// Generate vocabulary from image with bounding boxes
  Future<VocabularyExtractionResult> extractVocabulary({
    required Uint8List imageData,
    required String level,
    required String category,
    String englishVariant = 'US',
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
• level           — $level
• category        — $category
• english_variant — $englishVariant (US or UK English)

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
          maxOutputTokens: 16384,  // Increased to prevent truncated JSON responses
        ),
      );

      final text = response.text ?? '';
      final result = VocabularyExtractionResult.fromJson(text);

      return result;
    });
  }

  /// Generate sentences for selected vocabulary words
  Future<SentenceGenerationResult> generateSentences({
    Uint8List? imageData,  // Optional: if provided, sentences will be grounded to the image
    required List<String> words,
    required String level,
    required List<String> tones,
    required String category,
    required bool combined,
    String englishVariant = 'US',
  }) async {
    return await _retryWithBackoff(() async {
      final result = await _generateSentencesInternal(
        imageData: imageData,
        words: words,
        level: level,
        tones: tones,
        category: category,
        combined: combined,
        englishVariant: englishVariant,
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
    Uint8List? imageData,
    required List<String> words,
    required String level,
    required List<String> tones,
    required String category,
    required bool combined,
    String englishVariant = 'US',
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
ENGLISH VARIANT (US vs UK)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• US  → American English spelling/color/colorful, favorite, center
• UK  → British English spelling/colour/colourful, favourite, centre
• Use vocabulary and idioms natural for that region
• Follow the "english_variant" from input parameters strictly

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
• For each selected tone → ONE sentence that MUST include EVERY word from the input list
• REQUIREMENT: ALL provided words MUST appear in the sentence — no exceptions, no omissions
• Words should be integrated naturally (e.g., "I use my laptop, notebook, and book for studying")
• Only explain in sentence_note if it's absolutely impossible to include all words (rare case)

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
• words           — ${words.join(', ')}
• level           — $level
• tones           — ${tones.join(', ')}
• category        — $category
• combined        — $combined
• english_variant — $englishVariant (US or UK English)

REMINDER: All sentences must describe ONE coherent scene. When multiple words are provided, their sentences should reference each other naturally (e.g., items in a cart, objects on a table).

${combined ? '''
⚠️ IMPORTANT FOR COMBINED MODE:
You MUST include ALL ${words.length} words in each combined sentence:
${words.map((w) => '  - "$w"').join('\n')}
DO NOT omit any word. Every single word must appear in the sentence.''' : ''}

Generate sentences now.''';

    return await _retryWithBackoff(() async {
      // Use vision model if image data is provided, otherwise use text model
      final model = imageData != null ? _visionModel : _textModel;

      // Build content parts
      List<Part> parts = [TextPart(userPrompt)];

      // Add image part if image data is provided
      if (imageData != null) {
        final mimeType = _detectMimeType(imageData);
        parts.insert(0, DataPart(mimeType, imageData)); // Insert image before text
      }

      final response = await model.generateContent(
        [Content.system(systemInstruction), Content.multi(parts)],
        generationConfig: GenerationConfig(
          temperature: 1.0, // Match AI Studio setting
          topP: 0.94,
          topK: 40,
          maxOutputTokens: 16384,  // Increased to prevent truncated JSON responses
        ),
      );

      final text = response.text ?? '';
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
        (apiKey.startsWith('AIza') || apiKey.startsWith('AQ.'));
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

/// Single vocabulary item with bounding box and optional pre-generated sentences
class VocabularyItem {
  final String word;
  final String type; // 'noun' or 'verb'
  final String thai;
  final BoundingBox boundingBox;
  final String? englishSentence; // Pre-generated sentence (optional)
  final String? thaiSentence; // Pre-generated Thai translation (optional)

  VocabularyItem({
    required this.word,
    required this.type,
    required this.thai,
    required this.boundingBox,
    this.englishSentence,
    this.thaiSentence,
  });

  factory VocabularyItem.fromJson(Map<String, dynamic> json) {
    return VocabularyItem(
      word: json['word'] as String,
      type: json['type'] as String? ?? 'noun',
      thai: json['thai'] as String,
      boundingBox: BoundingBox.fromJson(
        json['bounding_box'] as Map<String, dynamic>? ?? {},
      ),
      englishSentence: json['english_sentence'] as String?,
      thaiSentence: json['thai_sentence'] as String?,
    );
  }

  /// Create a copy with sentences added
  VocabularyItem withSentences(String english, String thai) {
    return VocabularyItem(
      word: word,
      type: type,
      thai: this.thai,
      boundingBox: boundingBox,
      englishSentence: english,
      thaiSentence: thai,
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

    final json = jsonDecode(cleanJson) as Map<String, dynamic>;
    final mode = json['mode'] as String? ?? 'normal';

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

      if (resultsJson != null) {
        for (final item in resultsJson) {
          final itemMap = item as Map<String, dynamic>;
          final word = itemMap['word'] as String;
          final sentencesJson = itemMap['sentences'] as Map<String, dynamic>?;

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
    // Filter results to only include selected tones
    final filteredResults = <String, Map<String, SentenceData>>{};
    for (final entry in results.entries) {
      final word = entry.key;
      final sentences = entry.value;

      // Only include sentences for selected tones
      final filteredSentences = <String, SentenceData>{};
      for (final tone in selectedTones) {
        if (sentences.containsKey(tone)) {
          filteredSentences[tone] = sentences[tone]!;
        }
      }

      if (filteredSentences.isNotEmpty) {
        filteredResults[word] = filteredSentences;
      }
    }

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
