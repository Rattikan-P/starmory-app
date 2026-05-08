import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import 'onboarding_page.dart';
import 'auth/login_page.dart';
import 'language_selection_page.dart';
import 'english_variant_page.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  bool _isGuestMode = false;
  bool _isCheckingGuest = true;

  @override
  void initState() {
    super.initState();
    _checkGuestMode();
  }

  Future<void> _checkGuestMode() async {
    final hiveService = ref.read(onboardingServiceProvider);
    final isGuest = await hiveService.isGuestMode();
    if (mounted) {
      setState(() {
        _isGuestMode = isGuest;
        _isCheckingGuest = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    if (_isCheckingGuest) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: user == null
          ? _NotLoggedInView(isGuestMode: _isGuestMode)
          : _LoggedInView(user: user),
    );
  }
}

// Shared Preferences Widget
class _PreferencesSection extends ConsumerWidget {
  final String languageLevel;
  final String englishVariant;
  final bool isGuest;
  final VoidCallback? onPreferenceChanged;

  const _PreferencesSection({
    required this.languageLevel,
    required this.englishVariant,
    required this.isGuest,
    this.onPreferenceChanged,
  });

  String get variantName => englishVariant == 'UK' ? 'British English' : 'American English';
  String get variantFlag => englishVariant == 'UK' ? '🇬🇧' : '🇺🇸';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Language Proficiency Card
          Card(
            child: ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Language Proficiency'),
              subtitle: Text(languageLevel),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LanguageSelectionPage(
                      isGuest: isGuest,
                      isEditing: true,
                      isInitialSetup: false,
                    ),
                  ),
                );
                onPreferenceChanged?.call();
              },
            ),
          ),
          const SizedBox(height: 16),

          // English Variant Card
          Card(
            child: ListTile(
              leading: Text(variantFlag, style: const TextStyle(fontSize: 24)),
              title: const Text('English Variant'),
              subtitle: Text(variantName),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EnglishVariantPage(
                      isGuest: isGuest,
                      isEditing: true,
                      isInitialSetup: false,
                    ),
                  ),
                );
                onPreferenceChanged?.call();
              },
            ),
          ),
          const SizedBox(height: 16),

          // Settings
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to settings
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotLoggedInView extends ConsumerStatefulWidget {
  final bool isGuestMode;

  const _NotLoggedInView({required this.isGuestMode});

  @override
  ConsumerState<_NotLoggedInView> createState() => _NotLoggedInViewState();
}

class _NotLoggedInViewState extends ConsumerState<_NotLoggedInView> {
  String? _guestLanguageLevel;
  String? _guestEnglishVariant;

  @override
  void initState() {
    super.initState();
    if (widget.isGuestMode) {
      _loadGuestPreferences();
    }
  }

  Future<void> _loadGuestPreferences() async {
    final hiveService = ref.read(onboardingServiceProvider);
    final level = await hiveService.getGuestLanguageLevel();
    final variant = await hiveService.getGuestEnglishVariant();
    if (mounted) {
      setState(() {
        _guestLanguageLevel = level;
        _guestEnglishVariant = variant;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Non-guest: show simple login prompt
    if (!widget.isGuestMode) {
      return _buildLoginPrompt();
    }

    // Guest mode with preferences
    final theme = Theme.of(context);
    final languageLevel = _guestLanguageLevel ?? 'B1';
    final englishVariant = _guestEnglishVariant ?? 'US';

    return Column(
      children: [
        // Guest Header with register card
        Container(
          width: double.infinity,
          color: theme.colorScheme.surface,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Top bar with back button
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Register Prompt Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.1),
                          theme.colorScheme.primary.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Guest User badge inside the card
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Guest User',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Icon(
                          Icons.cloud_sync_outlined,
                          size: 32,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Save your progress',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Create an account to sync across devices',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LanguageSelectionPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.person_add),
                          label: const Text('Create Account'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),

        // Preferences Section (using shared widget)
        Expanded(
          child: _PreferencesSection(
            languageLevel: languageLevel,
            englishVariant: englishVariant,
            isGuest: true,
            onPreferenceChanged: _loadGuestPreferences,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginPrompt() {
    final theme = Theme.of(context);

    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_circle_outlined,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Not logged in',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to track your progress',
              style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
              icon: const Icon(Icons.login),
              label: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoggedInView extends ConsumerWidget {
  final User user;

  const _LoggedInView({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final displayName = user.userMetadata?['display_name'] ?? 'User';
    final email = user.email ?? '';
    final languageLevel = user.userMetadata?['language_level'] ?? 'B1';
    final englishVariant = user.userMetadata?['english_variant'] ?? 'US';

    return Column(
      children: [
        // Profile Header
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Top bar with back button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.white),
                        onPressed: () {
                          // TODO: Edit profile
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Avatar
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  child: Text(
                    displayName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Name
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                // Email
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // Preferences Section (using shared widget)
        Expanded(
          child: _PreferencesSection(
            languageLevel: languageLevel,
            englishVariant: englishVariant,
            isGuest: false,
          ),
        ),
        const SizedBox(height: 16),

        // Logout Button (separate for logged-in users)
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () async {
                // Sync preferences to guest before logout
                final client = Supabase.instance.client;
                final level = user.userMetadata?['language_level'];
                final variant = user.userMetadata?['english_variant'];

                final hiveService = ref.read(onboardingServiceProvider);
                if (level != null) await hiveService.setGuestLanguageLevel(level);
                if (variant != null) await hiveService.setGuestEnglishVariant(variant);

                await client.auth.signOut();
              },
              icon: const Icon(Icons.login),
              label: const Text('Logout'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
