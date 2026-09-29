import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/design_tokens.dart';
import '../../data/sticker_sets.dart';

/// Modal dialog to celebrate unlocking a new sticker pack
class StickerPackUnlockDialog extends StatefulWidget {
  final StickerSet stickerSet;
  final VoidCallback? onUseInScrapbook;

  const StickerPackUnlockDialog({
    super.key,
    required this.stickerSet,
    this.onUseInScrapbook,
  });

  /// Show the sticker pack unlock dialog
  static Future<void> show(
    BuildContext context, {
    required StickerSet stickerSet,
    VoidCallback? onUseInScrapbook,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Sticker Pack Unlock',
      barrierColor: Colors.black.withValues(alpha: 0.48),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return StickerPackUnlockDialog(
          stickerSet: stickerSet,
          onUseInScrapbook: onUseInScrapbook,
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
  State<StickerPackUnlockDialog> createState() => _StickerPackUnlockDialogState();
}
class _StickerPackUnlockDialogState extends State<StickerPackUnlockDialog>
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

    _rotateAnimation = Tween<double>(begin: -0.08, end: 0.0).animate(
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
    final pack = widget.stickerSet;
    final gradient = pack.gradientColors.isNotEmpty
        ? pack.gradientColors
        : const [Color(0xFF8B5CF6), Color(0xFF6366F1)];

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.88,
          constraints: const BoxConstraints(maxWidth: 390),
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
                            'STICKER PACK UNLOCKED!',
                            style: GoogleFonts.lexend(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: const Color(0xFF946200),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Animated Glowing Pack Icon
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Transform.rotate(
                            angle: _rotateAnimation.value * math.pi,
                            child: Container(
                              width: 100,
                              height: 100,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    gradient.first.withValues(alpha: 0.12),
                                    gradient.last.withValues(alpha: 0.08),
                                  ],
                                ),
                                border: Border.all(
                                  color: gradient.first.withValues(alpha: 0.28),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: gradient.first.withValues(
                                      alpha: 0.22 * _glowAnimation.value,
                                    ),
                                    blurRadius: 22 * _glowAnimation.value,
                                    spreadRadius: 2 * _glowAnimation.value,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Image.asset(
                                  pack.previewAsset,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.auto_awesome,
                                    size: 44,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    // Pack Count Tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: gradient.first.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: gradient.first.withValues(alpha: 0.22),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${pack.count} STICKERS READY',
                        style: GoogleFonts.lexend(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: DesignTokens.dialogBrand,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Pack Title
                    Text(
                      '${pack.name} Pack',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lexend(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: DesignTokens.dialogTitleColor,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Sticker Sample Preview Grid (first 4 items)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: gradient.first.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: gradient.first.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(
                              math.min(4, pack.count),
                              (idx) => Container(
                                width: 48,
                                height: 48,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFECE7F5),
                                  ),
                                ),
                                child: Image.asset(
                                  getStickerAsset(pack.id, idx),
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.star_rounded,
                                    color: Colors.amber,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            pack.description,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.lexend(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: DesignTokens.dialogSupportingTextColor,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action Button: Got It / Use in Scrapbook
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onUseInScrapbook?.call();
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
