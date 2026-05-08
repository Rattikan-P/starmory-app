import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../../data/models/vocabulary_model.dart';
import '../../data/services/gemini_service.dart';

/// Interactive Vocabulary Result Screen
/// Shows image with clickable dots, word chips, and context customization
class InteractiveVocabularyScreen extends ConsumerStatefulWidget {
  final String imagePath;
  final String cefrLevel;
  final String communicativeFunction;
  final VocabularyExtractionResult? extractionResult;

  const InteractiveVocabularyScreen({
    super.key,
    required this.imagePath,
    required this.cefrLevel,
    required this.communicativeFunction,
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

  @override
  void initState() {
    super.initState();
    // Load actual AI generation result
    _initializeVocabularyData();
  }

  void _initializeVocabularyData() {
    if (widget.extractionResult != null) {
      // Debug: Print the vocab list count
      debugPrint('📊 Extraction Result: ${widget.extractionResult!.vocabList.length} items');

      // Use actual AI result
      _vocabularyDots = widget.extractionResult!.vocabList.map((item) {
        final bbox = item.boundingBox;
        final (x, y) = bbox.center;
        debugPrint('✅ Word: ${item.word}, Thai: ${item.thai}, Center: ($x, $y)');
        return _VocabularyDot(
          id: item.word,
          word: item.word,
          thaiTranslation: item.thai,
          partOfSpeech: item.type,
          x: x,
          y: y,
          englishSentence: '', // Will be generated later
          thaiSentence: '', // Will be generated later
          tone: 'Describe', // Default
          category: widget.extractionResult!.category,
        );
      }).toList();

      debugPrint('🎯 Final _vocabularyDots count: ${_vocabularyDots.length}');
    } else {
      // No data available
      debugPrint('⚠️ Extraction result is null');
      _vocabularyDots = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Vocabulary Result'),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        actions: [
          // Rescan button
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: () {
              // TODO: Navigate to image picker
            },
            tooltip: 'Rescan',
          ),
          // Save button
          TextButton(
            onPressed: _selectedWordIds.isEmpty ? null : _saveAllVocabularies,
            child: Text(
              'Save (${_selectedWordIds.length})',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Image with Dots
          _buildImageWithDots(),

          // Selected Words Chips
          _buildSelectedWordsChips(),

          // Combined Sentence Toggle
          _buildCombinedSentenceToggle(),

          // Word Details / Expanded Content
          Expanded(
            child: _selectedWordIds.isEmpty
                ? _buildEmptyState()
                : _buildWordDetails(),
          ),
        ],
      ),
    );
  }

  Widget _buildCombinedSentenceToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Combined Sentence',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Switch(
            value: _useCombinedSentence,
            onChanged: (value) {
              setState(() => _useCombinedSentence = value);
            },
            activeTrackColor: const Color(0xFF6C63FF).withOpacity(0.5),
            activeThumbColor: const Color(0xFF6C63FF),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWithDots() {
    return SizedBox(
      height: 300,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return FutureBuilder<Size>(
            future: _getImageDimensions(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final imageSize = snapshot.data!;
              return Stack(
                children: [
                  // Image
                  Positioned.fill(
                    child: Image.file(
                      File(widget.imagePath),
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Dots Overlay with proper coordinate mapping for BoxFit.cover
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
      ),
    );
  }

  /// Get original image dimensions
  Future<Size> _getImageDimensions() async {
    final bytes = await File(widget.imagePath).readAsBytes();
    final decodedImage = await decodeImageFromList(bytes);
    return Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());
  }

  /// Calculate BoxFit.cover scaling and position
  ({double scale, double offsetX, double offsetY}) _calculateBoxFitCover(
    Size imageSize,
    double containerWidth,
    double containerHeight,
  ) {
    final imageAspectRatio = imageSize.width / imageSize.height;
    final containerAspectRatio = containerWidth / containerHeight;

    double scale;
    double offsetX = 0;
    double offsetY = 0;

    if (imageAspectRatio > containerAspectRatio) {
      // Image is wider than container - scale to height
      scale = containerHeight / imageSize.height;
      // Center horizontally
      offsetX = (containerWidth - imageSize.width * scale) / 2;
    } else {
      // Image is taller than container - scale to width
      scale = containerWidth / imageSize.width;
      // Center vertically
      offsetY = (containerHeight - imageSize.height * scale) / 2;
    }

    return (scale: scale, offsetX: offsetX, offsetY: offsetY);
  }

  List<Widget> _buildVocabularyDots(
    double containerWidth,
    double containerHeight,
    Size imageSize,
  ) {
    final fit = _calculateBoxFitCover(imageSize, containerWidth, containerHeight);

    debugPrint('📐 Container: $containerWidth x $containerHeight');
    debugPrint('🖼️ Image: ${imageSize.width} x ${imageSize.height}');
    debugPrint('🔧 Fit: scale=${fit.scale.toStringAsFixed(3)}, offsetX=${fit.offsetX.toStringAsFixed(1)}, offsetY=${fit.offsetY.toStringAsFixed(1)}');

    return _vocabularyDots.map((dot) {
      final isSelected = _selectedWordIds.contains(dot.id);

      // Convert normalized coordinates to actual image position
      final imageX = dot.x * imageSize.width;
      final imageY = dot.y * imageSize.height;

      // Apply BoxFit.cover transformation
      final displayedX = imageX * fit.scale + fit.offsetX;
      final displayedY = imageY * fit.scale + fit.offsetY;

      debugPrint('📍 Dot "${dot.word}": normalized=(${dot.x.toStringAsFixed(2)}, ${dot.y.toStringAsFixed(2)}) → displayed=(${displayedX.toStringAsFixed(1)}, ${displayedY.toStringAsFixed(1)})');

      // Temporarily disable bounds check for debugging
      // Check if dot is within visible bounds
      // if (displayedX < -20 || displayedX > containerWidth + 20 ||
      //     displayedY < -20 || displayedY > containerHeight + 20) {
      //   return const SizedBox.shrink();
      // }

      return Positioned(
        left: displayedX - 20,
        top: displayedY - 20,
        child: GestureDetector(
          onTap: () => _toggleWordSelection(dot.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? const Color(0xFF6C63FF)
                  : Colors.white.withOpacity(0.8),
              border: Border.all(
                color: const Color(0xFF6C63FF),
                width: isSelected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: Text(
                isSelected ? '${_vocabularyDots.indexOf(dot) + 1}' : '',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
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
          return Chip(
            label: Text(dot.word),
            avatar: CircleAvatar(
              backgroundColor: const Color(0xFF6C63FF),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
            backgroundColor: const Color(0xFF6C63FF).withOpacity(0.1),
            deleteIcon: const Icon(Icons.close, size: 18),
            onDeleted: () => _toggleWordSelection(dot.id),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Tap the dots on the image',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'to select vocabulary words',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordDetails() {
    final selectedDots = _vocabularyDots
        .where((dot) => _selectedWordIds.contains(dot.id))
        .toList();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: selectedDots.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final dot = selectedDots[index];
        return _WordDetailCard(
          dot: dot,
          index: index + 1,
          onContextTap: () => _showContextSelector(dot),
          onAudioTap: () => _playAudio(dot),
        );
      },
    );
  }

  void _toggleWordSelection(String wordId) {
    setState(() {
      if (_selectedWordIds.contains(wordId)) {
        _selectedWordIds.remove(wordId);
      } else {
        _selectedWordIds.add(wordId);
      }
    });
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

  void _applyContext(_VocabularyDot dot, String tone, String category) {
    setState(() {
      final index = _vocabularyDots.indexWhere((d) => d.id == dot.id);
      if (index != -1) {
        _vocabularyDots[index] = dot.copyWith(
          tone: tone,
          category: category,
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Context applied to ${dot.word}')),
    );
  }

  void _applyContextToAll(String tone, String category) {
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Context applied to all selected words')),
    );
  }

  void _playAudio(_VocabularyDot dot) {
    // TODO: Implement text-to-speech
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Playing: ${dot.word}')),
    );
  }

  void _saveAllVocabularies() {
    final selectedDots = _vocabularyDots
        .where((dot) => _selectedWordIds.contains(dot.id))
        .toList();

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
        imageUrl: widget.imagePath,
        tags: [dot.tone, dot.category],
        createdAt: DateTime.now(),
      );

      ref.read(vocabularyStateProvider.notifier).addVocabulary(vocabulary);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Saved ${selectedDots.length} words to collection!'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.popUntil(context, (route) => route.isFirst);
  }
}

/// Word detail card
class _WordDetailCard extends StatelessWidget {
  final _VocabularyDot dot;
  final int index;
  final VoidCallback onContextTap;
  final VoidCallback onAudioTap;

  const _WordDetailCard({
    required this.dot,
    required this.index,
    required this.onContextTap,
    required this.onAudioTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with word and index
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFF6C63FF),
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dot.word,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6C63FF),
                      ),
                    ),
                    Text(
                      '${dot.partOfSpeech} • ${dot.thaiTranslation}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Audio Button
              IconButton(
                icon: const Icon(Icons.volume_up),
                color: const Color(0xFF6C63FF),
                onPressed: onAudioTap,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Sentences
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dot.englishSentence,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
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
          const SizedBox(height: 12),

          // Context Tags & +Context Button
          Row(
            children: [
              _ContextChip(label: dot.tone, icon: Icons.tune),
              const SizedBox(width: 8),
              _ContextChip(label: dot.category, icon: Icons.category),
              const Spacer(),
              TextButton.icon(
                onPressed: onContextTap,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Context'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6C63FF),
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
        color: const Color(0xFF6C63FF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6C63FF)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6C63FF),
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

  final List<String> _tones = [
    'Describe',
    'Command',
    'Wish',
    'Conditional',
  ];

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
    _selectedCategory = widget.vocabularyDot.category;
  }

  @override
  void dispose() {
    _customTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customize Context'),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
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
                color: const Color(0xFF6C63FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    widget.vocabularyDot.word,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6C63FF),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.vocabularyDot.thaiTranslation,
                    style: TextStyle(
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Apply',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Use for All Selected',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
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
          selectedColor: const Color(0xFF6C63FF).withOpacity(0.3),
          checkmarkColor: const Color(0xFF6C63FF),
          backgroundColor: Colors.grey[100],
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
          selectedColor: const Color(0xFF6C63FF).withOpacity(0.3),
          checkmarkColor: const Color(0xFF6C63FF),
          backgroundColor: Colors.grey[100],
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
