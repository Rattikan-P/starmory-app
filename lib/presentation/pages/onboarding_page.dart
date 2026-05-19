import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/preference_service.dart';
import '../../data/services/auth_service.dart';
import 'auth/email_login_page.dart';
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
  bool _consentAccepted = false;

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
  void initState() {
    super.initState();
    _checkConsent();
  }

  Future<void> _checkConsent() async {
    final preferenceService = PreferenceService();
    await preferenceService.init();

    // เช็คจาก Local ก่อน
    var hasAccepted = await preferenceService.hasAcceptedCurrentTerms();

    // ถ้ายังไม่มีใน Local แต่ user login อยู่ → ดึงจาก Cloud
    if (!hasAccepted) {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId != null) {
        final authService = AuthService();
        final cloudVersion = await authService.getUserTermsVersion(userId);
        final currentVersion = preferenceService.getCurrentTermsVersion();

        if (cloudVersion != null && cloudVersion >= currentVersion) {
          // Cloud มี terms version ที่ถูกต้อง → sync กลับ Local
          await preferenceService.setTermsVersion(cloudVersion);
          hasAccepted = true;
        }
      }
    }

    if (mounted && hasAccepted) {
      setState(() => _consentAccepted = true);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _continueAsGuest() async {
    // บันทึก terms version สำหรับ guest
    if (_consentAccepted) {
      final preferenceService = PreferenceService();
      await preferenceService.init();
      await preferenceService.setTermsVersion(preferenceService.getCurrentTermsVersion());
    }

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
      final success = await authService.signInWithGoogle(
        forceAccountSelection: true,
      );

      if (!success || !mounted) return;

      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      final userData = await client
          .from('users')
          .select('id, language_level, onboarding_completed')
          .eq('id', userId)
          .maybeSingle();

      final isNewUser =
          userData == null || userData['onboarding_completed'] != true;

      if (!mounted) return;

      final preferenceService = ref.read(onboardingServiceProvider);

      if (isNewUser) {
        // ถาม level/variant ก่อน
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

        // ดึงค่าจาก Preference Service แล้ว save ลง Supabase
        final level = await preferenceService.getGuestLanguageLevel();
        final variant = await preferenceService.getGuestEnglishVariant();

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

        await preferenceService.setOnboardingCompleted(true);
        await preferenceService.setGuestMode(false);

        if (!mounted) return;

        // ถาม display name เพราะเป็น new user
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
        // Existing user → ไป main เลย
        await preferenceService.setOnboardingCompleted(true);
        await preferenceService.setGuestMode(false);

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
    if (mounted) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const EmailLoginPage()));
    }
  }

  Future<void> _showConsentAndContinueGoogle() async {
    if (_consentAccepted) {
      await _continueWithGoogle();
    } else if (mounted) {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _ConsentModal(
          onAccept: () => Navigator.of(context).pop(true),
          onDecline: () => Navigator.of(context).pop(false),
        ),
      );

      if (result == true && mounted) {
        setState(() => _consentAccepted = true);
        await _continueWithGoogle();
      }
    }
  }

  Future<void> _showConsentAndContinueEmail() async {
    if (_consentAccepted) {
      await _continueWithEmail();
    } else if (mounted) {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _ConsentModal(
          onAccept: () => Navigator.of(context).pop(true),
          onDecline: () => Navigator.of(context).pop(false),
        ),
      );

      if (result == true && mounted) {
        setState(() => _consentAccepted = true);
        await _continueWithEmail();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  Image.asset(
                    'assets/images/logo.png',
                    width: 80,
                    height: 80,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.primary.withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Starmory',
                    style: GoogleFonts.cormorantUnicase(
                      fontSize: 35,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Learn languages with spaced repetition',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Icon(
                                  item.icon,
                                  size: 48,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                item.title,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.description,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Page indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _items.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _currentPage == index ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary.withValues(
                                  alpha: 0.3,
                                ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Bottom container with rounded top corners and gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFFFB3BA).withValues(alpha: 0.6),
                    const Color(0xFFFFDFBA).withValues(alpha: 0.6),
                    const Color(0xFFE2D1F9).withValues(alpha: 0.6),
                    const Color(0xFFBFEAF5).withValues(alpha: 0.6),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
                child: Column(
                  children: [
                    // Signup buttons - show consent modal if not accepted
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: OutlinedButton(
                              onPressed: _showConsentAndContinueGoogle,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide.none,
                                foregroundColor: const Color(0xFF8B5CF6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/images/google_logo.png',
                                    width: 22,
                                    height: 22,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.g_mobiledata, size: 22);
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Continue with Google',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: FilledButton.icon(
                              onPressed: _showConsentAndContinueEmail,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF8B5CF6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.email_outlined, size: 22),
                              label: const Text(
                                'Continue with Email',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Divider
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: const Color(0xFF5E3A8E).withValues(alpha: 0.2),
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: const Color(0xFF5E3A8E).withValues(alpha: 0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: const Color(0xFF5E3A8E).withValues(alpha: 0.2),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Guest button
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF5E3A8E).withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextButton(
                          onPressed: _continueAsGuest,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF5E3A8E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Continue as Guest',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Consent text
                    Text(
                      'We collect photos for AI vocabulary learning',
                      style: TextStyle(
                        color: const Color(0xFF5E3A8E).withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
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

// Consent Modal Dialog
class _ConsentModal extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _ConsentModal({
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFE2D1F9).withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.privacy_tip_rounded,
                size: 32,
                color: Color(0xFF5E3A8E),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'Privacy Consent',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5E3A8E),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              'To use Starmory, we need your consent to collect and process your data for AI vocabulary learning. This includes photos you upload and your learning progress.',
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF5E3A8E).withValues(alpha: 0.8),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Additional info
            Text(
              'You can withdraw your consent at any time in Settings.',
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFF5E3A8E).withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Accept button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onAccept,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'I Accept',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Decline button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onDecline,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5E3A8E),
                  side: BorderSide(
                    color: const Color(0xFF5E3A8E).withValues(alpha: 0.3),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'I Decline',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
