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

  GeminiService({String? apiKey})
      : _visionModel = GenerativeModel(
          model: 'gemini-3-flash-preview',
          apiKey: apiKey ?? AppConstants.geminiApiKey,
        ),
        _textModel = GenerativeModel(
          model: 'gemini-3-flash-preview',
          apiKey: apiKey ?? AppConstants.geminiApiKey,
        );

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
        'Get your key from: https://ai.google.dev/'
      );
    }

    final prompt = TextPart('''
You are a visual vocabulary extraction engine for a language learning app called "Starmory".
Analyze the image and extract exactly 5 vocabulary items with bounding boxes.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
INPUT PARAMETERS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• level    — learner's CEFR level: A1 | A2 | B1 | B2
• category — one of: "Moment" | "Nature" | "Food" | "Study" | "Daily Life"
             OR a custom text string (overrides category entirely)

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
  "level": "$level",
  "category": "$category",
  "vocab_list": [
    {
      "word": "string",
      "type": "noun" | "verb",
      "thai": "string",
      "tone_note": "explain which context/level drove the word choice",
      "bounding_box": {
        "x_min": 0.0,
        "y_min": 0.0,
        "x_max": 1.0,
        "y_max": 1.0
      }
    }
  ]
}

Return exactly 5 items.
''');

    final mimeType = _detectMimeType(imageData);
    final imagePart = DataPart(mimeType, imageData);

    try {
      final response = await _visionModel.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      final text = response.text ?? '';
      debugPrint('🔍 Raw AI Response length: ${text.length} chars');
      debugPrint('📄 Raw AI Response (first 500 chars): ${text.substring(0, text.length > 500 ? 500 : text.length)}');

      final result = VocabularyExtractionResult.fromJson(text);
      debugPrint('✅ Parsed ${result.vocabList.length} vocabulary items');

      return result;
    } catch (e) {
      debugPrint('❌ Parse error: $e');
      throw AIServiceFailure('Vocabulary extraction failed: ${e.toString()}');
    }
  }

  /// Generate sentences for selected vocabulary words
  Future<SentenceGenerationResult> generateSentences({
    required List<String> words,
    required String level,
    required List<String> tones,
    required String category,
    required bool combined,
  }) async {
    final prompt = TextPart('''
You are a sentence generation engine for a language learning app called "Starmory".
You receive vocabulary words selected by the user and return example sentences for language practice.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
INPUT PARAMETERS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• words    — list of 1 or more vocabulary words (nouns or base-form verbs)
• level    — learner's CEFR level: A1 | A2 | B1 | B2
• tones    — list of selected Tone & Intent (1–4 items):
             "describe" | "command" | "wish" | "conditional"
• category — one of: "Moment" | "Nature" | "Food" | "Study" | "Daily Life"
             OR a custom text string (overrides category entirely)
• combined — boolean: true | false
             false → Normal mode: one sentence per word per tone
             true  → Combined mode: one sentence per tone using ALL words together

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

If any constraint cannot be satisfied, explain in sentence_note.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MODE A — NORMAL MODE  (combined: false)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Process each word independently
• For each word → one sentence per selected tone
• Each sentence uses only that single word as the target vocabulary

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
  "level": "$level",
  "category": "$category",
  "results": [
    {
      "word": "string",
      "sentences": {
        ${tones.map((t) => '"$t": { "text": "string", "thai": "string" }').join(',\n        ')}
      },
      "sentence_note": "string"
    }
  ]
}

─── COMBINED SENTENCE MODE (combined: true) ───

{
  "mode": "combined",
  "level": "$level",
  "category": "$category",
  "words": ${jsonEncode(words)},
  "sentences": {
    ${tones.map((t) => '"$t": { "text": "string", "thai": "string" }').join(',\n    ')}
  },
  "sentence_note": "string"
}

FIELD RULES:
• Include ONLY the tone keys that were selected in "tones"
• combined: false → "results" array, one object per word
• combined: true  → flat "sentences" object + "words" array, no "results"
''');

    try {
      final response = await _textModel.generateContent([
        Content.text(prompt.text)
      ]);

      final text = response.text ?? '';
      return SentenceGenerationResult.fromJson(text, tones);
    } catch (e) {
      throw AIServiceFailure('Sentence generation failed: ${e.toString()}');
    }
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
      vocabList: (json['vocab_list'] as List<dynamic>?)
              ?.map((item) => VocabularyItem.fromJson(item as Map<String, dynamic>))
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
  final String toneNote;
  final BoundingBox boundingBox;

  VocabularyItem({
    required this.word,
    required this.type,
    required this.thai,
    required this.toneNote,
    required this.boundingBox,
  });

  factory VocabularyItem.fromJson(Map<String, dynamic> json) {
    return VocabularyItem(
      word: json['word'] as String,
      type: json['type'] as String? ?? 'noun',
      thai: json['thai'] as String,
      toneNote: json['tone_note'] as String? ?? '',
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

  factory SentenceGenerationResult.fromJson(String jsonString, List<String> selectedTones) {
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
        words: (json['words'] as List<dynamic>?)
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

  SentenceData({
    required this.text,
    required this.thai,
  });

  factory SentenceData.fromJson(Map<String, dynamic> json) {
    return SentenceData(
      text: json['text'] as String,
      thai: json['thai'] as String,
    );
  }
}
