import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/hive_service.dart';
import 'auth/email_login_page.dart';
import 'language_selection_page.dart';

final onboardingServiceProvider =
    Provider<HiveService>((ref) => HiveService());

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

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
    super.dispose();
  }

  Future<void> _continueAsGuest() async {
    // Go to language selection first, then enter as guest
    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LanguageSelectionPage(isGuest: true, forceSelection: true)),
      );
      // After language selection, guest mode will be set and proceed to main
    }
  }

  Future<void> _continueWithGoogle() async {
    // TODO: Implement Google OAuth
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google sign in coming soon!')),
      );
    }
  }

  Future<void> _continueWithEmail() async {
    // Go to email input page (checks if email exists first)
    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const EmailLoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [

            // Content
            Expanded(
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Logo
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

                  // App name + tagline
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

                  // Slider
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
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.description,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Dots indicator
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
                              : theme.colorScheme.primary
                                  .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Continue with Google Button
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

                  // Continue with Email Button (Primary)
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

                  // Continue as Guest Button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _continueAsGuest,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Continue as Guest'),
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
