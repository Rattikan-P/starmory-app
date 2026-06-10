import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/preference_service.dart';
import '../../data/services/auth_service.dart';
import '../../utils/snackbar_helper.dart';
import 'auth/otp_verification_page.dart';
import 'language_selection_page.dart';
import 'main_navigation.dart';
import 'privacy_policy_page.dart';
import 'terms_of_service_page.dart';
import '../providers/providers.dart' show hiveServiceProvider, vocabularySyncServiceProvider;

final onboardingServiceProvider = Provider<PreferenceService>((ref) => PreferenceService());

class OnboardingPage extends ConsumerStatefulWidget {
  final bool skipToAuth;
  const OnboardingPage({super.key, this.skipToAuth = false});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final _emailController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();
  bool _isEmailLoading = false;
  final List<AnimationController> _starControllers = [];

  final List<OnboardingItem> _items = const [
    OnboardingItem(
      icon: Icons.camera_alt_rounded,
      title: 'Learn from Photos',
      description: 'Snap a photo, learn a word.\nYour world is your language lesson.',
    ),
    OnboardingItem(
      icon: Icons.schedule_rounded,
      title: '2 Minutes a Day',
      description: 'One word a day is enough.\nNo guilt, no pressure, just progress.',
    ),
    OnboardingItem(
      icon: Icons.auto_awesome_rounded,
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

    // Normal onboarding animations
    for (int i = 0; i < 3; i++) {
      _starControllers.add(AnimationController(
        duration: Duration(milliseconds: 2500 + i * 500),
        vsync: this,
      ));
      Future.delayed(Duration(milliseconds: i * 1200), () {
        if (mounted) {
          _starControllers[i].repeat();
        }
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _starControllers) {
      controller.dispose();
    }
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
      final preferenceService = PreferenceService();
      await preferenceService.init();

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
        await prefService.setGuestMode(false);

        // Auto sync local vocabularies to cloud (for existing users)
        try {
          print('🔄 [Onboarding Google] Starting auto sync...');
          final hiveService = ref.read(hiveServiceProvider);
          final vocabSyncService = ref.read(vocabularySyncServiceProvider);
          final localVocabs = await hiveService.getAllVocabulary();

          print('📦 [Onboarding Google] Found ${localVocabs.length} local vocabularies');

          if (localVocabs.isNotEmpty) {
            // Use mergeWithCloud to avoid duplicates
            print('☁️ [Onboarding Google] Merging with cloud...');
            final syncedVocabs = await vocabSyncService.mergeWithCloud(localVocabs);
            // Update local storage with merged vocabularies
            await hiveService.clearAllVocabulary();
            for (final vocab in syncedVocabs) {
              await hiveService.saveVocabulary(vocab);
            }
            print('✅ [Onboarding Google] Sync complete! Total vocabularies: ${syncedVocabs.length}');
          } else {
            print('ℹ️ [Onboarding Google] No local vocabularies to sync');
          }
        } catch (e) {
          print('❌ [Onboarding Google] Sync failed: $e');
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
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Galaxy gradient background
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
          Positioned(
            bottom: 100,
            left: -60,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFF472B6).withValues(alpha: 0.55),
                    const Color(0x00F472B6),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -60,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFCD34D).withValues(alpha: 0.35),
                    const Color(0x00FCD34D),
                  ],
                ),
              ),
            ),
          ),
          // Static stars
          ...List.generate(40, (i) {
            final r = Random(i * 42);
            final s = 1.5 + r.nextDouble() * 3.5;
            return Positioned(
              top: r.nextDouble() * MediaQuery.of(context).size.height,
              left: r.nextDouble() * MediaQuery.of(context).size.width,
              child: Opacity(
                opacity: 0.2 + r.nextDouble() * 0.6,
                child: Container(
                  width: s, height: s,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.white54, blurRadius: 2)],
                  ),
                ),
              ),
            );
          }),
          // Falling stars
          if (_starControllers.isNotEmpty && _starControllers.length >= 3) ...[
            _FallingStar(animation: _starControllers[0], index: 0),
            _FallingStar(animation: _starControllers[1], index: 1),
            _FallingStar(animation: _starControllers[2], index: 2),
          ],
          SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        // App name
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
                                          : const Color(0xFFc4b5fd),
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
                      ],
                    ),
                  ),

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
                              // Gradient icon
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Glow rings
                                  ...List.generate(3, (ringIndex) {
                                    final ringSize = 200.0 + (ringIndex * 30);
                                    return Container(
                                      width: ringSize,
                                      height: ringSize,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _getGradientColor(index)
                                              .withValues(alpha:0.2 - (ringIndex * 0.05)),
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
                                          _getGradientColor(index).withValues(alpha:0.25),
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
                                          _getGradientColor(index).withValues(alpha:0.8),
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: _getGradientColor(index).withValues(alpha:0.4),
                                          blurRadius: 28,
                                          offset: const Offset(0, 8),
                                        ),
                                        BoxShadow(
                                          color: _getGradientColor(index).withValues(alpha:0.2),
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
                                  color: const Color(0xFF4b5563),
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

                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
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
                                    Color(0xFF60a5fa), // soft blue
                                    Color(0xFF818cf8), // soft indigo
                                    Color(0xFFa78bfa), // soft violet
                                    Color(0xFFc084fc), // soft purple
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
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
                              'Sign in or create account',
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
      ],
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

// Simple falling star widget
class _FallingStar extends StatelessWidget {
  final Animation<double> animation;
  final int index;

  const _FallingStar({
    required this.animation,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final p = animation.value;

        // Trajectories
        final paths = [
          (0.05, 0.05, 0.85, 0.7),   // Star 0
          (0.3, 0.0, 0.95, 0.6),     // Star 1
          (0.0, 0.15, 0.6, 0.85),    // Star 2
        ];
        final path = paths[index % 3];

        final x = size.width * path.$1 + (size.width * path.$3 - size.width * path.$1) * p;
        final y = size.height * path.$2 + (size.height * path.$4 - size.height * path.$2) * p;
        final angle = atan2(size.height * (path.$4 - path.$2), size.width * (path.$3 - path.$1));

        return Positioned(
          left: x,
          top: y,
          child: Transform.rotate(
            angle: angle,
            child: Opacity(
              opacity: p > 0.85 ? (1 - p) * 6.5 : 1.0,
              child: Container(
                width: 80,
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      Colors.white,
                      Colors.white.withValues(alpha: 0.5),
                      Colors.white.withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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
      child: SingleChildScrollView(
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
                      return AlertMessages.emailRequired;
                    }
                    if (!SnackBarHelper.isValidEmail(value)) {
                      return AlertMessages.invalidEmail;
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
                          Color(0xFF60a5fa), // soft blue
                          Color(0xFF818cf8), // soft indigo
                          Color(0xFFa78bfa), // soft violet
                          Color(0xFFc084fc), // soft purple
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFa78bfa).withValues(alpha: 0.4),
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
                                  'Continue with Email',
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
              icon: SvgPicture.network(
                'https://thesvg.org/icons/google/default.svg',
                width: 20,
                height: 20,
              ),
              label: Text(
                'Continue with Google',
                style: GoogleFonts.lexend(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1f2937),
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
              children: [
                const TextSpan(text: 'By signing up, you agree to our '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: () {
                      if (context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const TermsOfServicePage()),
                        );
                      }
                    },
                    child: Text(
                      'Terms',
                      style: GoogleFonts.lexend(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFFa5b4fc),
                      ),
                    ),
                  ),
                ),
                const TextSpan(text: ' & '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: () {
                      if (context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                        );
                      }
                    },
                    child: Text(
                      'Privacy Policy',
                      style: GoogleFonts.lexend(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFFa5b4fc),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}