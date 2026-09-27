import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/design_tokens.dart';
import '../../data/services/app_state_service.dart';
import '../../data/services/auth_service.dart';
import '../../utils/snackbar_helper.dart';
import '../widgets/auth_widgets.dart';
import 'auth/otp_verification_page.dart';
import 'language_selection_page.dart';
import 'main_navigation.dart';
import '../providers/providers.dart' show hiveServiceProvider, vocabularySyncServiceProvider;

final onboardingServiceProvider = Provider<AppStateService>((ref) => AppStateService());

class OnboardingPage extends ConsumerStatefulWidget {
  final bool skipToAuth;
  const OnboardingPage({super.key, this.skipToAuth = false});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final _emailController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();
  bool _isEmailLoading = false;

  final List<OnboardingItem> _items = const [
    OnboardingItem(
      glowColor: Color(0xFF8B7CFF),
      imageAsset: 'assets/images/LearnFromPhotos_mascot.png',
      title: 'Learn from Photos',
      description: 'Snap a photo, learn a word.\nYour world is your language lesson.',
    ),
    OnboardingItem(
      glowColor: Color(0xFFD98FB4),
      imageAsset: 'assets/images/2MinutesaDay_mascot.png',
      imageScale: 1.30,
      title: '2 Minutes a Day',
      description: 'One word a day is enough.\nNo guilt, no pressure, just progress.',
    ),
    OnboardingItem(
      glowColor: Color(0xFFFFC629),
      imageAsset: 'assets/images/CollectYourStars_mascot.png',
      imageScale: 0.95,
      title: 'Collect Your Stars',
      description: 'Coffee, cats, views.\nEvery little moment is a new star.',
    ),
  ];

