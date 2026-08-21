import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../widgets/review_card_widget.dart';
import '../widgets/galaxy_screen_background.dart';

/// Review Session Page
/// Main review interface with flip cards and auto-advance
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
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _currentTopicFilter = widget.topicFilter;
    _batchSize = widget.batchSize;
    print('🔍 ReviewSessionPage initState: topic=$_currentTopicFilter, batch=$_batchSize');
  }

  bool _canPopImmediately(ReviewState state) {
    if (_allowPop) return true;
    if (state.isLoading || state.cards.isEmpty || state.isComplete || state.error != null) {
      return true;
    }
    // If the user hasn't answered any card yet, allow immediate exit
    if (state.currentIndex == 0) {
      return true;
    }
    return false;
  }

  Future<bool?> _showExitConfirmationDialog(
    BuildContext context,
    ReviewState state,
  ) {
    final reviewedCount = state.currentIndex;
    final totalCount = state.sessionCount;

    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFEFF), Color(0xFFF2EEFF)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFD8D0FF)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5C4EB6).withValues(alpha: 0.18),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Header
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEAFF),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B7CF6).withValues(alpha: 0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.pause_circle_outline_rounded,
                  size: 36,
                  color: Color(0xFF6D5CE7),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              const Text(
                'Leave review session?',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2F2855),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Auto-saved Status Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE4DFFF)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.cloud_done_rounded,
                          color: Color(0xFF2D8B5A),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Your progress is auto-saved',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2D8B5A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You reviewed $reviewedCount of $totalCount ${totalCount == 1 ? 'card' : 'cards'}.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF655D80),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B7CF6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Keep reviewing',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF7A7299),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Leave',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleBack(BuildContext context, ReviewState state) async {
    if (_canPopImmediately(state)) {
      Navigator.of(context).pop();
    } else {
      final shouldPop = await _showExitConfirmationDialog(context, state);
      if (shouldPop == true && context.mounted) {
        setState(() {
          _allowPop = true;
        });
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewState = ref.watch(reviewStateProvider);

    print('🔍 ReviewSessionPage build: _currentTopicFilter=$_currentTopicFilter, _hasTriedLoading=$_hasTriedLoading, cards=${reviewState.cards.length}');

    // Load session with topic filter and batch size on first build only
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

    return PopScope(
      canPop: _canPopImmediately(reviewState),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showExitConfirmationDialog(context, reviewState);
        if (shouldPop == true && context.mounted) {
          setState(() {
            _allowPop = true;
          });
          Navigator.of(context).pop();
        }
      },
      child: GalaxyScreenBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => _handleBack(context, reviewState),
            ),
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
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_done, color: Colors.green, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Auto-saved',
                        style: TextStyle(
                          color: Color(0xFF2D8B5A),
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
                      '${(reviewState.currentIndex + 1).clamp(1, reviewState.sessionCount)} / ${reviewState.sessionCount}',
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

    // Show card or complete state
    final currentCard = state.currentCard;
    if (currentCard == null) {
      return _buildCompleteState(context, state);
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
        // Card with unique key for smooth auto-advance
        Expanded(
          child: Center(
            child: ReviewCardWidget(
              key: ValueKey(currentCard.id),
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

  Widget _buildCompleteState(BuildContext context, ReviewState state) {
    final count = state.cards.length;

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
                  'Session Complete! 🎉',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2F2855),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Awesome job! You have strengthened your memory today.',
                  style: TextStyle(fontSize: 15, color: Color(0xFF655D80)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Session Summary Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFFEFF), Color(0xFFF2EEFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFD8D0FF)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5C4EB6).withValues(alpha: 0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAE6FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.auto_stories_rounded,
                          color: Color(0xFF6D5CE7),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$count ${count == 1 ? 'word' : 'words'} reviewed',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2F2855),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Saved to your spaced repetition',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF655D80),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
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
