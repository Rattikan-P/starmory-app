import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/providers.dart';
import '../providers/auth_quota_provider.dart';
import '../../core/utils/quota_manager.dart';
import '../../data/services/gemini_service.dart';
import 'interactive_vocabulary_screen.dart';
import 'auth/account_method_page.dart';

/// Generation Loading Screen - Shows AI processing progress
class GenerationLoadingScreen extends ConsumerStatefulWidget {
  final String imagePath;
  final String cefrLevel;
  final String communicativeFunction;
  final String englishVariant;

  const GenerationLoadingScreen({
    super.key,
    required this.imagePath,
    required this.cefrLevel,
    required this.communicativeFunction,
    required this.englishVariant,
  });

  @override
  ConsumerState<GenerationLoadingScreen> createState() =>
      _GenerationLoadingScreenState();
}

class _GenerationLoadingScreenState
    extends ConsumerState<GenerationLoadingScreen>
    with TickerProviderStateMixin {
  int _currentPhase = 1;
  String? _errorMessage;
  bool _isProcessing = true;
  bool _quotaDeducted = false; // Track if quota was deducted in this session

  // Phase descriptions - updated to reflect actual process
  final List<String> _phaseDescriptions = [
    'Analyzing your photo...',
    'Detecting vocabulary words...',
    'Finalizing...',
  ];

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
                // Navigate to sign up screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AccountMethodPage(),
                  ),
                );
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

      // Phase 2: Analyzing with AI
      setState(() => _currentPhase = 2);

      // Phase 3: Processing results
      setState(() => _currentPhase = 3);

      // Actual API call with timeout to prevent indefinite hanging
      final result = await geminiService.extractVocabulary(
        imageData: imageData,
        level: widget.cefrLevel,
        category: 'Daily Life',
        englishVariant: widget.englishVariant,
      ).timeout(
        const Duration(seconds: 90), // 90 second timeout
        onTimeout: () {
          throw TimeoutException('AI processing timed out. Please check your connection and try again.');
        },
      );

      if (mounted && result.vocabList.isNotEmpty) {
        // Phase 4: Generate sentences for all vocabulary words
        // Use default 'Describe' tone for initial sentences
        final words = result.vocabList.map((item) => item.word).toList();
        final tones = ['describe']; // Default tone

        final sentencesResult = await geminiService.generateSentences(
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

          setState(() => _isProcessing = false);
          _showResult(updatedResult);
        }
      } else if (mounted) {
        setState(() => _isProcessing = false);
        _showResult(result);
      }
    } on _ImageAnalysisException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isProcessing = false;
        });
        _handleImageError(e.errorCode, e.message);
      }
    } on TimeoutException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
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

          // Refund quota since generation failed due to API quota exceeded
          await _refundQuota();

          setState(() {
            _errorMessage = 'Starmory needs a rest today 😴\nNew lessons will be ready again tomorrow!';
            _isProcessing = false;
          });
          _handleNetworkError('Starmory needs a rest today 😴\nNew lessons will be ready again tomorrow!');
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
          _errorMessage = 'Error: $errorMessage';
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

  void _showResult(dynamic result) {
    // Record quota usage after successful generation
    _quotaDeducted = true; // Mark that quota was deducted
    final authQuotaNotifier = ref.read(authQuotaProvider.notifier);
    authQuotaNotifier.recordQuotaUsage(imageId: widget.imagePath);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFE8F4FD),
                    Color(0xFFF5EEF8),
                    Color(0xFFFDF4E8),
                  ],
                ),
              ),
            ),
          ),

          // Galaxy blobs
          Positioned(
            top: -100,
            left: -80,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFC4B5FD).withValues(alpha: 0.5),
                    const Color(0x00C4B5FD),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF93C5FD).withValues(alpha: 0.4),
                    const Color(0x0093C5FD),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 30),

                  // TOP TEXT
                  Column(
                    children: [
                      Text(
                        'Creating Magic',
                        style: GoogleFonts.lexend(
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1f2937),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _phaseDescriptions[_currentPhase - 1],
                        textAlign: TextAlign.center,
                        style: GoogleFonts.lexend(
                          fontSize: 15,
                          height: 1.5,
                          color: const Color(0xFF6b7280),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // IMAGE CARD
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 340),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      color: Colors.white.withValues(alpha: 0.9),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                          blurRadius: 40,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        children: [
                          // IMAGE
                          AspectRatio(
                            aspectRatio: 0.8,
                            child: Image.file(
                              File(widget.imagePath),
                              fit: BoxFit.cover,
                            ),
                          ),

                          // DARK OVERLAY
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.1),
                                    Colors.black.withValues(alpha: 0.25),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // SCAN EFFECT
                          if (_isProcessing)
                            Positioned.fill(
                              child: AnimatedBuilder(
                                animation: _scanAnimation,
                                builder: (context, child) {
                                  return Align(
                                    alignment: Alignment(
                                      0,
                                      -1 + (_scanAnimation.value * 2),
                                    ),
                                    child: Container(
                                      height: 80,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            const Color(0xFF8B7CFF)
                                                .withValues(alpha: 0.4),
                                            Colors.transparent,
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                          // CENTER LOADER
                          if (_isProcessing)
                            Positioned.fill(
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.1),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF8b7cf6),
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'AI Processing',
                                        style: TextStyle(
                                          color: Color(0xFF1f2937),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // STEP INDICATOR
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      final isActive = index + 1 == _currentPhase;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: isActive ? 36 : 10,
                        height: 10,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: isActive
                              ? const Color(0xFF8b7cf6)
                              : const Color(0xFFc4b5fd).withValues(alpha: 0.3),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'This may take a few seconds',
                    style: GoogleFonts.lexend(
                      color: const Color(0xFF9ca3af),
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPhaseIndicator() {
    String label;
    switch (_currentPhase) {
      case 1:
        label = 'Scene Analysis...';
        break;
      case 2:
        label = 'Detect Words...';
        break;
      case 3:
        label = 'Finalizing...';
        break;
      default:
        label = 'Processing...';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.lexend(
            fontSize: 16,
            color: const Color(0xFF1f2937),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Refund quota when generation fails due to API quota exceeded
  Future<void> _refundQuota() async {
    try {
      // Only refund if quota was actually deducted in this session
      if (!_quotaDeducted) {
        debugPrint('⏭️ Quota was not deducted in this session, skipping refund');
        return;
      }

      final user = ref.read(currentUserProvider);
      if (user == null || user.quotaManager.usageHistory.isEmpty) {
        return;
      }

      // Remove the last usage entry
      final updatedHistory =
          List<QuotaEntry>.from(user.quotaManager.usageHistory)..removeLast();

      final updatedQuotaManager = QuotaManager(
        totalLimit: user.quotaManager.totalLimit,
        dailyLimit: user.quotaManager.dailyLimit,
        usageHistory: updatedHistory,
      );

      final updatedUser = user.copyWith(quotaManager: updatedQuotaManager);

      // Update user state
      final userNotifier = ref.read(userStateProvider.notifier);
      await userNotifier.updateUser(updatedUser);

      // Rollback Supabase quota count for registered users
      if (!user.isGuest) {
        try {
          final client = Supabase.instance.client;
          final supabaseUser = client.auth.currentUser;
          if (supabaseUser != null) {
            // Get current quota from Supabase using auto-reset function
            final quotaResponse = await client
                .rpc('get_user_quota_with_reset', params: {'p_user_id': supabaseUser.id})
                .maybeSingle();

            if (quotaResponse != null) {
              final dailyCount = quotaResponse['daily_gen_count'] as int? ?? 0;
              final totalCount = quotaResponse['total_gen_count'] as int? ?? 0;

              // Calculate the new counts after refund
              int newDailyCount = dailyCount - 1;
              int newTotalCount = totalCount - 1;

              // Ensure counts don't go negative
              if (newDailyCount < 0) {
                newDailyCount = 0;
              }
              if (newTotalCount < 0) {
                newTotalCount = 0;
              }

              // Update Supabase with decremented counts
              await client
                  .from('user_quotas')
                  .update({
                    'daily_gen_count': newDailyCount,
                    'total_gen_count': newTotalCount,
                    'updated_at': DateTime.now().toIso8601String(),
                  })
                  .eq('user_id', supabaseUser.id);

              debugPrint('✅ Refund synced to Supabase: daily=$newDailyCount, total=$newTotalCount');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Failed to rollback Supabase quota: $e');
          // Continue anyway - local refund is more important
        }
      }

      debugPrint('✅ Quota refunded successfully');
    } catch (e) {
      debugPrint('⚠️ Failed to refund quota: $e');
    }
  }
}

/// Custom exception for image analysis errors
class _ImageAnalysisException implements Exception {
  final String message;
  final String errorCode;

  _ImageAnalysisException(this.message, this.errorCode);
}
