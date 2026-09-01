import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/design_tokens.dart';
import '../../data/models/scrapbook_model.dart';
import '../pages/edit_scrapbook_screen.dart';
import '../providers/navigation_provider.dart';
import 'scrapbook_polaroid.dart';

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

  void _goToReview(BuildContext sheetContext) {
    Navigator.of(sheetContext).pop();
    ProviderScope.containerOf(parentContext)
        .read(navigationProvider.notifier)
        .goReview();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildHeader(context),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE9E7EC)),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(
                26,
                24,
                26,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                _SectionTitle(title: 'Photos', count: photoScrapbooks.length),
                const SizedBox(height: 14),
                _PhotoStrip(
                  scrapbooks: photoScrapbooks,
                  onTap: (entry) => _openEditor(context, entry),
                ),
                const SizedBox(height: 30),
                const _SectionTitle(title: 'Vocab · tap to review'),
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
      padding: const EdgeInsets.fromLTRB(26, 18, 18, 16),
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
                    color: const Color(0xFF2D2B30),
                  ),
                ),
                if (scrapbooks.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '${scrapbooks.length} memories saved on this day',
                      style: GoogleFonts.lexend(
                        fontSize: 12,
                        color: DesignTokens.textSecondary,
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
            icon: const Icon(Icons.close_rounded, size: 28),
            color: const Color(0xFF27252A),
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
          color: DesignTokens.textSecondary,
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: vocabulary.map((word) {
        return Semantics(
          button: true,
          label: '${word.word}, ${word.thaiTranslation}',
          child: Material(
            color: const Color(0xFFF4F3F5),
            borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
            child: InkWell(
              onTap: () => _goToReview(context),
              borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 96),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(
                    word.word,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lexend(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF302D33),
                    ),
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
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF302D33),
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 7),
          Text(
            '$count',
            style: GoogleFonts.lexend(
              fontSize: 12,
              color: DesignTokens.textSecondary,
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
