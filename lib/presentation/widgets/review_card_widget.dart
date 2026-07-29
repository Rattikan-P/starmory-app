import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/models/word_card_model.dart';

/// Swipeable Review Card Widget
/// Displays vocabulary image with swipe gestures for review
class ReviewCardWidget extends StatefulWidget {
  final WordCardModel card;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;

  const ReviewCardWidget({
    super.key,
    required this.card,
    this.onSwipeLeft,
    this.onSwipeRight,
  });

  @override
  State<ReviewCardWidget> createState() => _ReviewCardWidgetState();
}

class _ReviewCardWidgetState extends State<ReviewCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  double _dragStartX = 0;
  double _dragOffsetX = 0;

  static const double _swipeThreshold = 100.0;
  static const double _maxRotation = 0.3;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _slideAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handlePanStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final dx = details.globalPosition.dx - _dragStartX;
    setState(() {
      _dragOffsetX = dx;
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    // Check if passed threshold
    if (_dragOffsetX > _swipeThreshold) {
      // Swiped right (recalled)
      _animateSwipe(1);
      widget.onSwipeRight?.call();
    } else if (_dragOffsetX < -_swipeThreshold) {
      // Swiped left (forgot)
      _animateSwipe(-1);
      widget.onSwipeLeft?.call();
    } else {
      // Snap back
      _animateSnapBack();
    }
  }

  void _animateSwipe(int direction) {
    _animationController.addListener(() {
      if (_animationController.isCompleted) {
        setState(() {
          _dragOffsetX = 0;
        });
        _animationController.reset();
      }
    });

    _slideAnimation = Tween<double>(
      begin: _dragOffsetX,
      end: direction * 500,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _rotationAnimation = Tween<double>(
      begin: _getRotation(_dragOffsetX),
      end: direction * _maxRotation,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();
  }

  void _animateSnapBack() {
    _slideAnimation = Tween<double>(
      begin: _dragOffsetX,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: _getRotation(_dragOffsetX),
      end: 0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward().then((_) {
      setState(() {
        _dragOffsetX = 0;
      });
      _animationController.reset();
    });
  }

  double _getRotation(double dx) {
    // Rotate based on horizontal drag
    return dx * 0.001;
  }

  @override
  Widget build(BuildContext context) {
    final vocab = widget.card.vocabulary;
    if (vocab == null) {
      return const Center(child: Text('No vocabulary data'));
    }

    return AnimatedBuilder(
      animation: Listenable.merge([
        _slideAnimation,
        _rotationAnimation,
        _scaleAnimation,
      ]),
      builder: (context, child) {
        final dx = _dragOffsetX + _slideAnimation.value;
        final rotation = _getRotation(dx) + _rotationAnimation.value;
        final scale = _scaleAnimation.value;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translate(dx)
            ..rotateZ(rotation)
            ..scale(scale),
          child: GestureDetector(
            onPanStart: _handlePanStart,
            onPanUpdate: _handlePanUpdate,
            onPanEnd: _handlePanEnd,
            child: _buildCard(context, vocab!),
          ),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, dynamic vocab) {
    return Container(
      width: double.infinity,
      height: 400,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF8b7cf6),
            const Color(0xFF7c6ff5),
            const Color(0xFF6C63FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8b7cf6).withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Background image (memory trigger)
            if (vocab.imageUrl.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  vocab.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image, size: 64),
                    );
                  },
                ),
              ),
            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.6),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            // Swipe indicators
            Positioned(
              top: 20,
              left: 20,
              child: _buildSwipeIndicator(false),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: _buildSwipeIndicator(true),
            ),
            // Center hint
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Swipe to answer',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeIndicator(bool isRight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: (isRight ? Colors.green : Colors.red).withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRight ? Icons.check : Icons.close,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 4),
          Text(
            isRight ? 'Recalled' : 'Forgot',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
