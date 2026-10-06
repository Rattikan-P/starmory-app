import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/providers.dart';
import '../../core/utils/image_clarity_checker.dart';
import '../../core/utils/image_validator.dart';
import '../../core/utils/internet_connection_checker.dart';
import '../../constants/app_defaults.dart';
import '../../constants/design_tokens.dart';
import '../widgets/tokenized_notice_dialogs.dart';
import 'generation_loading_screen.dart';
import 'auth/account_method_page.dart';

/// Image Preview Screen - Preview and confirm photo selection
class ImagePreviewScreen extends ConsumerStatefulWidget {
  final String imagePath;

  const ImagePreviewScreen({super.key, required this.imagePath});

  @override
  ConsumerState<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends ConsumerState<ImagePreviewScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userStateProvider);
    final currentUser = userState.user;
    final canGenerate = currentUser?.canGenerate ?? false;
    final isGuest = currentUser?.isGuest ?? true;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Fullscreen Image
          Image.file(
            File(widget.imagePath),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),

          // 2. Top Vignette Gradient Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 140,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 3. Bottom Vignette Gradient Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 320,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.90),
                    Colors.black.withValues(alpha: 0.50),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // 4. Foreground Content
          SafeArea(
            child: Column(
              children: [
                // TOP BAR
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    children: [
                      _glassButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      Text(
                        'Preview',
                        style: GoogleFonts.lexend(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      // Balance space for center title
                      const SizedBox(width: 44),
                    ],
                  ),
                ),

                const Spacer(),

                // BOTTOM TEXT & ACTION BUTTON
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ready to Generate',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.lexend(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'AI will analyze your image and create\ncontextual vocabulary cards',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.lexend(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Generate Vocabulary Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: (_isProcessing || !canGenerate)
                              ? null
                              : _usePhoto,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: const Color(0xFF8B5CF6),
                            disabledBackgroundColor:
                                Colors.white.withValues(alpha: 0.25),
                            foregroundColor: Colors.white,
                            disabledForegroundColor:
                                Colors.white.withValues(alpha: 0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: _isProcessing
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    canGenerate
                                        ? 'Generate Vocabulary'
                                        : 'Generation Limit Reached',
                                    style: GoogleFonts.lexend(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),

                      if (!canGenerate && isGuest) ...[
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => AccountMethodPage.show(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFFDE047),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Sign up for 15 daily generations!',
                                  style: GoogleFonts.lexend(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else if (!canGenerate && !isGuest) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Daily limit reached. Come back tomorrow for 15 new generations!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.lexend(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  void _retakePhoto() {
    Navigator.pop(context);
  }

  Future<void> _usePhoto() async {
    setState(() => _isProcessing = true);

    try {
      // Step 1: Check if user can generate (without deducting yet)
      final currentUser = ref.read(currentUserProvider);
      final canGenerate = currentUser?.canGenerate ?? false;

      if (!canGenerate) {
        if (mounted) {
          setState(() => _isProcessing = false);
          // Show appropriate dialog based on user type
          _showQuotaLimitDialog(currentUser?.isGuest ?? true);
        }
        return;
      }

      // Step 1.5: Check internet connection
      final hasConnection =
          await InternetConnectionChecker.hasInternetConnection();
      if (!hasConnection) {
        if (mounted) {
          setState(() => _isProcessing = false);
          _showNoInternetDialog();
        }
        return;
      }

      // Step 2: Check image format
      final validationResult =
          ImageValidator.validateFromFile(widget.imagePath);
      if (!validationResult.valid) {
        if (mounted) {
          setState(() => _isProcessing = false);
          _showImageFormatDialog();
        }
        return;
      }

      // Step 3: Check image clarity
      final clarityResult =
          await ImageClarityChecker.checkFromFile(widget.imagePath);

      if (!clarityResult.isClear) {
        if (mounted) {
          setState(() => _isProcessing = false);
          _showImageClarityDialog(clarityResult);
        }
        return;
      }

      // Step 3: Get user's default CEFR level, English variant, and communicative function
      final user = ref.read(currentUserProvider);
      debugPrint('🔍 User preferences: ${user?.preferences}');
      final defaultCefrLevel =
          user?.preferences['defaultCefrLevel'] as String? ??
              AppDefaults.defaultLanguageLevel;
      final defaultEnglishVariant =
          user?.preferences['languageVariant'] as String? ??
              AppDefaults.defaultEnglishVariant;
      debugPrint(
          '📤 Using CEFR: $defaultCefrLevel, English Variant: $defaultEnglishVariant');
      final defaultCommunicativeFunction = 'Indicative'; // Default for now

      // Step 4: Navigate directly to Generation Loading Screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GenerationLoadingScreen(
              imagePath: widget.imagePath,
              cefrLevel: defaultCefrLevel,
              communicativeFunction: defaultCommunicativeFunction,
              englishVariant: defaultEnglishVariant,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        _showErrorDialog('Error', 'Failed to process photo: ${e.toString()}');
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showTokenizedErrorDialog(
      context,
      title: title,
      message: message,
      icon: Icons.error_outline_rounded,
      onOk: () => setState(() => _isProcessing = false),
    );
  }

  void _showQuotaLimitDialog(bool isGuest) {
    if (isGuest) {
      showFreeTrialLimitDialog(
        context,
        isTotalLimitReached: ref
                .read(userStateProvider)
                .user
                ?.quotaManager
                .isTotalLimitReached() ??
            false,
        onSignUp: () {
          setState(() => _isProcessing = false);
          AccountMethodPage.show(context);
        },
      );
      return;
    }

    showDailyLimitReachedDialog(
      context,
      onOk: () => setState(() => _isProcessing = false),
    );
  }

  void _showImageClarityDialog(ImageClarityResult result) {
    showImageQualityIssueDialog(
      context,
      message:
          '${result.message} Please try with a clearer, well-lit photo for best results.',
      onTryAgain: _retakePhoto,
    );
  }

  void _showImageFormatDialog() {
    showUnsupportedImageFormatDialog(
      context,
      onChooseAnother: _retakePhoto,
    );
  }

  void _showNoInternetDialog() {
    showTokenizedActionDialog(
      context,
      title: 'No Internet Connection',
      message: 'Please check your internet connection and try again.',
      icon: Icons.cloud_off_rounded,
      secondaryLabel: 'Cancel',
      primaryLabel: 'Try Again',
      onPrimary: _usePhoto,
    );
  }
}