  @override
  void initState() {
    super.initState();

    // Skip to auth bottom sheet immediately if requested (for logout)
    if (widget.skipToAuth) {
      Future.microtask(() => _showAuthBottomSheet());
      return;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _continueAsGuest() async {
    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const LanguageSelectionPage(
            isGuest: true,
            isInitialSetup: true,
          ),
        ),
      );
    }
  }

  Future<void> _continueWithGoogle() async {
    try {
      final authService = AuthService();
      final appStateService = AppStateService();
      await appStateService.init();

      final success = await authService.signInWithGoogle(
        forceAccountSelection: true,
      );

      if (!success) {
        if (mounted) {
          // Close bottom sheet first, then show SnackBar
          Navigator.of(context).pop();
          SnackBarHelper.error(context, AlertMessages.loginFailed);
        }
        return;
      }

      if (!mounted) return;

      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) {
          // Close bottom sheet first, then show SnackBar
          Navigator.of(context).pop();
          SnackBarHelper.error(context, AlertMessages.loginFailed);
        }
        return;
      }

      // Auto-accept terms on signup
      await appStateService.setTermsVersion(appStateService.getCurrentTermsVersion());

      final userData = await client
          .from('users')
          .select('id, language_level, onboarding_completed')
          .eq('id', userId)
          .maybeSingle();

      final isNewUser =
          userData == null || userData['onboarding_completed'] != true;

      if (!mounted) return;

      final prefService = ref.read(onboardingServiceProvider);

      if (isNewUser) {
        // EnglishVariantPage จะจัดการทุกอย่างเมื่อ isInitialSetup
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const LanguageSelectionPage(
              isGuest: false,
              isInitialSetup: true,
              returnAfterSelection: false,
            ),
          ),
        );
        // Context will be unmounted here since EnglishVariantPage handles full navigation
        return;
      } else {
        await prefService.setOnboardingCompleted(true);
        // Note: setGuestMode removed - UserModel.isGuest reflects actual auth state

        // Auto sync local vocabularies to cloud (for existing users)
        try {
          final hiveService = ref.read(hiveServiceProvider);
          final vocabSyncService = ref.read(vocabularySyncServiceProvider);
          final localVocabs = await hiveService.getAllVocabulary();

          if (localVocabs.isNotEmpty) {
            // Use mergeWithCloud to avoid duplicates
            final syncedVocabs = await vocabSyncService.mergeWithCloud(localVocabs);
            // Update local storage with merged vocabularies
            await hiveService.clearAllVocabulary();
            for (final vocab in syncedVocabs) {
              await hiveService.saveVocabulary(vocab);
            }
          }
        } catch (e) {
          // Sync failed - continue with login (local vocabularies still available)
        }

        if (!mounted) return;

        SnackBarHelper.success(context, AlertMessages.welcomeBack);

        // Wait a bit so user can see the success message
        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) =>
                const MainNavigationScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        // Close bottom sheet first, then show SnackBar
        Navigator.of(context).pop();
        SnackBarHelper.error(context, AlertMessages.loginFailed);
      }
    }
  }

  Future<void> _continueWithEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() => _isEmailLoading = true);

    try {
      final email = _emailController.text.trim();

      // Send OTP first, then navigate
      final authService = ref.read(authServiceProvider);
      await authService.sendOtp(email);

      // Close bottom sheet first
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (!mounted) return;
      SnackBarHelper.success(context, 'OTP sent to $email');

      // Navigate to OTP page after successful send
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerificationPage(
            email: email,
            isGuestCreatingAccount: false,
          ),
        ),
      );
    } catch (e) {
      // Close bottom sheet on error too
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        SnackBarHelper.error(context, AlertMessages.otpSendFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _isEmailLoading = false);
      }
    }
  }

  void _nextPage() {
    if (_currentPage < _items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Last page - show auth options
      _showAuthBottomSheet();
    }
  }

  Future<void> _showAuthBottomSheet() async {
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AuthOptionsSheet(
        onGoogleTap: _continueWithGoogle,
        onEmailTap: _continueWithEmail,
        onGuestTap: _continueAsGuest,
        emailController: _emailController,
        emailFormKey: _emailFormKey,
        isEmailLoading: _isEmailLoading,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildReferenceLayout();
  }

  Widget _buildReferenceLayout() {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: DesignTokens.spacingXLarge),
            SizedBox(
              height: DesignTokens.touchTarget,
              child: Image.asset(
                'assets/images/text_logo.png',
                width: 140,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Text(
                  'Starmory',
                  style: GoogleFonts.cormorantUnicase(fontSize: 23, color: Colors.black),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _items.length,
                itemBuilder: (context, index) => _buildReferencePage(_items[index]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _items.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: _currentPage == index ? 22 : 5,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? DesignTokens.brandColor
                        : const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DesignTokens.spacingXLarge,
                DesignTokens.spacingXLarge,
                DesignTokens.spacingXLarge,
                DesignTokens.spacingMedium,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        elevation: 4,
                        shadowColor: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(27),
                        ),
                      ),
                      child: Text(
                        _currentPage == _items.length - 1 ? 'Get Started' : 'Next',
                        style: GoogleFonts.lexend(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _continueAsGuest,
                        borderRadius: BorderRadius.circular(30),
                        child: Ink(
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
                          child: Center(
                            child: Text(
                              'Try without signing up',
                              style: GoogleFonts.lexend(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF7C3AED),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  InkWell(
                    onTap: _showAuthBottomSheet,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: DesignTokens.spacingMedium,
                        horizontal: DesignTokens.spacingSmall,
                      ),
                      child: Text(
                        'Sign in or create account',
                        style: GoogleFonts.lexend(
                          fontSize: DesignTokens.fontSizeBody,
                          color: DesignTokens.textMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferencePage(OnboardingItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SizedBox(
                width: 380,
                height: 380,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 552,
                      height: 552,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            item.glowColor.withValues(alpha: 0.48),
                            item.glowColor.withValues(alpha: 0.30),
                            item.glowColor.withValues(alpha: 0.12),
                            item.glowColor.withValues(alpha: 0),
                          ],
                          stops: const [0, 0.38, 0.72, 1],
                        ),
                      ),
                    ),
                    Transform.scale(
                      scale: item.imageScale,
                      child: Image.asset(
                        item.imageAsset,
                        width: 255,
                        height: 255,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.lexend(
              fontSize: DesignTokens.fontSizeTitle,
              fontWeight: DesignTokens.weightSemiBold,
              color: DesignTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.lexend(
              fontSize: DesignTokens.fontSizeBody,
              height: 1.35,
              color: DesignTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 17),
        ],
      ),
    );
  }
}

class OnboardingItem {
  final Color glowColor;
  final String imageAsset;
  final double imageScale;
  final String title;
  final String description;

  const OnboardingItem({
    this.glowColor = const Color(0xFF8B7CFF),
    this.imageScale = 1,
    required this.imageAsset,
    required this.title,
    required this.description,
  });
}

// Auth Options Bottom Sheet
class _AuthOptionsSheet extends StatelessWidget {
  final VoidCallback onGoogleTap;
  final VoidCallback onEmailTap;
  final VoidCallback onGuestTap;
  final TextEditingController emailController;
  final GlobalKey<FormState> emailFormKey;
  final bool isEmailLoading;

  const _AuthOptionsSheet({
    required this.onGoogleTap,
    required this.onEmailTap,
    required this.onGuestTap,
    required this.emailController,
    required this.emailFormKey,
    required this.isEmailLoading,
  });

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: 20 + keyboardHeight,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 18),

            // Header
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, size: 16, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 8),
                Text(
                  'Sign in or create account',
                  style: GoogleFonts.lexend(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: DesignTokens.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Choose your preferred method',
              style: GoogleFonts.lexend(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: DesignTokens.textMuted,
              ),
            ),
            const SizedBox(height: 18),

            // Reusable AuthForm
            AuthForm(
              onGoogleTap: onGoogleTap,
              onEmailTap: onEmailTap,
              emailController: emailController,
              emailFormKey: emailFormKey,
              isEmailLoading: isEmailLoading,
            ),
          ],
        ),
      ),
    );
  }
}
