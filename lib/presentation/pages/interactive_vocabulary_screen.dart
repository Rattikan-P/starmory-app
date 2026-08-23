import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/providers.dart';
import '../../data/models/vocabulary_model.dart';
import '../../data/models/scrapbook_model.dart';
import '../../data/services/gemini_service.dart';
import '../../data/services/tts_service.dart';
import 'generation_loading_screen.dart';
import 'edit_scrapbook_screen.dart';
import 'dart:ui';

/// Interactive Vocabulary Result Screen
/// Shows image with clickable dots, word chips, and context customization
class InteractiveVocabularyScreen extends ConsumerStatefulWidget {
  final String imagePath;
  final String cefrLevel;
  final String communicativeFunction;
  final String englishVariant;
  final VocabularyExtractionResult? extractionResult;

  const InteractiveVocabularyScreen({
    super.key,
    required this.imagePath,
    required this.cefrLevel,
    required this.communicativeFunction,
    required this.englishVariant,
    this.extractionResult,
  });

  @override
  ConsumerState<InteractiveVocabularyScreen> createState() =>
      _InteractiveVocabularyScreenState();
}

class _InteractiveVocabularyScreenState
    extends ConsumerState<InteractiveVocabularyScreen> {
  late List<_VocabularyDot> _vocabularyDots;
  bool _useCombinedSentence = false;
  final Set<String> _selectedWordIds = {};
  bool _isRegenerating = false;
  _VocabularyDot? _selectedDotForOverlay;

  // TTS service
  final TTSService _ttsService = TTSService();
  String? _playingAudioId; // Track which audio (word or sentence) is currently playing
  StreamSubscription? _ttsCompletionSubscription;
  StreamSubscription? _ttsErrorSubscription;

  // Store container and image dimensions for overlay positioning
  Size? _containerSize;
  Size? _imageSize;
  ({double scale, double offsetX, double offsetY})? _imageFit;

  // Store individual sentences before switching to combined mode
  final Map<String, ({String english, String thai})> _savedIndividualSentences =
      {};

  // Store combined sentences cache per tone to avoid regenerating
  final Map<String, ({String english, String thai})> _savedCombinedSentences =
      {};

  /// Map UI tone to API tone format
  String _mapToneToApiFormat(String uiTone) {
    final toneMap = {
      'Describe': 'describe',
      'Command': 'command',
      'Wish': 'wish',
      'Conditional': 'conditional',
    };
    return toneMap[uiTone] ?? uiTone.toLowerCase();
  }

  @override
  void initState() {
    super.initState();

    // Initialize TTS service
    _ttsService.initialize();

    // Listen to TTS completion
    _ttsCompletionSubscription = _ttsService.onComplete.listen((_) {
      if (mounted) {
        setState(() => _playingAudioId = null);
      }
    });

    // Listen to TTS errors
    _ttsErrorSubscription = _ttsService.onError.listen((message) {
      if (mounted) {
        setState(() => _playingAudioId = null);
        debugPrint('TTS Error: $message');
      }
    });

    // Load actual AI generation result
    _initializeVocabularyData();
  }

  @override
  void dispose() {
    _ttsCompletionSubscription?.cancel();
    _ttsErrorSubscription?.cancel();
    _ttsService.stop();
    super.dispose();
  }

  void _initializeVocabularyData() {
    if (widget.extractionResult != null) {
      // Use default context (Describe + image category) for initial sentences
      final defaultTone = 'Describe';
      final defaultCategory = widget.extractionResult!.category;

      // Check if any vocabulary items have pre-generated sentences
      final hasPreGeneratedSentences = widget.extractionResult!.vocabList.any(
        (item) => item.englishSentence != null && item.englishSentence!.isNotEmpty,
      );

      // Use actual AI result - use pre-generated sentences if available
      _vocabularyDots = widget.extractionResult!.vocabList.asMap().entries.map((entry) {
        final item = entry.value;
        final index = entry.key;
        final bbox = item.boundingBox;

        // Generate unique ID (timestamp + index to guarantee no duplicates)
        final uniqueId = '${DateTime.now().millisecondsSinceEpoch}_$index';

        return _VocabularyDot(
          id: uniqueId,
          word: item.word,
          thaiTranslation: item.thai,
          partOfSpeech: item.type,
          // Use AI's direct center_point (primary) instead of bbox center
          x: item.centerX,
          y: item.centerY,
          // Use pre-generated sentences if available, otherwise empty
          englishSentence: item.englishSentence ?? '',
          thaiSentence: item.thaiSentence ?? '',
          tone: defaultTone,
          category: defaultCategory,
          topic: item.topic,
          // Debug: store original bounding box from AI
          bboxXMin: bbox.xMin,
          bboxYMin: bbox.yMin,
          bboxXMax: bbox.xMax,
          bboxYMax: bbox.yMax,
        );
      }).toList();

      // Fix overlapping coordinates
      _fixOverlappingCoordinates();

      // Only generate sentences if we don't have pre-generated ones
      if (!hasPreGeneratedSentences) {
        _generateAllSentences();
      } else {
        // Save pre-generated sentences to cache for later use
        for (final dot in _vocabularyDots) {
          if (dot.englishSentence.isNotEmpty) {
            _savedIndividualSentences[dot.id] = (
              english: dot.englishSentence,
              thai: dot.thaiSentence,
            );
          }
        }
      }
    } else {
      // No data available
      debugPrint('⚠️ Extraction result is null');
      _vocabularyDots = [];
    }
  }

  /// Fix overlapping coordinates so dots never visually touch/stick together
  void _fixOverlappingCoordinates() {
    const minDistance = 0.045; // Minimum distance between dot centers (~36px) to prevent touching
    const iterations = 2; // Relaxation passes

    for (var pass = 0; pass < iterations; pass++) {
      for (var i = 0; i < _vocabularyDots.length; i++) {
        for (var j = i + 1; j < _vocabularyDots.length; j++) {
          final dot1 = _vocabularyDots[i];
          final dot2 = _vocabularyDots[j];

          double dx = dot2.x - dot1.x;
          double dy = dot2.y - dot1.y;
          double dist = math.sqrt(dx * dx + dy * dy);

          // If dots are closer than minDistance (or at the exact same spot)
          if (dist < minDistance) {
            // Handle overlapping dots at identical coordinates
            if (dist < 0.001) {
              final angle = (j * 1.047); // Spread evenly around circle
              dx = math.cos(angle) * 0.02;
              dy = math.sin(angle) * 0.02;
              dist = 0.02;
            }

            // Calculate required push distance to achieve minDistance gap
            final overlap = (minDistance - dist) / 2.0;
            final nx = dx / dist; // Unit vector X
            final ny = dy / dist; // Unit vector Y

            // Push dot1 backward and dot2 forward along line connecting their centers
            _vocabularyDots[i] = dot1.copyWith(
              x: (dot1.x - nx * overlap).clamp(0.05, 0.95),
              y: (dot1.y - ny * overlap).clamp(0.05, 0.95),
            );

            _vocabularyDots[j] = dot2.copyWith(
              x: (dot2.x + nx * overlap).clamp(0.05, 0.95),
              y: (dot2.y + ny * overlap).clamp(0.05, 0.95),
            );
          }
        }
      }
    }
  }

  /// Generate sentences for selected vocabulary words with current context
  Future<void> _generateAllSentences() async {
    if (_vocabularyDots.isEmpty) return;

    // Get selected dots (or all dots if nothing selected - initial state)
    final selectedDots = _selectedWordIds.isEmpty
        ? _vocabularyDots
        : _vocabularyDots
              .where((d) => _selectedWordIds.contains(d.id))
              .toList();

    if (selectedDots.isEmpty) return;

    try {
      final geminiService = ref.read(geminiServiceProvider);

      // Collect all unique tones from selected dots
      final tones = selectedDots
          .map((d) => _mapToneToApiFormat(d.tone))
          .toSet()
          .toList();

      // Get selected words only
      final words = selectedDots.map((d) => d.word).toList();

      // Load image for contextually relevant sentences
      final imageData = await _loadImageData();

      // Generate sentences
      final result = await geminiService.generateSentences(
        imageData: imageData,
        words: words,
        level: widget.cefrLevel,
        tones: tones,
        category: selectedDots.first.category,
        combined: _useCombinedSentence,
        englishVariant: widget.englishVariant,
      );

      // Update each selected dot with generated sentences
      setState(() {
        _isRegenerating = false; // Clear loading state
        if (_useCombinedSentence && result.mode == 'combined') {
          // Combined mode: all selected dots share the same sentences
          final combinedSentences = result.combinedSentences;
          if (combinedSentences != null) {
            // Save to cache for future restoration
            _savedCombinedSentences.clear();

            for (var i = 0; i < _vocabularyDots.length; i++) {
              final dot = _vocabularyDots[i];
              // Only update selected dots
              if (_selectedWordIds.contains(dot.id)) {
                final toneKey = _mapToneToApiFormat(dot.tone);
                final sentenceData = combinedSentences[toneKey];
                if (sentenceData != null) {
                  _vocabularyDots[i] = dot.copyWith(
                    englishSentence: sentenceData.text,
                    thaiSentence: sentenceData.thai,
                  );

                  // Cache this combined sentence by tone
                  _savedCombinedSentences[toneKey] = (
                    english: sentenceData.text,
                    thai: sentenceData.thai,
                  );
                }
              }
            }
          }
        } else {
          // Normal mode: each dot has its own sentence
          for (var i = 0; i < _vocabularyDots.length; i++) {
            final dot = _vocabularyDots[i];
            // Only update selected dots (or all if nothing selected)
            if (_selectedWordIds.contains(dot.id) || _selectedWordIds.isEmpty) {
              final wordResult = result.results[dot.word];
              if (wordResult != null && wordResult.isNotEmpty) {
                // Get the tone sentence for this dot
                final toneKey = _mapToneToApiFormat(dot.tone);
                final sentenceData = wordResult[toneKey];
                if (sentenceData != null) {
                  _vocabularyDots[i] = dot.copyWith(
                    englishSentence: sentenceData.text,
                    thaiSentence: sentenceData.thai,
                  );
                  // Save to cache for later restoration (save ALL sentences, not just selected)
                  _savedIndividualSentences[dot.id] = (
                    english: sentenceData.text,
                    thai: sentenceData.thai,
                  );
                }
              }
            }
          }
        }
      });
    } catch (e) {
      setState(() => _isRegenerating = false); // Clear loading state on error
      debugPrint('❌ Error generating sentences: $e');
      debugPrint('📝 Using fallback sentences instead');
      // Use fallback sentences on error
      _applyFallbackSentences();
    }
  }

  /// Apply fallback sentences when AI fails
  void _applyFallbackSentences() {
    setState(() {
      for (var i = 0; i < _vocabularyDots.length; i++) {
        final dot = _vocabularyDots[i];
        final (enSentence, thSentence) = _generateFallbackSentence(
          dot.word,
          dot.thaiTranslation,
          dot.tone,
          dot.category,
        );
        _vocabularyDots[i] = dot.copyWith(
          englishSentence: enSentence,
          thaiSentence: thSentence,
        );
        // Save fallback sentences to cache as well
        _savedIndividualSentences[dot.id] = (
          english: enSentence,
          thai: thSentence,
        );
      }
    });
  }

  /// Generate contextual fallback sentence based on tone and category
  (String, String) _generateFallbackSentence(
    String word,
    String thai,
    String tone,
    String category,
  ) {
    final toneLower = tone.toLowerCase();
    final categoryLower = category.toLowerCase();

    // Describe tone
    if (toneLower == 'describe') {
      if (categoryLower == 'nature') {
        return ('The $word is beautiful in nature.', '$thai สวยงามในธรรมชาติ');
      } else if (categoryLower == 'food') {
        return ('The $word looks delicious.', '$thai ดูน่าทานมาก');
      } else if (categoryLower == 'study') {
        return (
          'This $word is useful for learning.',
          '$thai มีประโยชน์ต่อการเรียนรู้',
        );
      } else if (categoryLower == 'moment') {
        return (
          'The $word makes this moment special.',
          '$thai ทำให้ช่วงเวลานี้พิเศษ',
        );
      }
      return ('I see a $word here.', 'ฉันเห็น $thai ที่นี่');
    }

    // Command tone
    if (toneLower == 'command') {
      if (categoryLower == 'nature') {
        return (
          'Look at the $word carefully.',
          'จงจดจ่อมอง $thai อย่างละเอียด',
        );
      } else if (categoryLower == 'food') {
        return ('Try the $word now.', 'ลอง $thai ดูสิ');
      }
      return ('Use the $word.', 'จงใช้ $thai');
    }

    // Wish tone
    if (toneLower == 'wish') {
      return ('I wish I had a $word.', 'ฉันหวังว่าฉันจะมี $thai');
    }

    // Conditional tone
    if (toneLower == 'conditional') {
      return (
        'If you have a $word, use it well.',
        'หากคุณมี $thai ให้ใช้มันอย่างดี',
      );
    }

    // Fallback
    return ('This is a $word.', 'นี่คือ$thai');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF2D2A4A),
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text(
          'Vocabulary Result',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Color(0xFF2D2A4A),
          ),
        ),
        titleTextStyle: GoogleFonts.lexend(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF2D2A4A),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _showRescanConfirmation(),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Image with Dots
          Positioned.fill(
            child: GestureDetector(
              onTap: _selectedDotForOverlay != null ? _hideWordOverlay : null,
              behavior: HitTestBehavior.translucent,
              child: _buildImageWithDots(),
            ),
          ),

          // Word Overlay (before bottom sheet so bottom sheet can cover it)
          if (_selectedDotForOverlay != null)
            _buildWordOverlay(_selectedDotForOverlay!),

          // Bottom Sheet (on top of overlay)
          Positioned.fill(child: _buildBottomSheet()),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FilledButton(
        onPressed: _selectedWordIds.isEmpty ? null : _navigateToEditScrapbook,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF7B6EF6),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          elevation: 8,
        ),
        child: Text(
          'Create Scrapbook',
          style: GoogleFonts.lexend(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCombinedSentenceToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              final value = !_useCombinedSentence;

              if (value) {
                // Switching TO combined mode - save individual sentences first
                _saveIndividualSentences();

                setState(() {
                  _useCombinedSentence = true;
                  _clearSelectedSentences();
                  _isRegenerating = true;
                });

                // Check if we have cached combined sentences to use
                final restored = _restoreCombinedSentences();

                if (!restored) {
                  // No cache, need to generate
                  await _generateAllSentences();
                } else {
                  // Cache hit - just clear loading state
                  setState(() => _isRegenerating = false);
                }
              } else {
                // Switching FROM combined mode - restore individual sentences
                setState(() => _useCombinedSentence = false);

                final restored = _restoreIndividualSentences();

                if (!restored) {
                  setState(() {
                    _isRegenerating = true;
                  });

                  await _generateAllSentences();
                }
              }
            },

            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),

              width: 22,
              height: 22,

              decoration: BoxDecoration(
                color: _useCombinedSentence
                    ? const Color(0xFF7B6EF6)
                    : Colors.transparent,

                borderRadius: BorderRadius.circular(6),

                border: Border.all(
                  color: _useCombinedSentence
                      ? const Color(0xFF7B6EF6)
                      : const Color.fromARGB(255, 77, 74, 98),
                  width: 1.5,
                ),
              ),

              child: _useCombinedSentence
                  ? const Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),

          const SizedBox(width: 12),

          Text(
            'Combined Sentence',
            style: GoogleFonts.lexend(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2D2A4A),
            ),
          ),
        ],
      ),
    );
  }

  /// Clear sentences for selected dots (to trigger loading state)
  void _clearSelectedSentences() {
    for (var i = 0; i < _vocabularyDots.length; i++) {
      if (_selectedWordIds.contains(_vocabularyDots[i].id)) {
        _vocabularyDots[i] = _vocabularyDots[i].copyWith(
          englishSentence: '',
          thaiSentence: '',
        );
      }
    }
  }

  /// Save individual sentences before switching to combined mode
  /// Now saves ALL sentences (not just selected) for better restoration
  void _saveIndividualSentences() {
    _savedIndividualSentences.clear();
    for (final dot in _vocabularyDots) {
      // Save ALL words that have sentences, not just selected ones
      if (dot.englishSentence.isNotEmpty) {
        _savedIndividualSentences[dot.id] = (
          english: dot.englishSentence,
          thai: dot.thaiSentence,
        );
      }
    }
  }

  /// Restore individual sentences when switching back from combined mode
  /// Returns true if sentences were restored, false if need to regenerate
  bool _restoreIndividualSentences() {
    if (_savedIndividualSentences.isEmpty) {
      debugPrint('📭 No saved sentences, will regenerate');
      return false;
    }

    // Check if all selected words have saved sentences
    final hasAllSaved = _selectedWordIds.every(
      (id) => _savedIndividualSentences.containsKey(id),
    );

    setState(() {
      for (var i = 0; i < _vocabularyDots.length; i++) {
        final dot = _vocabularyDots[i];
        final saved = _savedIndividualSentences[dot.id];
        if (saved != null) {
          _vocabularyDots[i] = dot.copyWith(
            englishSentence: saved.english,
            thaiSentence: saved.thai,
          );
        }
      }
    });

    if (hasAllSaved) {
      return true;
    } else {
      return false;
    }
  }

  /// Restore combined sentences from cache when switching to combined mode
  /// Returns true if sentences were restored, false if need to regenerate
  bool _restoreCombinedSentences() {
    if (_savedCombinedSentences.isEmpty) {
      debugPrint('📭 No saved combined sentences, will regenerate');
      return false;
    }

    setState(() {
      // Restore combined sentences for each selected dot based on its tone
      for (var i = 0; i < _vocabularyDots.length; i++) {
        final dot = _vocabularyDots[i];
        if (_selectedWordIds.contains(dot.id)) {
          final toneKey = _mapToneToApiFormat(dot.tone);
          final saved = _savedCombinedSentences[toneKey];
          if (saved != null) {
            _vocabularyDots[i] = dot.copyWith(
              englishSentence: saved.english,
              thaiSentence: saved.thai,
            );
          }
        }
      }
    });

    return true;
  }

  Widget _buildImageWithDots() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FutureBuilder<Size?>(
          future: _getImageDimensions(),
          builder: (context, snapshot) {
            // Show loading while waiting
            if (!snapshot.hasData && !snapshot.hasError) {
              return const Center(child: CircularProgressIndicator());
            }

            // Handle error or null result
            if (snapshot.hasError || snapshot.data == null) {
              // Check if file exists before trying fallback
              final file = File(widget.imagePath);
              final fileExists = file.existsSync();

              if (!fileExists) {
                // File doesn't exist - show error with action buttons
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image_outlined, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Image Not Found',
                          style: GoogleFonts.lexend(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2D2A4A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The image file may have been deleted or moved.',
                          style: GoogleFonts.lexend(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Go Back'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF6C63FF),
                                side: const BorderSide(color: Color(0xFF6C63FF)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: () => _showRescanConfirmation(),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Rescan'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6C63FF),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Fallback: show image directly without dimension calculation
              debugPrint('⚠️ Using fallback image display due to error');
              _containerSize = Size(constraints.maxWidth, constraints.maxHeight);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: Image.file(
                      file,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 8),
                              Text(
                                'Failed to load image',
                                style: GoogleFonts.lexend(color: Colors.grey[700]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Please try rescanning',
                                style: GoogleFonts.lexend(fontSize: 12, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  // Show dots without precise positioning (will use normalized coordinates directly)
                  if (_vocabularyDots.isNotEmpty)
                    ..._buildVocabularyDotsFallback(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    ),
                ],
              );
            }

            final imageSize = snapshot.data!;

            // Store dimensions for overlay use
            _containerSize = Size(constraints.maxWidth, constraints.maxHeight);
            _imageSize = imageSize;
            _imageFit = _calculateBoxFitContain(
              imageSize,
              constraints.maxWidth,
              constraints.maxHeight,
            );

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // เปลี่ยนจาก Center เป็น Align ชิดบน
                Align(
                  alignment: Alignment.topCenter,
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 8),
                            Text(
                              'Failed to load image',
                              style: GoogleFonts.lexend(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                ..._buildVocabularyDots(
                  constraints.maxWidth,
                  constraints.maxHeight,
                  imageSize,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBottomSheet() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FutureBuilder<Size?>(
          future: _getImageDimensions(),
          builder: (context, snapshot) {
            double minChildSize = 0.15;
            double maxChildSize = 0.85;

            if (snapshot.hasData && snapshot.data != null) {
              final imageSize = snapshot.data!;
              final screenHeight = constraints.maxHeight;
              final screenWidth = constraints.maxWidth;

              final fit = _calculateBoxFitContain(
                imageSize,
                screenWidth,
                screenHeight,
              );
              final displayedImageHeight = imageSize.height * fit.scale;

              final remainingHeight = screenHeight - displayedImageHeight;
              minChildSize = (remainingHeight / screenHeight).clamp(0.05, 0.5);
            }

            return DraggableScrollableSheet(
              initialChildSize: minChildSize.clamp(0.35, 0.85),
              minChildSize: minChildSize,
              maxChildSize: maxChildSize,
              builder: (context, scrollController) {
                return ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 18,
                      sigmaY: 18,
                    ),
                    child: GestureDetector(
                      onTap: _selectedDotForOverlay != null ? _hideWordOverlay : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.82),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(32),
                          ),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7B6EF6).withValues(alpha: 0.08),
                              blurRadius: 30,
                              offset: const Offset(0, -10),
                            ),
                          ],
                        ),
                        child: CustomScrollView(
                        controller: scrollController,
                        slivers: [
                          // Drag Handle
                          SliverToBoxAdapter(
                            child: Center(
                              child: Container(
                                margin: const EdgeInsets.only(top: 12, bottom: 8),
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD4CCFF),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                          ),

                          // Selected Words Chips
                          SliverToBoxAdapter(child: _buildSelectedWordsChips()),

                          // Combined Sentence Toggle
                          SliverToBoxAdapter(child: _buildCombinedSentenceToggle()),

                          // Combined Sentence Display
                          SliverToBoxAdapter(
                            child: _buildCombinedSentenceDisplay(),
                          ),

                          // Word Details / Empty State
                          // Hide individual word cards when combined mode is ON
                          if (_selectedWordIds.isEmpty)
                            _buildEmptyStateSliver(scrollController)
                          else if (!_useCombinedSentence)
                            _buildWordDetailsSliver(scrollController),
                        ],
                      ),
                    ),
                  ),
                ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Build word overlay popup near the dot
  Widget _buildWordOverlay(_VocabularyDot dot) {
    // Use stored dimensions
    if (_containerSize == null || _imageSize == null || _imageFit == null) {
      return const SizedBox.shrink();
    }

    final containerWidth = _containerSize!.width;
    final containerHeight = _containerSize!.height;
    final imageSize = _imageSize!;
    final fit = _imageFit!;

    // Calculate dot position
    final imageX = dot.x * imageSize.width;
    final imageY = dot.y * imageSize.height;
    final displayedX = imageX * fit.scale + fit.offsetX;
    final displayedY = imageY * fit.scale + fit.offsetY;

    // Calculate overlay position (show below the dot)
    const dotSize = 34.0;
    const overlayWidth = 156.0;
    const overlayHeight = 110.0;
    const borderRadius = 16.0;
    const arrowWidth = 16.0;
    const arrowHeight = 8.0;

    double overlayX = displayedX - overlayWidth / 2;
    double overlayY = displayedY + dotSize / 2 + 8;

    // Reserve space for bottom sheet (min height ~35% of screen) and safe area
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final bottomSheetMinHeight = containerHeight * 0.35;
    final reservedBottomSpace = bottomSheetMinHeight + bottomSafeArea;
    final maxBottomY = containerHeight - overlayHeight - reservedBottomSpace - 8;

    // Track if overlay is shown above or below dot
    bool showAboveDot = false;

    // Check if overlay would go below the bottom sheet
    if (overlayY > maxBottomY) {
      // Show overlay ABOVE the dot instead
      overlayY = displayedY - dotSize / 2 - overlayHeight + 20;
      showAboveDot = true;
    } else {
      // Keep overlay within vertical bounds (normal case - below dot)
      overlayY = overlayY.clamp(8.0, maxBottomY);
    }

    // Calculate horizontal bounds - keep overlay within screen
    overlayX = overlayX.clamp(8.0, containerWidth - overlayWidth - 8);

    // Calculate triangle offset - strictly clamped to the flat edge of the card
    // so the arrow base never floats over the rounded corners
    double triangleRelativeX = displayedX - overlayX;
    final minTriangleX = borderRadius + (arrowWidth / 2);
    final maxTriangleX = overlayWidth - borderRadius - (arrowWidth / 2);
    triangleRelativeX = triangleRelativeX.clamp(minTriangleX, maxTriangleX);

    return Positioned(
      left: overlayX,
      top: overlayY,
      child: GestureDetector(
        onTap: () {}, // Prevent closing when tapping on the card
        child: SizedBox(
          width: overlayWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Triangle arrow - position based on whether overlay is above or below dot
              // Shift by 1px into card edge to eliminate any subpixel/hairline separation
              if (!showAboveDot)
                Transform.translate(
                  offset: Offset(triangleRelativeX - overlayWidth / 2, 1.0),
                  child: CustomPaint(
                    size: const Size(arrowWidth, arrowHeight),
                    painter: _TrianglePainter(
                      color: Colors.white.withValues(alpha: 0.95),
                      pointDown: false, // Pointing up (triangle at top)
                    ),
                  ),
                ),
              Material(
                elevation: 8,
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(borderRadius),
                child: Container(
                  width: overlayWidth,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: word and listen button
                      Row(
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                dot.word,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF7B6EF6),
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Listen button (icon only)
                          InkWell(
                            onTap: () => _playAudio(dot),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                _playingAudioId == dot.id
                                    ? Icons.stop_rounded
                                    : Icons.volume_up_rounded,
                                size: 20,
                                color: const Color(0xFF7B6EF6),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Thai Translation with auto-scaling
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          dot.thaiTranslation,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (showAboveDot)
                Transform.translate(
                  offset: Offset(triangleRelativeX - overlayWidth / 2, -1.0),
                  child: CustomPaint(
                    size: const Size(arrowWidth, arrowHeight),
                    painter: _TrianglePainter(
                      color: Colors.white.withValues(alpha: 0.95),
                      pointDown: true, // Pointing down (triangle at bottom)
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get original image dimensions with timeout and EXIF orientation handling
  Future<Size?> _getImageDimensions() async {
    try {
      final file = File(widget.imagePath);
      if (!await file.exists()) {
        debugPrint('❌ File not found: ${widget.imagePath}');
        throw FileSystemException('File not found', widget.imagePath);
      }

      final completer = Completer<ImageInfo>();
      final imageStream = FileImage(file).resolve(const ImageConfiguration());
      final listener = ImageStreamListener(
        (ImageInfo info, bool _) {
          if (!completer.isCompleted) {
            completer.complete(info);
          }
        },
        onError: (dynamic error, StackTrace? stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );
      imageStream.addListener(listener);

      final info = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          imageStream.removeListener(listener);
          throw TimeoutException('Image decoding timeout');
        },
      );
      imageStream.removeListener(listener);

      return Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
    } catch (e) {
      debugPrint('❌ Error getting image dimensions: $e');
      return null;
    }
  }

  /// Load image data from file for AI generation
  Future<Uint8List> _loadImageData() async {
    return await File(widget.imagePath).readAsBytes();
  }

  /// Calculate BoxFit.contain scaling and position (centered)
  ({double scale, double offsetX, double offsetY}) _calculateBoxFitContain(
    Size imageSize,
    double containerWidth,
    double containerHeight,
  ) {
    final imageAspectRatio = imageSize.width / imageSize.height;
    final containerAspectRatio = containerWidth / containerHeight;

    double scale;
    double offsetX = 0;
    const double offsetY = 0;

    // BoxFit.contain: scale to fit within container, then center
    if (imageAspectRatio > containerAspectRatio) {
      // Image is wider than container - scale to width
      scale = containerWidth / imageSize.width;
      // Center vertically
      // offsetY = 0 (ชิดบน)
    } else {
      // Image is taller than container - scale to height
      scale = containerHeight / imageSize.height;
      // Center horizontally
      offsetX = (containerWidth - imageSize.width * scale) / 2;
    }

    return (scale: scale, offsetX: offsetX, offsetY: offsetY);
  }

  List<Widget> _buildVocabularyDots(
    double containerWidth,
    double containerHeight,
    Size imageSize,
  ) {
    final fit = _calculateBoxFitContain(
      imageSize,
      containerWidth,
      containerHeight,
    );

    return _vocabularyDots.map((dot) {
      final isSelected = _selectedWordIds.contains(dot.id);

      // Convert normalized coordinates to actual image position
      final imageX = dot.x * imageSize.width;
      final imageY = dot.y * imageSize.height;

      // Apply BoxFit.contain transformation
      final displayedX = imageX * fit.scale + fit.offsetX;
      final displayedY = imageY * fit.scale + fit.offsetY;

      // debugPrint(
      //   '📍 Dot "${dot.word}": normalized=(${dot.x.toStringAsFixed(2)}, ${dot.y.toStringAsFixed(2)}) → displayed=(${displayedX.toStringAsFixed(1)}, ${displayedY.toStringAsFixed(1)})',
      // );

      // Don't hide dots that are out of bounds - let them be clickable even if outside visible area
      const dotSize = 34.0;

      return Positioned(
        left: displayedX - dotSize / 2,
        top: displayedY - dotSize / 2,
        child: GestureDetector(
          onTap: () => _showWordOverlay(dot),
          child: Container(
            width: dotSize,
            height: dotSize,
            padding: const EdgeInsets.all(8), // Invisible tap area padding
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? const Color(0xFF7B6EF6).withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.6),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF7B6EF6)
                      : Colors.white,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF7B6EF6,
                    ).withOpacity(isSelected ? 0.35 : 0.15),
                    blurRadius: isSelected ? 16 : 8,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: isSelected
                        ? const Color(0xFF7B6EF6).withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.6),
                    blurRadius: 0,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  /// Fallback method to build vocabulary dots when image dimensions are unavailable
  /// Uses normalized coordinates directly (assumes container is the display area)
  List<Widget> _buildVocabularyDotsFallback(
    double containerWidth,
    double containerHeight,
  ) {
    return _vocabularyDots.map((dot) {
      final isSelected = _selectedWordIds.contains(dot.id);

      // Use normalized coordinates directly (0-1 range mapped to container)
      final displayedX = dot.x * containerWidth;
      final displayedY = dot.y * containerHeight;

      const dotSize = 34.0;

      return Positioned(
        left: displayedX - dotSize / 2,
        top: displayedY - dotSize / 2,
        child: GestureDetector(
          onTap: () => _showWordOverlay(dot),
          child: Container(
            width: dotSize,
            height: dotSize,
            padding: const EdgeInsets.all(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? const Color(0xFF7B6EF6).withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.6),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF7B6EF6)
                      : Colors.white,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7B6EF6).withValues(alpha: isSelected ? 0.35 : 0.15),
                    blurRadius: isSelected ? 16 : 8,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: isSelected
                        ? const Color(0xFF7B6EF6).withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.6),
                    blurRadius: 0,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildSelectedWordsChips() {
    final selectedDots = _vocabularyDots
        .where((dot) => _selectedWordIds.contains(dot.id))
        .toList();

    if (selectedDots.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: selectedDots.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final dot = selectedDots[index];
          final isOverlayActive = _selectedDotForOverlay?.id == dot.id;

          return InputChip(
            backgroundColor: isOverlayActive
                ? const Color(0xFFE9E5FF)
                : const Color(0xFFF1EEFF),
            selected: isOverlayActive,
            selectedColor: const Color(0xFFE9E5FF),
            showCheckmark: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: isOverlayActive
                  ? const BorderSide(color: Color(0xFF7B6EF6), width: 1.5)
                  : BorderSide.none,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            labelStyle: TextStyle(
              color: isOverlayActive
                  ? const Color(0xFF7B6EF6)
                  : const Color(0xFF2D2A4A),
              fontWeight: FontWeight.w600,
            ),
            label: Text(dot.word),
            deleteIcon: const Icon(Icons.close, size: 18),
            deleteIconColor: isOverlayActive
                ? const Color(0xFF7B6EF6)
                : const Color(0xFF8B87A6),
            onPressed: () {
              // Open overlay for this word, just like tapping the dot on the image
              _showWordOverlay(dot);
            },
            onDeleted: () => _toggleWordSelection(dot.id),
          );
        },
      ),
    );
  }

  Widget _buildCombinedSentenceDisplay() {
    if (!_useCombinedSentence || _selectedWordIds.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get the first selected dot to extract the combined sentence
    final firstSelectedDot = _vocabularyDots.firstWhere(
      (dot) => _selectedWordIds.contains(dot.id),
      orElse: () => _vocabularyDots.first,
    );

    // Get all selected words
    final selectedWords = _vocabularyDots
        .where((dot) => _selectedWordIds.contains(dot.id))
        .map((dot) => dot.word)
        .toList();

    // Get unique tones and categories from all selected dots
    final uniqueTones = _selectedWordIds
        .map((id) => _vocabularyDots.firstWhere((d) => d.id == id).tone)
        .toSet()
        .toList();

    final uniqueCategories = _selectedWordIds
        .map((id) => _vocabularyDots.firstWhere((d) => d.id == id).category)
        .toSet()
        .toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE7E1FF),
        borderRadius: BorderRadius.circular(24),

        border: Border.all(color: const Color(0xFFD2C7FF), width: 1.2),

        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B6EF6).withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'COMBINED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sentence using: ${selectedWords.join(", ")}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Sentence
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F6FF),
              borderRadius: BorderRadius.circular(18),

              border: Border.all(color: const Color(0xFFE0D8FF)),
            ),
            child: _isRegenerating
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF6C63FF),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Generating combined sentence...',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  )
                : firstSelectedDot.englishSentence.isEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No sentence generated. Try selecting words first.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              firstSelectedDot.englishSentence,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              firstSelectedDot.thaiSentence,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          _playingAudioId == 'combined_sentence'
                              ? Icons.stop_rounded
                              : Icons.volume_up_rounded,
                          size: 22,
                        ),
                        color: const Color(0xFF7B6EF6),
                        onPressed: () => _playSentenceAudio(
                          'combined_sentence',
                          firstSelectedDot.englishSentence,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Read sentence',
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),

          // Context Tags & +Context Button
          Row(
            children: [
              // Show only first tone (all selected words should share the same tone after combined context is applied)
              if (uniqueTones.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ContextChip(label: uniqueTones.first, icon: Icons.tune),
                ),
              // Show first category
              if (uniqueCategories.isNotEmpty)
                _ContextChip(label: uniqueCategories.first, icon: Icons.category),
              const Spacer(),
              TextButton.icon(
                onPressed: _isRegenerating ? null : () => _showCombinedContextSelector(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Context'),
                style: TextButton.styleFrom(
                  foregroundColor: _isRegenerating
                      ? Colors.grey
                      : const Color(0xFF6C63FF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateSliver(ScrollController scrollController) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.touch_app_rounded,
              size: 70,
              color: Color(0xFFC5BCFF),
            ),
            const SizedBox(height: 16),
            Text(
              'Tap the dots on the image',
              style: GoogleFonts.lexend(
                fontSize: 18,
                color: const Color(0xFF2D2A4A),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'to select vocabulary words',
              style: GoogleFonts.lexend(fontSize: 14, color: const Color(0xFF8B87A6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordDetailsSliver(ScrollController scrollController) {
    final selectedDots = _vocabularyDots
        .where((dot) => _selectedWordIds.contains(dot.id))
        .toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final dot = selectedDots[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              if (index > 0) const SizedBox(height: 12),
              _WordDetailCard(
                dot: dot,
                index: index + 1,
                onContextTap: () =>
                    _isRegenerating ? null : _showContextSelector(dot),
                onAudioTap: () => _playAudio(dot),
                onSentenceAudioTap: () => _playSentenceAudio(
                  'sentence_${dot.id}',
                  dot.englishSentence,
                ),
                isRegenerating: _isRegenerating,
                playingAudioId: _playingAudioId,
              ),
            ],
          ),
        );
      }, childCount: selectedDots.length),
    );
  }

  void _showWordOverlay(_VocabularyDot dot) {
    setState(() {
      // If clicking the same dot, deselect it
      if (_selectedDotForOverlay?.id == dot.id) {
        _selectedWordIds.remove(dot.id);
        _selectedDotForOverlay = null;
      } else {
        _selectedDotForOverlay = dot;
        // Also select the word when showing overlay
        if (!_selectedWordIds.contains(dot.id)) {
          _selectedWordIds.add(dot.id);
        }
      }
    });
  }

  void _hideWordOverlay() {
    setState(() {
      _selectedDotForOverlay = null;
    });
  }

  void _toggleWordSelection(String wordId) async {
    final wasSelected = _selectedWordIds.contains(wordId);

    setState(() {
      if (wasSelected) {
        _selectedWordIds.remove(wordId);
        // Close overlay if removing the currently shown word
        if (_selectedDotForOverlay?.id == wordId) {
          _selectedDotForOverlay = null;
        }
      } else {
        _selectedWordIds.add(wordId);
      }
    });

    // If combined mode is ON and there are selected words
    if (_useCombinedSentence && _selectedWordIds.isNotEmpty) {
      // Try to restore from cache first (for newly selected words)
      final dotIndex = _vocabularyDots.indexWhere((d) => d.id == wordId);
      if (dotIndex != -1 && !wasSelected) {
        // This is a newly selected word - check if we have cached combined sentence for its tone
        final dot = _vocabularyDots[dotIndex];
        final toneKey = _mapToneToApiFormat(dot.tone);
        final cached = _savedCombinedSentences[toneKey];

        if (cached != null) {
          // Cache hit - just update this word without regenerating
          setState(() {
            _vocabularyDots[dotIndex] = dot.copyWith(
              englishSentence: cached.english,
              thaiSentence: cached.thai,
            );
          });
          return; // Don't regenerate
        }
      }

      // No cache for the new word, need to regenerate
      setState(() {
        _clearSelectedSentences();
        _isRegenerating = true;
      });
      await _generateAllSentences();
    }
  }

  void _showContextSelector(_VocabularyDot dot) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContextSelectorScreen(
          vocabularyDot: dot,
          onApply: (tone, category) => _applyContext(dot, tone, category),
          onApplyToAll: (tone, category) => _applyContextToAll(tone, category),
        ),
      ),
    );
  }

  void _applyContext(_VocabularyDot dot, String tone, String category) async {
    // Show loading
    setState(() {
      _isRegenerating = true;
    });

    // Update tone and category first
    setState(() {
      final index = _vocabularyDots.indexWhere((d) => d.id == dot.id);
      if (index != -1) {
        _vocabularyDots[index] = dot.copyWith(tone: tone, category: category);
      }
    });

    // Regenerate sentence with new context
    final success = await _regenerateSentence(dot.id, tone, category);

    if (!mounted) return;

    setState(() {
      _isRegenerating = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Context applied to ${dot.word}'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✗ Failed to update ${dot.word}. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _applyContextToAll(String tone, String category) async {
    // Show loading
    setState(() {
      _isRegenerating = true;
    });

    // Update tone and category for all selected words
    final selectedDotIds = List<String>.from(_selectedWordIds);

    setState(() {
      for (int i = 0; i < _vocabularyDots.length; i++) {
        if (_selectedWordIds.contains(_vocabularyDots[i].id)) {
          _vocabularyDots[i] = _vocabularyDots[i].copyWith(
            tone: tone,
            category: category,
          );
        }
      }
    });

    // Regenerate sentences for all selected words
    final success = await _regenerateSentencesForWords(
      selectedDotIds,
      tone,
      category,
    );

    if (!mounted) return;

    setState(() {
      _isRegenerating = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Context applied to ${selectedDotIds.length} words'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✗ Failed to update some words. Please try again.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// Regenerate sentence for a specific word with new context
  Future<bool> _regenerateSentence(
    String wordId,
    String tone,
    String category,
  ) async {
    // Declare variables outside try block for catch block access
    final geminiService = ref.read(geminiServiceProvider);
    final dotIndex = _vocabularyDots.indexWhere((d) => d.id == wordId);
    if (dotIndex == -1) return false;

    final dot = _vocabularyDots[dotIndex];
    final apiTone = _mapToneToApiFormat(tone);

    try {
      // Load image for contextually relevant sentences
      final imageData = await _loadImageData();

      final result = await geminiService.generateSentences(
        imageData: imageData,
        words: [dot.word],
        level: widget.cefrLevel,
        tones: [apiTone],
        category: category,
        combined: false,
        englishVariant: widget.englishVariant,
      );

      if (!mounted) return false;

      final sentenceData = result.results[dot.word]?[apiTone];

      if (sentenceData != null) {
        setState(() {
          _vocabularyDots[dotIndex] = _vocabularyDots[dotIndex].copyWith(
            englishSentence: sentenceData.text,
            thaiSentence: sentenceData.thai,
          );
        });
        return true;
      } else {
        // Use fallback sentence
        final (enSentence, thSentence) = _generateFallbackSentence(
          dot.word,
          dot.thaiTranslation,
          tone,
          category,
        );
        setState(() {
          _vocabularyDots[dotIndex] = _vocabularyDots[dotIndex].copyWith(
            englishSentence: enSentence,
            thaiSentence: thSentence,
          );
        });
        return false; // Return false since API didn't work
      }
    } catch (e) {
      // Use fallback sentence on error
      final (enSentence, thSentence) = _generateFallbackSentence(
        dot.word,
        dot.thaiTranslation,
        tone,
        category,
      );
      setState(() {
        _vocabularyDots[dotIndex] = _vocabularyDots[dotIndex].copyWith(
          englishSentence: enSentence,
          thaiSentence: thSentence,
        );
      });
      return false;
    }
  }

  /// Regenerate sentences for multiple words
  Future<bool> _regenerateSentencesForWords(
    List<String> wordIds,
    String tone,
    String category,
  ) async {
    final geminiService = ref.read(geminiServiceProvider);

    // Get selected words
    final selectedDots = _vocabularyDots
        .where((d) => wordIds.contains(d.id))
        .toList();
    if (selectedDots.isEmpty) return false;

    final words = selectedDots.map((d) => d.word).toList();
    final apiTone = _mapToneToApiFormat(tone);

    try {
      // Load image for contextually relevant sentences
      final imageData = await _loadImageData();

      final result = await geminiService.generateSentences(
        imageData: imageData,
        words: words,
        level: widget.cefrLevel,
        tones: [apiTone],
        category: category,
        combined: _useCombinedSentence,
        englishVariant: widget.englishVariant,
      );

      if (!mounted) return false;

      int successCount = 0;

      // Update all dots with new sentences or fallbacks
      setState(() {
        if (_useCombinedSentence && result.mode == 'combined') {
          // Combined mode: all selected dots get the same combined sentence
          final combinedSentences = result.combinedSentences;
          if (combinedSentences != null) {
            final sentenceData = combinedSentences[apiTone];
            if (sentenceData != null) {
              for (var i = 0; i < _vocabularyDots.length; i++) {
                final dot = _vocabularyDots[i];
                if (wordIds.contains(dot.id)) {
                  _vocabularyDots[i] = dot.copyWith(
                    englishSentence: sentenceData.text,
                    thaiSentence: sentenceData.thai,
                  );
                  successCount++;
                }
              }
            }
          }
        } else {
          // Normal mode: each dot gets its own sentence
          for (var i = 0; i < _vocabularyDots.length; i++) {
            final dot = _vocabularyDots[i];
            if (wordIds.contains(dot.id)) {
              final sentenceData = result.results[dot.word]?[apiTone];

              if (sentenceData != null) {
                _vocabularyDots[i] = dot.copyWith(
                  englishSentence: sentenceData.text,
                  thaiSentence: sentenceData.thai,
                );
                successCount++;
              } else {
                // Use fallback sentence for this word
                final (enSentence, thSentence) = _generateFallbackSentence(
                  dot.word,
                  dot.thaiTranslation,
                  tone,
                  category,
                );
                _vocabularyDots[i] = dot.copyWith(
                  englishSentence: enSentence,
                  thaiSentence: thSentence,
                );
              }
            }
          }
        }
      });

      return successCount > 0;
    } catch (e) {
      // Use fallback sentences for all words on error
      setState(() {
        for (var i = 0; i < _vocabularyDots.length; i++) {
          final dot = _vocabularyDots[i];
          if (wordIds.contains(dot.id)) {
            final (enSentence, thSentence) = _generateFallbackSentence(
              dot.word,
              dot.thaiTranslation,
              tone,
              category,
            );
            _vocabularyDots[i] = dot.copyWith(
              englishSentence: enSentence,
              thaiSentence: thSentence,
            );
          }
        }
      });
      return false;
    }
  }

  void _playAudio(_VocabularyDot dot) {
    _playAudioText(dot.id, dot.word);
  }

  void _playSentenceAudio(String audioId, String sentence) {
    _playAudioText(audioId, sentence);
  }

  void _playAudioText(String audioId, String text) async {
    // If clicking the same audio that's playing, stop it
    if (_playingAudioId == audioId) {
      await _ttsService.stop();
      setState(() => _playingAudioId = null);
      return;
    }

    // Stop any currently playing audio first
    if (_playingAudioId != null) {
      await _ttsService.stop();
    }

    // Play pronunciation / audio
    setState(() => _playingAudioId = audioId);

    // Set language based on englishVariant
    final language = TTSService.getLanguageCode(widget.englishVariant);

    // Speak text (returns estimated duration for fallback)
    final estimatedDuration = _ttsService.speak(
      text,
      language: language,
    );

    // Fallback: Auto-reset after estimated duration
    Future.delayed(estimatedDuration, () {
      if (mounted && _playingAudioId == audioId) {
        setState(() => _playingAudioId = null);
      }
    });
  }

  void _navigateToEditScrapbook() {
    final selectedDots = _vocabularyDots
        .where((dot) => _selectedWordIds.contains(dot.id))
        .toList();

    if (selectedDots.isEmpty) return;

    // Get the sentence to display
    String englishSentence = '';
    String thaiSentence = '';

    if (_useCombinedSentence && selectedDots.isNotEmpty) {
      // Use combined sentence from first selected dot
      englishSentence = selectedDots.first.englishSentence;
      thaiSentence = selectedDots.first.thaiSentence;
    } else if (selectedDots.isNotEmpty) {
      // For individual sentences, we can either:
      // 1. Show the first sentence
      // 2. Combine all sentences with line breaks
      // Let's combine them with line breaks
      englishSentence = selectedDots
          .map((dot) => dot.englishSentence)
          .where((s) => s.isNotEmpty)
          .join('\n');
      thaiSentence = selectedDots
          .map((dot) => dot.thaiSentence)
          .where((s) => s.isNotEmpty)
          .join('\n');
    }

    // Convert selected dots to ScrapbookVocabularyWord list
    final vocabularyWords = selectedDots.map((dot) {
      return ScrapbookVocabularyWord(
        word: dot.word,
        thaiTranslation: dot.thaiTranslation,
        partOfSpeech: dot.partOfSpeech,
      );
    }).toList();

    // Convert selected dots to full VocabularyModel list to save to collection
    final vocabulariesToSave = selectedDots.map((dot) {
      return VocabularyModel(
        id: dot.id,
        word: dot.word,
        partOfSpeech: dot.partOfSpeech,
        thaiTranslation: dot.thaiTranslation,
        englishSentence: dot.englishSentence,
        thaiSentence: dot.thaiSentence,
        cefrLevel: widget.cefrLevel,
        communicativeFunction: widget.communicativeFunction,
        languageVariant: widget.englishVariant,
        imageUrl: widget.imagePath,
        topic: dot.topic,
        tags: [dot.tone, dot.category],
        createdAt: DateTime.now(),
      );
    }).toList();

    // Navigate to Edit Scrapbook Screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditScrapbookScreen(
          imagePath: widget.imagePath,
          vocabularyWords: vocabularyWords,
          vocabulariesToSave: vocabulariesToSave,
          englishSentence: englishSentence,
          thaiSentence: thaiSentence,
          selectedEmoji: '😊', // Default emoji, user can change in edit screen
        ),
      ),
    );
  }

  Future<void> _saveAllVocabularies() async {
    final selectedDots = _vocabularyDots
        .where((dot) => _selectedWordIds.contains(dot.id))
        .toList();

    // Upload image to cloud if user is logged in
    String finalImageUrl = widget.imagePath;
    final currentUser = ref.read(currentUserProvider);
    final imageStorageService = ref.read(imageStorageServiceProvider);

    if (currentUser != null && !currentUser.isGuest) {
      try {
        final imageUrl = await imageStorageService.uploadVocabularyImage(
          imageFile: File(widget.imagePath),
          userId: currentUser.id,
        );
        finalImageUrl = imageUrl;
      } catch (e) {
        // Continue with local path on error
      }
    }

    for (final dot in selectedDots) {
      final vocabulary = VocabularyModel(
        id: dot.id,
        word: dot.word,
        partOfSpeech: dot.partOfSpeech,
        thaiTranslation: dot.thaiTranslation,
        englishSentence: dot.englishSentence,
        thaiSentence: dot.thaiSentence,
        cefrLevel: widget.cefrLevel,
        communicativeFunction: widget.communicativeFunction,
        languageVariant: 'US',
        imageUrl: finalImageUrl,
        topic: dot.topic,
        tags: [dot.tone, dot.category],
        createdAt: DateTime.now(),
      );

      // Wait for vocabulary to be saved to cloud first (trigger needs to fire)
      await ref.read(vocabularyStateProvider.notifier).addVocabulary(vocabulary);

      // Refresh review session to show newly added card
      ref.invalidate(reviewStateProvider);
    }

    // Check if widget is still mounted before updating streak
    if (!mounted) return;

    // Update streak when saving vocabulary (only once per day)
    final streakNotifier = ref.read(streakProvider.notifier);
    await streakNotifier.recordVocabularyAcquired();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Saved ${selectedDots.length} words to collection!'),
        backgroundColor: Colors.green,
      ),
    );

    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _showRescanConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [const Text('Rescan Image')]),
        content: const Text(
          'Do you want to scan this same image again to generate new vocabulary?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog

              // Collect all existing words to exclude when regenerating
              final existingWords = _vocabularyDots.map((dot) => dot.word).toList();

              // Navigate to GenerationLoadingScreen with same image and exclude words
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => GenerationLoadingScreen(
                    imagePath: widget.imagePath,
                    cefrLevel: widget.cefrLevel,
                    communicativeFunction: widget.communicativeFunction,
                    englishVariant: widget.englishVariant,
                    excludeWords: existingWords, // Exclude existing words
                    isRegenerate: true, // Mark as regeneration
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Rescan'),
          ),
        ],
      ),
    );
  }

  /// Show context selector for combined sentences
  void _showCombinedContextSelector() {
    if (_selectedWordIds.isEmpty) return;

    // Get current context from first selected dot
    final firstSelectedDot = _vocabularyDots.firstWhere(
      (d) => _selectedWordIds.contains(d.id),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CombinedContextSelectorScreen(
          currentTone: firstSelectedDot.tone,
          currentCategory: firstSelectedDot.category,
          selectedWords: _selectedWordIds
              .map((id) => _vocabularyDots.firstWhere((d) => d.id == id).word)
              .toList(),
          onApply: (tone, category) => _applyCombinedContext(tone, category),
        ),
      ),
    );
  }

  /// Apply new context to all selected words in combined mode
  void _applyCombinedContext(String tone, String category) async {
    // Show loading
    setState(() {
      _isRegenerating = true;
    });

    // Update tone and category for all selected words
    final selectedDotIds = List<String>.from(_selectedWordIds);

    setState(() {
      for (int i = 0; i < _vocabularyDots.length; i++) {
        if (_selectedWordIds.contains(_vocabularyDots[i].id)) {
          _vocabularyDots[i] = _vocabularyDots[i].copyWith(
            tone: tone,
            category: category,
          );
        }
      }
    });

    // Regenerate combined sentences with new context
    final success = await _regenerateCombinedSentences(
      selectedDotIds,
      tone,
      category,
    );

    if (!mounted) return;

    setState(() {
      _isRegenerating = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Combined sentence updated with new context'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✗ Failed to update combined sentence. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Regenerate combined sentences with new context
  Future<bool> _regenerateCombinedSentences(
    List<String> wordIds,
    String tone,
    String category,
  ) async {
    final geminiService = ref.read(geminiServiceProvider);

    // Get selected words
    final selectedDots = _vocabularyDots
        .where((d) => wordIds.contains(d.id))
        .toList();
    if (selectedDots.isEmpty) return false;

    final words = selectedDots.map((d) => d.word).toList();
    final apiTone = _mapToneToApiFormat(tone);

    try {
      // Load image for contextually relevant sentences
      final imageData = await _loadImageData();

      final result = await geminiService.generateSentences(
        imageData: imageData,
        words: words,
        level: widget.cefrLevel,
        tones: [apiTone],
        category: category,
        combined: true,
        englishVariant: widget.englishVariant,
      );

      if (!mounted) return false;

      bool success = false;

      // Update all dots with new combined sentences
      setState(() {
        if (result.mode == 'combined' && result.combinedSentences != null) {
          final combinedSentences = result.combinedSentences!;
          final sentenceData = combinedSentences[apiTone];

          if (sentenceData != null) {
            // Update cache
            _savedCombinedSentences[apiTone] = (
              english: sentenceData.text,
              thai: sentenceData.thai,
            );

            // Update all selected dots
            for (var i = 0; i < _vocabularyDots.length; i++) {
              final dot = _vocabularyDots[i];
              if (wordIds.contains(dot.id)) {
                _vocabularyDots[i] = dot.copyWith(
                  englishSentence: sentenceData.text,
                  thaiSentence: sentenceData.thai,
                );
              }
            }
            success = true;
          }
        }
      });

      return success;
    } catch (e) {
      debugPrint('❌ Error regenerating combined sentences: $e');
      return false;
    }
  }
}

/// Word detail card
class _WordDetailCard extends StatelessWidget {
  final _VocabularyDot dot;
  final int index;
  final VoidCallback onContextTap;
  final VoidCallback onAudioTap;
  final VoidCallback onSentenceAudioTap;
  final bool isRegenerating;
  final String? playingAudioId;

  const _WordDetailCard({
    required this.dot,
    required this.index,
    required this.onContextTap,
    required this.onAudioTap,
    required this.onSentenceAudioTap,
    this.isRegenerating = false,
    this.playingAudioId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with word
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dot.word,
                      style: GoogleFonts.lexend(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6C63FF),
                      ),
                    ),
                    Text(
                      '${dot.partOfSpeech} • ${dot.thaiTranslation}',
                      style: GoogleFonts.lexend(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Audio Button (Word pronunciation)
              IconButton(
                icon: Icon(
                  playingAudioId == dot.id
                      ? Icons.stop_rounded
                      : Icons.volume_up_rounded,
                ),
                color: isRegenerating ? Colors.grey : const Color(0xFF6C63FF),
                onPressed: isRegenerating ? null : onAudioTap,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Sentences
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F4FF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: dot.englishSentence.isEmpty || isRegenerating
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF6C63FF),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Updating sentence...',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dot.englishSentence,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dot.thaiSentence,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          playingAudioId == 'sentence_${dot.id}'
                              ? Icons.stop_rounded
                              : Icons.volume_up_rounded,
                          size: 20,
                        ),
                        color: isRegenerating
                            ? Colors.grey
                            : const Color(0xFF6C63FF),
                        onPressed: isRegenerating ? null : onSentenceAudioTap,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Read sentence',
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),

          // Context Tags & +Context Button
          Row(
            children: [
              _ContextChip(label: dot.tone, icon: Icons.tune),
              const SizedBox(width: 8),
              _ContextChip(label: dot.category, icon: Icons.category),
              const Spacer(),
              TextButton.icon(
                onPressed: isRegenerating ? null : onContextTap,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Context'),
                style: TextButton.styleFrom(
                  foregroundColor: isRegenerating
                      ? Colors.grey
                      : const Color(0xFF6C63FF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _ContextChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1EEFF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF7B6EF6)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF7B6EF6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Vocabulary dot data model
class _VocabularyDot {
  final String id;
  final String word;
  final String thaiTranslation;
  final String partOfSpeech;
  final double x;
  final double y;
  final String englishSentence;
  final String thaiSentence;
  final String tone;
  final String category;
  final String topic;
  // Debug: original bounding box from AI
  final double? bboxXMin;
  final double? bboxYMin;
  final double? bboxXMax;
  final double? bboxYMax;

  _VocabularyDot({
    required this.id,
    required this.word,
    required this.thaiTranslation,
    required this.partOfSpeech,
    required this.x,
    required this.y,
    required this.englishSentence,
    required this.thaiSentence,
    required this.tone,
    required this.category,
    required this.topic,
    this.bboxXMin,
    this.bboxYMin,
    this.bboxXMax,
    this.bboxYMax,
  });

  _VocabularyDot copyWith({
    String? id,
    String? word,
    String? thaiTranslation,
    String? partOfSpeech,
    double? x,
    double? y,
    String? englishSentence,
    String? thaiSentence,
    String? tone,
    String? category,
    String? topic,
    double? bboxXMin,
    double? bboxYMin,
    double? bboxXMax,
    double? bboxYMax,
  }) {
    return _VocabularyDot(
      id: id ?? this.id,
      word: word ?? this.word,
      thaiTranslation: thaiTranslation ?? this.thaiTranslation,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      x: x ?? this.x,
      y: y ?? this.y,
      englishSentence: englishSentence ?? this.englishSentence,
      thaiSentence: thaiSentence ?? this.thaiSentence,
      tone: tone ?? this.tone,
      category: category ?? this.category,
      topic: topic ?? this.topic,
      bboxXMin: bboxXMin ?? this.bboxXMin,
      bboxYMin: bboxYMin ?? this.bboxYMin,
      bboxXMax: bboxXMax ?? this.bboxXMax,
      bboxYMax: bboxYMax ?? this.bboxYMax,
    );
  }
}

/// Context Selector Screen
class ContextSelectorScreen extends StatefulWidget {
  final _VocabularyDot vocabularyDot;
  final Function(String tone, String category) onApply;
  final Function(String tone, String category) onApplyToAll;

  const ContextSelectorScreen({
    super.key,
    required this.vocabularyDot,
    required this.onApply,
    required this.onApplyToAll,
  });

  @override
  State<ContextSelectorScreen> createState() => _ContextSelectorScreenState();
}

class _ContextSelectorScreenState extends State<ContextSelectorScreen> {
  late String _selectedTone;
  late String _selectedCategory;
  final TextEditingController _customTextController = TextEditingController();

  final List<String> _tones = ['Describe', 'Command', 'Wish', 'Conditional'];

  final List<String> _categories = [
    'Moment',
    'Nature',
    'Food',
    'Study',
    'Daily Life',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    _selectedTone = widget.vocabularyDot.tone;

    // Check if the saved category is a custom one (not in predefined list)
    if (_categories.contains(widget.vocabularyDot.category)) {
      _selectedCategory = widget.vocabularyDot.category;
    } else {
      _selectedCategory = 'Custom';
      _customTextController.text = widget.vocabularyDot.category;
    }
  }

  @override
  void dispose() {
    _customTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF2D2A4A),
        title: Text(
          'Customize Context',
          style: GoogleFonts.lexend(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2D2A4A),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Word Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),

                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    widget.vocabularyDot.word,
                    style: GoogleFonts.lexend(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF7B6EF6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.vocabularyDot.thaiTranslation,
                    style: GoogleFonts.lexend(
                      fontSize: 18,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tone & Intent Selection
            _buildSectionTitle('Tone & Intent'),
            const SizedBox(height: 12),
            _buildToneSelector(),
            const SizedBox(height: 24),

            // Category Selection
            _buildSectionTitle('Category'),
            const SizedBox(height: 12),
            _buildCategorySelector(),
            if (_selectedCategory == 'Custom') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customTextController,
                decoration: InputDecoration(
                  hintText: 'Enter custom category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _handleApply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Apply',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _handleApplyToAll,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6C63FF),
                  side: const BorderSide(color: Color(0xFF6C63FF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  'Use for All Selected',
                  style: GoogleFonts.lexend(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.lexend(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.grey[800],
      ),
    );
  }

  Widget _buildToneSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _tones.map((tone) {
        final isSelected = _selectedTone == tone;
        return FilterChip(
          label: Text(tone),
          selected: isSelected,
          onSelected: (_) {
            setState(() => _selectedTone = tone);
          },
          selectedColor: const Color(0xFFDCD4FF),
          backgroundColor: Colors.white,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),

          side: BorderSide(color: const Color(0xFFD8D1FF), width: 1.2),
        );
      }).toList(),
    );
  }

  Widget _buildCategorySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((category) {
        final isSelected = _selectedCategory == category;
        return FilterChip(
          label: Text(category),
          selected: isSelected,
          onSelected: (_) {
            setState(() => _selectedCategory = category);
          },
          selectedColor: const Color(0xFFDCD4FF),
          backgroundColor: Colors.white,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),

          side: BorderSide(color: const Color(0xFFD8D1FF), width: 1.2),
        );
      }).toList(),
    );
  }

  void _handleApply() {
    final category = _selectedCategory == 'Custom'
        ? (_customTextController.text.isNotEmpty
              ? _customTextController.text
              : 'Other')
        : _selectedCategory;

    widget.onApply(_selectedTone, category);
    Navigator.pop(context);
  }

  void _handleApplyToAll() {
    final category = _selectedCategory == 'Custom'
        ? (_customTextController.text.isNotEmpty
              ? _customTextController.text
              : 'Other')
        : _selectedCategory;

    widget.onApplyToAll(_selectedTone, category);
    Navigator.pop(context);
  }
}

/// Triangle painter for overlay arrow
class _TrianglePainter extends CustomPainter {
  final Color color;
  final bool pointDown;

  _TrianglePainter({
    required this.color,
    this.pointDown = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    if (pointDown) {
      // Triangle pointing down (for when overlay is above dot)
      path
        ..moveTo(0, 0) // Top left
        ..lineTo(size.width, 0) // Top right
        ..lineTo(size.width / 2, size.height) // Bottom center (point)
        ..close();
    } else {
      // Triangle pointing up (for when overlay is below dot)
      path
        ..moveTo(size.width / 2, 0) // Top center (point)
        ..lineTo(size.width, size.height) // Bottom right
        ..lineTo(0, size.height) // Bottom left
        ..close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.pointDown != pointDown;
}

/// Context Selector Screen for Combined Sentences
class CombinedContextSelectorScreen extends StatefulWidget {
  final String currentTone;
  final String currentCategory;
  final List<String> selectedWords;
  final Function(String tone, String category) onApply;

  const CombinedContextSelectorScreen({
    super.key,
    required this.currentTone,
    required this.currentCategory,
    required this.selectedWords,
    required this.onApply,
  });

  @override
  State<CombinedContextSelectorScreen> createState() =>
      _CombinedContextSelectorScreenState();
}

class _CombinedContextSelectorScreenState
    extends State<CombinedContextSelectorScreen> {
  late String _selectedTone;
  late String _selectedCategory;
  final TextEditingController _customTextController = TextEditingController();

  final List<String> _tones = ['Describe', 'Command', 'Wish', 'Conditional'];

  final List<String> _categories = [
    'Moment',
    'Nature',
    'Food',
    'Study',
    'Daily Life',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    _selectedTone = widget.currentTone;

    // Check if the saved category is a custom one (not in predefined list)
    if (_categories.contains(widget.currentCategory)) {
      _selectedCategory = widget.currentCategory;
    } else {
      _selectedCategory = 'Custom';
      _customTextController.text = widget.currentCategory;
    }
  }

  @override
  void dispose() {
    _customTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF2D2A4A),
        title: Text(
          'Customize Combined Context',
          style: GoogleFonts.lexend(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2D2A4A),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Combined Words Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Combined Sentence',
                    style: GoogleFonts.lexend(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF7B6EF6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Words: ${widget.selectedWords.join(", ")}',
                    style: GoogleFonts.lexend(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tone & Intent Selection
            _buildSectionTitle('Tone & Intent'),
            const SizedBox(height: 12),
            _buildToneSelector(),
            const SizedBox(height: 24),

            // Category Selection
            _buildSectionTitle('Category'),
            const SizedBox(height: 12),
            _buildCategorySelector(),
            if (_selectedCategory == 'Custom') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customTextController,
                decoration: InputDecoration(
                  hintText: 'Enter custom category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _handleApply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Apply to Combined Sentence',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.lexend(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.grey[800],
      ),
    );
  }

  Widget _buildToneSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _tones.map((tone) {
        final isSelected = _selectedTone == tone;
        return FilterChip(
          label: Text(tone),
          selected: isSelected,
          onSelected: (_) {
            setState(() => _selectedTone = tone);
          },
          selectedColor: const Color(0xFFDCD4FF),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(color: const Color(0xFFD8D1FF), width: 1.2),
        );
      }).toList(),
    );
  }

  Widget _buildCategorySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((category) {
        final isSelected = _selectedCategory == category;
        return FilterChip(
          label: Text(category),
          selected: isSelected,
          onSelected: (_) {
            setState(() => _selectedCategory = category);
          },
          selectedColor: const Color(0xFFDCD4FF),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(color: const Color(0xFFD8D1FF), width: 1.2),
        );
      }).toList(),
    );
  }

  void _handleApply() {
    final category = _selectedCategory == 'Custom'
        ? (_customTextController.text.isNotEmpty
              ? _customTextController.text
              : 'Other')
        : _selectedCategory;

    widget.onApply(_selectedTone, category);
    Navigator.pop(context);
  }
}
