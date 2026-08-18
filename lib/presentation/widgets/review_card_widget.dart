import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/word_card_model.dart';
import '../../data/services/tts_service.dart';

/// Review Card Widget with Active Recall
/// Front: Word + Blurred Image + "Tap to reveal" → Back: Clear Image + Meaning + Sentence + Rating
class ReviewCardWidget extends StatefulWidget {
  final WordCardModel card;
  final VoidCallback onForgot;
  final VoidCallback onKnow;
  final bool canUndo;
  final VoidCallback onUndo;
  final String currentLanguageVariant; // User's current setting (US/UK)

  const ReviewCardWidget({
    super.key,
    required this.card,
    required this.onForgot,
    required this.onKnow,
    this.canUndo = false,
    required this.onUndo,
    required this.currentLanguageVariant,
  });

  @override
  State<ReviewCardWidget> createState() => _ReviewCardWidgetState();
}

class _ReviewCardWidgetState extends State<ReviewCardWidget>
    with SingleTickerProviderStateMixin {
  bool _isRevealed = false;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

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
    // Initialize TTS service
    _ttsService.initialize();

    // Listen to TTS completion
    _ttsCompletionSubscription = _ttsService.onComplete.listen((_) {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    });

    // Listen to TTS errors
    _ttsErrorSubscription = _ttsService.onError.listen((_) {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    });

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ttsCompletionSubscription?.cancel();
    _ttsErrorSubscription?.cancel();
    _ttsService.stop();
    _flipController.dispose();
    super.dispose();
  }

  /// Play or stop pronunciation
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
        // Set language based on vocab's stored variant (word origin)
        final language = TTSService.getLanguageCode(widget.card.vocabulary?.languageVariant);

        // Speak the word (returns estimated duration for fallback)
        final estimatedDuration = _ttsService.speak(
          vocab.word,
          language: language,
        );

        // Fallback: Auto-reset after estimated duration
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

  /// Check if URL is a local file path
  bool _isLocalPath(String path) {
    return path.startsWith('/') || path.startsWith('file://');
  }

  /// Build image widget from URL or local path
  Widget _buildImage(String imageUrl, {BoxFit? fit}) {
    if (_isLocalPath(imageUrl)) {
      // Remove 'file://' prefix if present
      final localPath = imageUrl.startsWith('file://')
          ? imageUrl.substring(7)
          : imageUrl;
      return Image.file(
        File(localPath),
        fit: fit ?? BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: const Color(0xFF3D3A5C),
            child: const Icon(Icons.broken_image, size: 64, color: Colors.white38),
          );
        },
      );
    } else {
      return Image.network(
        imageUrl,
        fit: fit ?? BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: const Color(0xFF3D3A5C),
            child: const Icon(Icons.broken_image, size: 64, color: Colors.white38),
          );
        },
      );
    }
  }

  /// Build speaker button widget
  Widget _buildSpeakerButton() {
    return GestureDetector(
      onTap: _togglePronunciation,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _isPlaying
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          _isPlaying ? Icons.stop : Icons.volume_up,
          color: Colors.white.withValues(alpha: 0.95),
          size: 24,
        ),
      ),
    );
  }

  void _flip() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isRevealed = true;
    });
    _flipController.forward();
  }

  void _handleSwipe(bool remembered) {
    HapticFeedback.mediumImpact();
    if (remembered) {
      widget.onKnow();
    } else {
      widget.onForgot();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vocab = widget.card.vocabulary;
    if (vocab == null) {
      return const Center(child: Text('No vocabulary data'));
    }

    return Column(
      children: [
        // Card (speaker button now inside card)
        Expanded(
          child: Center(
            child: _buildCard(context, vocab),
          ),
        ),

        // Rating buttons (only when revealed)
        if (_isRevealed) ...[
          // Undo button (if available)
          if (widget.canUndo)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onUndo();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.undo,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Undo',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          _buildRatingButtons(context),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCard(BuildContext context, dynamic vocab) {
    return GestureDetector(
      // Tap to flip (only when not revealed)
      onTap: _isRevealed ? null : _flip,
      // Swipe drag start
      onHorizontalDragStart: _isRevealed
          ? (details) {
              setState(() {
                _dragStartX = details.globalPosition.dx;
                _dragOffsetX = 0;
              });
            }
          : null,
      // Swipe drag update
      onHorizontalDragUpdate: _isRevealed
          ? (details) {
              setState(() {
                _dragOffsetX = details.globalPosition.dx - _dragStartX;
              });
            }
          : null,
      // Swipe drag end
      onHorizontalDragEnd: _isRevealed
          ? (details) {
              if (details.primaryVelocity == null) return;
              final velocity = details.primaryVelocity!;

              // Check threshold or velocity
              if (_dragOffsetX.abs() > 100 || velocity.abs() > 500) {
                // Swipe complete
                setState(() {
                  _dragOffsetX = 0;
                });
                // Swipe right = Know, Swipe left = Forgot
                if (_dragOffsetX > 0 || velocity > 0) {
                  _handleSwipe(true);
                } else {
                  _handleSwipe(false);
                }
              } else {
                // Snap back
                setState(() {
                  _dragOffsetX = 0;
                });
              }
            }
          : null,
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          // Calculate which side to show based on flip progress
          final showBack = _flipAnimation.value > 0.5;

          // Calculate drag transform
          final dragRotation = _dragOffsetX * 0.002;
          final dragScale = 1 - (_dragOffsetX.abs() / 1000);
          final clampedScale = dragScale.clamp(0.85, 1.0);

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // Perspective
              ..rotateY(_flipAnimation.value * 3.14159) // Flip animation
              ..translate(-_dragOffsetX, 0.0, 0.0) // Drag movement (inverted for flipX)
              ..rotateZ(-dragRotation) // Drag rotation (inverted for flipX)
              ..scale(clampedScale, clampedScale, 1.0), // Drag scale
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
      height: 520,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
                  // Blur effect
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(),
                    ),
                  ),
                ],
              ),

            // Dark overlay for better text visibility
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),

            // Word in center + Tap to reveal hint
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Word
                  Text(
                    vocab.word,
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 3),
                          blurRadius: 12,
                          color: Colors.black87,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Tap to reveal hint
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.touch_app,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tap to reveal',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Border
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(28),
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
    );
  }

  // Back Side: Full Image + Black gradient at bottom + Readable text
  Widget _buildBackSide(BuildContext context, dynamic vocab) {
    return Transform.flip(
      flipX: true, // Flip content back since card is rotated 180
      child: Container(
        width: double.infinity,
        height: 520,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Full clear image (takes entire card)
              if (vocab.imageUrl.isNotEmpty)
                Positioned.fill(
                  child: _buildImage(vocab.imageUrl, fit: BoxFit.cover),
                ),

              // Black gradient at bottom for text readability
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 280,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.5),
                        Colors.black.withValues(alpha: 0.7),
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      stops: const [0.0, 0.2, 0.4, 0.7, 1.0],
                    ),
                  ),
                ),
              ),

              // Content section at bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Word
                      Text(
                        vocab.word,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.1,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 2),
                              blurRadius: 8,
                              color: Colors.black,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // "means" label
                      Text(
                        'means',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Meaning (prominent, readable)
                      Text(
                        vocab.thaiTranslation,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.3,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 6,
                              color: Colors.black,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Example sentence
                      if (vocab.englishSentence.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            vocab.englishSentence,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.9),
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 4,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Swipe hints overlay
              Positioned.fill(
                child: Stack(
                  children: [
                    // Left swipe hint
                    Positioned(
                      left: 20,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Opacity(
                          opacity: 0.3,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_back, color: Colors.white, size: 28),
                              SizedBox(height: 4),
                              Text('Not yet', style: TextStyle(color: Colors.white, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Right swipe hint
                    Positioned(
                      right: 20,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Opacity(
                          opacity: 0.3,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_forward, color: Colors.white, size: 28),
                              SizedBox(height: 4),
                              Text('Got it!', style: TextStyle(color: Colors.white, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Border
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(28),
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
    );
  }

  Widget _buildRatingButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _handleSwipe(false),
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B9D), Color(0xFFE84393)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B9D).withValues(alpha: 0.5),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.spa_outlined,
                      color: Colors.white,
                      size: 24,
                      shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Not yet',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: () => _handleSwipe(true),
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF74B9FF), Color(0xFF0984E3)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF74B9FF).withValues(alpha: 0.5),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.star_outlined,
                      color: Colors.white,
                      size: 24,
                      shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Got it!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
