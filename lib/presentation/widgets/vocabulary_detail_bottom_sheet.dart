import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/vocabulary_model.dart';
import '../../data/services/dictionary_service.dart';
import '../../data/services/tts_service.dart';

// Vocabulary Detail Bottom Sheet - Shows word details from dictionary API
class VocabularyDetailBottomSheet extends StatefulWidget {
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
  State<VocabularyDetailBottomSheet> createState() =>
      _VocabularyDetailBottomSheetState();
}

class _VocabularyDetailBottomSheetState
    extends State<VocabularyDetailBottomSheet> {
  DictionaryEntry? _dictionaryEntry;
  DictionaryEntry? _twinDictionaryEntry; // Dictionary entry for twin word
  bool _isLoading = true;
  bool _hasError = false;
  final TTSService _ttsService = TTSService();
  bool _isPlayingUK = false; // Track UK TTS state
  bool _isPlayingUS = false; // Track US TTS state
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
        });
      }
    });

    _ttsErrorSubscription = _ttsService.onError.listen((error) {
      if (mounted) {
        setState(() {
          _isPlayingUK = false;
          _isPlayingUS = false;
        });
      }
      print('🔊 TTS Error: $error');
    });
  }

  Future<void> _fetchDictionaryData() async {
    // Fetch dictionary for current word
    final result =
        await widget.dictionaryService.getWordDefinition(widget.vocabulary.word);

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
      return Row(
        children: [
          if (currentPhonetic != null) ...[
            Text(
              'UK: $currentPhonetic',
              style: GoogleFonts.lexend(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF8B5CF6),
              ),
            ),
            if (twinPhonetic != null) ...[
              const SizedBox(width: 12),
              Text(
                '|',
                style: GoogleFonts.lexend(
                  fontSize: 13,
                  color: const Color(0xFF9ca3af),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'US: $twinPhonetic',
                style: GoogleFonts.lexend(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ] else if (twinPhonetic != null)
            Text(
              twinPhonetic,
              style: GoogleFonts.lexend(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF6b7280),
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      );
    }

    // No twin word, show single phonetic
    return Text(
      currentPhonetic ?? '',
      style: GoogleFonts.lexend(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: const Color(0xFF6b7280),
        fontStyle: FontStyle.italic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF60a5fa)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      widget.vocabulary.word.isNotEmpty
                          ? widget.vocabulary.word[0].toUpperCase()
                          : '',
                      style: GoogleFonts.lexend(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Show both spellings if twin word exists
                      if (_twinWord != null)
                        Row(
                          children: [
                            Text(
                              widget.vocabulary.word,
                              style: GoogleFonts.lexend(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1f2937),
                              ),
                            ),
                            Text(
                              ' (${widget.vocabulary.languageVariant})',
                              style: GoogleFonts.lexend(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF8B5CF6),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '/',
                              style: GoogleFonts.lexend(
                                fontSize: 22,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF9ca3af),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _twinWord!.word,
                              style: GoogleFonts.lexend(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1f2937),
                              ),
                            ),
                            Text(
                              ' (${_twinWord!.languageVariant})',
                              style: GoogleFonts.lexend(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF8B5CF6),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          widget.vocabulary.word,
                          style: GoogleFonts.lexend(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1f2937),
                          ),
                        ),
                      // Show phonetics for both words if twin exists
                      if (_dictionaryEntry?.phonetic != null ||
                          _twinDictionaryEntry?.phonetic != null)
                        _buildPhoneticRow(),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF9ca3af)),
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
                // UK Button
                Expanded(
                  child: InkWell(
                    onTap: () => _playAudio(
                      _twinWord?.languageVariant == 'UK'
                          ? _twinWord!.word
                          : widget.vocabulary.word,
                      'UK',
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isPlayingUK)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF8B5CF6)),
                              ),
                            )
                          else
                            const Icon(Icons.volume_up,
                                color: Color(0xFF8B5CF6), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '🇬🇧 UK',
                            style: GoogleFonts.lexend(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF8B5CF6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // US Button
                Expanded(
                  child: InkWell(
                    onTap: () => _playAudio(
                      _twinWord?.languageVariant == 'US'
                          ? _twinWord!.word
                          : widget.vocabulary.word,
                      'US',
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isPlayingUS)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF8B5CF6)),
                              ),
                            )
                          else
                            const Icon(Icons.volume_up,
                                color: Color(0xFF8B5CF6), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '🇺🇸 US',
                            style: GoogleFonts.lexend(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF8B5CF6),
                            ),
                          ),
                        ],
                      ),
                    ),
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

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                color: Color(0xFF8B5CF6),
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
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 20, color: Color(0xFF9CA3AF)),
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
                  color: const Color(0xFF8B5CF6),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Vocabulary',
            style: GoogleFonts.lexend(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.vocabulary.word,
            style: GoogleFonts.lexend(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1f2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.vocabulary.thaiTranslation,
            style: GoogleFonts.lexend(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6b7280),
            ),
          ),
          if (widget.vocabulary.englishSentence.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.vocabulary.englishSentence,
              style: GoogleFonts.lexend(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF5E3A8E),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
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
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              meaning.partOfSpeech.toUpperCase(),
              style: GoogleFonts.lexend(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF8B5CF6),
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
                color: const Color(0xFF1f2937),
              ),
            ),
            const SizedBox(height: 8),
            ...meaning.definitions.take(3).map((def) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(color: Color(0xFF8B5CF6))),
                      Expanded(
                        child: Text(
                          def,
                          style: GoogleFonts.lexend(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF4b5563),
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
                color: const Color(0xFF1f2937),
              ),
            ),
            const SizedBox(height: 8),
            ...meaning.examples.take(3).map((ex) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    ex,
                    style: GoogleFonts.lexend(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF5E3A8E),
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
                color: const Color(0xFF1f2937),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: meaning.synonyms.take(6).map((syn) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      syn,
                      style: GoogleFonts.lexend(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6b7280),
                      ),
                    ),
                  )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
