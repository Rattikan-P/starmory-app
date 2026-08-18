import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../widgets/review_card_widget.dart';
import '../widgets/galaxy_screen_background.dart';

/// Review Session Page
/// Main review interface with flip cards and feedback
class ReviewSessionPage extends ConsumerStatefulWidget {
  final String? topicFilter;
  final int batchSize;

  const ReviewSessionPage({
    super.key, 
    this.topicFilter,
    this.batchSize = 5,
  });

  @override
  ConsumerState<ReviewSessionPage> createState() => _ReviewSessionPageState();
}

class _ReviewSessionPageState extends ConsumerState<ReviewSessionPage> {
  bool _hasTriedLoading = false;
  String? _currentTopicFilter;
  late int _batchSize;

  @override
  void initState() {
    super.initState();
    _currentTopicFilter = widget.topicFilter;
    _batchSize = widget.batchSize;
    print('🔍 ReviewSessionPage initState: topic=$_currentTopicFilter, batch=$_batchSize');
  }

  @override
  Widget build(BuildContext context) {
    final reviewState = ref.watch(reviewStateProvider);

    print('🔍 ReviewSessionPage build: _currentTopicFilter=$_currentTopicFilter, _hasTriedLoading=$_hasTriedLoading, cards=${reviewState.cards.length}');

    // Load session with topic filter and batch size on first build only
    // Note: We check !_hasTriedLoading to avoid multiple loads, but we don't check cards.isEmpty
    // because ReviewTab might have loaded cards already (with different filter/batchSize)
    if (!_hasTriedLoading && !reviewState.isLoading) {
      _hasTriedLoading = true;
      print('🔍 ReviewSessionPage: First load, calling loadSession with topicFilter=$_currentTopicFilter, batchSize=$_batchSize');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(reviewStateProvider.notifier).loadSession(
          topicFilter: _currentTopicFilter,
          batchSize: _batchSize,
        );
      });
    }

    return GalaxyScreenBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Review session',
            style: TextStyle(
              color: Color(0xFF2F2855),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Color(0xFF2F2855)),
          actions: [
            // Auto-saved hint
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBCE8D1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_done, color: Colors.green, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'Auto-saved',
                      style: TextStyle(
                        color: const Color(0xFF2D8B5A),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!reviewState.isLoading &&
                reviewState.cards.isNotEmpty &&
                !reviewState.isComplete)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.70),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD9D2FF)),
                  ),
                  child: Text(
                    '${reviewState.currentIndex + 1} / ${reviewState.sessionCount}',
                    style: const TextStyle(
                      color: Color(0xFF5C4EB6),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: _buildBody(context, ref, reviewState),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, ReviewState state) {
    // Loading state
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error state
    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error: ${state.error}',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(reviewStateProvider.notifier).loadSession(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Empty state (no cards)
    if (state.cards.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
      return const SizedBox.shrink();
    }

    // Show feedback
    if (state.showFeedback && state.lastRating != null) {
      return _buildFeedback(context, ref, state);
    }

    // Show card
    final currentCard = state.currentCard;
    if (currentCard == null) {
      return _buildCompleteState(context);
    }

    return _buildCardSwipe(context, ref, currentCard);
  }

  Widget _buildCardSwipe(
    BuildContext context,
    WidgetRef ref,
    dynamic currentCard,
  ) {
    return Column(
      children: [
        // Progress indicator
        LinearProgressIndicator(
          value: ref.read(reviewStateProvider).progress,
          backgroundColor: Colors.grey.withValues(alpha: 0.3),
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8b7cf6)),
        ),
        const SizedBox(height: 8),
        // Card
        Expanded(
          child: Center(
            child: ReviewCardWidget(
              card: currentCard,
              onForgot: () => _handleSwipe(ref, false),
              onKnow: () => _handleSwipe(ref, true),
              canUndo: ref.read(reviewStateProvider).canUndo,
              onUndo: () => ref.read(reviewStateProvider.notifier).undoSwipe(),
              currentLanguageVariant: ref.read(currentUserProvider)?.englishVariant ?? 'US',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedback(BuildContext context, WidgetRef ref, ReviewState state) {
    final currentCard = state.cards[state.currentIndex];
    final vocab = currentCard.vocabulary;

    if (vocab == null) {
      return const Center(child: Text('No vocabulary data'));
    }

    final remembered = state.lastRating ?? false;

    final resultColor = remembered
        ? const Color(0xFF2D9C72)
        : const Color(0xFFE49A2F);
    final resultBackground = remembered
        ? const Color(0xFFE3F6EC)
        : const Color(0xFFFFF0D8);

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: resultBackground,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 5),
                    boxShadow: [
                      BoxShadow(
                        color: resultColor.withValues(alpha: 0.22),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    remembered
                        ? Icons.check_rounded
                        : Icons.auto_awesome_rounded,
                    size: 36,
                    color: resultColor,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  remembered ? 'Nice work!' : "That is okay!",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2F2855),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  remembered
                      ? 'You remembered this word.'
                      : 'Seeing it again helps it stick.',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF655D80)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFFEFF), Color(0xFFF0ECFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFD8D0FF)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF695C9E).withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        vocab.word,
                        style: const TextStyle(
                          fontSize: 32,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2F2855),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAE6FF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'MEANING',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF6354B5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        vocab.thaiTranslation,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3A3263),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (vocab.englishSentence.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            vocab.englishSentence,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              color: Color(0xFF655D80),
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () => ref.read(reviewStateProvider.notifier).nextCard(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B7CF6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text(
                      'Next card',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (state.canUndo) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => ref.read(reviewStateProvider.notifier).undoSwipe(),
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    label: const Text('Change my rating'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF655D80),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteState(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFE5A5), Color(0xFFFFC96B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 6),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE3A23A).withValues(alpha: 0.28),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.celebration_rounded,
                    size: 46,
                    color: Color(0xFF8E5B00),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Review complete!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2F2855),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A little practice today goes a long way.',
                  style: TextStyle(fontSize: 15, color: Color(0xFF655D80)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B7CF6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text(
                      'Done',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleSwipe(WidgetRef ref, bool remembered) {
    ref.read(reviewStateProvider.notifier).swipeCard(remembered);
  }
}
