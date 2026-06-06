import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/providers.dart';
import 'interactive_vocabulary_screen.dart';

/// Generation Loading Screen - Shows AI processing progress
class GenerationLoadingScreen extends ConsumerStatefulWidget {
  final String imagePath;
  final String cefrLevel;
  final String communicativeFunction;

  const GenerationLoadingScreen({
    super.key,
    required this.imagePath,
    required this.cefrLevel,
    required this.communicativeFunction,
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

    // Start generation
    _startGeneration();
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
      ).timeout(
        const Duration(seconds: 90), // 90 second timeout
        onTimeout: () {
          throw TimeoutException('AI processing timed out. Please check your connection and try again.');
        },
      );

      if (mounted) {
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
        String errorMessage;
        if (e.toString().contains('Instance of')) {
          errorMessage =
              'AI service initialization failed. Please check your API key.';
        } else if (e.toString().contains('NotInitializedError')) {
          errorMessage = 'AI service is not ready. Please try again.';
        } else {
          errorMessage = e.toString().replaceAll('Exception: ', '');
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
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => InteractiveVocabularyScreen(
          imagePath: widget.imagePath,
          cefrLevel: widget.cefrLevel,
          communicativeFunction: widget.communicativeFunction,
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF6b7280),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tips for better results:',
                      style: GoogleFonts.lexend(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF92400e),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Use clear, well-lit photos',
                      style: GoogleFonts.lexend(
                        fontSize: 12,
                        color: const Color(0xFF92400e),
                      ),
                    ),
                    Text(
                      '• Ensure main objects are visible',
                      style: GoogleFonts.lexend(
                        fontSize: 12,
                        color: const Color(0xFF92400e),
                      ),
                    ),
                    Text(
                      '• Avoid blurry or low-resolution images',
                      style: GoogleFonts.lexend(
                        fontSize: 12,
                        color: const Color(0xFF92400e),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Connection Error',
                style: GoogleFonts.lexend(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1f2937),
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unable to connect to AI service: $error',
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF6b7280),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Possible solutions:',
                      style: GoogleFonts.lexend(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF991b1b),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Check your internet connection',
                      style: GoogleFonts.lexend(
                        fontSize: 12,
                        color: const Color(0xFF991b1b),
                      ),
                    ),
                    Text(
                      '• Try again in a moment',
                      style: GoogleFonts.lexend(
                        fontSize: 12,
                        color: const Color(0xFF991b1b),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
}

/// Custom exception for image analysis errors
class _ImageAnalysisException implements Exception {
  final String message;
  final String errorCode;

  _ImageAnalysisException(this.message, this.errorCode);
}
