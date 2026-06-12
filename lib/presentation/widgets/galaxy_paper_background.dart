import 'dart:math';
import 'package:flutter/material.dart';

/// Simple texture overlay widget - just adds texture image on top
/// Use this to add texture to existing backgrounds
class TextureOverlay extends StatelessWidget {
  final Widget child;
  final double opacity;
  final String texturePath;

  const TextureOverlay({
    super.key,
    required this.child,
    this.opacity = 0.3,
    this.texturePath = 'assets/textures/paper.jpg',
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: Opacity(
              opacity: opacity,
              child: Image.asset(
                texturePath,
                fit: BoxFit.cover,
                repeat: ImageRepeat.repeat,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Background widget combining texture image with galaxy theme
/// Uses an image texture overlay on top of galaxy gradient
class GalaxyPaperBackground extends StatefulWidget {
  final Widget child;
  final double textureOpacity;
  final String? textureImagePath; // Add your texture image path here

  const GalaxyPaperBackground({
    super.key,
    required this.child,
    this.textureOpacity = 0.3,
    this.textureImagePath, // e.g., 'assets/textures/paper_texture.png'
  });

  @override
  State<GalaxyPaperBackground> createState() => _GalaxyPaperBackgroundState();
}

class _GalaxyPaperBackgroundState extends State<GalaxyPaperBackground> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base galaxy gradient
        Positioned.fill(
          child: CustomPaint(
            painter: _GalaxyGradientPainter(),
            size: Size.infinite,
          ),
        ),
        // Texture image overlay (if provided)
        if (widget.textureImagePath != null)
          Positioned.fill(
            child: Opacity(
              opacity: widget.textureOpacity,
              child: Image.asset(
                widget.textureImagePath!,
                fit: BoxFit.cover,
                repeat: ImageRepeat.repeat,
                errorBuilder: (context, error, stackTrace) {
                  // Show red if image fails to load
                  return Container(
                    color: Colors.red,
                    child: const Center(
                      child: Text('Texture Image Not Found'),
                    ),
                  );
                },
              ),
            ),
          ),
        // Subtle stars overlay
        Positioned.fill(
          child: Opacity(
            opacity: 0.5,
            child: CustomPaint(
              painter: _StarsPainter(),
              size: Size.infinite,
            ),
          ),
        ),
        // Child content
        widget.child,
      ],
    );
  }
}

/// Painter for galaxy-themed gradient (the colored base)
class _GalaxyGradientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Base galaxy gradient (muted cosmic colors)
    final baseGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFF2a1a4a), // Deep purple
        const Color(0xFF1e2a5a), // Deep blue
        const Color(0xFF2d1a4a), // Deep purple
        const Color(0xFF1a2a4a), // Deep blue
      ],
      tileMode: TileMode.mirror,
    );

    final basePaint = Paint()
      ..shader = baseGradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      basePaint,
    );

    // Add subtle organic patches
    final random = Random(42);
    for (int i = 0; i < 8; i++) {
      final centerX = random.nextDouble() * size.width;
      final centerY = random.nextDouble() * size.height;
      final patchRadius = 50 + random.nextDouble() * 100;

      final patchGradient = RadialGradient(
        colors: [
          const Color(0xFF4a3a6a).withValues(alpha: 0.1),
          const Color(0xFF3a4a6a).withValues(alpha: 0.05),
          const Color(0xFF4a3a6a).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.6, 1.0],
      );

      final patchPaint = Paint()
        ..shader = patchGradient.createShader(
          Rect.fromCircle(center: Offset(centerX, centerY), radius: patchRadius),
        )
        ..blendMode = BlendMode.multiply;

      canvas.drawCircle(Offset(centerX, centerY), patchRadius, patchPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Painter for scattered stars
class _StarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42);

    // Draw small subtle stars
    for (int i = 0; i < 60; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final starSize = 0.8 + random.nextDouble() * 1.5;
      final opacity = 0.15 + random.nextDouble() * 0.35;

      final starPaint = Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, starSize * 0.8);

      canvas.drawCircle(Offset(x, y), starSize, starPaint);
    }

    // Draw a few larger glowing stars
    for (int i = 0; i < 4; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final starSize = 2.5 + random.nextDouble() * 3;

      final glowPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      canvas.drawCircle(Offset(x, y), starSize, glowPaint);

      final corePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.7);

      canvas.drawCircle(Offset(x, y), starSize * 0.25, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Simple container wrapper for use with the background
class GalaxyBackgroundContainer extends StatelessWidget {
  final Widget child;
  final double textureOpacity;
  final String? textureImagePath;

  const GalaxyBackgroundContainer({
    super.key,
    required this.child,
    this.textureOpacity = 0.3,
    this.textureImagePath,
  });

  @override
  Widget build(BuildContext context) {
    return GalaxyPaperBackground(
      textureOpacity: textureOpacity,
      textureImagePath: textureImagePath,
      child: child,
    );
  }
}
