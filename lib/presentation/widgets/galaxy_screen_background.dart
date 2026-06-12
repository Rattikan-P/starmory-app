import 'dart:math';
import 'package:flutter/material.dart';

/// Reusable galaxy screen background widget
/// Used across all pages for consistent visual design
class GalaxyScreenBackground extends StatefulWidget {
  final Widget child;
  final bool showFallingStars;
  final List<AnimationController>? starControllers;

  const GalaxyScreenBackground({
    super.key,
    required this.child,
    this.showFallingStars = false,
    this.starControllers,
  });

  @override
  State<GalaxyScreenBackground> createState() => _GalaxyScreenBackgroundState();
}

class _GalaxyScreenBackgroundState extends State<GalaxyScreenBackground> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradient background (4 colors)
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFE8F4FD), // Soft blue
                  Color(0xFFF5EEF8), // Soft purple
                  Color(0xFFFDF4E8), // Soft peach
                  Color(0xFFFDF4D8), // Soft yellow
                ],
              ),
            ),
          ),
        ),
        // Galaxy blobs (4 colored circles)
        _buildBlob(
          top: -100,
          left: -80,
          width: 350,
          height: 350,
          color: const Color(0xFFC4B5FD),
          opacity: 0.7,
        ),
        _buildBlob(
          top: 50,
          right: -100,
          width: 380,
          height: 380,
          color: const Color(0xFF93C5FD),
          opacity: 0.6,
        ),
        _buildBlob(
          bottom: 100,
          left: -60,
          width: 350,
          height: 350,
          color: const Color(0xFFF472B6),
          opacity: 0.55,
        ),
        _buildBlob(
          bottom: -80,
          right: -60,
          width: 380,
          height: 380,
          color: const Color(0xFFFCD34D),
          opacity: 0.5,
        ),
        // Static stars (40 random positions)
        ...List.generate(40, (i) {
          final r = Random(i * 42);
          final s = 1.5 + r.nextDouble() * 3.5;
          return Positioned(
            top: r.nextDouble() * MediaQuery.of(context).size.height,
            left: r.nextDouble() * MediaQuery.of(context).size.width,
            child: Opacity(
              opacity: 0.2 + r.nextDouble() * 0.6,
              child: Container(
                width: s,
                height: s,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.white54, blurRadius: 2)],
                ),
              ),
            ),
          );
        }),
        // Falling stars (optional animation)
        if (widget.showFallingStars &&
            widget.starControllers != null &&
            widget.starControllers!.length >= 3)
          ...List.generate(
            3,
            (i) => _FallingStar(
              animation: widget.starControllers![i],
              index: i,
            ),
          ),
        // Texture overlay
        Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: Opacity(
              opacity: 0.4,
              child: Image.asset(
                'assets/textures/paper.jpg',
                fit: BoxFit.cover,
                repeat: ImageRepeat.repeat,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
        // Child content
        widget.child,
      ],
    );
  }

  Widget _buildBlob({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double width,
    required double height,
    required Color color,
    required double opacity,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Falling star animation widget
class _FallingStar extends StatelessWidget {
  final Animation<double> animation;
  final int index;

  const _FallingStar({
    required this.animation,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = animation.value;

        // Calculate position (falling from top-right to bottom-left)
        final startX = size.width * (0.7 + index * 0.1);
        final startY = -50.0;
        final endX = size.width * (0.3 - index * 0.05);
        final endY = size.height + 50.0;

        final x = startX + (endX - startX) * progress;
        final y = startY + (endY - startY) * progress;

        // Calculate opacity (fade in then out)
        final fadeInEnd = 0.2;
        final fadeOutStart = 0.8;
        double opacity;
        if (progress < fadeInEnd) {
          opacity = progress / fadeInEnd;
        } else if (progress > fadeOutStart) {
          opacity = (1.0 - progress) / (1.0 - fadeOutStart);
        } else {
          opacity = 1.0;
        }

        return Positioned(
          left: x,
          top: y,
          child: Opacity(
            opacity: opacity * 0.7,
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.8),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
