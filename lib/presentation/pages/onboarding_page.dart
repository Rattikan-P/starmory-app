import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/preference_service.dart';
import '../../data/services/auth_service.dart';
import 'auth/email_login_page.dart';
import 'language_selection_page.dart';
import 'main_navigation.dart';

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
          languageLevel: level ?? 'B1',
          englishVariant: variant ?? 'US',
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

  void _showTerms(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Terms of Service - Coming Soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showPrivacy(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Privacy Policy - Coming Soon'),
        duration: Duration(seconds: 2),
      ),
    );
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
                  const SizedBox(height: 20),

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
                  const SizedBox(height: 32),

                  Text(
                    'Starmory',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Learn languages with spaced repetition',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

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

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _items.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary.withValues(
                                  alpha: 0.3,
                                ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Signup buttons (shown after consent)
                  if (_consentAccepted) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _continueWithGoogle,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.g_mobiledata, size: 20),
                        label: const Text('Continue with Google'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _continueWithEmail,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Continue with Email'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Guest button (always visible)
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _continueAsGuest,
                      style: TextButton.styleFrom(
                        disabledForegroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      child: const Text('Continue as Guest'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Consent checkbox
                  Row(
                    children: [
                      Checkbox(
                        value: _consentAccepted,
                        onChanged: (value) {
                          setState(() => _consentAccepted = value ?? false);
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _consentAccepted = !_consentAccepted);
                          },
                          child: Text(
                            'I accept the Terms & Privacy Policy',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Links
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => _showTerms(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Terms',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      Text(
                        ' • ',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showPrivacy(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Privacy',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Consent text
                  Text(
                    'We collect photos for AI vocabulary learning',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
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
