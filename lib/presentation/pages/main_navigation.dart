import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_tab.dart';
import 'review_tab.dart';
import 'scrapbook_tab.dart';
import 'progress_tab.dart';
import 'image_preview_screen.dart';
import 'auth/account_method_page.dart';
import '../providers/providers.dart';
import '../providers/navigation_provider.dart';

// Track last synced user ID to ensure syncing when switching accounts
String? _lastSyncedUserId;

/// Main Navigation Screen with Floating Bottom Navigation Bar
class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final List<Widget> _tabs = const [
    HomeTab(),
    ReviewTab(),
    ScrapbookTab(),
    ProgressTab(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncOnAppOpen();
    });
  }

  Future<void> _syncOnAppOpen() async {
    final currentSession = Supabase.instance.client.auth.currentSession;
    final currentUserId = currentSession?.user.id;

    if (currentSession == null || currentUserId == null) {
      print('ℹ️ [App Open] Skipping sync (not logged in)');
      _lastSyncedUserId = null;
      return;
    }

    if (_lastSyncedUserId == currentUserId) {
      print('ℹ️ [App Open] Skipping sync (already synced for user $currentUserId)');
      return;
    }

    try {
      print('🔄 [App Open] Starting auto sync for user $currentUserId...');
      final hiveService = ref.read(hiveServiceProvider);
      final vocabSyncService = ref.read(vocabularySyncServiceProvider);

      final localVocabs = await hiveService.getAllVocabulary();
      final syncedVocabs = await vocabSyncService.mergeWithCloud(localVocabs);

      await hiveService.clearAllVocabulary();
      for (final vocab in syncedVocabs) {
        await hiveService.saveVocabulary(vocab);
      }
      print('✅ [App Open] Sync complete! Total vocabularies: ${syncedVocabs.length}');
      await ref.read(vocabularyStateProvider.notifier).refresh();

      _lastSyncedUserId = currentUserId;
    } catch (e) {
      print('❌ [App Open] Sync failed: $e');
    }
  }

  void _showQuickAddModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Capture a New Memory',
              style: GoogleFonts.lexend(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Turn your photos into English words & stories',
              style: GoogleFonts.lexend(
                fontSize: 13,
                color: const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Camera',
                            style: GoogleFonts.lexend(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFDDD6FE), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.photo_library_outlined, color: Color(0xFF7C3AED), size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Gallery',
                            style: GoogleFonts.lexend(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF7C3AED),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final user = ref.read(userStateProvider).user;
    if (user != null && !user.canGenerate) {
      _showQuotaLimitDialog(user.isGuest);
      return;
    }

    try {
      if (source == ImageSource.camera) {
        final cameraStatus = await Permission.camera.request();
        if (!cameraStatus.isGranted) {
          _showPermissionDialog('Camera');
          return;
        }
      } else if (source == ImageSource.gallery) {
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

        final permanentPath = await _saveImagePermanently(image.path);

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImagePreviewScreen(imagePath: permanentPath),
          ),
        );
      }
    } catch (e) {
      _showErrorDialog('Error', 'Failed to pick image: ${e.toString()}');
    }
  }

  Future<String> _saveImagePermanently(String sourcePath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final vocabDir = Directory('${appDir.path}/vocabulary_images');
      if (!await vocabDir.exists()) {
        await vocabDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(sourcePath);
      final targetPath = '${vocabDir.path}/vocab_$timestamp$extension';

      final sourceFile = File(sourcePath);
      await sourceFile.copy(targetPath);
      return targetPath;
    } catch (e) {
      debugPrint('Error saving image permanently: $e');
      return sourcePath;
    }
  }

  void _showQuotaLimitDialog(bool isGuest) {
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
                isGuest ? 'Free Trial Limit' : 'Daily Limit Reached',
                style: GoogleFonts.lexend(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
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
                  ? "You've used all your guest generations. Sign up to get 15 daily generations!"
                  : "You've reached your 15 daily generations. Come back tomorrow for more!",
              style: GoogleFonts.lexend(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
            if (isGuest) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFF8B5CF6), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '15 generations everyday with free account!',
                        style: GoogleFonts.lexend(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF7C3AED),
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
                Navigator.pop(context);
                AccountMethodPage.show(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
            ),
            child: Text(
              isGuest ? 'Later' : 'OK',
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
            color: const Color(0xFF1F2937),
          ),
        ),
        content: Text(
          'Please grant $type permission to continue.',
          style: GoogleFonts.lexend(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF6B7280),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF9CA3AF),
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
              foregroundColor: const Color(0xFF8B5CF6),
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
            color: const Color(0xFF1F2937),
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.lexend(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF6B7280),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8B5CF6),
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
    final currentIndex = ref.watch(navigationProvider).currentIndex;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          IndexedStack(
            index: currentIndex,
            children: _tabs,
          ),
          // Floating Bottom Navigation Bar
          Positioned(
            left: 16,
            right: 16,
            bottom: 22,
            child: _buildFloatingNavBar(currentIndex),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingNavBar(int currentIndex) {
    return SizedBox(
      height: 74,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // 1. Center Arch / White Dome Background for the FAB
          Positioned(
            top: -12,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
            ),
          ),

          // 2. Main White Rounded Capsule Bar
          Container(
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Left side: Home & Review (Equal width slots)
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildNavItem(
                          index: 0,
                          currentIndex: currentIndex,
                          icon: Icons.home_rounded,
                          label: 'Home',
                        ),
                      ),
                      Expanded(
                        child: _buildNavItem(
                          index: 1,
                          currentIndex: currentIndex,
                          icon: Icons.refresh_rounded,
                          label: 'Review',
                        ),
                      ),
                    ],
                  ),
                ),

                // Center gap for the FAB
                const SizedBox(width: 60),

                // Right side: Scrapbook & Progress (Equal width slots)
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildNavItem(
                          index: 2,
                          currentIndex: currentIndex,
                          icon: Icons.menu_book_rounded,
                          label: 'Scrapbook',
                        ),
                      ),
                      Expanded(
                        child: _buildNavItem(
                          index: 3,
                          currentIndex: currentIndex,
                          icon: Icons.bar_chart_rounded,
                          label: 'Progress',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Center Gradient FAB (+) Button
          Positioned(
            top: -6,
            child: GestureDetector(
              onTap: () => _showQuickAddModal(context),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Color(0xFFD6C8FF), // soft pastel lavender
                      Color(0xFFFDE1EB), // soft pastel pink
                      Color(0xFFFFDFBA), // soft warm peach/champagne
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.20),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.add_rounded,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required int currentIndex,
    required IconData icon,
    required String label,
  }) {
    final isSelected = currentIndex == index;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ref.read(navigationProvider.notifier).setIndex(index);
          },
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            width: 58,
            height: 48,
            decoration: isSelected
                ? BoxDecoration(
                    color: const Color(0xFFF1EEFF),
                    borderRadius: BorderRadius.circular(22),
                  )
                : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: isSelected
                      ? const Color(0xFF7047EB)
                      : const Color(0xFF857E9E),
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style: GoogleFonts.lexend(
                        fontSize: 10.5,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFF7047EB)
                            : const Color(0xFF857E9E),
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
