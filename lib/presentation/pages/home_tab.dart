import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../providers/providers.dart';
import '../providers/scrapbook_provider.dart';
import '../providers/navigation_provider.dart';
import '../../data/models/scrapbook_model.dart';
import 'image_preview_screen.dart';
import 'edit_scrapbook_screen.dart';
import 'auth/account_method_page.dart';
import 'profile_tab.dart';
import '../widgets/galaxy_screen_background.dart';
import '../widgets/scrapbook_detail_sheet.dart';
import '../widgets/scrapbook_polaroid.dart';

/// Home Tab - Main screen with AI generation
/// Redesigned to feel warm, welcoming, and pressure-free
class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab>
    with TickerProviderStateMixin {
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Refresh user data when home page is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshUserData();
    });
  }

  Future<void> _refreshUserData() async {
    final userNotifier = ref.read(userStateProvider.notifier);
    final currentUser = ref.read(userStateProvider).user;
    // Only refresh if user is logged in (not guest)
    if (currentUser != null && !currentUser.isGuest) {
      try {
        await userNotifier.refreshUserFromSupabase();
        print('✅ Home page: User data refreshed');
      } catch (e) {
        print('⚠️ Home page: Failed to refresh user data: $e');
      }
    }
  }

  // Daily motivational quotes
  final List<DailyQuote> _quotes = const [
    DailyQuote(
      emoji: '✨',
      text: 'Small moments make beautiful memories',
      subtext: 'Capture something today',
    ),
    DailyQuote(
      emoji: '🌟',
      text: 'One word at a time, one star at a time',
      subtext: 'Your journey is uniquely yours',
    ),
    DailyQuote(
      emoji: '💫',
      text: 'Every photo tells a story waiting to be learned',
      subtext: 'What will you discover today?',
    ),
    DailyQuote(
      emoji: '🌙',
      text: 'Progress, not perfection',
      subtext: 'Take it at your own pace',
    ),
    DailyQuote(
      emoji: '☀️',
      text: 'The world is your classroom',
      subtext: 'Learn from what you see',
    ),
  ];

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileTab()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userStateProvider);
    final quote = _quotes[DateTime.now().day % _quotes.length];

    return Scaffold(
      body: GalaxyScreenBackground(
        child: Column(
          children: [
            // Status bar spacer
            SizedBox(
              height: MediaQuery.of(context).padding.top,
            ),
            // Main content
            Expanded(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),

                      // Header with warm greeting
                      _buildHeader(context, userState),

                      const SizedBox(height: 20),

                      // Daily motivation + Quick Actions combined
                      _buildActionCard(context, quote),

                      const SizedBox(height: 20),

                      // Subtle quota indicator (only if needed)
                      _buildSubtleQuotaIndicator(context),

                      const SizedBox(height: 24),

                      // Recent Scrapbook
                      _buildRecentScrapbook(context),

                      const SizedBox(height: 100), // Extra space at bottom
                    ],
                  ),
                ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, UserState userState) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else if (hour < 21) {
      greeting = 'Good evening';
    } else {
      greeting = 'Good night';
    }

    final userName = userState.user?.displayName ?? 'Guest';

    IconData getTimeIcon() {
      if (hour < 12) return Icons.wb_sunny_rounded;
      if (hour < 17) return Icons.wb_twilight_rounded;
      if (hour < 21) return Icons.nights_stay_rounded;
      return Icons.bedtime_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF8b5cf6),
            Color(0xFF7c3aed),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8b5cf6).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            getTimeIcon(),
            size: 42,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: GoogleFonts.lexend(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (() {
                    final display = userName.length > 11
                        ? '${userName.substring(0, 11)}...'
                        : userName;
                    return display;
                  })(),
                  style: GoogleFonts.lexend(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  overflow: TextOverflow.visible,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openProfile,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFC4B5FD), Color(0xFFA78BFA)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8b5cf6).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: userState.user?.photoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: userState.user!.photoUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: Text(
                              userState.user?.displayNameOrEmail[0].toUpperCase() ?? 'G',
                              style: GoogleFonts.lexend(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 22,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Center(
                            child: Text(
                              userState.user?.displayNameOrEmail[0].toUpperCase() ?? 'G',
                              style: GoogleFonts.lexend(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 22,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            userState.user?.displayNameOrEmail[0].toUpperCase() ?? 'G',
                            style: GoogleFonts.lexend(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 22,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, DailyQuote quote) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFE2D1F9).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quote section
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFDE68A), // ส้มเหลืองอ่อนกว่า
                      Color(0xFFFBCFE8), // ชมพู่อ่อนกว่า
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    quote.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quote.text,
                      style: GoogleFonts.lexend(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1f2937),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      quote.subtext,
                      style: GoogleFonts.lexend(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF9ca3af),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickImage(ImageSource.camera),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF60a5fa),
                          Color(0xFF3b82f6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF60a5fa).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Camera',
                          style: GoogleFonts.lexend(
                            fontSize: 16,
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
                child: GestureDetector(
                  onTap: () => _pickImage(ImageSource.gallery),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFa78bfa),
                          Color(0xFF8b5cf6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFa78bfa).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Gallery',
                          style: GoogleFonts.lexend(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubtleQuotaIndicator(BuildContext context) {
    final userState = ref.watch(userStateProvider);
    final user = userState.user;

    if (user == null) return const SizedBox.shrink();

    final isGuest = user.isGuest;
    final quotaManager = user.quotaManager;
    final todayUsage = quotaManager.getTodayUsage();
    final dailyLimit = quotaManager.dailyLimit;
    final totalUsage = quotaManager.usageHistory.length;
    final totalLimit = quotaManager.totalLimit;

    final totalReached = totalUsage >= totalLimit;
    final canGenerate = user.canGenerate;
    final remainingDaily = dailyLimit - todayUsage;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFE2D1F9).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: canGenerate
                  ? const Color(0xFFF3F4F6)
                  : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                canGenerate ? '📸' : '✨',
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  canGenerate
                      ? '$remainingDaily generations left today'
                      : (totalReached && isGuest ? 'That\'s all for now!' : 'See you tomorrow'),
                  style: GoogleFonts.lexend(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1f2937),
                  ),
                ),
                if (canGenerate)
                  Text(
                    'Keep capturing memories',
                    style: GoogleFonts.lexend(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF9ca3af),
                    ),
                  )
                else if (!totalReached || !isGuest)
                  Text(
                    'Continue your journey tomorrow',
                    style: GoogleFonts.lexend(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF9ca3af),
                    ),
                  )
                else
                  Text(
                    'Save your progress forever',
                    style: GoogleFonts.lexend(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF9ca3af),
                    ),
                  ),
              ],
            ),
          ),
          if (isGuest && !canGenerate && totalReached)
            GestureDetector(
              onTap: () {
                AccountMethodPage.show(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFa78bfa), Color(0xFF8b5cf6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8b5cf6).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'Save my stars',
                  style: GoogleFonts.lexend(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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

        // Save the image to permanent storage to prevent OS from deleting it
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

  /// Save the picked image to the app's permanent documents directory
  /// This prevents the image from being deleted when the OS clears the cache
  Future<String> _saveImagePermanently(String sourcePath) async {
    try {
      // Get the app's documents directory
      final appDir = await getApplicationDocumentsDirectory();

      // Create a subdirectory for vocabulary images
      final vocabDir = Directory('${appDir.path}/vocabulary_images');
      if (!await vocabDir.exists()) {
        await vocabDir.create(recursive: true);
      }

      // Generate a unique filename using timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(sourcePath);
      final fileName = 'vocab_$timestamp$extension';
      final targetPath = '${vocabDir.path}/$fileName';

      // Copy the file to the permanent location
      final sourceFile = File(sourcePath);
      await sourceFile.copy(targetPath);

      debugPrint('✅ Image saved permanently to: $targetPath');
      return targetPath;
    } catch (e) {
      debugPrint('❌ Error saving image permanently: $e');
      // Return the original path if copying fails
      return sourcePath;
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
    final scrapbookState = ref.watch(scrapbookStateProvider);
    final recentScrapbooks = scrapbookState.recentScrapbooks;

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
            TextButton.icon(
              onPressed: () =>
                  ref.read(navigationProvider.notifier).goScrapbook(),
              icon: const Icon(Icons.history_rounded, size: 21),
              label: Text(
                'View All',
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF5036A6),
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        recentScrapbooks.isEmpty
            ? _buildEmptyScrapbookState(context)
            : _buildScrapbookList(context, recentScrapbooks),
      ],
    );
  }

  /// Empty state for when no scrapbooks exist
  Widget _buildEmptyScrapbookState(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE8E5EC),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFF3F4F6),
                    const Color(0xFFE5E7EB).withValues(alpha: 0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                size: 28,
                color: Color(0xFF9ca3af),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No memories yet',
              style: GoogleFonts.lexend(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6b7280),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Start capturing moments today',
              style: GoogleFonts.lexend(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF9ca3af),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Horizontal list of scrapbook cards
  Widget _buildScrapbookList(BuildContext context, List<ScrapbookModel> scrapbooks) {
    return SizedBox(
      height: ScrapbookPolaroid.listExtent,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: scrapbooks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final scrapbook = scrapbooks[index];
          return _buildScrapbookCard(context, scrapbook, index);
        },
      ),
    );
  }

  Widget _buildScrapbookCard(BuildContext context, ScrapbookModel scrapbook, int index) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return _buildScrapbookCardInteractive(context, scrapbook);
    }

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 220 + (index * 35)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(18 * (1 - value), 0),
          child: Opacity(
            opacity: value,
            child: _buildScrapbookCardInteractive(context, scrapbook),
          ),
        );
      },
    );
  }

  Widget _buildScrapbookCardInteractive(
      BuildContext context, ScrapbookModel scrapbook) {
    return ScrapbookPolaroid(
      imagePath: scrapbook.imagePath,
      backgroundColor: Color(scrapbook.backgroundColor),
      vocabularyCount: scrapbook.vocabularyWords.length,
      semanticLabel: 'Open scrapbook from ${_formatDate(scrapbook.date)}',
      onTap: () => _showScrapbookBottomSheet(context, scrapbook),
    );
  }

  Widget _buildLegacyScrapbookCardInteractive(BuildContext context, ScrapbookModel scrapbook) {
    final vocabCount = scrapbook.vocabularyWords.length;

    return GestureDetector(
      onTap: () => _showScrapbookBottomSheet(context, scrapbook),
      child: Container(
        width: 140,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Polaroid frame
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Photo area
                  Flexible(
                    flex: 5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: scrapbook.imagePath.startsWith('http')
                          ? CachedNetworkImage(
                              imageUrl: scrapbook.imagePath,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              placeholder: (context, url) => Container(
                                color: const Color(0xFFF3F4F6),
                                child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF8b5cf6),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) {
                                return Container(
                                  color: const Color(0xFFE5E7EB),
                                  child: const Icon(
                                    Icons.broken_image,
                                    size: 24,
                                    color: Color(0xFF9ca3af),
                                  ),
                                );
                              },
                            )
                          : Image.file(
                              File(scrapbook.imagePath),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: const Color(0xFFE5E7EB),
                                  child: const Icon(
                                    Icons.broken_image,
                                    size: 24,
                                    color: Color(0xFF9ca3af),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // White bottom area (polaroid style)
                  Flexible(
                    flex: 1,
                    child: Container(
                      width: double.infinity,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // Star badge on top-right
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '⭐',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '$vocabCount',
                      style: GoogleFonts.lexend(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showScrapbookBottomSheet(BuildContext context, ScrapbookModel scrapbook) {
    showScrapbookDetailSheet(context, scrapbooks: [scrapbook]);
  }

  String _formatDate(DateTime date) {
    final month = _getMonthAbbreviation(date.month);
    final day = date.day;
    return '$day $month ${date.year}';
  }

  String _getMonthAbbreviation(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}

/// Bottom Sheet Widget for displaying a single scrapbook detail
class _ScrapbookDetailBottomSheet extends StatelessWidget {
  final ScrapbookModel scrapbook;
  final ScrollController scrollController;

  const _ScrapbookDetailBottomSheet({
    required this.scrapbook,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8b5cf6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      '${scrapbook.date.day}',
                      style: GoogleFonts.lexend(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8b5cf6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getMonthName(scrapbook.date.month)} ${scrapbook.date.year}',
                        style: GoogleFonts.lexend(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1f2937),
                        ),
                      ),
                      Text(
                        '1 memory',
                        style: GoogleFonts.lexend(
                          fontSize: 14,
                          color: const Color(0xFF6b7280),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF6b7280)),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Scrapbook card (same format as calendar)
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                _buildScrapbookCard(context),
              ],
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildScrapbookCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditScrapbookScreen(
              scrapbookId: scrapbook.id,
              imagePath: scrapbook.imagePath,
              vocabularyWords: scrapbook.vocabularyWords,
              englishSentence: scrapbook.englishSentence,
              thaiSentence: scrapbook.thaiSentence,
              selectedEmoji: scrapbook.selectedEmoji,
              date: scrapbook.date,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: const Color(0xFFE2D1F9).withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: scrapbook.imagePath.startsWith('http')
                    ? Image.network(
                        scrapbook.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade100,
                            child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                          );
                        },
                      )
                    : Image.file(
                        File(scrapbook.imagePath),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade100,
                            child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                          );
                        },
                      ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Emoji and English sentence
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scrapbook.selectedEmoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          scrapbook.englishSentence.isNotEmpty
                              ? scrapbook.englishSentence
                              : 'No sentence',
                          style: GoogleFonts.lexend(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1f2937),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (scrapbook.thaiSentence.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 36),
                      child: Text(
                        scrapbook.thaiSentence,
                        style: GoogleFonts.lexend(
                          fontSize: 14,
                          color: const Color(0xFF6b7280),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],

                  // Vocabulary words
                  if (scrapbook.vocabularyWords.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: scrapbook.vocabularyWords.map((word) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8b5cf6).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: word.word,
                                  style: GoogleFonts.lexend(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF8b5cf6),
                                  ),
                                ),
                                const TextSpan(
                                  text: ' - ',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF6b7280)),
                                ),
                                TextSpan(
                                  text: word.thaiTranslation,
                                  style: GoogleFonts.lexend(
                                    fontSize: 13,
                                    color: const Color(0xFF6b7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}

// Falling star widget (from onboarding)
// Daily quote data class
class DailyQuote {
  final String emoji;
  final String text;
  final String subtext;

  const DailyQuote({
    required this.emoji,
    required this.text,
    required this.subtext,
  });
}
