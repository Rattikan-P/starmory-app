import 'dart:math' as math;
import 'package:flutter/material.dart' hide Badge;
import 'package:google_fonts/google_fonts.dart';
import '../../constants/design_tokens.dart';
import '../providers/badge_provider.dart';
import 'reward_icon_widget.dart';

/// Modal dialog to celebrate unlocking an achievement badge
class BadgeUnlockDialog extends StatefulWidget {
  final Badge badge;
  final VoidCallback? onViewBadges;

  const BadgeUnlockDialog({
    super.key,
    required this.badge,
    this.onViewBadges,
  });

  /// Show the badge unlock dialog
  static Future<void> show(
    BuildContext context, {
    required Badge badge,
    VoidCallback? onViewBadges,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Badge Unlock',
      barrierColor: Colors.black.withValues(alpha: 0.48),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return BadgeUnlockDialog(
          badge: badge,
          onViewBadges: onViewBadges,
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curvedValue = Curves.easeOutBack.transform(anim1.value) - 1.0;
        return Transform(
          transform: Matrix4.translationValues(0.0, curvedValue * -50, 0.0),
          child: Opacity(
            opacity: anim1.value,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<BadgeUnlockDialog> createState() => _BadgeUnlockDialogState();
}
class _BadgeUnlockDialogState extends State<BadgeUnlockDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    );

    _rotateAnimation = Tween<double>(begin: -0.1, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.badge;
    final gradient = badge.gradientColors.isNotEmpty
        ? badge.gradientColors
        : const [Color(0xFF8B5CF6), Color(0xFF6366F1)];

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.88,
          constraints: const BoxConstraints(maxWidth: 380),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: gradient.first.withValues(alpha: 0.2),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withValues(alpha: 0.16),
                blurRadius: 28,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5D9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFFFE5A3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'BADGE UNLOCKED!',
                            style: GoogleFonts.lexend(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: const Color(0xFF946200),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Animated Glowing Badge Icon
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Transform.rotate(
                            angle: _rotateAnimation.value * math.pi,
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color.alphaBlend(
                                  gradient.first.withValues(alpha: 0.10),
                                  Colors.white,
                                ),
                                border: Border.all(
                                  color: gradient.first.withValues(alpha: 0.28),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: gradient.first.withValues(
                                      alpha: 0.24 * _glowAnimation.value,
                                    ),
                                    blurRadius: 24 * _glowAnimation.value,
                                    spreadRadius: 3 * _glowAnimation.value,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: RewardIconWidget(
                                  icon: badge.icon,
                                  size: 56,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Tier Tag (e.g. SILVER, GOLD, NEBULA)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badge.tierColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: badge.tierColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        badge.tier.toUpperCase(),
                        style: GoogleFonts.lexend(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: DesignTokens.dialogBrand,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Badge Title (English)
                    Text(
                      badge.name,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lexend(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: DesignTokens.dialogTitleColor,
                      ),
                    ),
                    const SizedBox(height: 4),

                    const SizedBox(height: 12),

                    // Description Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F6FC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFECE7F5),
                        ),
                      ),
                      child: Text(
                        badge.description,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.lexend(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: DesignTokens.dialogSupportingTextColor,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Button: Awesome / Claim
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onViewBadges?.call();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              DesignTokens.dialogButtonRadius,
                            ),
                          ),
                          shadowColor: Colors.transparent,
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                DesignTokens.dialogBrand,
                                Color(0xFF7045D8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(
                              DesignTokens.dialogButtonRadius,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: DesignTokens.dialogBrand.withValues(
                                  alpha: 0.22,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Awesome!',
                                  style: GoogleFonts.lexend(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Close button
              Positioned(
                top: 14,
                right: 14,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F1F7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Color(0xFF77717F),
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
}
