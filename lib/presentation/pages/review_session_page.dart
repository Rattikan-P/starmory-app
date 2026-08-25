import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/providers.dart';
import '../widgets/review_card_widget.dart';

/// Review Session Page
/// Main review interface with flip cards, auto-advance, and cozy clean design
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
  }

  bool _canPopImmediately(ReviewState state) {
    if (_allowPop) return true;
    if (state.isLoading ||
        state.cards.isEmpty ||
        state.isComplete ||
        state.error != null) {
      return true;
    }
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFEBE6FC), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C5CFC).withValues(alpha: 0.16),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Lavender Circle with Pause Icon
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1EDFF),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.pause_rounded,
                    size: 32,
                    color: Color(0xFF7C5CFC),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                'Leave review session?',
                style: GoogleFonts.lexend(
                  fontSize: 18.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF221F33),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Auto-saved box matching mockup
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE5DCFF),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.cloud_done_rounded,
                          color: Color(0xFF22C55E),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Your progress is auto-saved',
                          style: GoogleFonts.lexend(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF22C55E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'You reviewed $reviewedCount of $totalCount cards',
                      style: GoogleFonts.lexend(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF9892A6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Primary Button: Keep reviewing (Solid purple pill)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C5CFC),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    'Keep reviewing',
                    style: GoogleFonts.lexend(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Secondary Button: Leave (Grey flat text)
              SizedBox(
                width: double.infinity,
                height: 40,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF9892A6),
                    splashFactory: NoSplash.splashFactory,
                  ),
                  child: Text(
                    'Leave',
                    style: GoogleFonts.lexend(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF9892A6),
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

    // Load session with topic filter and batch size on first build only
    if (!_hasTriedLoading && !reviewState.isLoading) {
      _hasTriedLoading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(reviewStateProvider.notifier).loadSession(
              topicFilter: _currentTopicFilter,
              batchSize: _batchSize,
            );
      });
    }

    final currentIndex =
        (reviewState.currentIndex + 1).clamp(1, reviewState.sessionCount);
    final totalCount = reviewState.sessionCount;

    return PopScope(
      canPop: _canPopImmediately(reviewState),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop =
            await _showExitConfirmationDialog(context, reviewState);
        if (shouldPop == true && context.mounted) {
          setState(() {
            _allowPop = true;
          });
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Top Header Bar matching the mockup
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    // Circular back button
                    InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => _handleBack(context, reviewState),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF3F4F6),
                          border: Border.all(
                              color: const Color(0xFFE5E7EB), width: 1.0),
                        ),
                        child: const Icon(
                          Icons.chevron_left_rounded,
                          size: 26,
                          color: Color(0xFF221F33),
                        ),
                      ),
                    ),

                    // Title in center
                    Expanded(
                      child: Center(
                        child: Text(
                          'Review',
                          style: GoogleFonts.lexend(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF221F33),
                          ),
                        ),
                      ),
                    ),

                    // Progress counter pill (e.g. 1/3 or 3/3)
                    if (!reviewState.isLoading && reviewState.cards.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F0FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFFE5DCFF), width: 1.0),
                        ),
                        child: Text(
                          '$currentIndex/$totalCount',
                          style: GoogleFonts.lexend(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF7C5CFC),
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 40),
                  ],
                ),
              ),

              // Sleek Animated Progress Bar
              if (!reviewState.isLoading && reviewState.cards.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 3),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0.0,
                        end: reviewState.isComplete ? 1.0 : reviewState.progress,
                      ),
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      builder: (context, progressVal, child) {
                        return LinearProgressIndicator(
                          value: progressVal,
                          backgroundColor: const Color(0xFFEDE8FF),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF7C5CFC)),
                          minHeight: 4.5,
                        );
                      },
                    ),
                  ),
                ),

              const SizedBox(height: 6),

              // Body Content (Card or Complete state)
              Expanded(
                child: _buildBody(context, ref, reviewState),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, ReviewState state) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF7C5CFC)),
      );
    }

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
              onPressed: () =>
                  ref.read(reviewStateProvider.notifier).loadSession(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.cards.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
      return const SizedBox.shrink();
    }

    final currentCard = state.currentCard;
    if (currentCard == null || state.isComplete) {
      return _buildCompleteState(context, state);
    }

    final remainingCards =
        (state.sessionCount - (state.currentIndex + 1)).clamp(0, 999);

    return ReviewCardWidget(
      key: ValueKey(currentCard.id),
      card: currentCard,
      remainingCount: remainingCards,
      onForgot: () => _handleSwipe(ref, false),
      onKnow: () => _handleSwipe(ref, true),
      canUndo: ref.read(reviewStateProvider).canUndo,
      onUndo: () => ref.read(reviewStateProvider.notifier).undoSwipe(),
      currentLanguageVariant:
          ref.read(currentUserProvider)?.englishVariant ?? 'US',
    );
  }

  Widget _buildCompleteState(BuildContext context, ReviewState state) {
    final totalCount = state.sessionCount;
    final gotIt = state.gotItCount;
    final notYet = state.notYetCount;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Celebration Icon in soft lavender circle
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1EDFF),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.celebration_rounded,
                    color: Color(0xFF7C5CFC),
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                'Session complete',
                style: GoogleFonts.lexend(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF221F33),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),

              // Subtitle
              Text(
                'Awesome job! You have strengthened\nyour memory today',
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  color: const Color(0xFF4B5563),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // Summary Stat Card (REVIEWED | GOT IT | NOT YET)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border:
                      Border.all(color: const Color(0xFFEBE6FC), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C5CFC).withValues(alpha: 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Column 1: REVIEWED
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_stories_rounded,
                            color: Color(0xFF7C5CFC),
                            size: 20,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$totalCount',
                            style: GoogleFonts.lexend(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF221F33),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'REVIEWED',
                            style: GoogleFonts.lexend(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6B7280),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Divider 1
                    Container(
                      width: 1,
                      height: 44,
                      color: const Color(0xFFE5E7EB),
                    ),

                    // Column 2: GOT IT
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFF7C5CFC),
                            size: 22,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$gotIt',
                            style: GoogleFonts.lexend(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF221F33),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'GOT IT',
                            style: GoogleFonts.lexend(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6B7280),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Divider 2
                    Container(
                      width: 1,
                      height: 44,
                      color: const Color(0xFFE5E7EB),
                    ),

                    // Column 3: NOT YET
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_florist_rounded,
                            color: Color(0xFF7C5CFC),
                            size: 20,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$notYet',
                            style: GoogleFonts.lexend(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF221F33),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'NOT YET',
                            style: GoogleFonts.lexend(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6B7280),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Full-width Done Button
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C5CFC),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C5CFC).withValues(alpha: 0.30),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(26),
                    onTap: () => Navigator.pop(context),
                    child: Center(
                      child: Text(
                        'Done',
                        style: GoogleFonts.lexend(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
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

  void _handleSwipe(WidgetRef ref, bool remembered) {
    ref.read(reviewStateProvider.notifier).swipeCard(remembered);
  }
}
