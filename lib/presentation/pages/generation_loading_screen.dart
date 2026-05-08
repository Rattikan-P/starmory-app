import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../../data/models/vocabulary_model.dart';
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
  ConsumerState<GenerationLoadingScreen> createState() => _GenerationLoadingScreenState();
}

class _GenerationLoadingScreenState extends ConsumerState<GenerationLoadingScreen>
    with TickerProviderStateMixin {
  int _currentPhase = 1;
  String? _errorMessage;
  bool _isProcessing = true;

  // Phase descriptions
  final List<String> _phaseDescriptions = [
    'Analyzing your photo...',
    'Mapping vocabulary to your level...',
    'Generating contextual sentences...',
  ];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat();

    // Start generation
    _startGeneration();
  }

  @override
  void dispose() {
    _pulseController.dispose();
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
        throw _ImageAnalysisException('Image resolution too low for AI analysis', 'A1');
      }

      // Phase 1: Scene Analysis
      setState(() => _currentPhase = 1);
      await Future.delayed(const Duration(milliseconds: 800)); // Visual feedback

      final geminiService = ref.read(geminiServiceProvider);

      // Phase 2: Functional Mapping
      setState(() => _currentPhase = 2);
      await Future.delayed(const Duration(milliseconds: 800)); // Visual feedback

      // Phase 3: Complete Generation
      setState(() => _currentPhase = 3);

      final result = await geminiService.extractVocabulary(
        imageData: imageData,
        level: widget.cefrLevel,
        category: 'Daily Life', // Default for now
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
        // Get readable error message
        String errorMessage;
        if (e.toString().contains('Instance of')) {
          errorMessage = 'AI service initialization failed. Please check your API key.';
        } else if (e.toString().contains('NotInitializedError')) {
          errorMessage = 'AI service is not ready. Please try again.';
        } else {
          errorMessage = e.toString().replaceAll('Exception: ', '');
        }

        setState(() {
          _errorMessage = 'Error: $errorMessage';
          _isProcessing = false;
        });

        // Check if it's a network/API error (E2)
        if (errorMessage.toLowerCase().contains('network') ||
            errorMessage.toLowerCase().contains('connection') ||
            errorMessage.toLowerCase().contains('timeout') ||
            errorMessage.toLowerCase().contains('api key')) {
          _handleNetworkError(errorMessage);
        } else {
          // Otherwise treat as image analysis error (A1)
          _handleImageError('A1', errorMessage);
        }
      }
    }
  }

  void _showResult(dynamic result) {
    // Navigate to Interactive Vocabulary Screen with extraction result
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
    // A1: Image clarity/parsing error
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
        content: Column(
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
                  const Text('• Try different angles if needed'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Close dialog and go back to image picker
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to image preview
              // Then navigate to image picker
              Navigator.pop(context); // Go back to image picker
            },
            child: const Text('Try Different Photo'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to image preview
            },
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  void _handleNetworkError(String error) {
    // E2: Network error
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
        content: Column(
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
                  const Text('• Server might be busy - please wait'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startGeneration(); // Retry
            },
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6C63FF),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Logo
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.auto_awesome,
                          size: 60,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Title
                if (_isProcessing) ...[
                  const Text(
                    'Creating Your Vocabulary',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  Text(
                    _phaseDescriptions[_currentPhase - 1],
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Progress Indicators
                  _buildPhaseIndicator(1, 'Scene Analysis', _currentPhase >= 1),
                  const SizedBox(height: 16),
                  _buildPhaseIndicator(2, 'Functional Mapping', _currentPhase >= 2),
                  const SizedBox(height: 16),
                  _buildPhaseIndicator(3, 'Sentence Synthesis', _currentPhase >= 3),
                ] else if (_errorMessage != null) ...[
                  // Error State
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Generation Failed',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseIndicator(int phaseNumber, String label, bool isActive) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isActive
                ? Icon(
                    phaseNumber < _currentPhase ? Icons.check : Icons.hourglass_empty,
                    size: 18,
                    color: const Color(0xFF6C63FF),
                  )
                : Text(
                    '$phaseNumber',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: isActive ? Colors.white : Colors.white.withOpacity(0.6),
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
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
