import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/providers.dart';
import 'image_preview_screen.dart';

/// Home Tab - Main screen with AI generation
class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  final ImagePicker _imagePicker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userStateProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(context, userState),
              const SizedBox(height: 24),

              // Quick Actions
              _buildQuickActions(context),

              // Quota Status
              _buildQuotaStatus(context),

              const SizedBox(height: 20),

              // Recent Scrapbook
              _buildRecentScrapbook(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, UserState userState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '✨ Starmory',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Hi, ${userState.user?.displayNameOrEmail.split('@')[0] ?? 'Guest'}! 👋',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            // TODO: Open profile
          },
          child: CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF6C63FF).withOpacity(0.1),
            child: Text(
              userState.user?.displayNameOrEmail[0].toUpperCase() ?? 'G',
              style: const TextStyle(
                color: Color(0xFF6C63FF),
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.camera_alt,
                label: 'Camera',
                color: const Color(0xFF6C63FF),
                onTap: () => _pickImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.photo_library,
                label: 'Gallery',
                color: const Color(0xFF4CAF50),
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuotaStatus(BuildContext context) {
    final userState = ref.watch(userStateProvider);
    final user = userState.user;

    if (user == null) return const SizedBox.shrink();

    final quotaManager = user.quotaManager;
    final canGenerate = user.canGenerate;
    final isGuest = user.isGuest;

    final todayUsage = quotaManager.getTodayUsage();
    final dailyLimit = quotaManager.dailyLimit;
    final totalUsage = quotaManager.usageHistory.length;
    final totalLimit = quotaManager.totalLimit;

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: canGenerate
              ? [const Color(0xFF6C63FF).withValues(alpha: 0.1), const Color(0xFF8B7CFF).withValues(alpha: 0.05)]
              : [Colors.orange.withValues(alpha: 0.1), Colors.orange.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: canGenerate ? const Color(0xFF6C63FF).withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: canGenerate
                  ? const Color(0xFF6C63FF).withValues(alpha: 0.15)
                  : Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              canGenerate ? Icons.auto_awesome_rounded : Icons.warning_amber_rounded,
              color: canGenerate ? const Color(0xFF6C63FF) : Colors.orange,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  canGenerate ? 'Generations available' : 'Quota limit reached',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: canGenerate ? const Color(0xFF6C63FF) : Colors.orange,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isGuest
                      ? 'Guest: $todayUsage/$dailyLimit today • $totalUsage/$totalLimit total'
                      : '$todayUsage/$dailyLimit today',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6E6E7A),
                  ),
                ),
              ],
            ),
          ),
          if (isGuest && !canGenerate)
            ElevatedButton(
              onPressed: () {
                // TODO: Navigate to sign up screen
              },
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Sign Up',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Request permissions
      if (source == ImageSource.camera) {
        final cameraStatus = await Permission.camera.request();
        if (!cameraStatus.isGranted) {
          _showPermissionDialog('Camera');
          return;
        }
      } else if (source == ImageSource.gallery) {
        // Request photo library permission
        final photoStatus = await Permission.photos.request();
        if (!photoStatus.isGranted) {
          _showPermissionDialog('Photo Library');
          return;
        }
      }

      // Pick image
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        // Check file format - only allow JPEG and PNG
        final pathLower = image.path.toLowerCase();
        if (pathLower.endsWith('.gif') ||
            pathLower.endsWith('.webp') ||
            image.mimeType == 'image/gif' ||
            image.mimeType == 'image/webp') {
          _showErrorDialog(
            'Unsupported Format',
            'Only JPEG and PNG images are supported. Please select a different photo.',
          );
          return;
        }

        // Navigate to preview
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImagePreviewScreen(imagePath: image.path),
          ),
        );
      }
    } catch (e) {
      _showErrorDialog('Error', 'Failed to pick image: ${e.toString()}');
    }
  }

  void _showPermissionDialog(String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$type Permission Required'),
        content: Text('Please grant $type permission to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentScrapbook(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Scrapbook',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            GestureDetector(
              onTap: () {
                // TODO: Navigate to Scrapbook tab
              },
              child: Text(
                'See All',
                style: TextStyle(
                  fontSize: 14,
                  color: const Color(0xFF6C63FF),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library_outlined, size: 32, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'No memories yet',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Start capturing moments!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
