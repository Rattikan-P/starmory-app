import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      // Read image file
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

      // Phase 1: Scene Analysis (mock delay)
      setState(() => _currentPhase = 1);
      await Future.delayed(const Duration(seconds: 5));

      final geminiService = ref.read(geminiServiceProvider);

      // Phase 2: Detect vocabulary (mock delay)
      setState(() => _currentPhase = 2);
      await Future.delayed(const Duration(seconds: 5));

      // Phase 3: Complete Generation - set to phase 3 but NOT complete yet
      setState(() => _currentPhase = 3);

      // Actual API call happens here
      final result = await geminiService.extractVocabulary(
        imageData: imageData,
        level: widget.cefrLevel,
        category: 'Daily Life',
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
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text('Image Analysis Failed'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tips for better results:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[900],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('• Use clear, well-lit photos'),
                    const Text('• Ensure main objects are visible'),
                    const Text('• Avoid blurry or low-resolution images'),
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
            child: const Text('OK'),
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
        title: Row(
          children: [
            Icon(Icons.cloud_off, color: Colors.red[700]),
            const SizedBox(width: 8),
            const Text('Connection Error'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Unable to connect to AI service: $error'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Possible solutions:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red[900],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('• Check your internet connection'),
                    const Text('• Try again in a moment'),
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
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0F14), Color(0xFF171721), Color(0xFF1F1F2B)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 30),

                // TOP TEXT
                Column(
                  children: [
                    const Text(
                      'Creating Magic ✨',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      _phaseDescriptions[_currentPhase - 1],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: Colors.white.withValues(alpha: 0.65),
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
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
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
                                  Colors.black.withValues(alpha: 0.15),
                                  Colors.black.withValues(alpha: 0.35),
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
                                          const Color(
                                            0xFF8B7CFF,
                                          ).withValues(alpha: 0.5),
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
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF9D97FF),
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'AI Processing',
                                      style: TextStyle(
                                        color: Colors.white,
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
                            ? const Color(0xFF8B7CFF)
                            : Colors.white.withValues(alpha: 0.15),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 20),

                Text(
                  'This may take a few seconds',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
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
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
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
