import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/error/failures.dart';
import '../../core/config/app_constants.dart';
import '../../utils/topic_categories.dart';

/// Gemini Vision AI Service for Starmory
/// Using custom prompts for vocabulary extraction and sentence generation
class GeminiService {
  final GenerativeModel _primaryVisionModel;
  final GenerativeModel _fallbackVisionModel;
  final GenerativeModel _primaryTextModel;
  final GenerativeModel _fallbackTextModel;

  static const int _maxRetries = 3;
  static const Duration _initialDelay = Duration(seconds: 3);
  static const Duration _requestTimeout = Duration(seconds: 60);

  GeminiService({String? apiKey})
    : _primaryVisionModel = GenerativeModel(
        model: 'gemini-3.5-flash-lite',
        apiKey: apiKey ?? AppConstants.geminiApiKey,
      ),
      _fallbackVisionModel = GenerativeModel(
        model: 'gemini-3.5-flash',
        apiKey: apiKey ?? AppConstants.geminiApiKey,
      ),
      _primaryTextModel = GenerativeModel(
        model: 'gemini-3.5-flash-lite',
        apiKey: apiKey ?? AppConstants.geminiApiKey,
      ),
      _fallbackTextModel = GenerativeModel(
        model: 'gemini-3.5-flash',
        apiKey: apiKey ?? AppConstants.geminiApiKey,
      );

  /// Execute with exponential backoff retry and automatic model fallback
  Future<T> _retryWithBackoff<T>(
    Future<T> Function(bool useFallback) operation, {
    int maxRetries = _maxRetries,
  }) async {
    Duration delay = _initialDelay;
    int attempts = 0;
    bool useFallback = false;

    while (true) {
      attempts++;
      try {
        return await operation(useFallback).timeout(
          _requestTimeout,
          onTimeout: () =>
              throw TimeoutException('Request timed out after ${_requestTimeout.inSeconds}s'),
        );
      } catch (e) {
        // Switch to fallback model on retry (e.g. 503 high demand, 429, timeout)
        useFallback = true;

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

        final errorStrLower = e.toString().toLowerCase();
        final isSyntaxOrNotFound = e is FormatException ||
            e is TypeError ||
            errorStrLower.contains('not found') ||
            errorStrLower.contains('not supported') ||
            errorStrLower.contains('404');

        if (isSyntaxOrNotFound) {
          debugPrint(
            '⚠️ Retry $attempts/$maxRetries (instant fallback model switch) due to: $e',
          );
        } else {
          debugPrint(
            '⚠️ Retry $attempts/$maxRetries after ${delay.inSeconds}s (switching to fallback model) due to: $e',
          );
          await Future.delayed(delay);
          delay *= 2; // Exponential backoff (3s -> 6s -> 12s)
        }
      }
    }
  }

  /// Check if error is retryable
  bool _isRetryableError(dynamic error) {
    if (error is TimeoutException) return true;
    // FormatException and TypeError from incomplete JSON or bad types are retryable
    if (error is FormatException) return true;
    if (error is TypeError) return true;
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('503') ||
        errorStr.contains('429') ||
        errorStr.contains('unavailable') ||
        errorStr.contains('timeout') ||
        errorStr.contains('network') ||
        errorStr.contains('socket') ||
        errorStr.contains('not found') ||
        errorStr.contains('not supported') ||
        errorStr.contains('404');
  }

  /// Check if returned words match requested words (case-insensitive)
  bool _wordsMatch(Set<String> returned, Set<String> requested) {
    final returnedLower = returned.map((w) => w.toLowerCase()).toSet();
    final requestedLower = requested.map((w) => w.toLowerCase()).toSet();
    return returnedLower.containsAll(requestedLower);
  }

  /// Post-process AI topic categorization to fix common mistakes
  /// This is a safety net for cases where AI might miscategorize
  String _fixTopicCategory(String word, String aiTopic, String context) {
    // Normalize word for matching
    final normalizedWord = word.toLowerCase().trim();

    // Special case rules for common ambiguous words
    final specialCases = {
      // Accessories that often get miscategorized
      'glasses': _isMedicalContext(context) ? 'health' : 'daily_life',
      'sunglasses': 'daily_life',
      'watch': _hasDigitalKeywords(context) ? 'technology' : 'daily_life',

      // Health items
      'bandage': TopicCategories.health,
      'medicine': TopicCategories.health,
      'pill': TopicCategories.health,
      'pills': TopicCategories.health,
      'ointment': TopicCategories.health,
      'thermometer': TopicCategories.health,
      'stethoscope': TopicCategories.health,
      'crutch': TopicCategories.health,
      'bandaid': TopicCategories.health,
      'first aid': TopicCategories.health,

      // Clothing vs accessories
      'hat': TopicCategories.clothing,
      'bag': TopicCategories.dailyLife,
      'purse': TopicCategories.clothing,
      'backpack': TopicCategories.dailyLife,
      'wallet': TopicCategories.dailyLife,
      'belt': TopicCategories.clothing,
      'scarf': TopicCategories.clothing,
      'gloves': TopicCategories.clothing,

      // Tech items
      'phone': TopicCategories.technology,
      'laptop': TopicCategories.technology,
      'tablet': TopicCategories.technology,
      'computer': TopicCategories.technology,
      'camera': _hasHobbyKeywords(context) ? TopicCategories.hobbies : TopicCategories.technology,

      // People/professions (context-dependent)
      'doctor': _isEducationalContext(context) ? TopicCategories.people : TopicCategories.health,
      'nurse': TopicCategories.health,
      'teacher': TopicCategories.education,
      'student': TopicCategories.education,
      'chef': TopicCategories.hobbies, // cooking as hobby
      'driver': TopicCategories.dailyLife, // transportation

      // Nature items
      'dog': TopicCategories.nature,
      'cat': TopicCategories.nature,
      'bird': TopicCategories.nature,
      'fish': TopicCategories.food, // unless clearly in nature context
      'tree': TopicCategories.nature,
      'flower': TopicCategories.nature,
      'plant': _isHomeContext(context) ? TopicCategories.home : TopicCategories.nature,

      // Home items
      'sofa': TopicCategories.home,
      'couch': TopicCategories.home,
      'chair': TopicCategories.home,
      'table': TopicCategories.home,
      'bed': TopicCategories.home,
      'desk': TopicCategories.home,
      'shelf': TopicCategories.home,
      'lamp': TopicCategories.home,
      'fridge': TopicCategories.home,
      'refrigerator': TopicCategories.home,
      'oven': TopicCategories.home,
      'stove': TopicCategories.home,

      // Hobbies/entertainment
      'guitar': TopicCategories.hobbies,
      'piano': TopicCategories.hobbies,
      'book': _hasHobbyKeywords(context) ? TopicCategories.hobbies : TopicCategories.entertainment,
      'game': TopicCategories.entertainment,

      // Food vs nature (can be ambiguous)
      'meat': TopicCategories.food,
      'fruit': TopicCategories.food,
      'vegetable': TopicCategories.food,
    };

    // Check if we have a special case rule
    if (specialCases.containsKey(normalizedWord)) {
      return specialCases[normalizedWord]!;
    }

    // Otherwise, return the AI's original categorization
    return aiTopic;
  }

