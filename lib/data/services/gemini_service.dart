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
    int maxRetriesPerModel = _maxRetries,
  }) async {
    Duration delay = _initialDelay;
    int primaryAttempts = 0;
    int fallbackAttempts = 0;
    bool useFallback = false;
    final maxTotalAttempts = maxRetriesPerModel * 2;

    while (true) {
      if (useFallback) {
        fallbackAttempts++;
      } else {
        primaryAttempts++;
      }
      final totalAttempts = primaryAttempts + fallbackAttempts;

      try {
        return await operation(useFallback).timeout(
          _requestTimeout,
          onTimeout: () => throw TimeoutException(
              'Request timed out after ${_requestTimeout.inSeconds}s'),
        );
      } catch (e) {
        final isRetryable = _isRetryableError(e);

        // Check if we should switch to fallback model
        // Switch if:
        // 1. Primary model has exhausted its retries (primaryAttempts >= maxRetriesPerModel)
        // 2. Or instant-fallback error (FormatException, TypeError, 404/not supported)
        final errorStrLower = e.toString().toLowerCase();
        final isSyntaxOrNotFound = e is FormatException ||
            e is TypeError ||
            errorStrLower.contains('not found') ||
            errorStrLower.contains('not supported') ||
            errorStrLower.contains('404');

        final shouldSwitchToFallback = !useFallback &&
            (primaryAttempts >= maxRetriesPerModel || isSyntaxOrNotFound);

        if (!isRetryable ||
            totalAttempts >= maxTotalAttempts ||
            (useFallback && fallbackAttempts >= maxRetriesPerModel)) {
          debugPrint(
            '❌ Max retries reached (primary: $primaryAttempts, fallback: $fallbackAttempts) or non-retryable error: $e',
          );

          final errorStr = e.toString().toLowerCase();

          // Check if it's a quota exceeded error (429)
          if (errorStr.contains('429') ||
              errorStr.contains('quota') ||
              errorStr.contains('rate limit') ||
              errorStr.contains('rate_limit')) {
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

        if (isSyntaxOrNotFound) {
          useFallback = true;
          delay = _initialDelay;
          debugPrint(
            '⚠️ Instant fallback model switch due to: $e',
          );
        } else if (shouldSwitchToFallback) {
          useFallback = true;
          debugPrint(
            '⚠️ Primary model failed $primaryAttempts/$maxRetriesPerModel times. Switching to fallback model after ${delay.inSeconds}s due to: $e',
          );
          await Future.delayed(delay);
          delay = _initialDelay; // Reset delay for fallback model
        } else if (!useFallback) {
          debugPrint(
            '⚠️ Retry $primaryAttempts/$maxRetriesPerModel on primary model after ${delay.inSeconds}s due to: $e',
          );
          await Future.delayed(delay);
          delay *= 2; // Exponential backoff (3s -> 6s -> 12s)
        } else {
          debugPrint(
            '⚠️ Retry $fallbackAttempts/$maxRetriesPerModel on fallback model after ${delay.inSeconds}s due to: $e',
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

  /// Check if returned words match requested words (case-insensitive & inflection tolerant)
  bool _wordsMatch(Set<String> returned, Set<String> requested) {
    final returnedLower = returned.map((w) => w.toLowerCase()).toSet();
    final requestedLower = requested.map((w) => w.toLowerCase()).toSet();

    for (final req in requestedLower) {
      final hasMatch = returnedLower.any(
        (ret) =>
            ret == req ||
            ret.startsWith(req) ||
            req.startsWith(ret) ||
            _isInflectionMatch(ret, req),
      );
      if (!hasMatch) return false;
    }
    return true;
  }

  /// Normalize returned JSON word key back to exact requested word string
  static String _normalizeWordKey(
      String returnedWord, List<String> requestedWords) {
    final retLower = returnedWord.toLowerCase().trim();

    // 1. Direct match (case-insensitive)
    for (final req in requestedWords) {
      if (req.toLowerCase().trim() == retLower) {
        return req;
      }
    }

    // 2. Stem / inflection match (e.g. crusts -> crust, running -> run)
    for (final req in requestedWords) {
      final reqLower = req.toLowerCase().trim();
      if (retLower.startsWith(reqLower) ||
          reqLower.startsWith(retLower) ||
          _isInflectionMatch(retLower, reqLower)) {
        return req;
      }
    }

    return returnedWord;
  }

  static bool _isInflectionMatch(String w1, String w2) {
    if (w1 == '${w2}s' || w2 == '${w1}s') return true;
    if (w1 == '${w2}es' || w2 == '${w1}es') return true;
    if (w1 == '${w2}ies' || w2 == '${w1}ies') return true;
    if (w1.length > 3 && w2.length > 3) {
      final prefix1 = w1.substring(0, w1.length - 2);
      final prefix2 = w2.substring(0, w2.length - 2);
      if (w1.startsWith(prefix2) || w2.startsWith(prefix1)) return true;
    }
    return false;
  }

  /// Catches known word-category mismatches the model keeps making
  /// despite prompt instructions. Runs after generation, before topic fixing.
  String _fixWordMismatch(String word, String context, String category) {
    final w = word.toLowerCase().trim();
    final contextLower = '$category $context'.toLowerCase();

    // 1. Handlebar: Banned unless vehicle keywords exist in context
    if (w == 'handlebar') {
      const vehicleKeywords = {
        'bicycle',
        'motorcycle',
        'bike',
        'scooter',
        'moped',
        'vehicle',
        'cyclist',
        'ride',
        'transport',
        'wheels',
        '2-wheeler'
      };
      final hasVehicleSupport =
          vehicleKeywords.any((k) => contextLower.contains(k));
      if (!hasVehicleSupport) {
        debugPrint(
          '⚠️ Word mismatch caught by code safety net: "handlebar" without vehicle context — falling back to "handle"',
        );
        return 'handle';
      }
    }

    // 2. Saucer: Banned ONLY IF there are no cup/beverage/dining keywords and category is unrelated
    if (w == 'saucer') {
      const saucerKeywords = {
        'cup',
        'mug',
        'coffee',
        'tea',
        'espresso',
        'crema',
        'latte',
        'cappuccino',
        'drink',
        'beverage',
        'ceramic',
        'pot',
        'cafe',
        'dining',
        'food',
        'home',
        'daily_life',
        'daily life',
        'saucer',
        'coffeecup',
        'teacup'
      };
      final hasSaucerSupport =
          saucerKeywords.any((k) => contextLower.contains(k));
      if (!hasSaucerSupport) {
        debugPrint(
          '⚠️ Word mismatch caught by code safety net: "saucer" without cup/coffee/dining context — falling back to "plate"',
        );
        return 'plate';
      }
    }

    // 3. Foliage: Banned ONLY IF context is explicitly fabric/apparel/print without any botanical/nature/greenery context
    if (w == 'foliage') {
      const foliageKeywords = {
        'leaf',
        'leaves',
        'bush',
        'branch',
        'greenery',
        'plant',
        'tree',
        'forest',
        'lawn',
        'garden',
        'nature',
        'botanical',
        'flora',
        'herb',
        'flower',
        'pot',
        'potted',
        'outdoor',
        'succulent',
        'vegetation',
        'woodgrain'
      };
      const printKeywords = {
        'fabric',
        'cloth',
        'pattern',
        'print',
        'apparel',
        'dress',
        'shirt',
        'clothing'
      };

      final hasBotanicalSupport =
          foliageKeywords.any((k) => contextLower.contains(k)) ||
              category.toLowerCase() == 'nature';
      final hasPrintContext =
          printKeywords.any((k) => contextLower.contains(k));

      if (!hasBotanicalSupport && hasPrintContext) {
        debugPrint(
          '⚠️ Word mismatch caught by code safety net: "foliage" on printed cloth/pattern — falling back to "pattern"',
        );
        return 'pattern';
      }
    }

    // 4. Upholstery: Banned unless furniture/seating/padding context exists
    if (w == 'upholstery') {
      const upholsteryKeywords = {
        'chair',
        'sofa',
        'couch',
        'armchair',
        'cushion',
        'seat',
        'furniture',
        'padded',
        'interior',
        'home',
        'living'
      };
      final hasFurnitureSupport =
          upholsteryKeywords.any((k) => contextLower.contains(k));
      if (!hasFurnitureSupport) {
        debugPrint(
          '⚠️ Word mismatch caught by code safety net: "upholstery" without furniture context — falling back to "fabric"',
        );
        return 'fabric';
      }
    }

    return word;
  }

  /// Post-process AI topic categorization to fix common mistakes
  /// This is a safety net for cases where AI might miscategorize
  String _fixTopicCategory(String word, String aiTopic, String context) {
    // Normalize word for matching
    final normalizedWord = word.toLowerCase().trim();

    // Special case rules for common ambiguous words
    final specialCases = {
      // Accessories that often get miscategorized
      'glasses':
          _isMedicalContext(context) ? TopicCategories.health : TopicCategories.dailyLife,
      'sunglasses': TopicCategories.dailyLife,
      'watch': _hasDigitalKeywords(context)
          ? TopicCategories.technology
          : TopicCategories.dailyLife,

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
      'camera': _hasHobbyKeywords(context)
          ? TopicCategories.hobbies
          : TopicCategories.technology,

      // People/professions (context-dependent)
      'doctor': _isEducationalContext(context)
          ? TopicCategories.people
          : TopicCategories.health,
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
      'plant': _isHomeContext(context)
          ? TopicCategories.home
          : TopicCategories.nature,

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
      'book': _hasHobbyKeywords(context)
          ? TopicCategories.hobbies
          : TopicCategories.entertainment,
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
      'doctor',
      'hospital',
      'clinic',
      'nurse',
      'medical',
      'prescription',
      'reading',
      'eye',
      'vision',
      'sight',
      'medicine',
      'pharmacy',
      'treatment',
      'checkup'
    ];
    final contextLower = context.toLowerCase();
    return medicalKeywords.any((keyword) => contextLower.contains(keyword));
  }

  /// Check if context contains digital/tech keywords
  bool _hasDigitalKeywords(String context) {
    final techKeywords = [
      'smart',
      'digital',
      'electronic',
      'app',
      'screen',
      'bluetooth',
      'charging',
      'notification',
      'fitness tracker'
    ];
    final contextLower = context.toLowerCase();
    return techKeywords.any((keyword) => contextLower.contains(keyword));
  }

  /// Check if context contains hobby/leisure keywords
  bool _hasHobbyKeywords(String context) {
    final hobbyKeywords = [
      'hobby',
      'leisure',
      'fun',
      'enjoy',
      'relax',
      'photography',
      'playing',
      'collection',
      'interest'
    ];
    final contextLower = context.toLowerCase();
    return hobbyKeywords.any((keyword) => contextLower.contains(keyword));
  }

  /// Check if context contains educational keywords
  bool _isEducationalContext(String context) {
    final eduKeywords = [
      'school',
      'classroom',
      'lesson',
      'learning',
      'teaching',
      'education',
      'training',
      'course',
      'study'
    ];
    final contextLower = context.toLowerCase();
    return eduKeywords.any((keyword) => contextLower.contains(keyword));
  }

  /// Check if context contains home/household keywords
  bool _isHomeContext(String context) {
    final homeKeywords = [
      'home',
      'house',
      'room',
      'living room',
      'bedroom',
      'kitchen',
      'bathroom',
      'furniture',
      'decor',
      'interior'
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
    final systemInstruction = '''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TOPIC CATEGORIZATION PER WORD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
For EACH vocabulary item, select exactly ONE category that best describes it:

  • food          — ${TopicCategories.descriptions[TopicCategories.food]}
  • people        — ${TopicCategories.descriptions[TopicCategories.people]}
  • nature        — ${TopicCategories.descriptions[TopicCategories.nature]}
  • home          — ${TopicCategories.descriptions[TopicCategories.home]}
  • Daily Life    — ${TopicCategories.descriptions[TopicCategories.dailyLife]}
  • clothing      — ${TopicCategories.descriptions[TopicCategories.clothing]}
  • hobbies       — ${TopicCategories.descriptions[TopicCategories.hobbies]}
  • education     — ${TopicCategories.descriptions[TopicCategories.education]}
  • work          — ${TopicCategories.descriptions[TopicCategories.work]}
  • technology    — ${TopicCategories.descriptions[TopicCategories.technology]}
  • health        — ${TopicCategories.descriptions[TopicCategories.health]}
  • entertainment — ${TopicCategories.descriptions[TopicCategories.entertainment]}
  • other         — ${TopicCategories.descriptions[TopicCategories.other]}

IMPORTANT: Assign each extracted vocabulary item to the single category that most accurately describes that specific word's primary meaning in the visual context of the photo.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WORD EXTRACTION RULES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Identify EXACTLY 5 vocabulary items: a mix of nouns (objects) and verbs (visible actions).

Noun items
• MUST be clearly visible, prominent FOREGROUND physical objects.
• STRICTLY NO BORDER-EDGE OR CUT-OFF OBJECTS: DO NOT pick objects that are cut off, cropped, or located near the borders/edges of the photo frame (e.g. x < 0.10 or x > 0.90 or y < 0.10 or y > 0.90). All selected objects MUST be comfortably contained within the main central area of the frame.
• STRICTLY UN-OCCLUDED: DO NOT pick objects that are occluded, covered, or hidden behind other objects or clutter.
• Each from a different noun category when possible.
• One bounding box per object; pick the most prominent, unobstructed instance.

Verb items
• Must be a visible action actively occurring in the image
• Must have a clear human or subject performing it
• Minimum 1 verb, maximum 3 verbs across the 5 items
• If no action is visible → all 5 items are nouns

Combined rule: Nouns + verbs = EXACTLY 5 items total.
CRITICAL QUANTITY GUARANTEE: You MUST ALWAYS return EXACTLY 5 items. Never return fewer than 5 items (e.g. 3 or 4). If there are not enough items matching the target category, fill the remaining slots with any prominent, clearly visible foreground objects in the image.

ANCHOR WORD REQUIREMENT:
Among the 5 items, AT LEAST 1 item MUST be the single most visually dominant, unambiguous whole-object noun in the image (the "main subject" a person would name first if asked "what is this photo of?").
• At higher CEFR levels (B1/B2), use a more specific noun for the main subject ONLY when the visual evidence in the image is sufficient to distinguish it from broader alternatives.
• Exclude: cut-off or border-edge objects, occluded or hidden objects, shadows, lighting effects, abstract concepts, background blur, implied or off-screen actions.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WORD RULES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• One single English word (noun or base-form verb)
• No spaces, hyphens, or adjective+noun combinations
• Validation: Can a learner look at the image and confirm this word?
  ✅ YES → use it | ❌ NO → find a more visually grounded synonym

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CORE PRINCIPLE — LEXICAL PRECISION, NOT ARTIFICIAL DIFFICULTY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Higher CEFR levels MUST NOT be achieved by replacing common words with rare, literary, technical, or abstract synonyms.

Instead, increase lexical sophistication through PRECISION and SPECIFICITY when the image provides sufficient visual evidence.

PREFER:
• a more precise noun over a broad hypernym
• a visually identifiable sub-structure over the whole object
• a specific material, texture, or feature when clearly visible
• a specific functional component when clearly visible
• a domain-specific term ONLY when visual evidence clearly supports it and the term is genuinely useful for an upper-intermediate learner

NEVER:
• invent hidden parts or details
• infer properties that cannot be visually verified
• choose a word merely because it sounds advanced
• use rare dictionary words to artificially satisfy B2
• replace a natural common word with an unnatural hypernym

IMPORTANT:
Specialized does NOT automatically mean B2.
Rare does NOT automatically mean B2.
Technical does NOT automatically mean B2.

The selected word MUST be both:
1. visually grounded in the image, and
2. appropriate and useful for the requested CEFR level ($level).

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CEFR LEVEL CALIBRATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• A1 (Beginner):
  Whole main objects and very common concrete nouns/verbs.

• A2 (Elementary):
  Common visible parts, features, and familiar concrete details.

• B1 (Intermediate):
  More specific functional components, physical features, and descriptive concrete nouns.

• B2 (Upper-Intermediate):
  Precise, less-common but natural vocabulary that an upper-intermediate learner can use to describe the image. This may include specialized visual details, sub-structures, materials, textures, mechanisms, or domain-specific terms WHEN they are clearly visible and genuinely useful.
  *Note*: B2 does NOT require every word to be technical or obscure, nor does it force micro-parts when not supported by the image. If the image does not provide sufficient visual evidence for a more specific B2 term, retain the most precise natural word that the image supports.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
VISUAL EVIDENCE THRESHOLD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Before selecting any specialized or B2-level word, ask:
"Could a learner point to the EXACT visual feature in the image that this word refers to?"

• If NO → REJECT the word.
• If the word requires hidden knowledge, inference, or assumptions about the object's identity, material, function, or composition → REJECT IT.
• The image MUST provide sufficient visual evidence for the word itself, not merely for the general category of the object.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ABSOLUTE PROHIBITIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• NO OVERLY BROAD UMBRELLA TERMS (HYPERNYMS): Never use generic category umbrellas just to sound advanced.
• NO ABSTRACT FOOD META-WORDS: DO NOT overuse abstract food meta-words for every dish. Label specific visible ingredients, produce, condiments, or food components actually shown in the photo.
• NO CATEGORY / SPECIES MISMATCHES: Never use a wrong category or vehicle type (e.g. 2-wheeler vs 4-wheeler, pet species, stemware vs mug).
• NO COMPONENT TYPE MISMATCHES:
  - General container, pan, bag, or pot grips must use standard container holding terms (never vehicle steering terms).
  - Standard picnic/dinner plates or serving dishes must use standard plate terms (never specialty tea/coffee under-cup terms).
  - Colorful flower blossoms or petals must use flower bloom terms (never green leaf/botanical greenery terms).
• ACCURATE THAI TRANSLATIONS: The Thai translation ("thai") MUST strictly match the precise, natural primary dictionary meaning of the English word.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WORD SELECTION PRIORITY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. VISUAL ACCURACY & INTUITION (STRICT PRIMARY MANDATE):
   • The word MUST be 100% factually accurate for the specific item in the image, and make 100% natural sense when looking at the tap dot.

2. CEFR LEVEL DIFFICULTY:
   • Match requested level ($level) using the calibration and visual evidence threshold above.

3. CONTEXT & CATEGORY RELEVANCE:
   • Align with the specified category and overall scene context.

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

Rule 2 — BASE & SURFACE OBJECTS:
• DO NOT draw a bounding box around the whole image for a table/surface!
• Instead, choose a SPECIFIC EXPOSED/BARE PATCH of the surface (e.g., bare wood grain at the bottom-left or bottom-right corner).
• The center_point and bounding_box MUST be placed on that bare patch — NEVER on cups, plates, food, or items sitting on top!

Rule 3 — OCCLUDED & STACKED OBJECTS:
When an object's center is covered by another object, SHIFT the point to the nearest EXPOSED surface:
• Seating near a table → Place center_point on the EXPOSED SEAT CUSHION, ARMREST, or BACKREST (on the outer side, away from the table edge), NEVER on the table surface!
• Dishes filled with food → Place center_point ON THE EXPOSED CERAMIC RIM / EDGE (near the bottom or side of the dish), NOT on the contents inside!
• Containers with liquid inside → Place center_point on the CERAMIC / GLASS BODY (the outer wall in the lower half of the container), NOT on the liquid surface!
• Base plates / under-dishes with items on top → Place center_point AT THE BOTTOM CURVED RIM of the under-dish — NEVER inside the top item body!
• Prep boards with items on top → tap the EXPOSED HANDLE or bare edge

Rule 4 — VERBS & ACTIONS:
• For verbs, the action is performed by a person/subject in the photo!
• Place the center_point and bounding_box DIRECTLY ON THE PERSON / BODY PART / SUBJECT performing the action:
  - Arm or hand movements → place on the outstretched ARM or HAND
  - Facial expressions → place on the FACE or HEAD
  - Whole-body posture or locomotion → place on the BODY of the subject
• ❌ NEVER return (0.0, 0.0) or an empty/degenerate box for a verb!

Rule 5 — CLUSTERS, PLANTS & GROUPS:
• For plants, trees, or botanical elements:
  - Place the center_point and bounding_box directly on the CLEARLY VISIBLE LEAVES or flower bloom!
  - ❌ NEVER return (0,0) or stick to the top-left edge!
• For groups or clusters of items:
  - Pick ONE PROMINENT, CLEARLY VISIBLE ITEM in the cluster and place the center_point directly on it!

Rule 6 — STANDALONE OBJECTS:
For fully visible objects with nothing blocking, place the point at the object's visual center.

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
• level           — $level (CRITICAL: Every word extracted MUST strictly match $level level difficulty!)
• category        — $category
• english_variant — $englishVariant (US or UK English)
$excludeWordsText

Extract exactly 5 vocabulary items from the image, strictly matching the requested CEFR level: $level.''');

    final mimeType = _detectMimeType(imageData);
    final imagePart = DataPart(mimeType, imageData);

    return await _retryWithBackoff((useFallback) async {
      // Use higher temperature for regenerate to get more variety
      final temp = isRegenerate ? 0.7 : 0.6;
      final maxTokens =
          isRegenerate ? 10240 : 8192; // Increased to prevent truncation

      final model = useFallback ? _fallbackVisionModel : _primaryVisionModel;
      if (useFallback) {
        debugPrint('🔄 Using fallback vision model (gemini-3.5-flash)');
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
        debugPrint(
            '⚠️ AI returned only ${result.vocabList.length} items instead of requested 5. Retrying...');
        throw FormatException(
            'AI returned only ${result.vocabList.length} items instead of requested 5');
      }

      // Apply post-processing to fix word mismatches & topic categorization
      result = result.copyWith(
        vocabList: result.vocabList.map((item) {
          final context =
              '$category ${item.englishSentence ?? ''} ${item.thaiSentence ?? ''} ${result.vocabList.map((v) => v.word).join(' ')}';
          final fixedWord = _fixWordMismatch(item.word, context, category);

          // If word was corrected by safety net, update Thai translation accordingly
          String fixedThai = item.thai;
          if (fixedWord != item.word) {
            final fallbackThai = {
              'handle': 'หูหิ้ว',
              'plate': 'จาน',
              'pattern': 'ลวดลาย',
              'fabric': 'ผ้า',
            };
            if (fallbackThai.containsKey(fixedWord)) {
              fixedThai = fallbackThai[fixedWord]!;
            }
          }

          final fixedTopic = _fixTopicCategory(fixedWord, item.topic, context);
          return item.copyWith(
              word: fixedWord, thai: fixedThai, topic: fixedTopic);
        }).toList(),
      );

      // Seating vs Table adjustment (chair, armchair, stool, bench, sofa near a table):
      // When a chair is tucked beside a table, the inner side of the chair's bbox is covered by the table.
      // Shift the chair's dot towards the outer exposed seat cushion/backrest (away from table).
      const seatingWords = {
        'chair',
        'armchair',
        'stool',
        'bench',
        'sofa',
        'couch'
      };
      const tableWords = {'table', 'desk', 'counter', 'countertop'};
      final tableItems = result.vocabList
          .where((v) => tableWords.contains(v.word.toLowerCase()))
          .toList();

      if (tableItems.isNotEmpty) {
        final tableItem = tableItems.first;
        result = result.copyWith(
          vocabList: result.vocabList.map((item) {
            if (seatingWords.contains(item.word.toLowerCase()) &&
                item.centerX >= 0) {
              final chairWidth = item.boundingBox.xMax - item.boundingBox.xMin;
              if (chairWidth > 0.10) {
                if (tableItem.centerX > item.centerX) {
                  // Table is to the right -> place chair dot on the left side of chair (outer cushion)
                  final outerX = item.boundingBox.xMin + chairWidth * 0.32;
                  if (item.centerX > outerX) {
                    debugPrint(
                        '⚠️ Chair "${item.word}" dot (${item.centerX.toStringAsFixed(2)}) was near table (${tableItem.centerX.toStringAsFixed(2)}) — shifting left to outer cushion (${outerX.toStringAsFixed(2)})');
                    return item.copyWith(centerX: outerX);
                  }
                } else {
                  // Table is to the left -> place chair dot on the right side of chair
                  final outerX = item.boundingBox.xMax - chairWidth * 0.32;
                  if (item.centerX < outerX) {
                    debugPrint(
                        '⚠️ Chair "${item.word}" dot (${item.centerX.toStringAsFixed(2)}) was near table (${tableItem.centerX.toStringAsFixed(2)}) — shifting right to outer cushion (${outerX.toStringAsFixed(2)})');
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
      debugPrint(
          '────────── EXTRACTED VOCABULARY (${result.vocabList.length} ITEMS) ──────────');
      for (int i = 0; i < result.vocabList.length; i++) {
        final item = result.vocabList[i];
        final (bboxCx, bboxCy) = item.boundingBox.center;
        final cpX = (item.centerX * 100).toStringAsFixed(1);
        final cpY = (item.centerY * 100).toStringAsFixed(1);
        final bpX = (bboxCx * 100).toStringAsFixed(1);
        final bpY = (bboxCy * 100).toStringAsFixed(1);
        debugPrint(
            '  ${i + 1}. ${item.word} (${item.type}) → ${item.thai} [Topic: ${item.topic}] Center: ($cpX%, $cpY%) BBox: ($bpX%, $bpY%)');
      }
      debugPrint(
          '────────────────────────────────────────────────────────────');

      // Coordinate sanity check: detect when AI returns all dots stacked at the same x or y
      final validItems = result.vocabList.where((v) => v.centerX >= 0).toList();

      if (validItems.isNotEmpty) {
        final cxValues = validItems.map((v) => v.centerX).toList()..sort();
        final cyValues = validItems.map((v) => v.centerY).toList()..sort();
        final cxRange = cxValues.last - cxValues.first;
        final cyRange = cyValues.last - cyValues.first;

        // If ALL valid dots are truly stacked in a razor-thin degenerate line (<3%) or tiny clump (<4%), retry
        final isTrulyStacked = (cxRange < 0.04 && cyRange < 0.04) ||
            (cxRange < 0.03) ||
            (cyRange < 0.03);
        if (validItems.length >= 4 && isTrulyStacked) {
          debugPrint(
              '⚠️ Coordinates look broken: all dots stacked! cx range=${(cxRange * 100).toStringAsFixed(1)}%, cy range=${(cyRange * 100).toStringAsFixed(1)}%. Retrying...');
          throw FormatException(
            'AI returned stacked coordinates (cx range: ${(cxRange * 100).toStringAsFixed(1)}%, cy range: ${(cyRange * 100).toStringAsFixed(1)}%). Retrying for better spatial accuracy.',
          );
        }
      }

      // Fix broken items: handle per-axis coordinate repair
      final hasAnyBroken =
          result.vocabList.any((v) => v.centerX < 0 || v.centerY < 0);
      if (hasAnyBroken) {
        final brokenCount = result.vocabList
            .where((v) => v.centerX < 0 || v.centerY < 0)
            .length;
        debugPrint('🔧 Fixing $brokenCount item(s) with broken coordinates...');

        // Collect all existing valid 2D positions
        final validDots = result.vocabList
            .where((v) => v.centerX >= 0 && v.centerY >= 0)
            .map((v) => (v.centerX, v.centerY))
            .toList();

        const upperWords = {
          'balloon',
          'balloons',
          'banner',
          'cloud',
          'sky',
          'ceiling',
          'lamp',
          'light',
          'chandelier',
          'sun',
          'moon',
          'star',
          'garland'
        };
        const plantWords = {
          'plant',
          'plants',
          'tree',
          'trees',
          'flower',
          'flowers',
          'leaf',
          'leaves',
          'bush',
          'shrub',
          'rosemary',
          'succulent',
          'houseplant',
          'foliage',
          'branch',
          'stem',
          'herb',
          'herbs'
        };
        const boardWords = {
          'board',
          'cutting board',
          'wooden board',
          'charcuterie board',
          'tray',
          'platter'
        };
        const surfaceWords = {
          'table',
          'desk',
          'counter',
          'countertop',
          'floor',
          'ground',
          'tablecloth',
          'rug',
          'carpet',
          'grass',
          'bowl',
          'plate',
          'dish',
          'saucer'
        };

        final fixedList = result.vocabList.map((item) {
          if (item.centerX >= 0 && item.centerY >= 0)
            return item; // Fully valid

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
                    ? [
                        0.18,
                        0.82,
                        0.12,
                        0.88,
                        0.25,
                        0.75
                      ] // Potted plants/leaves on the sides
                    : (isBoard
                        ? [
                            0.08,
                            0.88,
                            0.12,
                            0.82
                          ] // Wooden handle or outer wood rim
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

          debugPrint(
              '  → Fixed "${item.word}": cx=${item.centerX < 0 ? "❌→$fixedCx" : "✓"} cy=${item.centerY < 0 ? "❌→$fixedCy" : "✓(${item.centerY.toStringAsFixed(2)})"}');
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
    Uint8List?
        imageData, // Optional: if provided, sentences will be grounded to the image
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
CEFR LEVEL GUIDE & LENGTH BOUNDS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Level | Sentence structure, word length & Vocabulary level
A1    | Simple SVO, present tense only (4–8 words)
A2    | Simple sentences, 1–2 clauses (8–14 words)
B1    | Compound sentences, common tenses (12–20 words)
B2    | Complex sentences, varied tenses (15–25 words max)

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
  Example (A1): "The cake is on the wooden table."
  Example (B2): "The handcrafted pastry features a delicate, golden-brown crust with subtle sugar dusting."

COMMAND
  Purpose : instruction, suggestion, or warning related to the visual context
  Form    : base-verb opening; no subject (or "Let's…" for inclusive)
  Example (A1): "Eat the cake slowly."
  Example (B2): "Handle the fragile pastry gently so as not to ruin its intricate frosting."

WISH
  Purpose : desire, hope, or hypothetical wish tied to the scene
  Form    : "I wish…" / "If only…" / "I hope…" / subjunctive clause
  Example (A1): "I wish I had a fresh cake."
  Example (B2): "I wish I could frequent an artisanal bakery like this every morning."

CONDITIONAL
  Purpose : if-clause structure based on the visual scene
  Form    : match conditional type to CEFR level above
  Example (A1): "If you eat this cake, you will like it."
  Example (B2): "Had you sampled this pastry fresh from the oven, you would have appreciated its texture."

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
IMAGE GROUNDING & RELEVANCE GUIDE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Every generated sentence MUST be directly grounded in and relevant to the provided image.
• Focus on what is actually present and happening in the photo (objects, actions, environment, visual details).
• General facts, textbook knowledge, insights, or proverbs ARE FULLY ALLOWED as long as they directly connect to what is visible in the photo!
  ✅ ALLOWED (Fact/Insight anchored in photo): "Eating a fresh salad, like the vibrant greens served on this plate, provides essential nutrients for health."
  ✅ ALLOWED (Knowledge/Observation anchored in photo): "Perusing a manuscript in a quiet study, as shown in the scene, expands one's understanding."
  ✅ ALLOWED (Direct Visual Description): "The ceramic vessel sitting on the wooden tray holds a warm beverage."
  ❌ STRICT PROHIBITION ON HYPOTHETICAL / ABSENT OBJECT CHEATING:
     NEVER invent hypothetical objects, vehicles, or items that are NOT visible in the photo just to force a target word into the sentence (e.g., NEVER write "Had a bicycle been parked nearby...", "If a car passed by...", or "Although cups are absent...").
     Every target word MUST refer to an object, detail, or action that is ACTUALLY VISIBLE in the photo!
  ❌ AVOID ONLY IF UNRELATED: Do NOT generate sentences that are completely detached from or have no connection to what is shown in the photo.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SENTENCE CONSTRAINTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Every sentence must satisfy ALL of the following:

1. Image grounding   — MUST connect directly to what is visible in the photo (objects, actions, scene context, or related facts)
2. CEFR complexity   — grammar, tense, clause structure, AND vocabulary difficulty should all scale with the requested level ($level). Higher levels should use less common, more sophisticated words where natural — see rule 6 for how vocabulary must still relate to the photo.
3. Word usage        — sentence must use the target vocab word naturally. Inflected forms (such as verb tenses e.g., run → running/ran, or plural nouns e.g., car → cars) are FULLY ALLOWED and encouraged for natural grammar, as long as the base root/lemma matches.
4. Context relevance — content MUST adapt to the selected category or custom user context:
   • "Food"       → eating, cooking, dining, or culinary context
   • "Moment"     → personal, emotional, or time-specific experience
   • "Nature"     → outdoor, botanical, or environmental setting
   • "Study"      → learning, academic, or reading context
   • "Daily Life" → everyday routine, household, or lifestyle situations
   • Custom text  → interpret user's intended topic and apply naturally
5. Sentence coherence — when generating multiple sentences, they must form ONE coherent story describing the image
   ✅ "The cart has groceries." + "The juice is in the cart." + "The bread is in bags."
   ❌ "The cart has groceries." + "I like running." + "Birds fly high." (unrelated)
6. Visual naming accuracy — When a word (including a harder/advanced word chosen for a higher CEFR level) refers to an object, person, or action visible in the photo, it MUST still be a specific, accurate label for that exact thing — not a broader, vaguer, or mismatched term picked only because it "sounds advanced."
   • Test: could someone look at the photo and the sentence side by side and immediately confirm the word correctly and precisely names what they see — with no hesitation and no other object it could equally mean? If yes, the word passes, no matter how advanced or rare it is.
   • FAILS this test: swapping in a broader category word for a specific visible object (e.g. "conveyance" or "automobile" for a visible bicycle — wrong specificity or wrong category).
   • PASSES this test: a harder but equally precise word for the same object, action, or detail (e.g. "handlebar", "pedal", "rusted frame", "cobblestone path" for a bicycle photo — still exactly what's visible, just less common vocabulary).
   • When increasing difficulty, prefer: (a) a more precise/specific word for a visible detail the simpler word glossed over, or (b) added descriptive/abstract vocabulary in the surrounding sentence (commentary, connectors, idioms) — over (c) replacing a correct simple label with a vaguer fancy one.
   • If unsure whether an advanced word still matches the image precisely, choose the plainer word that is definitely correct over the fancier word that might be wrong.

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
• For each selected tone → sentence(s) that include EVERY word from the input list
• REQUIREMENT: ALL provided words MUST appear in the sentence structure — no exceptions, no omissions
• Words should be integrated naturally (e.g., "I use my laptop, notebook, and book for studying")
• FALLBACK RULE FOR HIGH WORD COUNT:
  If the user provides more than 3 words (4–5 words) at level A1, A2, or B1, connecting 2 simple/compound clauses or sentences using basic conjunctions (e.g. "and", "with", "as", "while") is FULLY ALLOWED and encouraged instead of forcing a single awkward monster clause.
  (B2 sentence structure is complex/varied enough to naturally absorb up to 5 words in one sentence without this fallback.)

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
• combined: true  → flat "sentences" object + "words" array, no "results"
• CRITICAL WORD KEY RULE: In Normal Mode, the "word" field in the "results" array MUST strictly match the exact target vocabulary word as provided in the input list (e.g. use "word": "crust", NOT "word": "crusts"). You may conjugate or inflect the word inside the sentence text, but the JSON "word" key MUST be the exact input word string.
• sentence_note: MUST be set to empty string "" when there are no issues or constraints are satisfied cleanly. Do NOT include redundant explanations if sentence generation succeeded normally. Only populate with an explanation if impossible or if a fallback rule was applied.
• JSON ESCAPING GUARD: Output MUST be 100% strictly valid JSON. Properly escape any apostrophes, single quotes, or double quotes inside JSON string values (e.g. valid escaping for "doesn't", "it's").''';

    // User prompt with just the parameters
    final userPrompt = '''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
INPUT PARAMETERS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• words           — ${words.join(', ')}
• level           — $level
• tones           — ${tones.join(', ')}
• category        — $category
• combined        — $combined
• english_variant — $englishVariant (US or UK English)

DIRECTIVE: Every generated sentence MUST be directly tied to what is shown in the provided photo!
• You may describe visual features, actions, or include relevant facts, insights, or proverbs as long as they directly connect to the image content.

REMINDER: All sentences must describe ONE coherent scene. When multiple words are provided, their sentences should reference each other naturally (e.g., items in a cart, objects on a table).

${combined ? '''
⚠️ IMPORTANT FOR COMBINED MODE:
You MUST include ALL ${words.length} words in each combined sentence:
${words.map((w) => '  - "$w"').join('\n')}
DO NOT omit any word. Every single word must appear in the sentence structure (for A1/A2/B1 with > 3 words, 2 simple/compound connected clauses or sentences are allowed).''' : ''}

Generate sentences now describing the image.''';

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
        maxOutputTokens:
            8192, // Increased to prevent truncation (down from 16384)
      ),
    );

    final text = response.text ?? '';
    return SentenceGenerationResult.fromJson(text, tones,
        requestedWords: words);
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
        cleanJson =
            cleanJson.replaceAll('```json', '').replaceAll('```', '').trim();
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
      vocabList: (json['vocab_list'] as List<dynamic>?)
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
    final isBboxHealthy = bboxWidth >= 0.06 &&
        bboxHeight >= 0.06 &&
        !(bbox.xMin <= 0.02 && bbox.yMin <= 0.02);

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
          debugPrint(
              '⚠️ center_point ($cx, $cy) was ${isXEdgeStuck ? "x-edge-stuck" : "outside bbox"} for "$wordVal" — using healthy bbox center ($bboxCx, $bboxCy)');
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
            debugPrint(
                '⚠️ Both bbox and center_point are corrupt/corner-stuck for "$wordVal" — marking for auto-fix');
            cx = -1.0;
            cy = -1.0;
          }
        } else if (isXEdgeStuck) {
          // X is stuck at left edge (0.05)
          if (hasValidBboxX) {
            debugPrint(
                '⚠️ center_point X was stuck at left edge ($cx) for "$wordVal" — rescuing with bbox X ($bboxCx)');
            cx = bboxCx;
          } else {
            debugPrint(
                '⚠️ center_point X was stuck at left edge ($cx) and bbox X is at edge for "$wordVal" — marking X for auto-fix');
            cx = -1.0;
          }
        } else if (isYEdgeStuck) {
          // Y is stuck at top edge (0.05)
          if (hasValidBboxY) {
            debugPrint(
                '⚠️ center_point Y was stuck at top edge ($cy) for "$wordVal" — rescuing with bbox Y ($bboxCy)');
            cy = bboxCy;
          } else {
            debugPrint(
                '⚠️ center_point Y was stuck at top edge ($cy) and bbox Y is at edge for "$wordVal" — marking Y for auto-fix');
            cy = -1.0;
          }
        } else {
          debugPrint(
              '✅ Corrupt bbox for "$wordVal", but center_point ($cx, $cy) is valid — trusting center_point');
        }
      }
    } else {
      // No center_point provided — fallback to bbox center if healthy
      if (isBboxHealthy) {
        cx = bboxCx;
        cy = bboxCy;
      } else {
        final hasValidBboxY =
            bbox.yMin >= 0.12 || (bbox.yMax >= 0.20 && bboxHeight >= 0.03);
        final hasValidBboxX = bbox.xMin > 0.05 && bboxWidth >= 0.02;
        cx = hasValidBboxX ? bboxCx : -1.0;
        cy = hasValidBboxY ? bboxCy : -1.0;
      }
    }

    // Only apply geometric adjustments if coordinates are valid and not marked as broken (-1.0)
    if (cx >= 0 && cy >= 0) {
      // Base surface adjustment: words like table/desk/floor/counter should not sit in the dead center
      // where other objects (cups, plates) rest, especially if the bbox is huge (>70% of screen).
      const surfaceWords = {
        'table',
        'desk',
        'counter',
        'countertop',
        'floor',
        'ground',
        'tablecloth'
      };
      final isSurfaceWord = surfaceWords.contains(wordVal.trim().toLowerCase());
      if (isSurfaceWord && bboxWidth > 0.70 && bboxHeight > 0.70 && cy < 0.75) {
        debugPrint(
            '⚠️ Surface word "$wordVal" has full-screen bbox and center ($cx, $cy) on top of objects — shifting down to bare surface');
        cy = 0.85; // Shift down towards bottom where table surface is exposed
      }

      // Underlay object adjustment (saucer, coaster, placemat, tray):
      // When a cup/food sits on a saucer, the geometric center is ALWAYS the cup!
      // The only exposed part is the bottom curved rim (at ~88% of the bounding box height).
      const underlayWords = {'saucer', 'coaster', 'placemat', 'tray'};
      final isUnderlayWord =
          underlayWords.contains(wordVal.trim().toLowerCase());
      if (isUnderlayWord && bboxHeight > 0.06) {
        final middleThreshold = bbox.yMin + bboxHeight * 0.78;
        if (cy < middleThreshold) {
          final rimY = (bbox.yMin + bboxHeight * 0.88).clamp(0.05, 0.95);
          debugPrint(
              '⚠️ Underlay word "$wordVal" center ($cx, $cy) was inside cup/object — shifting down to exposed bottom rim ($cx, $rimY)');
          cy = rimY;
        }
      }

      // Container object adjustment (cup, mug, glass, bowl, pot, vase, jug, pitcher):
      // When a cup contains liquid/coffee, the liquid is in the top opening (upper 55%).
      // The physical cup ceramic/glass body is in the lower half (at ~76% of height).
      const containerWords = {
        'cup',
        'mug',
        'glass',
        'bowl',
        'pot',
        'vase',
        'jug',
        'pitcher'
      };
      final isContainerWord =
          containerWords.contains(wordVal.trim().toLowerCase());
      if (isContainerWord && bboxHeight > 0.06) {
        final upperThreshold = bbox.yMin + bboxHeight * 0.60;
        if (cy < upperThreshold) {
          final bodyY = (bbox.yMin + bboxHeight * 0.76).clamp(0.05, 0.95);
          debugPrint(
              '⚠️ Container word "$wordVal" center ($cx, $cy) was in liquid/opening — shifting down to ceramic/glass body ($cx, $bodyY)');
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
  VocabularyItem copyWith({
    String? word,
    String? type,
    String? thai,
    String? topic,
    BoundingBox? boundingBox,
    double? centerX,
    double? centerY,
    String? englishSentence,
    String? thaiSentence,
  }) {
    return VocabularyItem(
      word: word ?? this.word,
      type: type ?? this.type,
      thai: thai ?? this.thai,
      topic: topic ?? this.topic,
      boundingBox: boundingBox ?? this.boundingBox,
      centerX: centerX ?? this.centerX,
      centerY: centerY ?? this.centerY,
      englishSentence: englishSentence ?? this.englishSentence,
      thaiSentence: thaiSentence ?? this.thaiSentence,
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
          .map((e) =>
              (e is num) ? e.toDouble() : double.tryParse(e.toString()) ?? 0.0)
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
    List<String> selectedTones, {
    List<String>? requestedWords,
  }) {
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
          final rawWord = itemMap['word'] as String;
          final word = requestedWords != null
              ? GeminiService._normalizeWordKey(rawWord, requestedWords)
              : rawWord;
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
