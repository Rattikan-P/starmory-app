import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'onboarding_page.dart';
import 'auth/login_method_page.dart';
import 'main_navigation.dart';
import 'english_variant_page.dart';

class LanguageSelectionPage extends ConsumerStatefulWidget {
  final bool isGuest;
  final bool isEditing;
  final bool isInitialSetup;
  final bool forceSelection;
  final bool returnAfterSelection; // Return to previous screen after selection

  const LanguageSelectionPage({
    super.key,
    this.isGuest = false,
    this.isEditing = false,
    this.isInitialSetup = false,
    this.forceSelection = false,
    this.returnAfterSelection = false,
  });

  @override
  ConsumerState<LanguageSelectionPage> createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends ConsumerState<LanguageSelectionPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExistingGuestLevel();
    });
  }

  Future<void> _checkExistingGuestLevel() async {
    // Skip auto-navigation when editing or forcing selection
    if (widget.isEditing || widget.forceSelection) return;

    final hiveService = ref.read(onboardingServiceProvider);
    final existingLevel = await hiveService.getGuestLanguageLevel();

    if (existingLevel != null && mounted) {
      if (widget.isGuest) {
        // Guest mode: save level and go to main
        await hiveService.setGuestMode(true);
        await hiveService.setOnboardingCompleted(true);
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
            (route) => false,
          );
        }
      } else {
        // Register flow: go to register with existing level AND variant
        final existingVariant = await hiveService.getGuestEnglishVariant();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LoginMethodPage(
              languageLevel: existingLevel,
              englishVariant: existingVariant ?? 'US',
              isRegistration: true,
            ),
          ),
        );
      }
    }
  }

  static const List<LanguageLevel> levels = [
    LanguageLevel(
      code: 'A1',
      title: 'A1 - Beginner',
      description: 'Can understand and use basic phrases',
      icon: Icons.looks_one,
    ),
    LanguageLevel(
      code: 'A2',
      title: 'A2 - Elementary',
      description: 'Can communicate in simple tasks',
      icon: Icons.looks_two,
    ),
    LanguageLevel(
      code: 'B1',
      title: 'B1 - Intermediate',
      description: 'Can handle most situations while traveling',
      icon: Icons.looks_3,
    ),
    LanguageLevel(
      code: 'B2',
      title: 'B2 - Upper Intermediate',
      description: 'Can interact with native speakers fluently',
      icon: Icons.looks_4,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: widget.isEditing
            ? null
            : [
                TextButton(
                  onPressed: () => _skip(context),
                  child: const Text('Skip'),
                ),
              ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isEditing ? 'Change your level' : 'What\'s your level?',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isEditing
                        ? 'Select your new proficiency level'
                        : (widget.isGuest
                            ? 'This helps personalize your experience'
                            : 'This helps us personalize your learning experience'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: levels.length,
                separatorBuilder: (_, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final level = levels[index];
                  return Card(
                    elevation: 0,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          level.icon,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        level.title,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(level.description),
                      onTap: () => _selectLevel(context, level.code),
                    ),
                  );
                },
              ),
            ),

            // Bottom note - only show during initial selection
            if (!widget.isEditing)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'You can change this later in settings',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _skip(BuildContext context) {
    _selectLevel(context, 'B1'); // Default level
  }

  void _selectLevel(BuildContext context, String code) async {
    final hiveService = ref.read(onboardingServiceProvider);
    await hiveService.setGuestLanguageLevel(code);

    if (!context.mounted) return;

    if (widget.isEditing) {
      // Editing mode: update and go back
      if (widget.isGuest) {
        // Guest: already saved to Hive above
      } else {
        // Logged in: update Supabase user metadata AND users table
        final client = Supabase.instance.client;
        final userId = client.auth.currentSession?.user.id;
        if (userId != null) {
          // Update user metadata
          await client.auth.updateUser(
            UserAttributes(data: {'language_level': code}),
          );
          // Update users table
          await client.from('users').update({'language_level': code}).eq('id', userId);
        }
      }
      if (context.mounted) Navigator.pop(context);
      return;
    }

    // Go to English variant selection
    if (context.mounted) {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => EnglishVariantPage(
            isGuest: widget.isGuest,
            isInitialSetup: widget.isInitialSetup,
            languageLevel: code,
            forceSelection: widget.forceSelection,
            returnAfterSelection: widget.returnAfterSelection,
          ),
        ),
      );

      // If returning after selection, propagate the result
      if (widget.returnAfterSelection && context.mounted) {
        Navigator.pop(context, result ?? true);
      }
    }
  }
}

class LanguageLevel {
  final String code;
  final String title;
  final String description;
  final IconData icon;

  const LanguageLevel({
    required this.code,
    required this.title,
    required this.description,
    required this.icon,
  });
}
