import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../../core/utils/image_clarity_checker.dart';
import '../../core/utils/quota_manager.dart';
import 'generation_loading_screen.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Column(
          children: [
            // TOP BAR
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  _glassButton(
                    icon: Icons.arrow_back_ios_new,
                    onTap: () => Navigator.pop(context),
                  ),

                  const Spacer(),

                  const Text(
                    'Preview',
                    style: TextStyle(
                      color: Color(0xFF151515),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const Spacer(),

                  _glassButton(
                    icon: Icons.refresh,
                    onTap: _isProcessing ? null : _retakePhoto,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // IMAGE CARD
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: const Color(0xFFECECF3)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B7CFF).withValues(alpha: 0.08),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.file(
                      File(widget.imagePath),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),

            // TEXT + INFO
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ready to Generate ✨',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF151515),
                      letterSpacing: -1,
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'AI will analyze your image and create contextual vocabulary cards instantly.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Color(0xFF6E6E7A),
                    ),
                  ),
                ],
              ),
            ),

            // BUTTON
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 62,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _usePhoto,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF8B7CFF),
                    disabledBackgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.auto_awesome_rounded),
                              SizedBox(width: 10),
                              Text(
                                'Generate Vocabulary',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
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
    );
  }

  Widget _glassButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFECECF3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF151515), size: 18),
      ),
    );
  }

  void _retakePhoto() {
    Navigator.pop(context);
  }

  Future<void> _usePhoto() async {
    setState(() => _isProcessing = true);

    try {
      // Step 1: Check quota
      final notifier = ref.read(userStateProvider.notifier);
      final success = await notifier.recordQuotaUsage(
        imageId: widget.imagePath,
      );

      if (!success) {
        if (mounted) {
          setState(() => _isProcessing = false);
          // Show appropriate dialog based on user type
          final user = ref.read(currentUserProvider);
          _showQuotaLimitDialog(user?.isGuest ?? true);
        }
        return;
      }

      // Step 2: Check image clarity
      final clarityResult =
          await ImageClarityChecker.checkFromFile(widget.imagePath);

      if (!clarityResult.isClear) {
        if (mounted) {
          // Refund quota since image was rejected
          await _refundQuota();
          setState(() => _isProcessing = false);
          _showImageClarityDialog(clarityResult);
        }
        return;
      }

      // Step 3: Get user's default CEFR level and communicative function
      final user = ref.read(currentUserProvider);
      final defaultCefrLevel =
          user?.preferences['defaultCefrLevel'] as String? ?? 'A1';
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

  /// Refund quota when image is rejected
  Future<void> _refundQuota() async {
    // Remove the last usage entry that was just added
    final notifier = ref.read(userStateProvider.notifier);
    final user = ref.read(currentUserProvider);

    if (user != null && user.quotaManager.usageHistory.isNotEmpty) {
      // Create a new quota manager with the last entry removed
      final updatedHistory =
          List<QuotaEntry>.from(user.quotaManager.usageHistory)..removeLast();
      final updatedQuotaManager = QuotaManager(
        totalLimit: user.quotaManager.totalLimit,
        dailyLimit: user.quotaManager.dailyLimit,
        usageHistory: updatedHistory,
      );

      final updatedUser = user.copyWith(quotaManager: updatedQuotaManager);
      await notifier.updateUser(updatedUser);
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

  void _showQuotaLimitDialog(bool isGuest) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Expanded(
              child: Text(
                isGuest ? 'Guest Limit Reached' : 'Daily Limit Reached',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF151515),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          isGuest
              ? "You've used all your guest generations. Create an account to get more generations!"
              : "You've reached your 15 daily generations. Come back tomorrow for more!",
          style: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: Color(0xFF6E6E7A),
          ),
        ),
        actions: [
          if (isGuest)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _isProcessing = false);
                // TODO: Navigate to sign up screen
              },
              child: const Text(
                'Later',
                style: TextStyle(color: Color(0xFF6E6E7A), fontSize: 15),
              ),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isProcessing = false);
            },
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFF8B7CFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(isGuest ? 'Create Account' : 'Got it'),
          ),
        ],
      ),
    );
  }

  void _showImageClarityDialog(ImageClarityResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(
              Icons.blur_on_rounded,
              color: Colors.orange,
              size: 28,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Image Quality Issue',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF151515),
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
              result.message,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Color(0xFF6E6E7A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please try with a clearer, well-lit photo for best results.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6E6E7A), fontSize: 15),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _retakePhoto();
            },
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFF8B7CFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
