import 'package:flutter/material.dart';

/// Design Tokens for Starmory App
/// Centralized design system values for consistency
class DesignTokens {
  DesignTokens._();

  // ============= Brand Colors =============

  /// Primary brand color - Purple
  static const int brandColorValue = 0xFF8b5cf6;
  static const Color brandColor = Color(brandColorValue);

  /// Secondary brand accent - Light Purple
  static const int brandAccentValue = 0xFFC4B5FD;
  static const Color brandAccent = Color(brandAccentValue);

  // ============= Text Colors =============

  /// Primary text color - Dark gray
  static const int textPrimaryValue = 0xFF1f2937;
  static const Color textPrimary = Color(textPrimaryValue);

  /// Secondary text color - Medium gray
  static const int textSecondaryValue = 0xFF6b7280;
  static const Color textSecondary = Color(textSecondaryValue);

  /// Muted text color - Light gray
  static const int textMutedValue = 0xFF9ca3af;
  static const Color textMuted = Color(textMutedValue);

  /// Text on dark backgrounds
  static const Color textOnDark = Colors.white;
  static const Color textOnBrand = Colors.white;

  // ============= Surface Colors =============

  /// Primary surface - White with opacity
  static const Color surfacePrimary = Colors.white;
  static const Color surfacePrimary90 = Color(0xFFFFFFFF); // withValues(alpha: 0.9)
  static const Color surfacePrimary80 = Color(0xFFFFFFFF); // withValues(alpha: 0.8)

  /// Error colors
  static const Color error = Colors.red;
  static const Color errorBackground = Color(0xFFFFEBEE);

  /// Success colors
  static const Color success = Colors.green;

  // ============= Control Handle Colors =============

  /// Delete handle color (red)
  static const int controlDeleteValue = 0xFFEF4444;
  static const Color controlDelete = Color(controlDeleteValue);

  /// Duplicate handle color (blue)
  static const int controlDuplicateValue = 0xFF3B82F6;
  static const Color controlDuplicate = Color(controlDuplicateValue);

  /// Flip handle color (amber)
  static const int controlFlipValue = 0xFFF59E0B;
  static const Color controlFlip = Color(controlFlipValue);

  /// Resize/Rotate handle color (brand purple)
  static const int controlResizeValue = 0xFF8b5cf6;
  static const Color controlResize = Color(controlResizeValue);

  // ============= Border Radius =============

  /// Small border radius (8px) - chips, tags
  static const double radiusSmall = 8.0;

  /// Medium border radius (12px) - buttons, inputs
  static const double radiusMedium = 12.0;

  /// Large border radius (16px) - cards, buttons
  static const double radiusLarge = 16.0;

  /// Extra large border radius (20px) - panels, sheets
  static const double radiusXLarge = 20.0;

  /// Circular border radius (24px+) - hero elements
  static const double radiusCircular = 24.0;

  // ============= Spacing =============

  /// Base spacing unit (4px)
  static const double spacingBase = 4.0;

  /// Small spacing (8px)
  static const double spacingSmall = spacingBase * 2;

  /// Medium spacing (12px)
  static const double spacingMedium = spacingBase * 3;

  /// Large spacing (16px)
  static const double spacingLarge = spacingBase * 4;

  /// Extra large spacing (24px)
  static const double spacingXLarge = spacingBase * 6;

  /// XX Large spacing (32px)
  static const double spacingXXLarge = spacingBase * 8;

  // ============= Shadows =============

  /// Subtle shadow for cards and panels
  static List<BoxShadow> shadowSubtle = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  /// Medium shadow for elevated elements
  static List<BoxShadow> shadowMedium = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  /// Strong shadow for floating elements
  static List<BoxShadow> shadowStrong = [
    BoxShadow(
      color: brandColor.withValues(alpha: 0.3),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  /// Shadow for brand-colored elements
  static List<BoxShadow> shadowBrand = [
    BoxShadow(
      color: brandColor.withValues(alpha: 0.15),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  // ============= Typography =============

  /// Font family used throughout the app
  static const String fontFamily = 'Lexend';

  /// Font weights
  static const FontWeight weightRegular = FontWeight.w400;
  static const FontWeight weightMedium = FontWeight.w500;
  static const FontWeight weightSemiBold = FontWeight.w600;
  static const FontWeight weightBold = FontWeight.w700;

  /// Font sizes
  static const double fontSizeCaption = 11.0;
  static const double fontSizeSmall = 12.0;
  static const double fontSizeBody = 14.0;
  static const double fontSizeBodyLarge = 15.0;
  static const double fontSizeSubtitle = 16.0;
  static const double fontSizeTitle = 18.0;
  static const double fontSizeHeading = 20.0;
  static const double fontSizeDisplay = 24.0;

  /// Letter spacing for headings
  static const double letterSpacingHeading = 1.0;
  static const double letterSpacingDisplay = 2.0;

  // ============= Opacity =============

  static const double opacityTransparent = 0.0;
  static const double opacityVerySubtle = 0.1;
  static const double opacitySubtle = 0.3;
  static const double opacityMedium = 0.5;
  static const double opacitySemiTransparent = 0.7;
  static const double opacityMostlyOpaque = 0.9;
  static const double opacityOpaque = 1.0;

  // ============= Animations =============

  /// Standard animation duration for micro-interactions
  static const int durationFast = 150;

  /// Standard animation duration for transitions
  static const int durationMedium = 200;

  /// Long animation duration for major transitions
  static const int durationSlow = 300;

  /// Animation curve for natural deceleration
  static const Curve curveEaseOut = Curves.easeOut;

  /// Animation curve for entering elements
  static const Curve curveEaseOutQuart = Curves.easeOutQuart;

  // ============= Touch Targets =============

  /// Minimum touch target size (44px) - iOS standard
  static const double touchTarget = 44.0;

  /// Icon button size
  static const double iconButtonSize = 44.0;

  // ============= Scrapbook Specific =============

  /// Canvas height for scrapbook editing
  static const double scrapbookCanvasHeight = 400.0;

  /// Canvas width (same as height for square canvas)
  static const double scrapbookCanvasWidth = 400.0;

  /// Maximum overflow percentage for items outside canvas
  static const double scrapbookOverflowRatio = 0.3;

  /// Default emoji button size
  static const double emojiButtonSize = 48.0;

  /// Default sticker size
  static const double stickerSize = 40.0;

  /// Delete zone height from bottom
  static const double deleteZoneHeight = 150.0;

  /// Control handle size for selected elements (meets 44x44 touch target)
  static const double controlHandleSize = 36.0;

  /// Control handle offset from element edge
  static const double controlHandleOffset = 12.0;

  /// Control touch padding for better touch recognition
  static const double controlTouchPadding = 4.0;

  // ============= Helper Methods =============

  /// Create white color with opacity
  static Color whiteWithOpacity(double opacity) {
    return Color.fromARGB((255 * opacity).round(), 255, 255, 255);
  }

  /// Create black color with opacity
  static Color blackWithOpacity(double opacity) {
    return Color.fromARGB((255 * opacity).round(), 0, 0, 0);
  }

  /// Create brand color with opacity
  static Color brandWithOpacity(double opacity) {
    return Color.fromARGB((255 * opacity).round(), 139, 92, 246);
  }

  /// Get shadow for card at specific elevation
  static List<BoxShadow> shadowForElevation(int elevation) {
    switch (elevation) {
      case 1:
        return shadowSubtle;
      case 2:
        return shadowMedium;
      case 3:
        return shadowStrong;
      default:
        return shadowSubtle;
    }
  }
}
