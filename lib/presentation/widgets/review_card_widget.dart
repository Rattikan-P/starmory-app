import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/word_card_model.dart';
import '../../data/services/tts_service.dart';

/// Review Card Widget with Active Recall, Realistic Card Deck & Interactive Rating Stamps
/// - Physical Deck: natural tilt angles, starmory card-back patterns, smooth spring deck-pop
/// - Interactive Stamps: Live swipe stamps & punchy pop-up badge on rating selection
class ReviewCardWidget extends StatefulWidget {
  final WordCardModel card;
  final VoidCallback onForgot;
  final VoidCallback onKnow;
  final bool canUndo;
  final VoidCallback onUndo;
  final String currentLanguageVariant;
  final int remainingCount;

  const ReviewCardWidget({
    super.key,
    required this.card,
    required this.onForgot,
    required this.onKnow,
    this.canUndo = false,
    required this.onUndo,
    required this.currentLanguageVariant,
    this.remainingCount = 0,
  });

  @override
  State<ReviewCardWidget> createState() => _ReviewCardWidgetState();
}

class _ReviewCardWidgetState extends State<ReviewCardWidget>
    with TickerProviderStateMixin {
  bool _isRevealed = false;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  // Deck rise animation (when moving to next card)
  late AnimationController _deckRiseController;
  late Animation<double> _deckRiseAnimation;

  // Stamp feedback pop animation (when user rates or finishes swiping)
  bool? _feedbackRemembered;
  bool _isProcessingSwipe = false;
  late AnimationController _stampFeedbackController;
  late Animation<double> _stampFeedbackAnimation;

  // Swipe fly-out animation
  late AnimationController _swipeFlyOutController;

  // Swipe drag state
  double _dragOffsetX = 0;
  double _dragStartX = 0;

  // TTS state
  final TTSService _ttsService = TTSService();
  bool _isPlaying = false;
  StreamSubscription? _ttsCompletionSubscription;
  StreamSubscription? _ttsErrorSubscription;

  @override
  void initState() {
    super.initState();
    _ttsService.initialize();

    _ttsCompletionSubscription = _ttsService.onComplete.listen((_) {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    });

    _ttsErrorSubscription = _ttsService.onError.listen((_) {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    });

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _deckRiseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _deckRiseAnimation = CurvedAnimation(
      parent: _deckRiseController,
      curve: Curves.easeOutBack,
    );
    _deckRiseController.forward();

    _stampFeedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _stampFeedbackAnimation = CurvedAnimation(
      parent: _stampFeedbackController,
      curve: Curves.easeOutBack,
    );

    _swipeFlyOutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void didUpdateWidget(covariant ReviewCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id) {
      _ttsService.stop();
      _isPlaying = false;
      _isRevealed = false;
      _dragOffsetX = 0;
      _isProcessingSwipe = false;
      _feedbackRemembered = null;
      _stampFeedbackController.reset();
      _swipeFlyOutController.reset();
      _flipController.reset();
      _deckRiseController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _ttsCompletionSubscription?.cancel();
    _ttsErrorSubscription?.cancel();
    _ttsService.stop();
    _flipController.dispose();
    _deckRiseController.dispose();
    _stampFeedbackController.dispose();
    _swipeFlyOutController.dispose();
    super.dispose();
  }

  Future<void> _togglePronunciation() async {
    final vocab = widget.card.vocabulary;
    if (vocab == null) return;

    if (_isPlaying) {
      await _ttsService.stop();
      setState(() => _isPlaying = false);
    } else {
      HapticFeedback.lightImpact();
      setState(() => _isPlaying = true);

      try {
        final language =
            TTSService.getLanguageCode(widget.card.vocabulary?.languageVariant);

        final estimatedDuration = _ttsService.speak(
          vocab.word,
          language: language,
        );

        Future.delayed(estimatedDuration, () {
          if (mounted && _isPlaying) {
            setState(() => _isPlaying = false);
          }
        });
      } catch (e) {
        debugPrint('TTS Error: $e');
        setState(() => _isPlaying = false);
      }
    }
  }

  void _flip() {
    if (_isRevealed || _isProcessingSwipe) return;
    HapticFeedback.lightImpact();
    _flipController.forward().then((_) {
      if (mounted) {
        setState(() {
          _isRevealed = true;
        });
      }
    });
  }

  /// Handle Rating via Button Tap (shows the stamp pop feedback in place)
  void _handleButtonTap(bool remembered) {
    if (_isProcessingSwipe) return;
    _isProcessingSwipe = true;

    HapticFeedback.mediumImpact();
    setState(() {
      _feedbackRemembered = remembered;
    });

    _stampFeedbackController.forward(from: 0.0).then((_) {
      Future.delayed(const Duration(milliseconds: 160), () {
        if (mounted) {
          if (remembered) {
            widget.onKnow();
          } else {
            widget.onForgot();
          }
          _isProcessingSwipe = false;
          _feedbackRemembered = null;
        }
      });
    });
  }

  /// Handle Rating via Card Swipe Gesture (animates the card smoothly off screen)
  void _handleSwipeGesture(bool remembered, double targetX) {
    if (_isProcessingSwipe) return;
    _isProcessingSwipe = true;
    HapticFeedback.mediumImpact();

    setState(() {
      _feedbackRemembered = remembered;
    });
    _stampFeedbackController.forward(from: 0.0);

    final startX = _dragOffsetX;
    final animation = Tween<double>(begin: startX, end: targetX).animate(
      CurvedAnimation(
        parent: _swipeFlyOutController,
        curve: Curves.easeOutCubic,
      ),
    );

    void listener() {
      if (mounted) {
        setState(() {
          _dragOffsetX = animation.value;
        });
      }
    }

    animation.addListener(listener);

    _swipeFlyOutController.forward(from: 0.0).then((_) {
      animation.removeListener(listener);
      if (mounted) {
        if (remembered) {
          widget.onKnow();
        } else {
          widget.onForgot();
        }
        _isProcessingSwipe = false;
        _feedbackRemembered = null;
      }
    });
  }

  bool _isLocalPath(String path) {
    return path.startsWith('/') || path.startsWith('file://');
  }

  Widget _buildImage(String imageUrl, {BoxFit? fit}) {
    if (_isLocalPath(imageUrl)) {
      final localPath =
          imageUrl.startsWith('file://') ? imageUrl.substring(7) : imageUrl;
      return Image.file(
        File(localPath),
        fit: fit ?? BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: const Color(0xFF2D264B),
            child: const Center(
              child: Icon(Icons.image_not_supported_rounded,
                  color: Colors.white54, size: 48),
            ),
          );
        },
      );
    } else {
      return Image.network(
        imageUrl,
        fit: fit ?? BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: const Color(0xFF2D264B),
            child: const Center(
              child: Icon(Icons.image_not_supported_rounded,
                  color: Colors.white54, size: 48),
            ),
          );
        },
      );
    }
  }

  Widget _buildSpeakerButton() {
    return GestureDetector(
      onTap: _togglePronunciation,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            _isPlaying ? Icons.volume_up_rounded : Icons.volume_up_outlined,
            color: const Color(0xFF221F33),
            size: 22,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vocab = widget.card.vocabulary;
    if (vocab == null) {
      return const Center(child: Text('Card data not available'));
    }

    final dragProgress = (_dragOffsetX.abs() / 180).clamp(0.0, 1.0);

    return Column(
      children: [
        // Top Floating Swipe Text Indicator (Appears when dragging/swiping)
        SizedBox(
          height: 28,
          child: _buildSwipeTextIndicator(),
        ),

        const SizedBox(height: 4),

        // Main Card with Deck Stacking, Spring Rise & Overlapping Stamp
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 356,
                  maxHeight: 525,
                ),
                child: AspectRatio(
                  aspectRatio: 3 / 4.28,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Layer 2: Deepest card in deck (if 2+ cards remaining)
                      if (widget.remainingCount >= 2)
                        _buildDeckCardLayer(
                          scale: 0.88 + (0.06 * dragProgress),
                          translateY: 16.0 - (7.0 * dragProgress),
                          rotateAngle: -0.038 * (1.0 - dragProgress),
                          borderColor: const Color(0xFFDDD5FA),
                          gradientColors: const [
                            Color(0xFFF4EEFF),
                            Color(0xFFE9E1FC)
                          ],
                          shadowOpacity: 0.06,
                        ),

                      // Layer 1: Directly behind active card (if 1+ card remaining)
                      if (widget.remainingCount >= 1)
                        _buildDeckCardLayer(
                          scale: 0.94 + (0.06 * dragProgress),
                          translateY: 9.0 - (9.0 * dragProgress),
                          rotateAngle: 0.028 * (1.0 - dragProgress),
                          borderColor: const Color(0xFFE2DBFD),
                          gradientColors: const [
                            Color(0xFFFBF8FF),
                            Color(0xFFF0EAFF)
                          ],
                          shadowOpacity: 0.10,
                        ),

                      // Top Active Card with smooth Rise Animation
                      AnimatedBuilder(
                        animation: _deckRiseAnimation,
                        builder: (context, child) {
                          final riseScale =
                              0.94 + (0.06 * _deckRiseAnimation.value);
                          final riseTranslateY =
                              8.0 * (1.0 - _deckRiseAnimation.value);

                          return Transform(
                            alignment: Alignment.center,
                            // ignore: deprecated_member_use
                            transform: Matrix4.identity()
                              // ignore: deprecated_member_use
                              ..translate(0.0, riseTranslateY, 0.0)
                              // ignore: deprecated_member_use
                              ..scale(riseScale, riseScale, 1.0),
                            child: child,
                          );
                        },
                        child: _buildCard(context, vocab),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Bottom Controls Area: Rating Buttons when revealed, or Undo Button when not revealed
        Transform.translate(
          offset: const Offset(0, -8),
          child: SizedBox(
            height: 90,
            child: _isRevealed
                ? _buildRatingButtons(context)
                : (widget.canUndo ? _buildUndoButton() : const SizedBox.shrink()),
          ),
        ),

        const SizedBox(height: 10),
      ],
    );
  }

  /// Builds a realistic physical card back layer in the stack
  Widget _buildDeckCardLayer({
    required double scale,
    required double translateY,
    required double rotateAngle,
    required Color borderColor,
    required List<Color> gradientColors,
    required double shadowOpacity,
  }) {
    return Positioned.fill(
      child: Transform(
        alignment: Alignment.center,
        // ignore: deprecated_member_use
        transform: Matrix4.identity()
          // ignore: deprecated_member_use
          ..translate(0.0, translateY, 0.0)
          ..rotateZ(rotateAngle)
          // ignore: deprecated_member_use
          ..scale(scale, scale, 1.0),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C5CFC).withValues(alpha: shadowOpacity),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Opacity(
              opacity: 0.20,
              child: Icon(
                Icons.star_rounded,
                color: Color(0xFF8652FF),
                size: 40,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUndoButton() {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onUndo();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2DBFD), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C5CFC).withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.undo_rounded,
                  color: Color(0xFF6D5CE7),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Undo last card',
                  style: GoogleFonts.lexend(
                    color: const Color(0xFF5C4EB6),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, dynamic vocab) {
    return GestureDetector(
      onTap: _isRevealed ? null : _flip,
      onHorizontalDragStart: (_isRevealed && !_isProcessingSwipe)
          ? (details) {
              setState(() {
                _dragStartX = details.globalPosition.dx;
                _dragOffsetX = 0;
              });
            }
          : null,
      onHorizontalDragUpdate: (_isRevealed && !_isProcessingSwipe)
          ? (details) {
              setState(() {
                _dragOffsetX = details.globalPosition.dx - _dragStartX;
              });
            }
          : null,
      onHorizontalDragEnd: (_isRevealed && !_isProcessingSwipe)
          ? (details) {
              if (details.primaryVelocity == null) return;
              final velocity = details.primaryVelocity!;
              final dragOffset = _dragOffsetX;

              if (dragOffset.abs() > 80 || velocity.abs() > 400) {
                final remembered =
                    dragOffset > 0 || (dragOffset == 0 && velocity > 0);
                final screenWidth = MediaQuery.of(context).size.width;
                final targetX =
                    remembered ? (screenWidth + 250) : -(screenWidth + 250);
                _handleSwipeGesture(remembered, targetX);
              } else {
                setState(() {
                  _dragOffsetX = 0;
                });
              }
            }
          : null,
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final showBack = _flipAnimation.value > 0.5;
          final dragRotation = _dragOffsetX * 0.002;
          final dragScale = 1 - (_dragOffsetX.abs() / 1000);
          final clampedScale = dragScale.clamp(0.85, 1.0);

          return Transform(
            alignment: Alignment.center,
            // ignore: deprecated_member_use
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(_flipAnimation.value * 3.14159)
              // ignore: deprecated_member_use
              ..translate(-_dragOffsetX, 0.0, 0.0)
              ..rotateZ(-dragRotation)
              // ignore: deprecated_member_use
              ..scale(clampedScale, clampedScale, 1.0),
            child: showBack
                ? _buildBackSide(context, vocab)
                : _buildFrontSide(context, vocab),
          );
        },
      ),
    );
  }

  // Front Side: Word + Blurred Image + "Tap to reveal"
  Widget _buildFrontSide(BuildContext context, dynamic vocab) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Blurred background image
            if (vocab.imageUrl.isNotEmpty)
              Stack(
                fit: StackFit.expand,
                children: [
                  _buildImage(vocab.imageUrl, fit: BoxFit.cover),
                  // Gaussian Blur
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(color: const Color(0xFF221F33)),

            // Word in center + Tap to reveal hint
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    vocab.word,
                    style: GoogleFonts.lexend(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          offset: Offset(0, 3),
                          blurRadius: 10,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.touch_app_rounded,
                        color: Colors.white70,
                        size: 17,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Tap to reveal',
                        style: GoogleFonts.lexend(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Speaker button (inside card, top-right corner)
            Positioned(
              top: 16,
              right: 16,
              child: _buildSpeakerButton(),
            ),
          ],
        ),
      ),
    );
  }

  // Back Side: Full Clear Image + Bottom Scrim with meaning & sentence + Swipe hints + Overlapping Star Stamp
  Widget _buildBackSide(BuildContext context, dynamic vocab) {
    return Transform.flip(
      flipX: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Full clear image
                  if (vocab.imageUrl.isNotEmpty)
                    Positioned.fill(
                      child: _buildImage(vocab.imageUrl, fit: BoxFit.cover),
                    )
                  else
                    Container(color: const Color(0xFF221F33)),

                  // Bottom Gradient for readability
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 320,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45),
                            Colors.black.withValues(alpha: 0.75),
                            Colors.black.withValues(alpha: 0.90),
                          ],
                          stops: const [0.0, 0.35, 0.7, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Content section at bottom
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Word
                          Text(
                            vocab.word,
                            style: GoogleFonts.lexend(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // "means" label
                          Text(
                            'means',
                            style: GoogleFonts.lexend(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.70),
                            ),
                          ),
                          const SizedBox(height: 2),

                          // Meaning
                          Text(
                            vocab.thaiTranslation,
                            style: GoogleFonts.lexend(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // "example" label & sentence
                          if (vocab.englishSentence.isNotEmpty) ...[
                            Text(
                              'example',
                              style: GoogleFonts.lexend(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.70),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '"${vocab.englishSentence}"',
                                style: GoogleFonts.lexend(
                                  fontSize: 11.5,
                                  color: Colors.white.withValues(alpha: 0.95),
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Left & Right Swipe Hints matching mockup
                  Positioned(
                    left: 14,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Opacity(
                        opacity: 0.45,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_back_rounded,
                                color: Colors.white, size: 20),
                            const SizedBox(height: 2),
                            Text(
                              'Not yet',
                              style: GoogleFonts.lexend(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    right: 14,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Opacity(
                        opacity: 0.45,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_forward_rounded,
                                color: Colors.white, size: 20),
                            const SizedBox(height: 2),
                            Text(
                              'Got it',
                              style: GoogleFonts.lexend(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Speaker button (inside card, top-right corner)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: _buildSpeakerButton(),
                  ),
                ],
              ),
            ),
          ),

          // Star Stamp pinned overlapping the top edge of the card (on Button Tap!)
          if (_feedbackRemembered != null && _dragOffsetX == 0)
            Positioned(
              top: -28,
              left: _feedbackRemembered == false ? 12 : null,
              right: _feedbackRemembered == true ? 12 : null,
              child: AnimatedBuilder(
                animation: _stampFeedbackAnimation,
                builder: (context, child) => _buildStarStampBadge(),
              ),
            ),
        ],
      ),
    );
  }

  /// Star-shaped Stamp Badge overlapping the top edge of the card (Shown on Button Tap)
  Widget _buildStarStampBadge() {
    if (_feedbackRemembered == null) {
      return const SizedBox.shrink();
    }

    final bool isGotIt = _feedbackRemembered == true;
    final double scale = 0.80 + (0.22 * _stampFeedbackAnimation.value);
    final rotateAngle = isGotIt ? 0.18 : -0.18; // ~ +10 deg on right, -10 deg on left

    return Transform.rotate(
      angle: rotateAngle,
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: _stampFeedbackAnimation.value.clamp(0.0, 1.0),
          child: SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(88, 88),
                  painter: _StarStampPainter(
                    isGotIt: isGotIt,
                    shadowColor: (isGotIt
                            ? const Color(0xFF1D68FE)
                            : const Color(0xFFFA2C68))
                        .withValues(alpha: 0.45),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 44),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isGotIt
                              ? Icons.star_rounded
                              : Icons.local_florist_rounded,
                          color: Colors.white,
                          size: isGotIt ? 20 : 17,
                        ),
                        const SizedBox(height: 1),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isGotIt ? 'GOT IT' : 'NOT YET',
                            style: GoogleFonts.lexend(
                              fontSize: 9.0,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
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

  /// Floating text indicator shown above the card during swipe/drag
  Widget _buildSwipeTextIndicator() {
    final isDragging =
        _isRevealed && _dragOffsetX.abs() > 20 && _feedbackRemembered == null;
    final isSwipeFlyOut = _feedbackRemembered != null && _dragOffsetX != 0;

    if (!isDragging && !isSwipeFlyOut) {
      return const SizedBox.shrink();
    }

    final bool isGotIt =
        isSwipeFlyOut ? (_feedbackRemembered == true) : (_dragOffsetX > 0);

    final double opacity = isSwipeFlyOut
        ? 1.0
        : ((_dragOffsetX.abs() - 20) / 50).clamp(0.0, 1.0);

    return Align(
      alignment: isGotIt ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Opacity(
          opacity: opacity,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: isGotIt
                  ? const Color(0xFFEFF6FF)
                  : const Color(0xFFFDF2F8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isGotIt
                    ? const Color(0xFF93C5FD)
                    : const Color(0xFFF9A8D4),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isGotIt
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFFFA578E))
                      .withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isGotIt
                      ? Icons.star_rounded
                      : Icons.local_florist_rounded,
                  color: isGotIt
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFDB2777),
                  size: 18,
                ),
                const SizedBox(width: 5),
                Text(
                  isGotIt ? 'Got it!' : 'Not yet',
                  style: GoogleFonts.lexend(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isGotIt
                        ? const Color(0xFF1D4ED8)
                        : const Color(0xFFBE185D),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Rating Buttons (Circular Pink 'Not yet' + Circular Blue 'Got it' matching Image 3)
  Widget _buildRatingButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Not Yet Button (Pink with flower icon)
        GestureDetector(
          onTap: () => _handleButtonTap(false),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFFA578E),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFA578E).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.local_florist_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Not yet',
                style: GoogleFonts.lexend(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF221F33),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 48),

        // Got It Button (Blue with star icon)
        GestureDetector(
          onTap: () => _handleButtonTap(true),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.star_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Got it',
                style: GoogleFonts.lexend(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF221F33),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StarStampPainter extends CustomPainter {
  final bool isGotIt;
  final Color shadowColor;

  _StarStampPainter({
    required this.isGotIt,
    required this.shadowColor,
  });

  Path _createStarPath(Size size, {double scale = 1.0}) {
    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outerRadius = (size.width / 2) * scale;
    final innerRadius = outerRadius * 0.58;
    const numPoints = 5;
    const step = pi / numPoints;

    for (int i = 0; i < 2 * numPoints; i++) {
      final r = (i % 2 == 0) ? outerRadius : innerRadius;
      final angle = i * step - (pi / 2);
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final starPath = _createStarPath(size, scale: 0.95);

    // 1. Soft Drop Shadow
    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(starPath.shift(const Offset(0, 3)), shadowPaint);

    // 2. Gradient Fill
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isGotIt
          ? const [Color(0xFF388BFF), Color(0xFF1D68FE)]
          : const [Color(0xFFFF5287), Color(0xFFFA2C68)],
    );
    final fillPaint = Paint()
      ..shader = gradient
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(starPath, fillPaint);

    // 3. Crisp White Outer Border
    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(starPath, borderPaint);

    // 4. Subtle Inner Accent Line
    final innerStarPath = _createStarPath(size, scale: 0.74);
    final innerBorderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(innerStarPath, innerBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _StarStampPainter oldDelegate) =>
      oldDelegate.isGotIt != isGotIt;
}
