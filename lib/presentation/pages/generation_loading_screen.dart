import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/providers.dart';
import '../providers/auth_quota_provider.dart';
import '../../data/services/gemini_service.dart';
import 'interactive_vocabulary_screen.dart';
import 'auth/account_method_page.dart';

/// Generation Loading Screen - Shows AI processing progress
class GenerationLoadingScreen extends ConsumerStatefulWidget {
  final String imagePath;
  final String cefrLevel;
  final String communicativeFunction;
  final String englishVariant;
  final List<String> excludeWords; // Words to exclude when regenerating
  final bool isRegenerate; // Flag to indicate this is a regeneration

  const GenerationLoadingScreen({
    super.key,
    required this.imagePath,
    required this.cefrLevel,
    required this.communicativeFunction,
    required this.englishVariant,
    this.excludeWords = const [],
    this.isRegenerate = false,
  });

  @override
  ConsumerState<GenerationLoadingScreen> createState() =>
      _GenerationLoadingScreenState();
}

class _GenerationLoadingScreenState
    extends ConsumerState<GenerationLoadingScreen>
    with TickerProviderStateMixin {
  int _currentPhase = 1;
  bool _isProcessing = true;

  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );
    _scanController.repeat(reverse: true);

    // Check quota first, then start generation
    _checkQuotaAndStart();
  }

  Future<void> _checkQuotaAndStart() async {
    // Wait for providers to be ready
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;

    final authQuotaState = ref.read(authQuotaProvider);

    if (!authQuotaState.canGenerate) {
      _handleQuotaExhausted(authQuotaState.isGuest);
      return;
    }

    // Start generation
    _startGeneration();
  }

  void _handleQuotaExhausted(bool isGuest) {
    if (!mounted) return;

    setState(() => _isProcessing = false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Generation Limit Reached',
                style: GoogleFonts.lexend(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1f2937),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isGuest
                  ? 'You\'ve used all your free generations as a guest.'
                  : 'You\'ve reached your daily generation limit.',
              style: GoogleFonts.lexend(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF6b7280),
              ),
            ),
            if (isGuest) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF8b5cf6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star_rounded, color: const Color(0xFF8b5cf6), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sign up for unlimited generations!',
                        style: GoogleFonts.lexend(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF7c3aed),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (isGuest)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                // Show sign up bottom sheet
                AccountMethodPage.show(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8b5cf6),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'Sign Up Free',
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.popUntil(context, (route) => route.isFirst); // Go to home
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6b7280),
            ),
            child: Text(
              'Later',
              style: GoogleFonts.lexend(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _startGeneration() async {
    try {
      // Phase 1: Reading image
      setState(() => _currentPhase = 1);
      final imageData = await File(widget.imagePath).readAsBytes();

      // Validate image size
      if (imageData.isEmpty) {
        throw _ImageAnalysisException('Image file is empty', 'A1');
      }

      if (imageData.length < 1024) {
        throw _ImageAnalysisException(
          'Image resolution too low for AI analysis',
          'A1',
        );
      }

      final geminiService = ref.read(geminiServiceProvider);

      // Brief delay so Phase 1 is visible smoothly
      await Future.delayed(const Duration(milliseconds: 600));

      // Phase 2: Analyzing with AI
      if (mounted) setState(() => _currentPhase = 2);

      // Actual API call with timeout to prevent indefinite hanging
      final result = await geminiService.extractVocabulary(
        imageData: imageData,
        level: widget.cefrLevel,
        category: 'Daily Life',
        englishVariant: widget.englishVariant,
        excludeWords: widget.excludeWords,
        isRegenerate: widget.isRegenerate,
      ).timeout(
        const Duration(seconds: 90), // 90 second timeout
        onTimeout: () {
          throw TimeoutException('AI processing timed out. Please check your connection and try again.');
        },
      );

      if (mounted && result.vocabList.isNotEmpty) {
        // Phase 3: Generate sentences for all vocabulary words
        setState(() => _currentPhase = 3);

        // Use default 'Describe' tone for initial sentences
        final words = result.vocabList.map((item) => item.word).toList();
        final tones = ['describe']; // Default tone

        final sentencesResult = await geminiService.generateSentences(
          imageData: imageData,  // Send image for contextually relevant sentences
          words: words,
          level: widget.cefrLevel,
          tones: tones,
          category: result.category,
          combined: false, // Generate individual sentences initially
          englishVariant: widget.englishVariant,
        ).timeout(
          const Duration(seconds: 60), // 60 second timeout for sentences
          onTimeout: () {
            throw TimeoutException('Sentence generation timed out. Please try again.');
          },
        );

        if (mounted) {
          // Attach generated sentences to each vocabulary item
          final vocabListWithSentences = result.vocabList.map((item) {
            final sentenceData = sentencesResult.results[item.word]?['describe'];
            if (sentenceData != null) {
              return item.withSentences(sentenceData.text, sentenceData.thai);
            }
            return item; // Keep original if no sentence found
          }).toList();

          // Create updated result with sentences
          final updatedResult = VocabularyExtractionResult(
            level: result.level,
            category: result.category,
            vocabList: vocabListWithSentences,
          );

          // Phase 4: Finalizing / Done!
          setState(() => _currentPhase = 4);
          await Future.delayed(const Duration(milliseconds: 600));
          if (!mounted) return;
          setState(() => _isProcessing = false);
          await _showResult(updatedResult);
        }
      } else if (mounted) {
        // No vocabulary found - show error
        setState(() => _isProcessing = false);
        _handleImageError('A1', 'No vocabulary found in this image. Please try another photo with clearer objects.');
      }
    } on _ImageAnalysisException catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        _handleImageError(e.errorCode, e.message);
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        _handleNetworkError('Request timed out. Please check your connection and try again.');
      }
    } catch (e) {
      if (mounted) {
        final errorStr = e.toString();
        final errorStrLower = errorStr.toLowerCase();

        // debugPrint('🔍 Generation loading caught error: "$errorStr"');

        // Handle QuotaExceededFailure with a friendly message (don't mention quota/backend limit)
        if (errorStr.contains('QuotaExceededFailure') ||
            errorStr.contains('Starmory needs a rest') ||
            errorStrLower.contains('quota exceeded') ||
            errorStrLower.contains('please check your plan and billing')) {
          // debugPrint('✅ Showing friendly quota message to userrrrrr');

          setState(() {
            _isProcessing = false;
          });
          _handleNetworkError('Starmory needs a rest today 😴\nNew lessons will be ready again tomorrow!');
          return;
        }

        // Handle AIServiceFailure (includes 503 and other service errors with friendly messages)
        if (errorStr.contains('AIServiceFailure') ||
            errorStrLower.contains('temporarily busy') ||
            errorStrLower.contains('please wait a moment')) {
          setState(() {
            _isProcessing = false;
          });
          // Extract the friendly message from AIServiceFailure
          final friendlyMessage = errorStr.contains('AIServiceFailure')
              ? errorStr.replaceAll('Exception: AIServiceFailure: ', '').replaceAll('AIServiceFailure: ', '')
              : 'AI service is temporarily busy 😅\nPlease wait a moment and try again!';
          _handleNetworkError(friendlyMessage);
          return;
        }

        // Handle 503/UNAVAILABLE errors (high demand, service temporarily unavailable) - fallback for raw errors
        if (errorStr.contains('503') ||
            errorStrLower.contains('unavailable') ||
            errorStrLower.contains('high demand') ||
            errorStrLower.contains('temporarily') ||
            errorStrLower.contains('try again later')) {
          setState(() {
            _isProcessing = false;
          });
          _handleNetworkError('AI service is temporarily busy 😅\nPlease wait a moment and try again!');
          return;
        }

        String errorMessage;
        if (errorStr.contains('Instance of')) {
          errorMessage =
              'AI service initialization failed. Please check your API key.';
        } else if (errorStr.contains('NotInitializedError')) {
          errorMessage = 'AI service is not ready. Please try again.';
        } else {
          errorMessage = errorStr.replaceAll('Exception: ', '');
        }

        setState(() {
          _isProcessing = false;
        });

        if (errorMessage.toLowerCase().contains('network') ||
            errorMessage.toLowerCase().contains('connection') ||
            errorMessage.toLowerCase().contains('timeout') ||
            errorMessage.toLowerCase().contains('api key')) {
          _handleNetworkError(errorMessage);
        } else {
          _handleImageError('A1', errorMessage);
        }
      }
    }
  }

  Future<void> _showResult(dynamic result) async {
    // Record quota usage after successful generation
    final authQuotaNotifier = ref.read(authQuotaProvider.notifier);
    await authQuotaNotifier.recordQuotaUsage(imageId: widget.imagePath);

    // Record streak & learning activity when vocabulary is generated
    final streakNotifier = ref.read(streakProvider.notifier);
    await streakNotifier.recordVocabularyAcquired();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => InteractiveVocabularyScreen(
          imagePath: widget.imagePath,
          cefrLevel: widget.cefrLevel,
          communicativeFunction: widget.communicativeFunction,
          englishVariant: widget.englishVariant,
          extractionResult: result,
        ),
      ),
    );
  }

  void _handleImageError(String errorCode, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Colors.orange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Image Analysis Failed',
                style: GoogleFonts.lexend(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1f2937),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.lexend(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF6b7280),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.popUntil(
                context,
                (route) => route.isFirst,
              ); // Go to home
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8b5cf6),
            ),
            child: Text(
              'OK',
              style: GoogleFonts.lexend(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNetworkError(String error) {
    if (!mounted) return;

    // Check if it's the friendly quota message
    final isQuotaMessage = error.contains('Starmory needs a rest');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isQuotaMessage
                    ? Colors.purple.withValues(alpha: 0.15)
                    : Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isQuotaMessage ? Icons.bedtime_rounded : Icons.cloud_off_rounded,
                color: isQuotaMessage ? Colors.purple : Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isQuotaMessage ? 'Starmory' : 'Connection Error',
                style: GoogleFonts.lexend(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1f2937),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          error,
          style: GoogleFonts.lexend(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF6b7280),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.popUntil(
                context,
                (route) => route.isFirst,
              ); // Go to home
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8b5cf6),
            ),
            child: Text(
              'OK',
              style: GoogleFonts.lexend(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const List<String> _phases = [
    'Analyzing your photo',
    'Detecting vocabulary words',
    'Generating contextual sentences',
    'Done!',
  ];

  Widget _buildPhaseItem(int index) {
    final phaseNum = index + 1;
    final isCurrent = _currentPhase == phaseNum;
    final isPast = _currentPhase > phaseNum;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      opacity: isCurrent ? 1.0 : (isPast ? 0.5 : 0.22),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        scale: isCurrent ? 1.08 : 0.92,
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isPast)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF4ADE80),
                  size: 16,
                )
              else if (isCurrent)
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF7A45),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFFF7A45),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 8),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                style: GoogleFonts.lexend(
                  fontSize: isCurrent ? 17.5 : 13.0,
                  fontWeight: isCurrent
                      ? FontWeight.w700
                      : (isPast ? FontWeight.w500 : FontWeight.w400),
                  color: isCurrent
                      ? Colors.white
                      : (isPast
                          ? Colors.white.withValues(alpha: 0.8)
                          : Colors.white.withValues(alpha: 0.5)),
                  letterSpacing: isCurrent ? 0.2 : 0,
                ),
                child: Text(_phases[index]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

          // 2. Dark Overlay
          Container(
            color: Colors.black.withValues(alpha: 0.55),
          ),

          // 3. Vignette Top and Bottom Gradients
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 160,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 280,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.85),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 4. Content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Top Title "Creating Magic"
                Text(
                  'Creating Magic',
                  style: GoogleFonts.lexend(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),

                const Spacer(),

                // Center Scanner Box with Orange Rounded Corners
                Center(
                  child: SizedBox(
                    width: 260,
                    height: 260,
                    child: Stack(
                      children: [
                        // Reticle corners
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ScannerReticlePainter(
                              color: const Color(0xFFFF6A3D),
                              cornerLength: 36,
                              cornerRadius: 18,
                              strokeWidth: 3.5,
                            ),
                          ),
                        ),

                        // Scan laser beam moving up and down
                        if (_isProcessing)
                          AnimatedBuilder(
                            animation: _scanAnimation,
                            builder: (context, child) {
                              return Positioned(
                                top: 12 + (_scanAnimation.value * (260 - 24)),
                                left: 16,
                                right: 16,
                                child: Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF6A3D).withValues(alpha: 0.8),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                    gradient: const LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Color(0xFFFF7A45),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Bottom Status Steps List and Pill Badge
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated Phase List
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          _phases.length,
                          (index) => _buildPhaseItem(index),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Translucent Pill Badge "This may take a few seconds."
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'This may take a few seconds.',
                          style: GoogleFonts.lexend(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
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
}

/// Custom painter for the scanner corner brackets
class _ScannerReticlePainter extends CustomPainter {
  final Color color;
  final double cornerLength;
  final double cornerRadius;
  final double strokeWidth;

  _ScannerReticlePainter({
    this.color = const Color(0xFFFF6A3D),
    this.cornerLength = 36.0,
    this.cornerRadius = 18.0,
    this.strokeWidth = 3.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    final r = cornerRadius;
    final l = cornerLength;

    // Top-Left Corner
    final tlPath = Path()
      ..moveTo(0, l)
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..lineTo(l, 0);
    canvas.drawPath(tlPath, paint);

    // Top-Right Corner
    final trPath = Path()
      ..moveTo(w - l, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: Radius.circular(r))
      ..lineTo(w, l);
    canvas.drawPath(trPath, paint);

    // Bottom-Left Corner
    final blPath = Path()
      ..moveTo(0, h - l)
      ..lineTo(0, h - r)
      ..arcToPoint(Offset(r, h), radius: Radius.circular(r))
      ..lineTo(l, h);
    canvas.drawPath(blPath, paint);

    // Bottom-Right Corner
    final brPath = Path()
      ..moveTo(w - l, h)
      ..lineTo(w - r, h)
      ..arcToPoint(Offset(w, h - r), radius: Radius.circular(r))
      ..lineTo(w, h - l);
    canvas.drawPath(brPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom exception for image analysis errors
class _ImageAnalysisException implements Exception {
  final String message;
  final String errorCode;

  _ImageAnalysisException(this.message, this.errorCode);
}
