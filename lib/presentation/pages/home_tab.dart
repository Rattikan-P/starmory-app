import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/providers.dart';
import 'image_preview_screen.dart';
import 'auth/account_method_page.dart';

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
            top: 50,
            right: -100,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF93C5FD).withValues(alpha: 0.5),
                    const Color(0x0093C5FD),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
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
        ],
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
              style: GoogleFonts.lexend(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1f2937),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Hi, ${userState.user?.displayNameOrEmail.split('@')[0] ?? 'Guest'}! 👋',
              style: GoogleFonts.lexend(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF6b7280),
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            // TODO: Open profile
          },
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                userState.user?.displayNameOrEmail[0].toUpperCase() ?? 'G',
                style: GoogleFonts.lexend(
                  color: const Color(0xFF8b5cf6),
                  fontWeight: FontWeight.w600,
                  fontSize: 22,
                ),
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
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                color: const Color(0xFF60a5fa),
                onTap: () => _pickImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                color: const Color(0xFFa78bfa),
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
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: canGenerate
                  ? const Color(0xFF8b7cf6).withValues(alpha: 0.15)
                  : Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              canGenerate ? Icons.auto_awesome_rounded : Icons.warning_amber_rounded,
              color: canGenerate ? const Color(0xFF8b5cf6) : Colors.orange,
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
                  style: GoogleFonts.lexend(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1f2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isGuest
                      ? 'Guest: $todayUsage/$dailyLimit today • $totalUsage/$totalLimit total'
                      : '$todayUsage/$dailyLimit today',
                  style: GoogleFonts.lexend(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF6b7280),
                  ),
                ),
              ],
            ),
          ),
          if (isGuest && !canGenerate)
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8b7cf6), Color(0xFF7c6ff5)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8b7cf6).withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AccountMethodPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Sign Up',
                  style: GoogleFonts.lexend(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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

      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '$type Permission Required',
          style: GoogleFonts.lexend(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1f2937),
          ),
        ),
        content: Text(
          'Please grant $type permission to continue.',
          style: GoogleFonts.lexend(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF6b7280),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF9ca3af),
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.lexend(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8b5cf6),
            ),
            child: Text(
              'Settings',
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

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: GoogleFonts.lexend(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1f2937),
          ),
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
            onPressed: () => Navigator.pop(context),
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

  Widget _buildRecentScrapbook(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Scrapbook',
              style: GoogleFonts.lexend(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1f2937),
              ),
            ),
            GestureDetector(
              onTap: () {
                // TODO: Navigate to Scrapbook tab
              },
              child: Text(
                'See All',
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  color: const Color(0xFF8b5cf6),
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
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 32,
                  color: const Color(0xFF9ca3af),
                ),
                const SizedBox(height: 8),
                Text(
                  'No memories yet',
                  style: GoogleFonts.lexend(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF6b7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Start capturing moments!',
                  style: GoogleFonts.lexend(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF9ca3af),
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.lexend(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1f2937),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
