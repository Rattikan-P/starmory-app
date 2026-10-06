import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/design_tokens.dart';
import '../../data/models/vocabulary_model.dart';
import '../../data/services/dictionary_service.dart';
import '../../data/services/tts_service.dart';
import '../providers/providers.dart' show currentUserProvider;
import 'bottom_sheet_chrome.dart';
import 'app_loading_widgets.dart';

// Vocabulary Detail Bottom Sheet - Shows word details from dictionary API
class VocabularyDetailBottomSheet extends ConsumerStatefulWidget {
  final VocabularyModel vocabulary;
  final DictionaryService dictionaryService;
  final List<VocabularyModel> allVocabularies;

  const VocabularyDetailBottomSheet({
    super.key,
    required this.vocabulary,
    required this.dictionaryService,
    required this.allVocabularies,
  });

  @override
  ConsumerState<VocabularyDetailBottomSheet> createState() =>
      _VocabularyDetailBottomSheetState();
}

class _VocabularyDetailBottomSheetState
    extends ConsumerState<VocabularyDetailBottomSheet> {
  DictionaryEntry? _dictionaryEntry;
  DictionaryEntry? _twinDictionaryEntry; // Dictionary entry for twin word
  bool _isLoading = true;
  bool _hasError = false;
  final TTSService _ttsService = TTSService();
  bool _isPlayingUK = false; // Track UK TTS state
  bool _isPlayingUS = false; // Track US TTS state
  bool _isPlayingSentence = false;
  StreamSubscription? _ttsCompletionSubscription;
  StreamSubscription? _ttsErrorSubscription;

  // Twin word (same word, different spelling like colour/color)
  VocabularyModel? _twinWord;

  @override
  void initState() {
    super.initState();
    _findTwinWord();
    _fetchDictionaryData();
    _setupTTSSubscriptions();
  }

  /// Find the twin word (same word, different variant)
  /// e.g., "colour (UK)" and "color (US)"
  void _findTwinWord() {
    final currentWord = widget.vocabulary.word.toLowerCase();
    final currentVariant = widget.vocabulary.languageVariant;

    for (final vocab in widget.allVocabularies) {
      // Skip self
      if (vocab.id == widget.vocabulary.id) continue;

      // Check if same word but different variant
      if (vocab.word.toLowerCase() == currentWord &&
          vocab.languageVariant != currentVariant) {
        setState(() {
          _twinWord = vocab;
        });
        print('🔗 Found twin word: ${vocab.word} (${vocab.languageVariant})');
        return;
      }
    }

    // Try to find words with common UK/US spelling differences
    final commonUKUSPairs = {
      'colour': 'color',
      'color': 'colour',
      'centre': 'center',
      'center': 'centre',
      'theatre': 'theater',
      'theater': 'theatre',
      'licence': 'license',
      'license': 'licence',
      'organisation': 'organization',
      'organization': 'organisation',
      'organise': 'organize',
      'organize': 'organise',
      'favourite': 'favorite',
      'favorite': 'favourite',
      'honour': 'honor',
      'honor': 'honour',
      'labour': 'labor',
      'labor': 'labour',
    };

    // Check if current word has a common pair
    final twinWord = commonUKUSPairs[currentWord];
    if (twinWord != null) {
      // Find the twin in the vocab list
      for (final vocab in widget.allVocabularies) {
        if (vocab.word.toLowerCase() == twinWord &&
            vocab.languageVariant != currentVariant) {
          setState(() {
            _twinWord = vocab;
          });
          print(
              '🔗 Found common twin word: ${vocab.word} (${vocab.languageVariant})');
          return;
        }
      }
    }
  }

  void _setupTTSSubscriptions() {
    _ttsCompletionSubscription = _ttsService.onComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlayingUK = false;
          _isPlayingUS = false;
          _isPlayingSentence = false;
        });
      }
    });

    _ttsErrorSubscription = _ttsService.onError.listen((error) {
      if (mounted) {
        setState(() {
          _isPlayingUK = false;
          _isPlayingUS = false;
          _isPlayingSentence = false;
        });
      }
      print('🔊 TTS Error: $error');
    });
  }

  Future<void> _fetchDictionaryData() async {
    // Fetch dictionary for current word
    final result = await widget.dictionaryService
        .getWordDefinition(widget.vocabulary.word);

    // Fetch dictionary for twin word if exists
    DictionaryEntry? twinResult;
    if (_twinWord != null) {
      twinResult =
          await widget.dictionaryService.getWordDefinition(_twinWord!.word);
      print('🔗 Fetched twin dictionary: ${_twinWord!.word}');
    }

    if (mounted) {
      setState(() {
        _dictionaryEntry = result;
        _twinDictionaryEntry = twinResult;
        _isLoading = false;
        _hasError = result == null && twinResult == null;
      });
    }
  }

  Future<void> _playAudio(String word, String variant) async {
    if (word.isEmpty) {
      print('❌ Word is empty');
      return;
    }

    // Stop any currently playing audio
    await _ttsService.stop();

    print('🔊 Speaking word: $word ($variant)');

    try {
      setState(() {
        if (variant == 'UK') {
          _isPlayingUK = true;
          _isPlayingUS = false;
        } else {
          _isPlayingUS = true;
          _isPlayingUK = false;
        }
      });

      // Use TTS with specific language variant
      _ttsService.speak(
        word,
        language: TTSService.getLanguageCode(variant),
      );

      print('✅ TTS speak command sent for $variant');
    } catch (e) {
      print('❌ Error speaking word: $e');
      setState(() {
        _isPlayingUK = false;
        _isPlayingUS = false;
      });
    }
  }

  Future<void> _playSentence(String sentence, String variant) async {
    if (sentence.trim().isEmpty) return;
    await _ttsService.stop();
    if (!mounted) return;
    setState(() {
      _isPlayingSentence = true;
      _isPlayingUK = false;
      _isPlayingUS = false;
    });
    try {
      await _ttsService.speak(
        sentence,
        language: TTSService.getLanguageCode(variant),
      );
    } catch (e) {
      if (mounted) setState(() => _isPlayingSentence = false);
    }
  }

  @override
  void dispose() {
    _ttsCompletionSubscription?.cancel();
    _ttsErrorSubscription?.cancel();
    _ttsService.stop();
    super.dispose();
  }

  /// Build phonetic row showing UK and US phonetics
  Widget _buildPhoneticRow() {
    final currentPhonetic = _dictionaryEntry?.phonetic;
    final twinPhonetic = _twinDictionaryEntry?.phonetic;

    // If twin word exists, show both phonetics
    if (_twinWord != null) {
      final spans = <InlineSpan>[];
      if (currentPhonetic != null && currentPhonetic.isNotEmpty) {
        spans.add(TextSpan(
          text: '${widget.vocabulary.languageVariant}:\u00A0$currentPhonetic',
          style: GoogleFonts.lexend(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: DesignTokens.dialogBrand,
          ),
        ));
      }
      if (currentPhonetic != null &&
          currentPhonetic.isNotEmpty &&
          twinPhonetic != null &&
          twinPhonetic.isNotEmpty) {
        spans.add(TextSpan(
          text: '   |   ',
          style: GoogleFonts.lexend(
            fontSize: 13,
            color: const Color(0xFF9ca3af),
          ),
        ));
      }
      if (twinPhonetic != null && twinPhonetic.isNotEmpty) {
        spans.add(TextSpan(
          text: '${_twinWord!.languageVariant}:\u00A0$twinPhonetic',
          style: GoogleFonts.lexend(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: DesignTokens.dialogBrand,
          ),
        ));
      }
      if (spans.isNotEmpty) {
        return Text.rich(TextSpan(children: spans));
      }
      return const SizedBox.shrink();
    }

    // No twin word, show single phonetic
    return Text(
      currentPhonetic ?? '',
      style: GoogleFonts.lexend(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: DesignTokens.dialogBrand,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.bottomSheetRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle bar
          const AppBottomSheetDragHandle(
            margin: EdgeInsets.only(top: 12),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Show both spellings if twin word exists
                      if (_twinWord != null)
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: widget.vocabulary.word,
                                style: GoogleFonts.lexend(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1f2937),
                                ),
                              ),
                              TextSpan(
                                text:
                                    '\u00A0(${widget.vocabulary.languageVariant})',
                                style: GoogleFonts.lexend(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: DesignTokens.dialogBrand,
                                ),
                              ),
                              TextSpan(
                                text: '  /  ',
                                style: GoogleFonts.lexend(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF9ca3af),
                                ),
                              ),
                              TextSpan(
                                text: _twinWord!.word,
                                style: GoogleFonts.lexend(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1f2937),
                                ),
                              ),
                              TextSpan(
                                text: '\u00A0(${_twinWord!.languageVariant})',
                                style: GoogleFonts.lexend(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: DesignTokens.dialogBrand,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          widget.vocabulary.word,
                          style: GoogleFonts.lexend(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1f2937),
                          ),
                        ),
                      // Show phonetics
                      if (_isLoading) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Loading phonetic...',
                          style: GoogleFonts.lexend(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF9ca3af),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ] else if (_dictionaryEntry?.phonetic != null ||
                          _twinDictionaryEntry?.phonetic != null) ...[
                        const SizedBox(height: 4),
                        _buildPhoneticRow(),
                      ],
                    ],
                  ),
                ),
                AppBottomSheetCloseButton(
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Audio Player (TTS) - UK and US buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _buildPronunciationButton(
                    variant: 'UK',
                    word: _twinWord?.languageVariant == 'UK'
                        ? _twinWord!.word
                        : widget.vocabulary.word,
                    isPlaying: _isPlayingUK,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPronunciationButton(
                    variant: 'US',
                    word: _twinWord?.languageVariant == 'US'
                        ? _twinWord!.word
                        : widget.vocabulary.word,
                    isPlaying: _isPlayingUS,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPronunciationButton({
    required String variant,
    required String word,
    required bool isPlaying,
  }) {
    final accentColor = DesignTokens.dialogBrand;
    return Tooltip(
      message: 'Listen to $variant pronunciation',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _playAudio(word, variant),
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isPlaying ? DesignTokens.dialogBrandTint : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isPlaying
                    ? accentColor
                    : DesignTokens.dialogAccentBorderColor(accentColor),
                width: isPlaying ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color:
                        isPlaying ? accentColor : DesignTokens.dialogBrandTint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying
                        ? Icons.graphic_eq_rounded
                        : Icons.volume_up_rounded,
                    size: 17,
                    color: isPlaying ? Colors.white : accentColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  variant == 'UK' ? '🇬🇧' : '🇺🇸',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(width: 4),
                Text(
                  variant,
                  style: GoogleFonts.lexend(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        // Original vocab info - ALWAYS displayed immediately
        _buildOriginalVocabInfo(),

        const SizedBox(height: 20),

        // Dictionary definitions section
        _buildDictionarySection(),
      ],
    );
  }

  Widget _buildDictionarySection() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: DesignTokens.dialogBrand,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading dictionary definitions...',
              style: GoogleFonts.lexend(
                fontSize: 13,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    if (_hasError ||
        _dictionaryEntry == null ||
        _dictionaryEntry!.meanings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: DesignTokens.dialogAccentBorderColor(
              DesignTokens.dialogBrand,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.info_outline,
              size: 20,
              color: DesignTokens.dialogBrand,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No online dictionary definitions found',
                style: GoogleFonts.lexend(
                  fontSize: 13,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
                _fetchDictionaryData();
              },
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.lexend(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: DesignTokens.dialogBrand,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._dictionaryEntry!.meanings.asMap().entries.map((entry) {
          final index = entry.key;
          final meaning = entry.value;
          return _buildMeaningSection(meaning, index);
        }),
      ],
    );
  }

  Widget _buildOriginalVocabInfo() {
    final examples = widget.vocabulary.allExamples;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: DesignTokens.dialogAccentBorderColor(DesignTokens.dialogBrand),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'MEANING',
                style: GoogleFonts.lexend(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: DesignTokens.dialogBrand,
                  letterSpacing: 1.2,
                ),
              ),
              if (examples.length > 1) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: DesignTokens.dialogBrandTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${examples.length} examples',
                    style: GoogleFonts.lexend(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: DesignTokens.dialogBrand,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.vocabulary.thaiTranslation,
            style: GoogleFonts.lexend(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: DesignTokens.dialogTitleColor,
            ),
          ),
          if (examples.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: DesignTokens.dialogAccentBorderColor(
                DesignTokens.dialogBrand,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'FROM YOUR MEMORIES',
              style: GoogleFonts.lexend(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: DesignTokens.dialogTitleColor,
              ),
            ),
            const SizedBox(height: 8),
            if (examples.length == 1)
              SizedBox(
                height: 196,
                child: _buildVocabularyExamplePage(examples.single),
              )
            else
              SizedBox(
                height: 196,
                child: PageView.builder(
                  itemCount: examples.length,
                  itemBuilder: (context, index) => _buildVocabularyExamplePage(
                    examples[index],
                    position: '${index + 1} / ${examples.length}',
                  ),
                ),
              ),
          ] else if (widget.vocabulary.englishSentence.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.vocabulary.englishSentence,
              style: GoogleFonts.lexend(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: DesignTokens.dialogBrand,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVocabularyExamplePage(
    VocabularyExample example, {
    String? position,
  }) {
    final selectedVariant = (ref
            .watch(currentUserProvider)
            ?.preferences['languageVariant'] as String?) ??
        widget.vocabulary.languageVariant;
    final sentence = example.englishSentence.trim();
    final thaiSentence = example.thaiSentence.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildScrapbookImage(example.imageUrl),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC000000)],
                stops: [0.3, 1],
              ),
            ),
          ),
          if (position != null)
            Positioned(
              top: 10,
              right: 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.45),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      position,
                      style: GoogleFonts.lexend(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: const [
                          Shadow(color: Colors.black38, blurRadius: 3),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 124),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const ClampingScrollPhysics(),
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sentence.isNotEmpty)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                sentence,
                                style: GoogleFonts.lexend(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  fontStyle: FontStyle.italic,
                                  height: 1.35,
                                  shadows: const [
                                    Shadow(
                                        color: Colors.black54, blurRadius: 4),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Semantics(
                              button: true,
                              label:
                                  'Play sentence pronunciation in $selectedVariant',
                              child: Material(
                                color: Colors.white.withValues(alpha: 0.94),
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () =>
                                      _playSentence(sentence, selectedVariant),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _isPlayingSentence
                                              ? Icons.graphic_eq_rounded
                                              : Icons.volume_up_rounded,
                                          size: 15,
                                          color: DesignTokens.dialogBrand,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          selectedVariant,
                                          style: GoogleFonts.lexend(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: DesignTokens.dialogBrand,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (thaiSentence.isNotEmpty) ...[
                        if (sentence.isNotEmpty) const SizedBox(height: 4),
                        Text(
                          thaiSentence,
                          style: GoogleFonts.lexend(
                            fontSize: 11.5,
                            color: Colors.white,
                            height: 1.35,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 4),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrapbookImage(String imagePath) {
    if (imagePath.isEmpty) {
      return _buildScrapbookImageFallback();
    }

    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) =>
            loadingProgress == null ? child : const AppImageSkeleton(),
        errorBuilder: (_, __, ___) => _buildScrapbookImageFallback(),
      );
    }

    return Image.file(
      File(imagePath),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildScrapbookImageFallback(),
    );
  }

  Widget _buildScrapbookImageFallback() {
    return Container(
      color: DesignTokens.dialogBrandTint,
      alignment: Alignment.center,
      child: Icon(
        Icons.photo_outlined,
        size: 34,
        color: DesignTokens.dialogBrand.withValues(alpha: 0.6),
      ),
    );
  }

  Widget _buildMeaningSection(Meaning meaning, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Part of Speech badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: DesignTokens.dialogBrandTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              meaning.partOfSpeech.toUpperCase(),
              style: GoogleFonts.lexend(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: DesignTokens.dialogBrand,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Definitions
          if (meaning.definitions.isNotEmpty) ...[
            Text(
              'Definitions',
              style: GoogleFonts.lexend(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: DesignTokens.dialogTitleColor,
              ),
            ),
            const SizedBox(height: 8),
            ...meaning.definitions.take(3).map((def) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(color: DesignTokens.dialogBrand)),
                      Expanded(
                        child: Text(
                          def,
                          style: GoogleFonts.lexend(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: DesignTokens.dialogBodyColor,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],

          // Examples
          if (meaning.examples.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Examples',
              style: GoogleFonts.lexend(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: DesignTokens.dialogTitleColor,
              ),
            ),
            const SizedBox(height: 8),
            ...meaning.examples.take(3).map((ex) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DesignTokens.dialogBrandTint.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    ex,
                    style: GoogleFonts.lexend(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: DesignTokens.dialogBodyColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )),
          ],

          // Synonyms
          if (meaning.synonyms.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Synonyms',
              style: GoogleFonts.lexend(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: DesignTokens.dialogTitleColor,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: meaning.synonyms
                  .take(6)
                  .map((syn) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: DesignTokens.dialogBrandTint,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          syn,
                          style: GoogleFonts.lexend(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: DesignTokens.dialogBrand,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
