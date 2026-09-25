import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/design_tokens.dart';
import '../../data/models/scrapbook_model.dart';
import '../../data/models/vocabulary_model.dart';
import '../../data/services/dictionary_service.dart';
import '../pages/edit_scrapbook_screen.dart';
import '../providers/providers.dart';
import 'scrapbook_polaroid.dart';
import 'vocabulary_detail_bottom_sheet.dart';

Future<void> showScrapbookDetailSheet(
  BuildContext context, {
  required List<ScrapbookModel> scrapbooks,
}) async {
  if (scrapbooks.isEmpty) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.22),
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.76,
      minChildSize: 0.56,
      maxChildSize: 0.94,
      expand: false,
      snap: true,
      snapSizes: const [0.76, 0.94],
      builder: (_, scrollController) => _ScrapbookDetailSheet(
        scrapbooks: scrapbooks,
        scrollController: scrollController,
        parentContext: context,
      ),
    ),
  );
}

class _ScrapbookDetailSheet extends StatelessWidget {
  const _ScrapbookDetailSheet({
    required this.scrapbooks,
    required this.scrollController,
    required this.parentContext,
  });

  final List<ScrapbookModel> scrapbooks;
  final ScrollController scrollController;
  final BuildContext parentContext;

  ScrapbookModel get scrapbook => scrapbooks.first;

  List<ScrapbookModel> get photoScrapbooks => scrapbooks
      .where((entry) => entry.imagePath.trim().isNotEmpty)
      .toList();

  List<ScrapbookVocabularyWord> get vocabulary {
    final words = <String, ScrapbookVocabularyWord>{};
    for (final entry in scrapbooks) {
      for (final word in entry.vocabularyWords) {
        words.putIfAbsent(word.word.toLowerCase(), () => word);
      }
    }
    return words.values.toList();
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _openEditor(BuildContext sheetContext, [ScrapbookModel? selected]) {
    final entry = selected ?? scrapbook;
    Navigator.of(sheetContext).pop();
    Navigator.of(parentContext).push(
      MaterialPageRoute(
        builder: (_) => EditScrapbookScreen(
          scrapbookId: entry.id,
          imagePath: entry.imagePath,
          vocabularyWords: entry.vocabularyWords,
          englishSentence: entry.englishSentence,
          thaiSentence: entry.thaiSentence,
          selectedEmoji: entry.selectedEmoji,
          date: entry.date,
        ),
      ),
    );
  }

  void _showWordDetail(BuildContext context, ScrapbookVocabularyWord word) {
    List<VocabularyModel> allVocabularies = const [];
    try {
      allVocabularies = ProviderScope.containerOf(parentContext)
          .read(vocabularyStateProvider)
          .vocabularies;
    } catch (_) {
      try {
        allVocabularies = ProviderScope.containerOf(context)
            .read(vocabularyStateProvider)
            .vocabularies;
      } catch (_) {}
    }

    final matchingVocab = allVocabularies.where(
      (v) => v.word.trim().toLowerCase() == word.word.trim().toLowerCase(),
    ).firstOrNull;

    final targetVocab = matchingVocab ??
        VocabularyModel(
          id: 'scrapbook_${word.word}',
          word: word.word,
          partOfSpeech: word.partOfSpeech,
          thaiTranslation: word.thaiTranslation,
          englishSentence: scrapbook.englishSentence,
          thaiSentence: scrapbook.thaiSentence,
          cefrLevel: 'A1',
          communicativeFunction: 'Indicative',
          languageVariant: 'US',
          imageUrl: scrapbook.imagePath,
          topic: 'other',
          createdAt: scrapbook.date,
        );

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => VocabularyDetailBottomSheet(
        vocabulary: targetVocab,
        dictionaryService: DictionaryService(),
        allVocabularies: allVocabularies,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _buildHeader(context),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                _SectionTitle(title: 'Photos', count: photoScrapbooks.length),
                const SizedBox(height: 14),
                _PhotoStrip(
                  scrapbooks: photoScrapbooks,
                  onTap: (entry) => _openEditor(context, entry),
                ),
                const SizedBox(height: 28),
                const _SectionTitle(title: 'Vocab'),
                const SizedBox(height: 14),
                _buildVocabulary(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(scrapbook.date),
                  style: GoogleFonts.lexend(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                if (scrapbooks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '${scrapbooks.length} ${scrapbooks.length == 1 ? 'memory' : 'memories'} saved on this day',
                      style: GoogleFonts.lexend(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _buildHeaderEmojis(context),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, size: 24),
            color: const Color(0xFF4B5563),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderEmojis(BuildContext context) {
    final entries = photoScrapbooks.isEmpty ? [scrapbook] : photoScrapbooks;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 132),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: entries.map((entry) {
            return Semantics(
              button: true,
              label: 'Edit scrapbook for this emoji',
              child: InkResponse(
                onTap: () => _openEditor(context, entry),
                radius: 22,
                child: SizedBox(
                  width: DesignTokens.touchTarget,
                  height: DesignTokens.touchTarget,
                  child: Center(
                    child: Text(
                      entry.selectedEmoji,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildVocabulary(BuildContext context) {
    if (vocabulary.isEmpty) {
      return Text(
        'No vocabulary saved yet',
        style: GoogleFonts.lexend(
          fontSize: 13,
          color: const Color(0xFF6B7280),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: vocabulary.map((word) {
        return Semantics(
          button: true,
          label: '${word.word}, ${word.thaiTranslation}',
          child: Material(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _showWordDetail(context, word),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                constraints: const BoxConstraints(minWidth: 96),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(
                  word.word,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lexend(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.lexend(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1F2937),
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEDE9FE)),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.lexend(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF7C3AED),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({
    required this.scrapbooks,
    required this.onTap,
  });

  final List<ScrapbookModel> scrapbooks;
  final ValueChanged<ScrapbookModel> onTap;

  @override
  Widget build(BuildContext context) {
    if (scrapbooks.isEmpty) {
      return Container(
        height: 112,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F4F6),
          borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        ),
        child: const Icon(Icons.photo_outlined, color: Color(0xFF77717D)),
      );
    }

    return SizedBox(
      height: ScrapbookPolaroid.listExtent,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: scrapbooks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final entry = scrapbooks[index];
          return Transform.rotate(
            angle: index.isEven ? -0.025 : 0.025,
            child: ScrapbookPolaroid(
              imagePath: entry.imagePath,
              backgroundColor: Color(entry.backgroundColor),
              semanticLabel: 'Open this photo in scrapbook editor',
              onTap: () => onTap(entry),
            ),
          );
        },
      ),
    );
  }
}
