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
import '../../data/models/scrapbook_model.dart';
import 'image_preview_screen.dart';
import 'edit_scrapbook_screen.dart';
import 'auth/account_method_page.dart';
import 'profile_tab.dart';
import '../utils/reward_unlock_helper.dart';
import '../widgets/scrapbook_detail_sheet.dart';
import '../widgets/scrapbook_polaroid.dart';
import '../widgets/top_header_actions.dart';

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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Refresh user data when home page is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshUserData();
      _checkPendingRewards();
    });
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
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

  void _checkPendingRewards() {
    if (ref.read(pendingRewardCheckProvider)) {
      ref.read(pendingRewardCheckProvider.notifier).state = false;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && context.mounted) {
          RewardUnlockHelper.checkAndShowUnlocks(context, ref);
        }
      });
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
    _scrollController.dispose();
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
    // Listen for scroll to top signal from tab navigation
    ref.listen<int>(
      navigationProvider.select((s) => s.homeScrollToTopTrigger),
      (previous, next) {
        if (previous != next) {
          _scrollToTop();
        }
      },
    );

    // Listen for pending reward celebration upon returning to Home
    ref.listen<bool>(
      pendingRewardCheckProvider,
      (previous, next) {
        if (next == true) {
          ref.read(pendingRewardCheckProvider.notifier).state = false;
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && context.mounted) {
              RewardUnlockHelper.checkAndShowUnlocks(context, ref);
            }
          });
        }
      },
    );

    final userState = ref.watch(userStateProvider);
    final quote = _quotes[DateTime.now().day % _quotes.length];

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with greeting and profile avatar
              _buildHeader(context, userState),

              const SizedBox(height: 22),

              // Hero Card with "Every photo hides a word you don't know yet."
              _buildHeroCard(context),

              const SizedBox(height: 16),

              // Quota indicator card
              _buildQuotaCard(context),

              const SizedBox(height: 24),

              // Recent Scrapbook
              _buildRecentScrapbook(context),

              const SizedBox(height: 120), // Extra space at bottom for floating nav
            ],
          ),
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
    final avatarLetter = userState.user?.displayNameOrEmail.isNotEmpty == true
        ? userState.user!.displayNameOrEmail[0].toUpperCase()
        : 'G';
    final photoUrl = userState.user?.photoUrl;

    return SizedBox(
      height: 52,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Sun / Weather icon
          const Icon(
            Icons.wb_sunny_rounded,
            size: 32,
            color: Color(0xFF1F2937),
          ),
          const SizedBox(width: 14),
          // Greeting & Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  greeting,
                  style: GoogleFonts.lexend(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF9892A6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  userName,
                  style: GoogleFonts.lexend(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF221F33),
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Top Header Actions (Streak + Shield + Profile Avatar)
          TopHeaderActions(
            onProfileTap: _openProfile,
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final userState = ref.watch(userStateProvider);
    final user = userState.user;
    final canGenerate = user?.canGenerate ?? false;
    final isGuest = user?.isGuest ?? true;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFE5C2), // rich warm peach/champagne
            Color(0xFFFDCFE0), // rich rose pastel pink
            Color(0xFFDFD2FD), // rich lilac lavender
            Color(0xFFCEC2FD), // soft vivid violet purple
          ],
          stops: [0.0, 0.32, 0.70, 1.0],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background decorative outline stars
          Positioned(
            top: -15,
            right: -25,
            child: Icon(
              Icons.star_border_rounded,
              size: 150,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 30,
            child: Icon(
              Icons.star_border_rounded,
              size: 75,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Every photo hides a\nword you don't know\nyet.",
                  style: GoogleFonts.lexend(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2E244F),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 24),
                // Action buttons: Camera & Gallery
                Row(
                  children: [
                    // Camera Button
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: canGenerate
                              ? () => _pickImage(ImageSource.camera)
                              : () => _showQuotaLimitDialog(isGuest),
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF8B5CF6),
                                  Color(0xFF7C3AED),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(30),
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
                                const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
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
                    ),
                    const SizedBox(width: 12),
                    // Gallery Button
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: canGenerate
                              ? () => _pickImage(ImageSource.gallery)
                              : () => _showQuotaLimitDialog(isGuest),
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: const Color(0xFFDDD6FE),
                                width: 1.5,
                              ),
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
                                const Icon(
                                  Icons.photo_library_outlined,
                                  color: Color(0xFF7C3AED),
                                  size: 20,
                                ),
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
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaCard(BuildContext context) {
    final userState = ref.watch(userStateProvider);
    final user = userState.user;

    final isGuest = user?.isGuest ?? true;
    final quotaManager = user?.quotaManager;
    final todayUsage = quotaManager?.getTodayUsage() ?? 0;
    final dailyLimit = quotaManager?.dailyLimit ?? 3;
    final totalUsage = quotaManager?.usageHistory.length ?? 0;
    final totalLimit = quotaManager?.totalLimit ?? 3;

    final remainingGenerations = isGuest
        ? (totalLimit - totalUsage).clamp(0, (dailyLimit - todayUsage).clamp(0, dailyLimit))
        : (dailyLimit - todayUsage).clamp(0, dailyLimit);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFEDE9FE),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF7C3AED),
                width: 3,
              ),
            ),
            child: Center(
              child: Text(
                '$remainingGenerations',
                style: GoogleFonts.lexend(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$remainingGenerations generation${remainingGenerations == 1 ? '' : 's'} left today',
                  style: GoogleFonts.lexend(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Keep capturing memories',
                  style: GoogleFonts.lexend(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
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
                  ? "You've used all your guest generations. Sign up to get 15 daily generations!"
                  : "You've reached your 15 daily generations. Come back tomorrow for more!",
              style: GoogleFonts.lexend(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF6b7280),
                height: 1.5,
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
                    const Icon(Icons.star_rounded, color: Color(0xFF8b5cf6), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '15 generations everyday with free account!',
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
                Navigator.pop(context);
                AccountMethodPage.show(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8b5cf6),
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
              foregroundColor: const Color(0xFF6b7280),
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

  Future<void> _pickImage(ImageSource source) async {
    final user = ref.read(userStateProvider).user;
    if (user != null && !user.canGenerate) {
      _showQuotaLimitDialog(user.isGuest);
      return;
    }

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
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1F2937),
              ),
            ),
            GestureDetector(
              onTap: () =>
                  ref.read(navigationProvider.notifier).goScrapbook(),
              child: Text(
                'See all',
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF7C5CFC),
                ),
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
    final tiltAngle = index.isEven ? -0.018 : 0.018;

    if (MediaQuery.disableAnimationsOf(context)) {
      return Transform.rotate(
        angle: tiltAngle,
        child: _buildScrapbookCardInteractive(context, scrapbook),
      );
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
            child: Transform.rotate(
              angle: tiltAngle,
              child: _buildScrapbookCardInteractive(context, scrapbook),
            ),
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
