import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/preference_service.dart';
import '../../data/services/auth_service.dart';
import 'auth/otp_verification_page.dart';
import 'language_selection_page.dart';
import 'main_navigation.dart';
import '../../constants/app_defaults.dart';

final onboardingServiceProvider = Provider<PreferenceService>((ref) => PreferenceService());

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

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
      icon: Icons.auto_stories_rounded,
      title: 'Learn Vocabulary',
      description: 'Master new words with spaced repetition',
    ),
    OnboardingItem(
      icon: Icons.camera_alt_rounded,
      title: 'Photo Scrapbook',
      description: 'Capture moments and learn from real life',
    ),
    OnboardingItem(
      icon: Icons.trending_up_rounded,
      title: 'Track Progress',
      description: 'Watch your language skills grow',
    ),
  ];

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
          builder: (_) =>
              const LanguageSelectionPage(isGuest: true, forceSelection: true),
        ),
      );
    }
  }

  Future<void> _continueWithGoogle() async {
    try {
      final authService = AuthService();
      final preferenceService = PreferenceService();
      await preferenceService.init();

      final success = await authService.signInWithGoogle(
        forceAccountSelection: true,
      );

      if (!success || !mounted) return;

      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      // Auto-accept terms on signup
      await preferenceService.setTermsVersion(preferenceService.getCurrentTermsVersion());

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
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => const LanguageSelectionPage(
              isGuest: false,
              forceSelection: true,
              returnAfterSelection: true,
            ),
          ),
        );

        if (!mounted || result != true) {
          await client.auth.signOut();
          return;
        }

        final level = await prefService.getGuestLanguageLevel();
        final variant = await prefService.getGuestEnglishVariant();

        await authService.updateUserPreferences(
          userId: userId,
          email: client.auth.currentUser?.email ?? '',
          languageLevel: level ?? AppDefaults.defaultLanguageLevel,
          englishVariant: variant ?? AppDefaults.defaultEnglishVariant,
          termsVersion: preferenceService.getCurrentTermsVersion(),
        );

        await client
            .from('users')
            .update({'onboarding_completed': true})
            .eq('id', userId);

        await prefService.setOnboardingCompleted(true);
        await prefService.setGuestMode(false);

        if (!mounted) return;

        final hasDisplayName =
            client.auth.currentUser?.userMetadata?['display_name'] != null;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) =>
                MainNavigationScreen(showDisplayNamePrompt: !hasDisplayName),
          ),
          (route) => false,
        );
      } else {
        await prefService.setOnboardingCompleted(true);
        await prefService.setGuestMode(false);

        if (!mounted) return;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) =>
                const MainNavigationScreen(showDisplayNamePrompt: false),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Future<void> _continueWithEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() => _isEmailLoading = true);

    try {
      final email = _emailController.text.trim();

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerificationPage(
            email: email,
            isGuestCreatingAccount: false,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
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

  void _skip() {
    _showAuthBottomSheet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFf0f4ff), // Very light blue
              Color(0xFFf8f5ff), // Very light purple
              Color(0xFFfff5f8), // Very light pink
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Main content
              Column(
                children: [
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Row(
                      children: [
                        // App name + indicators
                        Row(
                          children: [
                            Image.asset(
                              'assets/images/logo.png',
                              height: 40,
                              errorBuilder: (context, error, stackTrace) {
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star, size: 18, color: Color(0xFFc4b5fd)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Starmory',
                                      style: GoogleFonts.cormorantUnicase(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFc4b5fd),
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(width: 5),

                            // Page indicators
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: List.generate(
                                  _items.length,
                                  (index) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    width: _currentPage == index ? 28 : 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      gradient: _currentPage == index
                                          ? const LinearGradient(
                                              colors: [Color(0xFF8b7cf6), Color(0xFF7c6ff5)],
                                            )
                                          : null,
                                      color: _currentPage == index
                                          ? null
                                          : const Color(0xFFd1d5db),
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: _currentPage == index
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF8b7cf6).withValues(alpha: 0.4),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        // Skip button
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextButton(
                            onPressed: _skip,
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF8b5cf6),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: Text(
                              'Skip',
                              style: GoogleFonts.lexend(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF8b5cf6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Carousel
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() => _currentPage = index);
                      },
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Gradient Icon with glow effect
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Outer glow rings
                                  ...List.generate(3, (ringIndex) {
                                    final ringSize = 200.0 + (ringIndex * 30);
                                    return Container(
                                      width: ringSize,
                                      height: ringSize,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _getGradientColor(index)
                                              .withOpacity(0.2 - (ringIndex * 0.05)),
                                          width: 1.5,
                                        ),
                                      ),
                                    );
                                  }),
                                  // Glow effect
                                  Container(
                                    width: 180,
                                    height: 180,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          _getGradientColor(index).withOpacity(0.25),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Icon container with shadow
                                  Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          _getGradientColor(index),
                                          _getGradientColor(index).withOpacity(0.8),
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: _getGradientColor(index).withOpacity(0.4),
                                          blurRadius: 28,
                                          offset: const Offset(0, 8),
                                        ),
                                        BoxShadow(
                                          color: _getGradientColor(index).withOpacity(0.2),
                                          blurRadius: 50,
                                          offset: const Offset(0, 20),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      item.icon,
                                      size: 65,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 56),

                              // Title
                              Text(
                                item.title,
                                style: GoogleFonts.lexend(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1f2937),
                                  height: 1.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),

                              // Description
                              Text(
                                item.description,
                                style: GoogleFonts.lexend(
                                  fontSize: 15,
                                  color: const Color(0xFF9ca3af),
                                  height: 1.6,
                                  fontWeight: FontWeight.w400,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom buttons
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 20,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Next button with gradient
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton(
                            onPressed: _nextPage,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFc4b5fd), // Soft purple
                                    Color(0xFFa5b4fc), // Soft indigo
                                    Color(0xFF8b8ef5), // Indigo
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFc4b5fd).withOpacity(0.35),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  _currentPage == _items.length - 1 ? 'Get Started' : 'Next',
                                  style: GoogleFonts.lexend(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Try without signing up
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton.icon(
                            onPressed: _continueAsGuest,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF8b5cf6),
                              side: const BorderSide(
                                color: Color(0xFFe5e7eb),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: const Icon(Icons.explore, size: 20),
                            label: Text(
                              'Try without signing up',
                              style: GoogleFonts.lexend(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF8b5cf6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Already have an account
                        InkWell(
                          onTap: _showAuthBottomSheet,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            child: Text(
                              'Already have an account?',
                              style: GoogleFonts.lexend(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF9ca3af),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getGradientColor(int index) {
    final colors = [
      const Color(0xFFf472b6), // Soft pink
      const Color(0xFF60a5fa), // Soft blue
      const Color(0xFF34d399), // Soft mint
    ];
    return colors[index % colors.length];
  }
}

class OnboardingItem {
  final IconData icon;
  final String title;
  final String description;

  const OnboardingItem({
    required this.icon,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        left: 28,
        right: 28,
        top: 28,
        bottom: 28 + keyboardHeight,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFd1d5db),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 28),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, size: 20, color: Color(0xFFc4b5fd)),
              const SizedBox(width: 8),
              Text(
                'Sign in or create account',
                style: GoogleFonts.lexend(
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF1f2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Choose your preferred method',
            style: GoogleFonts.lexend(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF9ca3af),
            ),
          ),
          const SizedBox(height: 24),

          // Email input with continue button
          Form(
            key: emailFormKey,
            child: Column(
              children: [
                // Email input field
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  style: GoogleFonts.lexend(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    hintText: 'your@email.com',
                    hintStyle: GoogleFonts.lexend(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF9ca3af),
                    ),
                    prefixIcon: const Icon(Icons.email_outlined, size: 20, color: Color(0xFF9ca3af)),
                    filled: true,
                    fillColor: const Color(0xFFf3f4f6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFc4b5fd), width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFef4444), width: 1),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFef4444), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                  ),
                  onFieldSubmitted: (_) => onEmailTap(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.trim().contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                // Email Continue button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFc4b5fd),
                          Color(0xFFa5b4fc),
                          Color(0xFF8b8ef5),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFc4b5fd).withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isEmailLoading ? null : onEmailTap,
                        borderRadius: BorderRadius.circular(16),
                        child: Center(
                          child: isEmailLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  'Send OTP',
                                  style: GoogleFonts.lexend(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // OR divider
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: const Color(0xFFe5e7eb),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'OR',
                  style: GoogleFonts.lexend(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF9ca3af),
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: const Color(0xFFe5e7eb),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Google Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: onGoogleTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8b5cf6),
                side: const BorderSide(color: Color(0xFFe5e7eb), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
              icon: Image.asset(
                'assets/images/google_logo.png',
                width: 20,
                height: 20,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.g_mobiledata, size: 20, color: Color(0xFF1f2937));
                },
              ),
              label: Text(
                'Continue with Google',
                style: GoogleFonts.lexend(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF8b5cf6),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Terms notice
          Text.rich(
            TextSpan(
              style: GoogleFonts.lexend(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF9ca3af),
              ),
              children: const [
                TextSpan(text: 'By signing up, you agree to our '),
                TextSpan(
                  text: 'Terms',
                  style: TextStyle(
                    color: Color(0xFFa5b4fc),
                  ),
                ),
                TextSpan(text: ' & '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: TextStyle(
                    color: Color(0xFFa5b4fc),
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}