  /// Check if context contains medical/health keywords
  bool _isMedicalContext(String context) {
    final medicalKeywords = [
      'doctor', 'hospital', 'clinic', 'nurse', 'medical',
      'prescription', 'reading', 'eye', 'vision', 'sight',
      'medicine', 'pharmacy', 'treatment', 'checkup'
    ];
    final contextLower = context.toLowerCase();
    return medicalKeywords.any((keyword) => contextLower.contains(keyword));
  }

  /// Check if context contains digital/tech keywords
  bool _hasDigitalKeywords(String context) {
    final techKeywords = [
      'smart', 'digital', 'electronic', 'app', 'screen',
      'bluetooth', 'charging', 'notification', 'fitness tracker'
    ];
    final contextLower = context.toLowerCase();
    return techKeywords.any((keyword) => contextLower.contains(keyword));
  }

  /// Check if context contains hobby/leisure keywords
  bool _hasHobbyKeywords(String context) {
    final hobbyKeywords = [
      'hobby', 'leisure', 'fun', 'enjoy', 'relax',
      'photography', 'playing', 'collection', 'interest'
    ];
    final contextLower = context.toLowerCase();
    return hobbyKeywords.any((keyword) => contextLower.contains(keyword));
  }

  /// Check if context contains educational keywords
  bool _isEducationalContext(String context) {
    final eduKeywords = [
      'school', 'classroom', 'lesson', 'learning', 'teaching',
      'education', 'training', 'course', 'study'
    ];
    final contextLower = context.toLowerCase();
    return eduKeywords.any((keyword) => contextLower.contains(keyword));
  }

  /// Check if context contains home/household keywords
  bool _isHomeContext(String context) {
    final homeKeywords = [
      'home', 'house', 'room', 'living room', 'bedroom',
      'kitchen', 'bathroom', 'furniture', 'decor', 'interior'
    ];
    final contextLower = context.toLowerCase();
    return homeKeywords.any((keyword) => contextLower.contains(keyword));
  }

