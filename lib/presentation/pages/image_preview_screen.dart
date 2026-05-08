import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import 'generation_loading_screen.dart';

/// Image Preview Screen - Preview and confirm photo selection
class ImagePreviewScreen extends ConsumerStatefulWidget {
  final String imagePath;

  const ImagePreviewScreen({
    super.key,
    required this.imagePath,
  });

  @override
  ConsumerState<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends ConsumerState<ImagePreviewScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Photo'),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: _isProcessing ? null : _retakePhoto,
            icon: const Icon(Icons.refresh),
            label: const Text('Retake'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Image Preview
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(widget.imagePath),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // Info Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ready to Generate Vocabulary?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This will analyze your photo and generate contextual vocabulary with AI.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoCard(),
                ],
              ),
            ),

            // Use Photo Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _usePhoto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    _isProcessing ? 'Processing...' : 'Use Photo',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final canGenerate = ref.watch(canGenerateProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: canGenerate
            ? const Color(0xFF6C63FF).withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: canGenerate
              ? const Color(0xFF6C63FF).withOpacity(0.3)
              : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            canGenerate ? Icons.check_circle : Icons.warning,
            color: canGenerate ? const Color(0xFF6C63FF) : Colors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  canGenerate ? 'Ready to generate!' : 'Quota Limit Reached',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: canGenerate ? const Color(0xFF6C63FF) : Colors.orange,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  canGenerate
                      ? 'This will use 1 generation from your allowance'
                      : 'Upgrade to Pro for unlimited generations',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _retakePhoto() {
    Navigator.pop(context);
  }

  Future<void> _usePhoto() async {
    setState(() => _isProcessing = true);

    try {
      // Check quota and deduct
      final notifier = ref.read(userStateProvider.notifier);
      final success = await notifier.recordQuotaUsage(
        imageId: widget.imagePath,
      );

      if (!success) {
        if (mounted) {
          setState(() => _isProcessing = false);
          _showErrorDialog(
            'Quota Limit Reached',
            'You have reached your generation limit. Please upgrade to Pro for unlimited vocabulary generation.',
          );
        }
        return;
      }

      // Get user's default CEFR level and communicative function
      final user = ref.read(currentUserProvider);
      final defaultCefrLevel = user?.preferences['defaultCefrLevel'] as String? ?? 'A1';
      final defaultCommunicativeFunction = 'Indicative'; // Default for now

      // Navigate directly to Generation Loading Screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GenerationLoadingScreen(
              imagePath: widget.imagePath,
              cefrLevel: defaultCefrLevel,
              communicativeFunction: defaultCommunicativeFunction,
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isProcessing = false);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
