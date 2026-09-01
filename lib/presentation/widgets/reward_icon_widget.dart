import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Reusable widget for displaying Badge and Sticker icons
/// Supports both emoji text and local asset image paths (PNG, SVG, etc.)
class RewardIconWidget extends StatelessWidget {
  final String icon;
  final double size;
  final bool isLocked;
  final BoxFit fit;

  const RewardIconWidget({
    super.key,
    required this.icon,
    this.size = 40,
    this.isLocked = false,
    this.fit = BoxFit.contain,
  });

  /// Check if the icon string is a local image asset path
  bool get _isAssetImage {
    return icon.startsWith('assets/') ||
        icon.endsWith('.png') ||
        icon.endsWith('.jpg') ||
        icon.endsWith('.webp') ||
        icon.endsWith('.svg');
  }

  bool get _isSvg => icon.endsWith('.svg');

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_isAssetImage) {
      if (_isSvg) {
        content = SvgPicture.asset(
          icon,
          width: size,
          height: size,
          fit: fit,
        );
      } else {
        content = Image.asset(
          icon,
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.star_rounded,
              size: size * 0.8,
              color: const Color(0xFF8B5CF6),
            );
          },
        );
      }
    } else {
      // Emoji or text icon
      content = Text(
        icon,
        style: TextStyle(
          fontSize: size * 0.75,
          height: 1,
        ),
        textAlign: TextAlign.center,
      );
    }

    // Apply locked styling (grayscale & opacity) if locked
    if (isLocked) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      0.4, 0,
        ]),
        child: content,
      );
    }

    return content;
  }
}