  /// Generate vocabulary from image with bounding boxes
  Future<VocabularyExtractionResult> extractVocabulary({
    required Uint8List imageData,
    required String level,
    required String category,
    String englishVariant = 'US',
    List<String> excludeWords = const [], // Words to avoid (for regenerate)
    bool isRegenerate = false, // Use higher temp for regenerate to get variety
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
    final topicPrompt = '''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TOPIC CATEGORIZATION PER WORD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
For EACH vocabulary item, select exactly ONE category that best describes it:

  • food          — ${TopicCategories.descriptions[TopicCategories.food]}
  • people        — ${TopicCategories.descriptions[TopicCategories.people]}
  • nature        — ${TopicCategories.descriptions[TopicCategories.nature]}
  • home          — ${TopicCategories.descriptions[TopicCategories.home]}
  • daily_life    — ${TopicCategories.descriptions[TopicCategories.dailyLife]}
  • clothing      — ${TopicCategories.descriptions[TopicCategories.clothing]}
  • hobbies       — ${TopicCategories.descriptions[TopicCategories.hobbies]}
  • education     — ${TopicCategories.descriptions[TopicCategories.education]}
  • work          — ${TopicCategories.descriptions[TopicCategories.work]}
  • technology    — ${TopicCategories.descriptions[TopicCategories.technology]}
  • health        — ${TopicCategories.descriptions[TopicCategories.health]}
  • entertainment — ${TopicCategories.descriptions[TopicCategories.entertainment]}
  • other         — ${TopicCategories.descriptions[TopicCategories.other]}

IMPORTANT: Each word gets its own topic based on what THAT word represents.
Examples:
• "phone" → technology
• "jacket" → clothing
• "glasses" → daily_life (unless clearly medical/reading glasses → health)
• "watch" → technology (smartwatch) or daily_life (analog)
• "sunglasses" → daily_life
• "bandage" → health
• "medicine" → health
• "pill" → health
• "bag" → daily_life
• "wallet" → daily_life
• "backpack" → daily_life
• "thermometer" → health
• "stethoscope" → health
• "doctor" → people (profession) OR health (medical context)
• "teacher" → people (profession) OR education (school context)
• "dog" → nature (animal)
• "tree" → nature (plant)
• "sofa" → home (furniture)
• "fridge" → home (household item)
• "camera" → technology (digital) OR hobbies (photography as hobby)
• "guitar" → hobbies (musical instrument)
• "book" → education (learning) OR entertainment (reading for fun)
• "laptop" → technology (digital device)
• "pills" → health (medicine)
• "stand" (verb) → daily_life (action)''';

    final systemInstruction = '''
You are a visual vocabulary extraction engine for a language learning app called "Starmory".
Analyze the image and extract exactly 5 vocabulary items with bounding boxes.

$topicPrompt

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WORD EXTRACTION RULES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Identify EXACTLY 5 vocabulary items: a mix of nouns (objects) and verbs (visible actions).

Noun items
• MUST be clearly visible, prominent FOREGROUND physical objects.
• STRICTLY NO BORDER-EDGE OR CUT-OFF OBJECTS: DO NOT pick objects (e.g. plants, cups, food) that are cut off, cropped, or located near the borders/edges of the photo frame (e.g. x < 0.10 or x > 0.90 or y < 0.10 or y > 0.90). All selected objects MUST be comfortably contained within the main central area of the frame.
• STRICTLY UN-OCCLUDED: DO NOT pick objects (e.g. bowls, plates, cutlery) that are occluded, covered, or hidden behind other objects or clutter.
• Each from a different noun category when possible.
• One bounding box per object; pick the most prominent, unobstructed instance.

Verb items
• Must be a visible action actively occurring in the image
• Must have a clear human or subject performing it
• Minimum 1 verb, maximum 3 verbs across the 5 items
• If no action is visible → all 5 items are nouns

Combined rule: Nouns + verbs = EXACTLY 5 items total.
CRITICAL QUANTITY GUARANTEE: You MUST ALWAYS return EXACTLY 5 items. Never return fewer than 5 items (e.g. 3 or 4). If there are not enough items matching the target category, fill the remaining slots with any prominent, clearly visible foreground objects in the image.
Exclude: cut-off or border-edge objects, occluded or hidden objects, shadows, lighting effects, abstract concepts, background blur, implied or off-screen actions.

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
OBJECT LOCATION RULES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
You MUST provide a "center_point" for each vocabulary item.
This point will be used as the interactive tap dot on the image.

center_point format:
• "cx": horizontal position, normalized 0.0 (left edge) to 1.0 (right edge)
• "cy": vertical position, normalized 0.0 (top edge) to 1.0 (bottom edge)

CRITICAL PLACEMENT RULES:

Rule 1 — VISIBLE SURFACE ONLY:
The center_point MUST land on a part of the object that is CLEARLY VISIBLE and NOT covered by anything.
• ✅ Tap the EXPOSED area that a user can actually see and recognize
• ❌ NEVER place on the geometric center if something else covers that area

Rule 2 — BASE & SURFACE OBJECTS (table, desk, counter, floor, wall, plate, tray):
• DO NOT draw a bounding box around the whole image for a table/surface!
• Instead, choose a SPECIFIC EXPOSED/BARE PATCH of the surface (e.g., bare wood grain at the bottom-left or bottom-right corner).
• The center_point and bounding_box MUST be placed on that bare patch — NEVER on cups, plates, food, or items sitting on top!

Rule 3 — OCCLUDED & STACKED OBJECTS (saucer under cup, chair near table, food in bowl):
When the object's center is covered by another object, SHIFT the point to the nearest EXPOSED surface:
• chair / armchair / stool near a table → The table cuts across the inner edge of the chair! Place center_point on the EXPOSED SEAT CUSHION, ARMREST, or BACKREST (on the outer side, away from the table edge), NEVER on the table surface!
• bowl / plate / dish filled with food → The food occupies the whole center! Place center_point ON THE EXPOSED CERAMIC RIM / EDGE (near the bottom or side of the dish), NOT on the food/salad inside!
• cup / mug / glass / bowl with liquid/drink inside → The liquid is in the top opening! Place center_point on the CERAMIC / GLASS BODY (the outer wall in the lower half of the cup), NOT on the liquid/coffee surface!
• saucer / coaster with cup on top → The cup sits in the center! Place center_point AT THE BOTTOM CURVED RIM of the saucer (near the bottom edge of the saucer box) — NEVER inside the cup body!
• cutting board with food → tap the EXPOSED WOODEN HANDLE or bare edge

Rule 4 — VERBS & ACTIONS (feed, reach, hold, stretch, look, stand, eat, drink, talk):
• For verbs, the action is performed by a person/subject in the photo!
• Place the center_point and bounding_box DIRECTLY ON THE PERSON / BODY PART / SUBJECT performing the action:
  - "feed" / "reach" / "stretch" → place on the outstretched ARM or HAND
  - "look" / "smile" → place on the FACE or HEAD
  - "stand" / "walk" → place on the BODY of the standing/walking subject
• ❌ NEVER return (0.0, 0.0) or an empty/degenerate box for a verb!

Rule 5 — CLUSTERS, PLANTS & GROUPS (balloons, plants, flowers, trees, lights):
• For plants, trees, or foliage (e.g. potted plant on the side, rosemary in a pot):
  - Place the center_point and bounding_box directly on the CLEARLY VISIBLE GREEN LEAVES or flower bloom (on the left or right side)!
  - ❌ NEVER return (0,0) or stick to the top-left edge!
• For groups or arches of items (e.g. balloon arch, bouquet):
  - Pick ONE PROMINENT, CLEARLY VISIBLE ITEM in the cluster (e.g. one bright balloon) and place the center_point directly on it!

Rule 6 — STANDALONE OBJECTS (nothing blocking):
For fully visible objects (e.g. a cup, a book), place the point at the object's visual center.

Rule 7 — SAFE BOUNDS & SPREAD:
• Each point MUST be within 0.05–0.95 range (not at extreme edges)
• No two center_points should be closer than 0.04 from each other

You also MUST provide a "bounding_box" for each item:
• Normalized coordinates 0.0–1.0
• (x_min, y_min) = top-left corner, (x_max, y_max) = bottom-right corner
• x_min < x_max and y_min < y_max
• For surfaces (table/floor), wrap only the exposed patch, NOT the whole scene!

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
      "topic": "string",
      "center_point": {
        "cx": 0.35,
        "cy": 0.72
      },
      "bounding_box": {
        "x_min": 0.25,
        "y_min": 0.60,
        "x_max": 0.45,
        "y_max": 0.84
      }
    }
  ]
}

Return EXACTLY 5 items. Each item MUST have its own topic field.''';

    // User prompt with just the parameters
    final excludeWordsText = excludeWords.isNotEmpty
        ? '''

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EXCLUDED WORDS (DO NOT USE)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ AVOID these words: ${excludeWords.join(', ')}
Find different vocabulary items instead.'''
        : '';

    final userPrompt = TextPart('''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
INPUT PARAMETERS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• level           — $level
• category        — $category
• english_variant — $englishVariant (US or UK English)
$excludeWordsText

Extract exactly 5 vocabulary items from the image.''');

    final mimeType = _detectMimeType(imageData);
    final imagePart = DataPart(mimeType, imageData);

    return await _retryWithBackoff((useFallback) async {
      // Use higher temperature for regenerate to get more variety
      final temp = isRegenerate ? 0.7 : 0.6;
      final maxTokens = isRegenerate ? 10240 : 8192; // Increased to prevent truncation

      final model = useFallback ? _fallbackVisionModel : _primaryVisionModel;
      if (useFallback) {
        debugPrint('🔄 Using fallback vision model (gemini-3.6-flash)');
      }

      final response = await model.generateContent(
        [
          Content.multi([
            TextPart(systemInstruction),
            userPrompt,
            imagePart,
          ]),
        ],
        generationConfig: GenerationConfig(
          temperature: temp, // 0.6 for normal, 0.7 for regenerate
          topP: 0.9,
          topK: 32,
          maxOutputTokens: maxTokens, // 8192 for normal, 10240 for regenerate
        ),
      );

      final text = response.text ?? '';
      var result = VocabularyExtractionResult.fromJson(text);

      if (result.vocabList.length < 5) {
        debugPrint('⚠️ AI returned only ${result.vocabList.length} items instead of requested 5. Retrying...');
        throw FormatException('AI returned only ${result.vocabList.length} items instead of requested 5');
      }

      // Apply post-processing to fix topic categorization
      result = result.copyWith(
        vocabList: result.vocabList.map((item) {
          // Use the category/user input as context for better categorization
          final context = '$category ${item.englishSentence ?? ''} ${item.thaiSentence ?? ''}';
          final fixedTopic = _fixTopicCategory(item.word, item.topic, context);
          return item.copyWith(topic: fixedTopic);
        }).toList(),
      );

      // Seating vs Table adjustment (chair, armchair, stool, bench, sofa near a table):
      // When a chair is tucked beside a table, the inner side of the chair's bbox is covered by the table.
      // Shift the chair's dot towards the outer exposed seat cushion/backrest (away from table).
      const seatingWords = {'chair', 'armchair', 'stool', 'bench', 'sofa', 'couch'};
      const tableWords = {'table', 'desk', 'counter', 'countertop'};
      final tableItems = result.vocabList.where((v) => tableWords.contains(v.word.toLowerCase())).toList();

      if (tableItems.isNotEmpty) {
        final tableItem = tableItems.first;
        result = result.copyWith(
          vocabList: result.vocabList.map((item) {
            if (seatingWords.contains(item.word.toLowerCase()) && item.centerX >= 0) {
              final chairWidth = item.boundingBox.xMax - item.boundingBox.xMin;
              if (chairWidth > 0.10) {
                if (tableItem.centerX > item.centerX) {
                  // Table is to the right -> place chair dot on the left side of chair (outer cushion)
                  final outerX = item.boundingBox.xMin + chairWidth * 0.32;
                  if (item.centerX > outerX) {
                    debugPrint('⚠️ Chair "${item.word}" dot (${item.centerX.toStringAsFixed(2)}) was near table (${tableItem.centerX.toStringAsFixed(2)}) — shifting left to outer cushion (${outerX.toStringAsFixed(2)})');
                    return item.copyWith(centerX: outerX);
                  }
                } else {
                  // Table is to the left -> place chair dot on the right side of chair
                  final outerX = item.boundingBox.xMax - chairWidth * 0.32;
                  if (item.centerX < outerX) {
                    debugPrint('⚠️ Chair "${item.word}" dot (${item.centerX.toStringAsFixed(2)}) was near table (${tableItem.centerX.toStringAsFixed(2)}) — shifting right to outer cushion (${outerX.toStringAsFixed(2)})');
                    return item.copyWith(centerX: outerX);
                  }
                }
              }
            }
            return item;
          }).toList(),
        );
      }

      // Print extracted vocabulary to console
      debugPrint('────────── EXTRACTED VOCABULARY (${result.vocabList.length} ITEMS) ──────────');
      for (int i = 0; i < result.vocabList.length; i++) {
        final item = result.vocabList[i];
        final (bboxCx, bboxCy) = item.boundingBox.center;
        final cpX = (item.centerX * 100).toStringAsFixed(1);
        final cpY = (item.centerY * 100).toStringAsFixed(1);
        final bpX = (bboxCx * 100).toStringAsFixed(1);
        final bpY = (bboxCy * 100).toStringAsFixed(1);
        debugPrint('  ${i + 1}. ${item.word} (${item.type}) → ${item.thai} [Topic: ${item.topic}] Center: ($cpX%, $cpY%) BBox: ($bpX%, $bpY%)');
      }
      debugPrint('────────────────────────────────────────────────────────────');

      // Coordinate sanity check: detect when AI returns all dots stacked at the same x or y
      final validItems = result.vocabList.where((v) => v.centerX >= 0).toList();

      if (validItems.isNotEmpty) {
        final cxValues = validItems.map((v) => v.centerX).toList()..sort();
        final cyValues = validItems.map((v) => v.centerY).toList()..sort();
        final cxRange = cxValues.last - cxValues.first;
        final cyRange = cyValues.last - cyValues.first;

        // If ALL valid dots are truly stacked in a razor-thin degenerate line (<3%) or tiny clump (<4%), retry
        final isTrulyStacked = (cxRange < 0.04 && cyRange < 0.04) || (cxRange < 0.03) || (cyRange < 0.03);
        if (validItems.length >= 4 && isTrulyStacked) {
          debugPrint('⚠️ Coordinates look broken: all dots stacked! cx range=${(cxRange * 100).toStringAsFixed(1)}%, cy range=${(cyRange * 100).toStringAsFixed(1)}%. Retrying...');
          throw FormatException(
            'AI returned stacked coordinates (cx range: ${(cxRange * 100).toStringAsFixed(1)}%, cy range: ${(cyRange * 100).toStringAsFixed(1)}%). Retrying for better spatial accuracy.',
          );
        }
      }

      // Fix broken items: handle per-axis coordinate repair
      final hasAnyBroken = result.vocabList.any((v) => v.centerX < 0 || v.centerY < 0);
      if (hasAnyBroken) {
        final brokenCount = result.vocabList.where((v) => v.centerX < 0 || v.centerY < 0).length;
        debugPrint('🔧 Fixing $brokenCount item(s) with broken coordinates...');

        // Collect all existing valid 2D positions
        final validDots = result.vocabList
            .where((v) => v.centerX >= 0 && v.centerY >= 0)
            .map((v) => (v.centerX, v.centerY))
            .toList();

        const upperWords = {'balloon', 'balloons', 'banner', 'cloud', 'sky', 'ceiling', 'lamp', 'light', 'chandelier', 'sun', 'moon', 'star', 'garland'};
        const plantWords = {'plant', 'plants', 'tree', 'trees', 'flower', 'flowers', 'leaf', 'leaves', 'bush', 'shrub', 'rosemary', 'succulent', 'houseplant', 'foliage', 'branch', 'stem', 'herb', 'herbs'};
        const boardWords = {'board', 'cutting board', 'wooden board', 'charcuterie board', 'tray', 'platter'};
        const surfaceWords = {'table', 'desk', 'counter', 'countertop', 'floor', 'ground', 'tablecloth', 'rug', 'carpet', 'grass', 'bowl', 'plate', 'dish', 'saucer'};

        final fixedList = result.vocabList.map((item) {
          if (item.centerX >= 0 && item.centerY >= 0) return item; // Fully valid

          var fixedCx = item.centerX;
          var fixedCy = item.centerY;
          final wordLower = item.word.toLowerCase();
          final isUpper = upperWords.contains(wordLower);
          final isPlant = plantWords.contains(wordLower);
          final isBoard = boardWords.contains(wordLower);
          final isSurface = surfaceWords.contains(wordLower);

          // Fix broken Y: upper words to top (0.22), plant to mid-upper (0.30), board to handle level (0.35), surface to bottom (0.85), others to mid (0.45)
          if (fixedCy < 0) {
            if (isUpper) {
              fixedCy = 0.22;
            } else if (isPlant) {
              fixedCy = 0.30;
            } else if (isBoard) {
              fixedCy = 0.35;
            } else if (isSurface) {
              fixedCy = 0.85;
            } else {
              fixedCy = 0.45;
            }
          }

          // Fix broken X: test candidate X positions at fixedCy to find an open area
          if (fixedCx < 0) {
            final testXCandidates = isUpper
                ? [0.70, 0.30, 0.85, 0.15, 0.50]
                : (isPlant
                    ? [0.18, 0.82, 0.12, 0.88, 0.25, 0.75] // Potted plants/leaves on the sides
                    : (isBoard
                        ? [0.08, 0.88, 0.12, 0.82] // Wooden handle or outer wood rim
                        : (isSurface
                            ? [0.15, 0.85, 0.25, 0.75, 0.35, 0.65, 0.50]
                            : [0.50, 0.30, 0.70, 0.20, 0.80, 0.15, 0.85])));

            for (final testX in testXCandidates) {
              final tooClose = validDots.any((v) {
                final dx = v.$1 - testX;
                final dy = v.$2 - fixedCy;
                return (dx * dx + dy * dy) < (0.12 * 0.12);
              });
              if (!tooClose) {
                fixedCx = testX;
                break;
              }
            }
            if (fixedCx < 0) fixedCx = testXCandidates.first;
            validDots.add((fixedCx, fixedCy));
          }

          debugPrint('  → Fixed "${item.word}": cx=${item.centerX < 0 ? "❌→$fixedCx" : "✓"} cy=${item.centerY < 0 ? "❌→$fixedCy" : "✓(${item.centerY.toStringAsFixed(2)})"}');
          return VocabularyItem(
            word: item.word,
            type: item.type,
            thai: item.thai,
            topic: item.topic,
            boundingBox: item.boundingBox,
            centerX: fixedCx,
            centerY: fixedCy,
            englishSentence: item.englishSentence,
            thaiSentence: item.thaiSentence,
          );
        }).toList();

        result = result.copyWith(vocabList: fixedList);
      }

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
    return await _retryWithBackoff((useFallback) async {
      final result = await _generateSentencesInternal(
        imageData: imageData,
        words: words,
        level: level,
        tones: tones,
        category: category,
        combined: combined,
        englishVariant: englishVariant,
        useFallback: useFallback,
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
    bool useFallback = false,
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

    // Use vision model if image data is provided, otherwise use text model
    final model = imageData != null
        ? (useFallback ? _fallbackVisionModel : _primaryVisionModel)
        : (useFallback ? _fallbackTextModel : _primaryTextModel);

    if (useFallback) {
      debugPrint('🔄 Using fallback model (gemini-3.6-flash)');
    }

    // Build content parts
    List<Part> parts = [
      TextPart(systemInstruction),
      TextPart(userPrompt),
    ];

    // Add image part if image data is provided
    if (imageData != null) {
      final mimeType = _detectMimeType(imageData);
      parts.insert(1, DataPart(mimeType, imageData)); // Insert image
    }

    final response = await model.generateContent(
      [Content.multi(parts)],
      generationConfig: GenerationConfig(
        temperature: 0.6, // Reduced from 1.0 for better speed
        topP: 0.9,
        topK: 32,
        maxOutputTokens: 8192, // Increased to prevent truncation (down from 16384)
      ),
    );

    final text = response.text ?? '';
    return SentenceGenerationResult.fromJson(text, tones);
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

  /// Safely clean and parse JSON response from Gemini API
  /// Handles markdown code blocks, isolates JSON objects, and strips trailing commas
  static Map<String, dynamic> _cleanAndParseJson(String jsonString) {
    String cleanJson = jsonString.trim();

    // Remove markdown code blocks
    if (cleanJson.contains('```')) {
      final start = cleanJson.indexOf('{');
      final end = cleanJson.lastIndexOf('}');
      if (start != -1 && end != -1 && start < end) {
        cleanJson = cleanJson.substring(start, end + 1);
      } else {
        cleanJson = cleanJson.replaceAll('```json', '').replaceAll('```', '').trim();
      }
    }

    // Extract just the JSON object
    final start = cleanJson.indexOf('{');
    final end = cleanJson.lastIndexOf('}');
    if (start != -1 && end != -1 && start < end) {
      cleanJson = cleanJson.substring(start, end + 1);
    }

    // Fix stray quotes after numbers (e.g., "y_max": 776")
    cleanJson = cleanJson.replaceAllMapped(
      RegExp(r':\s*(\d+(?:\.\d+)?)"(?=\s*[,}\]])'),
      (match) => ': ${match.group(1)}',
    );

    // Strip all trailing commas before ] or } repeatedly (handles nested trailing commas)
    final trailingRegex = RegExp(r',(\s*[\}\]])');
    while (cleanJson.contains(trailingRegex)) {
      cleanJson = cleanJson.replaceAllMapped(
        trailingRegex,
        (match) => match.group(1)!,
      );
    }

    // Strip trailing comma at end of string if truncated
    cleanJson = cleanJson.replaceAll(RegExp(r',\s*$'), '');

    // Auto-close unclosed brackets if JSON response was truncated
    int openBraces = 0;
    int openBrackets = 0;
    bool inString = false;
    for (int i = 0; i < cleanJson.length; i++) {
      final char = cleanJson[i];
      if (char == '"' && (i == 0 || cleanJson[i - 1] != '\\')) {
        inString = !inString;
      } else if (!inString) {
        if (char == '{') {
          openBraces++;
        } else if (char == '}') {
          openBraces = (openBraces - 1).clamp(0, 999);
        } else if (char == '[') {
          openBrackets++;
        } else if (char == ']') {
          openBrackets = (openBrackets - 1).clamp(0, 999);
        }
      }
    }

    while (openBrackets > 0) {
      cleanJson += ']';
      openBrackets--;
    }
    while (openBraces > 0) {
      cleanJson += '}';
      openBraces--;
    }

    return jsonDecode(cleanJson) as Map<String, dynamic>;
  }

  factory VocabularyExtractionResult.fromJson(String jsonString) {
    final json = _cleanAndParseJson(jsonString);

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

  /// Create a copy with different vocab list
  VocabularyExtractionResult copyWith({List<VocabularyItem>? vocabList}) {
    return VocabularyExtractionResult(
      level: level,
      category: category,
      vocabList: vocabList ?? this.vocabList,
    );
  }
}

/// Single vocabulary item with bounding box and optional pre-generated sentences
class VocabularyItem {
  final String word;
  final String type; // 'noun' or 'verb'
  final String thai;
  final String topic; // Topic category for this specific word
  final BoundingBox boundingBox;
  final double centerX; // Direct center point from AI (primary positioning)
  final double centerY;
  final String? englishSentence; // Pre-generated sentence (optional)
  final String? thaiSentence; // Pre-generated Thai translation (optional)

  VocabularyItem({
    required this.word,
    required this.type,
    required this.thai,
    required this.topic,
    required this.boundingBox,
    required this.centerX,
    required this.centerY,
    this.englishSentence,
    this.thaiSentence,
  });

  factory VocabularyItem.fromJson(Map<String, dynamic> json) {
    final wordVal = json['word']?.toString() ?? 'object';
    final typeVal = json['type']?.toString() ?? 'noun';
    final thaiVal = json['thai']?.toString() ?? wordVal;
    final topicVal = json['topic']?.toString() ?? 'other';

    final bboxRaw = json['bounding_box'] ?? json['box'] ?? json['box_2d'];
    final bbox = BoundingBox.fromJson(bboxRaw);

    // Parse center_point from AI (primary) — fallback to bbox center
    double cx;
    double cy;
    final (bboxCx, bboxCy) = bbox.center;
    final centerPointRaw = json['center_point'] ?? json['center'];
    // Calculate bbox dimensions and health
    final bboxWidth = bbox.xMax - bbox.xMin;
    final bboxHeight = bbox.yMax - bbox.yMin;
    final isBboxHealthy = bboxWidth >= 0.06 && bboxHeight >= 0.06 && !(bbox.xMin <= 0.02 && bbox.yMin <= 0.02);

    if (centerPointRaw is Map) {
      cx = _parseDouble(centerPointRaw['cx'] ?? centerPointRaw['x']) ?? bboxCx;
      cy = _parseDouble(centerPointRaw['cy'] ?? centerPointRaw['y']) ?? bboxCy;

      // Normalize if AI returned 0-1000 scale
      if (cx > 1.0 || cy > 1.0) {
        cx /= 1000.0;
        cy /= 1000.0;
      }

      // Clamp to safe range
      cx = cx.clamp(0.05, 0.95);
      cy = cy.clamp(0.05, 0.95);

      final isXEdgeStuck = (cx <= 0.06);
      final isYEdgeStuck = (cy <= 0.06);
      final isCenterPointCornerStuck = (cx <= 0.08 && cy <= 0.10);
      final hasValidBboxX = bbox.xMin > 0.05 && bboxWidth >= 0.02;
      final hasValidBboxY = bbox.yMin > 0.05 && bboxHeight >= 0.02;

      if (isBboxHealthy) {
        // Healthy BBox: validate center_point is within its bounds
        final isOutsideBbox = cx < (bbox.xMin - 0.04) ||
            cx > (bbox.xMax + 0.04) ||
            cy < (bbox.yMin - 0.04) ||
            cy > (bbox.yMax + 0.04);
        if (isOutsideBbox || isCenterPointCornerStuck || isXEdgeStuck) {
          debugPrint('⚠️ center_point ($cx, $cy) was ${isXEdgeStuck ? "x-edge-stuck" : "outside bbox"} for "$wordVal" — using healthy bbox center ($bboxCx, $bboxCy)');
          cx = bboxCx;
          cy = bboxCy;
        }
      } else {
        // BBox has irregular dimensions (slender object or partial failure)
        if (isXEdgeStuck && isYEdgeStuck) {
          // Both are broken/corner-stuck
          if (hasValidBboxX && hasValidBboxY) {
            cx = bboxCx;
            cy = bboxCy;
          } else {
            debugPrint('⚠️ Both bbox and center_point are corrupt/corner-stuck for "$wordVal" — marking for auto-fix');
            cx = -1.0;
            cy = -1.0;
          }
        } else if (isXEdgeStuck) {
          // X is stuck at left edge (0.05)
          if (hasValidBboxX) {
            debugPrint('⚠️ center_point X was stuck at left edge ($cx) for "$wordVal" — rescuing with bbox X ($bboxCx)');
            cx = bboxCx;
          } else {
            debugPrint('⚠️ center_point X was stuck at left edge ($cx) and bbox X is at edge for "$wordVal" — marking X for auto-fix');
            cx = -1.0;
          }
        } else if (isYEdgeStuck) {
          // Y is stuck at top edge (0.05)
          if (hasValidBboxY) {
            debugPrint('⚠️ center_point Y was stuck at top edge ($cy) for "$wordVal" — rescuing with bbox Y ($bboxCy)');
            cy = bboxCy;
          } else {
            debugPrint('⚠️ center_point Y was stuck at top edge ($cy) and bbox Y is at edge for "$wordVal" — marking Y for auto-fix');
            cy = -1.0;
          }
        } else {
          debugPrint('✅ Corrupt bbox for "$wordVal", but center_point ($cx, $cy) is valid — trusting center_point');
        }
      }
    } else {
      // No center_point provided — fallback to bbox center if healthy
      if (isBboxHealthy) {
        cx = bboxCx;
        cy = bboxCy;
      } else {
        final hasValidBboxY = bbox.yMin >= 0.12 || (bbox.yMax >= 0.20 && bboxHeight >= 0.03);
        final hasValidBboxX = bbox.xMin > 0.05 && bboxWidth >= 0.02;
        cx = hasValidBboxX ? bboxCx : -1.0;
        cy = hasValidBboxY ? bboxCy : -1.0;
      }
    }

    // Only apply geometric adjustments if coordinates are valid and not marked as broken (-1.0)
    if (cx >= 0 && cy >= 0) {
      // Base surface adjustment: words like table/desk/floor/counter should not sit in the dead center
      // where other objects (cups, plates) rest, especially if the bbox is huge (>70% of screen).
      const surfaceWords = {'table', 'desk', 'counter', 'countertop', 'floor', 'ground', 'tablecloth'};
      final isSurfaceWord = surfaceWords.contains(wordVal.trim().toLowerCase());
      if (isSurfaceWord && bboxWidth > 0.70 && bboxHeight > 0.70 && cy < 0.75) {
        debugPrint('⚠️ Surface word "$wordVal" has full-screen bbox and center ($cx, $cy) on top of objects — shifting down to bare surface');
        cy = 0.85; // Shift down towards bottom where table surface is exposed
      }

      // Underlay object adjustment (saucer, coaster, placemat, tray):
      // When a cup/food sits on a saucer, the geometric center is ALWAYS the cup!
      // The only exposed part is the bottom curved rim (at ~88% of the bounding box height).
      const underlayWords = {'saucer', 'coaster', 'placemat', 'tray'};
      final isUnderlayWord = underlayWords.contains(wordVal.trim().toLowerCase());
      if (isUnderlayWord && bboxHeight > 0.06) {
        final middleThreshold = bbox.yMin + bboxHeight * 0.78;
        if (cy < middleThreshold) {
          final rimY = (bbox.yMin + bboxHeight * 0.88).clamp(0.05, 0.95);
          debugPrint('⚠️ Underlay word "$wordVal" center ($cx, $cy) was inside cup/object — shifting down to exposed bottom rim ($cx, $rimY)');
          cy = rimY;
        }
      }

      // Container object adjustment (cup, mug, glass, bowl, pot, vase, jug, pitcher):
      // When a cup contains liquid/coffee, the liquid is in the top opening (upper 55%).
      // The physical cup ceramic/glass body is in the lower half (at ~76% of height).
      const containerWords = {'cup', 'mug', 'glass', 'bowl', 'pot', 'vase', 'jug', 'pitcher'};
      final isContainerWord = containerWords.contains(wordVal.trim().toLowerCase());
      if (isContainerWord && bboxHeight > 0.06) {
        final upperThreshold = bbox.yMin + bboxHeight * 0.60;
        if (cy < upperThreshold) {
          final bodyY = (bbox.yMin + bboxHeight * 0.76).clamp(0.05, 0.95);
          debugPrint('⚠️ Container word "$wordVal" center ($cx, $cy) was in liquid/opening — shifting down to ceramic/glass body ($cx, $bodyY)');
          cy = bodyY;
        }
      }
    }

    return VocabularyItem(
      word: wordVal,
      type: typeVal,
      thai: thaiVal,
      topic: topicVal,
      boundingBox: bbox,
      centerX: cx,
      centerY: cy,
      englishSentence: json['english_sentence']?.toString(),
      thaiSentence: json['thai_sentence']?.toString(),
    );
  }

  /// Parse a value to double safely
  static double? _parseDouble(dynamic val) {
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }

  /// Create a copy with modified fields
  VocabularyItem copyWith({String? topic, double? centerX, double? centerY}) {
    return VocabularyItem(
      word: word,
      type: type,
      thai: thai,
      topic: topic ?? this.topic,
      boundingBox: boundingBox,
      centerX: centerX ?? this.centerX,
      centerY: centerY ?? this.centerY,
      englishSentence: englishSentence,
      thaiSentence: thaiSentence,
    );
  }

  /// Create a copy with sentences added
  VocabularyItem withSentences(String english, String thai) {
    return VocabularyItem(
      word: word,
      type: type,
      thai: this.thai,
      topic: this.topic,
      boundingBox: boundingBox,
      centerX: centerX,
      centerY: centerY,
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

  factory BoundingBox.fromJson(dynamic rawJson) {
    double xMin = 0.4;
    double yMin = 0.4;
    double xMax = 0.6;
    double yMax = 0.6;

    if (rawJson is List && rawJson.length >= 4) {
      final nums = rawJson
          .map((e) => (e is num) ? e.toDouble() : double.tryParse(e.toString()) ?? 0.0)
          .toList();
      // Gemini box_2d is [ymin, xmin, ymax, xmax]
      yMin = nums[0];
      xMin = nums[1];
      yMax = nums[2];
      xMax = nums[3];
    } else if (rawJson is Map) {
      final json = rawJson;

      double? parseNum(List<String> keys) {
        for (final key in keys) {
          final val = json[key];
          if (val is num) return val.toDouble();
          if (val is String) {
            final parsed = double.tryParse(val);
            if (parsed != null) return parsed;
          }
        }
        return null;
      }

      xMin = parseNum(['x_min', 'xmin', 'x1', 'left']) ?? 0.4;
      yMin = parseNum(['y_min', 'ymin', 'y1', 'top']) ?? 0.4;
      xMax = parseNum(['x_max', 'xmax', 'x2', 'right']) ?? 0.6;
      yMax = parseNum(['y_max', 'ymax', 'y2', 'bottom']) ?? 0.6;
    }

    // If Gemini returned coordinates in 0..1000 integer scale, normalize to 0.0..1.0 ratio
    if (xMin > 1.0 || xMax > 1.0 || yMin > 1.0 || yMax > 1.0) {
      xMin /= 1000.0;
      yMin /= 1000.0;
      xMax /= 1000.0;
      yMax /= 1000.0;
    }

    // Keep coordinates within [0.0, 1.0] bounds
    xMin = xMin.clamp(0.0, 1.0);
    yMin = yMin.clamp(0.0, 1.0);
    xMax = xMax.clamp(0.0, 1.0);
    yMax = yMax.clamp(0.0, 1.0);

    if (xMin >= xMax) xMax = (xMin + 0.04).clamp(0.0, 1.0);
    if (yMin >= yMax) yMax = (yMin + 0.04).clamp(0.0, 1.0);

    return BoundingBox(
      xMin: xMin,
      yMin: yMin,
      xMax: xMax,
      yMax: yMax,
    );
  }

  /// Convert to center point for dot positioning (guarantee safe margin away from borders)
  (double x, double y) get center {
    final rawX = (xMin + xMax) / 2;
    final rawY = (yMin + yMax) / 2;
    return (rawX.clamp(0.06, 0.94), rawY.clamp(0.06, 0.94));
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
    final json = VocabularyExtractionResult._cleanAndParseJson(jsonString);
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
